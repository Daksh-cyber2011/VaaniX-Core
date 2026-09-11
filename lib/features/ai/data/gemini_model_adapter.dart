/// VaaniX AI - Gemini Model Adapter
///
/// The first real online [ModelAdapter]. Uses Google's `google_generative_ai`
/// SDK to call Gemini. Falls back to [OfflineModelAdapter] when no API key
/// is configured. The model name is configurable via
/// [AppEnvironment.geminiModel] (GEMINI_MODEL env, default
/// [AppConstants.defaultGeminiModel]).
///
/// Safety: All inputs are sanitized by [SafetyFilter] before being sent to
/// Gemini, and all outputs are moderated by [SafetyFilter] before being
/// returned to the caller. The [SafetyFilter.defensiveSystemPrompt] is
/// prepended to every persona prompt.
///
/// Quota optimization (Segment 7.5):
///   - [AiRateLimiter] throttles requests to stay under 15 RPM.
///   - [ResponseCache] returns cached answers for repeated questions
///     (40-60% API call reduction for a learning app).
///   - [TokenUsageTracker] records daily token usage for visibility.
///
/// Retry policy (Phase 10): transient online failures (timeouts, network
/// drops, 5xx server errors) are retried up to [_maxSendRetries] times with
/// bounded exponential backoff. PERMANENT failures are never retried:
/// invalid API keys, unsupported locations, rate-limit/quota responses (the
/// rate limiter owns those; retrying would amplify the storm), content
/// blocks, and malformed requests.
///
/// Error mapping: Gemini SDK exceptions are caught by [guardAsync] and
/// mapped to AI-specific Failure types via [ExceptionMapper]:
/// - Rate limit  [AiRateLimitFailure]
/// - Content filter  [AiContentFilterFailure]
/// - Context length  [AiContextLengthFailure]
/// - Timeout  [TimeoutFailure]
/// - Other  [AiServiceFailure]
library;

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/response_cache.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

class GeminiModelAdapter implements ModelAdapter {
  GeminiModelAdapter({
    SafetyFilter? safetyFilter,
    AiRateLimiter? rateLimiter,
    ResponseCache? responseCache,
    TokenUsageTracker? usageTracker,
  })  : _safetyFilter = safetyFilter ?? const DefaultSafetyFilter(),
        _rateLimiter = rateLimiter ?? AiRateLimiter(),
        _responseCache = responseCache,
        _usageTracker = usageTracker;

  /// Hard ceiling for a single non-streaming completion request.
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Retry budget for transient failures per request. Two retries with the
  /// backoff below keep the worst-case added latency under ~1.5s of sleep,
  /// so the chat never hangs on a dead backend.
  static const int _maxSendRetries = 2;

  /// Base delay for the exponential backoff (500ms, 1000ms).
  static const Duration _retryBaseDelay = Duration(milliseconds: 500);

  final SafetyFilter _safetyFilter;
  final AiRateLimiter _rateLimiter;
  final ResponseCache? _responseCache;
  final TokenUsageTracker? _usageTracker;

  GenerativeModel? _model;
  String? _modelSystemInstruction;
  int _counter = 0;

  @override
  AiProviderId get providerId => AiProviderId.gemini;

  @override
  String get displayName => 'Gemini (${AppEnvironment.geminiModel})';

  @override
  bool get isAvailable => AppEnvironment.isGeminiConfigured;

  /// Resolves the model name: request override wins, then env/default.
  String _modelName(AiConfig config) =>
      config.model.isEmpty ? AppEnvironment.geminiModel : config.model;

  /// The full system instruction for a request: the defensive safety
  /// prompt PLUS the stable persona prompt built by the [PromptPipeline].
  /// Phase 4: the per-turn learning-context snapshot no longer rides in
  /// the persona, so this instruction — and the [GenerativeModel] built
  /// from it — stays identical across turns and the client is reused
  /// instead of rebuilt on every request. The learning snapshot travels
  /// as framed message content (see [composeOutgoingMessage]).
  String _systemInstructionFor(ConversationContext context) {
    final defensive = _safetyFilter.defensiveSystemPrompt();
    final persona = context.personaPrompt.trim();
    if (persona.isEmpty) return defensive;
    return '$defensive\n\n$persona';
  }

  /// Lazily initialize the Gemini model with the API key + system instruction.
  /// Because the system instruction is stable across turns (Phase 4), the
  /// cached instance is reused for the lifetime of the adapter; it is only
  /// rebuilt when the model name or instruction genuinely changes.
  GenerativeModel _getModel(AiConfig config, ConversationContext context) {
    final systemInstruction = _systemInstructionFor(context);
    if (_model != null && _modelSystemInstruction == systemInstruction) {
      return _model!;
    }

    final apiKey = AppEnvironment.geminiApiKey;
    if (apiKey.isEmpty) {
      throw StateError('Gemini API key not configured');
    }

    _model = GenerativeModel(
      model: _modelName(config),
      apiKey: apiKey,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: GenerationConfig(
        temperature: config.temperature,
        maxOutputTokens: config.maxTokens,
        topP: config.topP,
      ),
    );
    _modelSystemInstruction = systemInstruction;
    return _model!;
  }

