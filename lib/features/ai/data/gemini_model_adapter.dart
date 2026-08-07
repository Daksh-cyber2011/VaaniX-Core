/// VaaniX AI — Gemini Model Adapter
///
/// The first real online [ModelAdapter]. Uses Google's `google_generative_ai`
/// SDK to call Gemini 1.5 Flash. Falls back to [OfflineModelAdapter] when
/// no API key is configured.
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
/// - Rate limit → [AiRateLimitFailure]
/// - Content filter → [AiContentFilterFailure]
/// - Context length → [AiContextLengthFailure]
/// - Other → [AiServiceFailure]

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

  final SafetyFilter _safetyFilter;
  final AiRateLimiter _rateLimiter;
  final ResponseCache? _responseCache;
  final TokenUsageTracker? _usageTracker;

  GenerativeModel? _model;
  int _counter = 0;

  @override
  AiProviderId get providerId => AiProviderId.gemini;

  @override
  String get displayName => 'Gemini 1.5 Flash';

  @override
  bool get isAvailable => AppEnvironment.isGeminiConfigured;

  /// Lazily initialize the Gemini model with the API key + system instruction.
  GenerativeModel _getModel(AiConfig config) {
    if (_model != null) return _model!;

    final apiKey = AppEnvironment.geminiApiKey;
    if (apiKey.isEmpty) {
      throw StateError('Gemini API key not configured');
    }

    _model = GenerativeModel(
      model: config.model.isEmpty ? 'gemini-1.5-flash' : config.model,
      apiKey: apiKey,
      systemInstruction: Content.system(_safetyFilter.defensiveSystemPrompt()),
      generationConfig: GenerationConfig(
        temperature: config.temperature,
        maxOutputTokens: config.maxTokens,
        topP: config.topP,
      ),
    );
    return _model!;
  }

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return guardAsync(() async {
      // Extract the latest user message.
      final lastUserMsg = context.messages.lastWhere(
        (m) => m.role == AiRole.user,
        orElse: () => AiMessage.user(id: 'temp', content: 'नमस्ते'),
      );
      final sanitizedInput = _safetyFilter.sanitizeInput(lastUserMsg.content);

      // ── Cache check ────────────────────────────────────────────────
      // Only cache if this looks like a standalone question (not a
      // follow-up in a long conversation). We check if the transcript
      // is short enough that the question makes sense in isolation.
      if (_responseCache != null && context.transcript.length <= 2) {
        final cached = await _responseCache!.get(sanitizedInput);
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

      // ── Rate limiting ──────────────────────────────────────────────
      // Wait for an available slot before sending (stays under 15 RPM).
      await _rateLimiter.awaitSlot();

      final model = _getModel(config);

      // Build the conversation history for Gemini.
      final history = <Content>[];
      for (final msg in context.transcript) {
        if (msg.role == AiRole.user) {
          history.add(Content.text(_safetyFilter.sanitizeInput(msg.content)));
        } else if (msg.role == AiRole.assistant) {
          history.add(Content.model([TextPart(msg.content)]));
        }
      }

      // Start a chat session with history.
      final chat = model.startChat(history: history);
      final response = await chat.sendMessage(Content.text(sanitizedInput));

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        throw const AiContentFilterFailure();
      }

      // Moderate the output.
      if (!_safetyFilter.isOutputSafe(responseText)) {
        throw const AiContentFilterFailure();
      }

      // ── Cache store ────────────────────────────────────────────────
      // Cache the Q&A pair for future reuse.
      if (_responseCache != null && context.transcript.length <= 2) {
        await _responseCache!.put(sanitizedInput, responseText);
      }

      // Extract usage metadata if available.
      final usage = response.usageMetadata;
      final promptTokens = usage?.promptTokenCount ?? 0;
      final completionTokens = usage?.candidatesTokenCount ?? 0;

      // ── Usage tracking ─────────────────────────────────────────────
      if (_usageTracker != null && usage != null) {
        await _usageTracker!.recordUsage(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
      }

      final metadata = <String, dynamic>{
        'provider': 'gemini',
        'model': config.model.isEmpty ? 'gemini-1.5-flash' : config.model,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'totalTokens': usage?.totalTokenCount ?? (promptTokens + completionTokens),
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
    try {
      // Rate limiting before streaming.
      await _rateLimiter.awaitSlot();

      final model = _getModel(config);

      // Build history.
      final history = <Content>[];
      for (final msg in context.transcript) {
        if (msg.role == AiRole.user) {
          history.add(Content.text(_safetyFilter.sanitizeInput(msg.content)));
        } else if (msg.role == AiRole.assistant) {
          history.add(Content.model([TextPart(msg.content)]));
        }
      }

      final chat = model.startChat(history: history);

      final lastUserMsg = context.messages.lastWhere(
        (m) => m.role == AiRole.user,
        orElse: () => AiMessage.user(id: 'temp', content: 'नमस्ते'),
      );

      final sanitizedInput = _safetyFilter.sanitizeInput(lastUserMsg.content);
      final responseStream = chat.sendMessageStream(Content.text(sanitizedInput));

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
    final msg = error.toString().toLowerCase();

    if (msg.contains('rate limit') || msg.contains('429') || msg.contains('quota')) {
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
