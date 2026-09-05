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
/// Error mapping: Gemini SDK exceptions are caught by [guardAsync] and
/// mapped to AI-specific Failure types via [ExceptionMapper]:
/// - Rate limit  [AiRateLimitFailure]
/// - Content filter  [AiContentFilterFailure]
/// - Context length  [AiContextLengthFailure]
/// - Timeout  [TimeoutFailure]
/// - Other  [AiServiceFailure]
library;

import 'dart:async';

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
      final response = await chat.sendMessage(Content.text(outgoing)).timeout(
                _requestTimeout,
                onTimeout: () => throw TimeoutException(
                  'Gemini completion timed out',
                ),
              );

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
      // Rate limiting before streaming.
      await _rateLimiter.awaitSlot();

      final model = _getModel(config, context);

      // Build history (excluding the outgoing message).
      final history = buildRequestHistory(
        transcript: context.transcript,
        outgoingMessage: lastUserMsg,
        sanitize: _safetyFilter.sanitizeInput,
      );

      final chat = model.startChat(history: history);

      final outgoing = composeOutgoingMessage(
        sanitizedUserText: _safetyFilter.sanitizeInput(lastUserMsg.content),
        learningContextMessage: context.learningContextMessage,
      );
      final responseStream = chat
          .sendMessageStream(Content.text(outgoing))
          .timeout(_requestTimeout);

      await for (final response in responseStream) {
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          // Moderate each chunk.
          if (!_safetyFilter.isOutputSafe(text)) {
            yield err(const AiContentFilterFailure());
            return;
          }
          yield ok(AiStreamDelta(content: text));
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
    return AiServiceFailure(msg);
  }

  String _nextId() {
    _counter += 1;
    return 'gemini_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