  /// The most recent user message, or null when absent/empty. The adapter
  /// never fabricates input: a request without a real user message is a
  /// contract violation and fails cleanly instead of sending garbage.
  AiMessage? _lastUserMessage(ConversationContext context) {
    AiMessage? last;
    for (final message in context.messages) {
      if (message.role == AiRole.user && message.content.trim().isNotEmpty) {
        last = message;
      }
    }
    return last;
  }

  /// Builds the Gemini chat history from the transcript.
  ///
  /// The outgoing user message ([outgoingMessage]) is EXCLUDED — it is
  /// passed to `sendMessage` as the new turn. Previously the history
  /// contained it too, so the model saw the learner's message twice per
  /// request (duplicated tokens and a duplicated prompt).
  ///
  /// @visibleForTesting static so request-shaping regressions are testable
  /// without network access.
  @visibleForTesting
  static List<Content> buildRequestHistory({
    required List<AiMessage> transcript,
    required AiMessage outgoingMessage,
    required String Function(String) sanitize,
  }) {
    final history = <Content>[];
    for (final msg in transcript) {
      if (identical(msg, outgoingMessage)) continue;
      if (msg.role == AiRole.user) {
        history.add(Content.text(sanitize(msg.content)));
      } else if (msg.role == AiRole.assistant) {
        history.add(Content.model([TextPart(msg.content)]));
      }
    }
    return history;
  }

  /// Composes the outgoing user-turn content: the framed learning-context
  /// message (internal progress notes, when present) followed by the
  /// sanitized learner text. Delivered as MESSAGE content — never merged
  /// into the system instruction — so the instruction stays stable and
  /// the model can tell internal notes apart from learner speech.
  @visibleForTesting
  static String composeOutgoingMessage({
    required String sanitizedUserText,
    required String learningContextMessage,
  }) {
    final contextMessage = learningContextMessage.trim();
    if (contextMessage.isEmpty) return sanitizedUserText;
    return '$contextMessage\n\n$sanitizedUserText';
  }

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return guardAsync(() async {
      final lastUserMsg = _lastUserMessage(context);
      if (lastUserMsg == null) {
        throw const AiServiceFailure('No user message in context');
      }
      final sanitizedInput = _safetyFilter.sanitizeInput(lastUserMsg.content);

      // Cache check.
      // Only cache if this looks like a standalone question (not a
      // follow-up in a long conversation). We check if the transcript
      // is short enough that the question makes sense in isolation.
      if (_responseCache != null && context.transcript.length <= 2) {
        final cached = await _responseCache.get(sanitizedInput);
        if (cached != null) {
          // Cache hit! Return instantly without consuming API quota.
          return AiMessage.assistant(
            id: _nextId(),
            content: cached,
            createdAt: DateTime.now().toUtc(),
            metadata: const {
              'provider': 'gemini',
              'cached': true,
            },
          );
        }
      }

      // Rate limiting.
      // Wait for an available slot before sending (stays under 15 RPM).
      await _rateLimiter.awaitSlot();

      final model = _getModel(config, context);

      // Build the conversation history for Gemini (excluding the outgoing
      // message — it is sent as the new turn below, not duplicated).
      final history = buildRequestHistory(
        transcript: context.transcript,
        outgoingMessage: lastUserMsg,
        sanitize: _safetyFilter.sanitizeInput,
      );

      // Start a chat session with history.
      final chat = model.startChat(history: history);
      final outgoing = composeOutgoingMessage(
        sanitizedUserText: sanitizedInput,
        learningContextMessage: context.learningContextMessage,
      );
      // Bounded retry for transient failures. A failed attempt never
      // mutates the client-side chat history, so re-sending on the same
      // session is safe. Each attempt re-awaits a rate-limiter slot so a
      // retry chain can never bypass the pacing contract.
      GenerateContentResponse? response;
      for (var attempt = 0; response == null; attempt++) {
        await _rateLimiter.awaitSlot();
        try {
          response = await chat.sendMessage(Content.text(outgoing)).timeout(
                _requestTimeout,
                onTimeout: () => throw TimeoutException(
                  'Gemini completion timed out',
                ),
              );
        } catch (e) {
          if (attempt >= _maxSendRetries || !isTransientAiError(e)) rethrow;
          await Future<void>.delayed(_backoffFor(attempt + 1));
        }
      }

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        throw const AiContentFilterFailure();
      }

      // Moderate the output.
      if (!_safetyFilter.isOutputSafe(responseText)) {
        throw const AiContentFilterFailure();
      }

      // Cache store.
      // Cache the Q&A pair for future reuse.
      if (_responseCache != null && context.transcript.length <= 2) {
        await _responseCache.put(sanitizedInput, responseText);
      }

      // Extract usage metadata if available.
      final usage = response.usageMetadata;
      final promptTokens = usage?.promptTokenCount ?? 0;
      final completionTokens = usage?.candidatesTokenCount ?? 0;

      // Usage tracking.
      if (_usageTracker != null && usage != null) {
        await _usageTracker.recordUsage(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
      }

      final metadata = <String, dynamic>{
        'provider': 'gemini',
        'model': _modelName(config),
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'totalTokens':
            usage?.totalTokenCount ?? (promptTokens + completionTokens),
      };

      return AiMessage.assistant(
        id: _nextId(),
        content: responseText,
        createdAt: DateTime.now().toUtc(),
        metadata: metadata,
      );
    });
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) async* {
    final lastUserMsg = _lastUserMessage(context);
    if (lastUserMsg == null) {
      yield err(const AiServiceFailure('No user message in context'));
      return;
    }
    try {
      // Rate limiting before the first (and any retry) attempt.
      await _rateLimiter.awaitSlot();

      final model = _getModel(config, context);

      // Build history (excluding the outgoing message).
      final history = buildRequestHistory(
        transcript: context.transcript,
        outgoingMessage: lastUserMsg,
        sanitize: _safetyFilter.sanitizeInput,
      );

      final outgoing = composeOutgoingMessage(
        sanitizedUserText: _safetyFilter.sanitizeInput(lastUserMsg.content),
        learningContextMessage: context.learningContextMessage,
      );

      // Bounded retry ONLY before the first delta reaches the caller:
      // once the learner has seen content, failing mid-stream surfaces an
      // error (the partial bubble is withdrawn by the chat controller).
      var yieldedAny = false;
      var attempt = 0;
      while (true) {
        final chat = model.startChat(history: history);
        final responseStream = chat
            .sendMessageStream(Content.text(outgoing))
            .timeout(_requestTimeout);
        try {
          await for (final response in responseStream) {
            final text = response.text;
            if (text != null && text.isNotEmpty) {
              // Moderate each chunk.
              if (!_safetyFilter.isOutputSafe(text)) {
                yield err(const AiContentFilterFailure());
                return;
              }
              yieldedAny = true;
              yield ok(AiStreamDelta(content: text));
            }
          }
          break; // stream completed normally
        } catch (e) {
          if (yieldedAny || attempt >= _maxSendRetries ||
              !isTransientAiError(e)) {
            rethrow;
          }
          attempt++;
          await Future<void>.delayed(_backoffFor(attempt));
          await _rateLimiter.awaitSlot();
        }
      }

      // Final delta signals completion.
      yield ok(const AiStreamDelta(content: '', done: true));
    } catch (e) {
      yield err(_mapException(e));
    }
  }

  @override
  void dispose() {
    _model = null;
  }

  /// True when [error] is a TRANSIENT failure worth retrying: timeouts,
  /// network drops, and 5xx server-side errors (the SDK surfaces those as
  /// [ServerException] with a message).
  ///
  /// Permanent failures MUST NOT be retried:
  ///   - [InvalidApiKey] / [UnsupportedUserLocation] (configuration),
  ///   - rate-limit / quota responses (retrying amplifies the storm — the
  ///     AiRateLimiter already paces requests),
  ///   - safety blocks and malformed requests.
  @visibleForTesting
  static bool isTransientAiError(Object error) {
    if (error is TimeoutException || error is SocketException) return true;
    if (error is InvalidApiKey) return false;
    if (error is UnsupportedUserLocation) return false;

    final msg = error.toString().toLowerCase();

    // Configuration / auth problems: permanent.
    if (msg.contains('api key') ||
        msg.contains('api_key') ||
        msg.contains('permission') ||
        msg.contains('unauthenticated')) {
      return false;
    }
    // Quota: the limiter owns pacing; a retry would make it worse.
    if (msg.contains('429') ||
        msg.contains('rate limit') ||
        msg.contains('quota') ||
        msg.contains('resource_exhausted')) {
      return false;
    }
    // Safety / content policy: deterministic rejection, not transient.
    if (msg.contains('blocked') || msg.contains('content filter')) {
      return false;
    }
    // Server-side trouble: transient.
    if (msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('internal error') ||
        msg.contains('overloaded') ||
        msg.contains('unavailable') ||
        msg.contains('server error') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('failed host lookup')) {
      return true;
    }
    return false;
  }

  Duration _backoffFor(int attempt) =>
      _retryBaseDelay * (1 << (attempt - 1)).clamp(1, 4);

  /// Map Gemini SDK exceptions to AI-specific Failures.
  Failure _mapException(Object error) {
    if (error is TimeoutException) return const TimeoutFailure();
    final msg = error.toString().toLowerCase();

    if (msg.contains('rate limit') ||
        msg.contains('429') ||
        msg.contains('quota')) {
      return const AiRateLimitFailure();
    }
    if (msg.contains('content filter') ||
        msg.contains('safety') ||
        msg.contains('blocked')) {
      return const AiContentFilterFailure();
    }
    if (msg.contains('context length') ||
        msg.contains('too long') ||
        msg.contains('token limit')) {
      return const AiContextLengthFailure();
    }
    // Unmapped SDK errors must never leak raw exception text (host names,
    // stack fragments) into the chat banner — serve the calm, canonical
    // message. The underlying error is still visible to crash reporting.
    return const AiServiceFailure();
  }

  String _nextId() {
    _counter += 1;
    return 'gemini_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
