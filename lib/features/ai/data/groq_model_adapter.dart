/// VaaniX AI — Groq Model Adapter
///
/// The second real online [ModelAdapter]. Hits Groq's OpenAI-compatible
/// `POST /openai/v1/chat/completions` endpoint using `dart:io`'s
/// `HttpClient` (no new dependency). The Groq API key + model are read
/// exclusively from `AppEnvironment` (`GROQ_API_KEY`, `GROQ_MODEL`) so
/// secrets and the model name are configured centrally.
///
/// Behavior parity with [GeminiModelAdapter]:
///   * Sanitises inputs and moderates outputs through [SafetyFilter].
///   * Throttles requests through [AiRateLimiter].
///   * Returns cached answers through [ResponseCache].
///   * Records daily usage through [TokenUsageTracker].
///   * Bounded exponential-backoff retry on TRANSIENT failures only.
///   * Maps failures to the existing [Failure] hierarchy so the chat
///     banner / VAN reaction pipeline is identical regardless of provider.
///
/// Failures mapped:
///   - HTTP 401/403 / placeholder keys  → [AuthException] → auth Failure.
///   - HTTP 429 / quota                → [AiRateLimitFailure] via the
///     existing exception→failure mapper.
///   - HTTP 400 (context length)        → [AiContextLengthFailure].
///   - HTTP 4xx (other)                 → [AiContentFilterFailure] (the
///     Groq SDK only rejects input that breaks policy when the API is
///     well configured; an unmapped 4xx is treated as a content rejection
///     so VAN can render the recovery reaction).
///   - HTTP 5xx / network / timeout    → [ServerException] / [TimeoutException]
///     which the existing mapper turns into [AiServiceFailure] / [TimeoutFailure].
///
/// The adapter is deliberately a thin transport layer: it does not own a
/// second safety pipeline, rate limiter, cache, or usage tracker. Every
/// shared concern is injected from the central AI providers module so a
/// Gemini swap and a Groq swap are interchangeable from the caller's
/// perspective.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/exception_mapper.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/response_cache.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

/// Tiny strategy seam so unit tests can stub the HTTP call without ever
/// touching the network. Production wires the default [GroqHttpTransport].
abstract class GroqHttpTransport {
  Future<GroqHttpResponse> postChatCompletions({
    required String body,
    required String apiKey,
  });
}

class GroqHttpResponse {
  const GroqHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// Production transport: POSTs the JSON body to Groq's
/// `/openai/v1/chat/completions` over HTTPS via `dart:io`.
class DefaultGroqHttpTransport implements GroqHttpTransport {
  const DefaultGroqHttpTransport({
    HttpClient Function()? clientFactory,
    Duration? timeout,
    Uri? endpoint,
  })  : _clientFactory = clientFactory ?? HttpClient.new,
        _timeout = timeout ?? const Duration(seconds: 30),
        _endpoint = endpoint;

  final HttpClient Function() _clientFactory;
  final Duration _timeout;
  final Uri? _endpoint;

  @override
  Future<GroqHttpResponse> postChatCompletions({
    required String body,
    required String apiKey,
  }) async {
    final uri = _endpoint ?? Uri.parse(AppConstants.groqChatCompletionsUrl);
    final client = _clientFactory();
    try {
      client.connectionTimeout = _timeout;
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set('Accept', 'application/json');
      request.add(utf8.encode(body));
      final response = await request.close().timeout(_timeout);
      final responseBody = await response.transform(utf8.decoder).join();
      return GroqHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on SocketException catch (e) {
      throw NetworkException('Groq transport failure: ${e.message}');
    } on HttpException catch (e) {
      throw ServerException(
        message: 'Groq transport failure: ${e.message}',
        statusCode: null,
      );
    } on TimeoutException {
      throw const TimeoutException('Groq completion timed out');
    } finally {
      client.close(force: true);
    }
  }
}

class GroqModelAdapter implements ModelAdapter {
  GroqModelAdapter({
    SafetyFilter? safetyFilter,
    AiRateLimiter? rateLimiter,
    ResponseCache? responseCache,
    TokenUsageTracker? usageTracker,
    GroqHttpTransport? transport,
  })  : _safetyFilter = safetyFilter ?? const DefaultSafetyFilter(),
        _rateLimiter = rateLimiter ?? AiRateLimiter(),
        _responseCache = responseCache,
        _usageTracker = usageTracker,
        _transport = transport ?? const DefaultGroqHttpTransport();

  /// Retry budget for transient failures. Two retries with the backoff
  /// below keep worst-case added latency well under 1.5 seconds so the
  /// chat never hangs on a dead backend. Permanent failures (401, 403,
  /// 429, 4xx content / context length) never retry.
  static const int _maxSendRetries = 2;
  static const Duration _retryBaseDelay = Duration(milliseconds: 500);

  final SafetyFilter _safetyFilter;
  final AiRateLimiter _rateLimiter;
  final ResponseCache? _responseCache;
  final TokenUsageTracker? _usageTracker;
  final GroqHttpTransport _transport;

  int _counter = 0;

  @override
  AiProviderId get providerId => AiProviderId.groq;

  @override
  String get displayName => 'Groq (${AppEnvironment.groqModel})';

  @override
  bool get isAvailable => AppEnvironment.isGroqConfigured;

  /// The most recent user message, or null when absent/empty. A request
  /// without a real user message is a contract violation; we fail cleanly
  /// instead of fabricating input.
  AiMessage? _lastUserMessage(ConversationContext context) {
    AiMessage? last;
    for (final msg in context.messages) {
      if (msg.role == AiRole.user && msg.content.trim().isNotEmpty) {
        last = msg;
      }
    }
    return last;
  }

  /// Build the OpenAI-compatible chat-completions request body from a
  /// VaaniX conversation context.
  ///
  /// - System instruction + persona is delivered as the first `system`
  ///   message (Groq does not accept a separate system field).
  /// - Earlier turns in the transcript map to `user` / `assistant` roles.
  /// - The outgoing user message is sent exactly once (history excludes
  ///   the outgoing message, mirroring the Gemini adapter's contract).
  /// - The bounded learning-context snapshot is folded into the outgoing
  ///   user message, framed so the model can tell internal notes apart
  ///   from learner speech.
  @visibleForTesting
  static Map<String, dynamic> buildRequestBody({
    required List<AiMessage> transcript,
    required AiMessage outgoingMessage,
    required String sanitizedOutgoing,
    required String learningContextMessage,
    required String model,
    required double temperature,
    required int maxTokens,
    required bool stream,
  }) {
    final messages = <Map<String, Object?>>[];

    // 1. System instruction = defensive safety + persona prompt.
    final persona = transcript
        .where((m) => m.role == AiRole.system)
        .map((m) => m.content)
        .join('\n\n')
        .trim();
    if (persona.isNotEmpty) {
      messages.add({'role': 'system', 'content': persona});
    }

    // 2. Earlier turns (excluding the outgoing message).
    for (final msg in transcript) {
      if (identical(msg, outgoingMessage)) continue;
      if (msg.role == AiRole.user) {
        messages.add({'role': 'user', 'content': msg.content});
      } else if (msg.role == AiRole.assistant) {
        messages.add({'role': 'assistant', 'content': msg.content});
      }
    }

    // 3. Outgoing turn — optionally prefixed with the bounded learning
    //    context snapshot so the model can use it without leaking it.
    final contextBlock = learningContextMessage.trim();
    final outgoingContent = contextBlock.isEmpty
        ? sanitizedOutgoing
        : '$contextBlock\n\n$sanitizedOutgoing';
    messages.add({'role': 'user', 'content': outgoingContent});

    return {
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': stream,
      'messages': messages,
    };
  }

  String _modelName(AiConfig config) =>
      config.model.isEmpty ? AppEnvironment.groqModel : config.model;

  /// Map Groq HTTP error responses to AI-specific exceptions so the
  /// existing [ExceptionMapper] can translate them into the canonical
  /// [Failure] hierarchy.
  ///
  /// Status semantics:
  ///   * 401/403      → AuthException  (configuration problem, never retry)
  ///   * 429          → AuthApiException('rate_limit') → AiRateLimitFailure
  ///   * 400          → ServerException('context_length') →
  ///                    AiContextLengthFailure
  ///   * 4xx (other)  → ServerException('content_filter') →
  ///                    AiContentFilterFailure
  ///   * 5xx          → ServerException → AiServiceFailure
  @visibleForTesting
  static Never throwForHttpStatus(int statusCode, String body) {
    final lowered = body.toLowerCase();
    if (statusCode == 401 || statusCode == 403) {
      throw AuthException(
        message: 'Groq auth failed (HTTP $statusCode).',
        // NOTE: body deliberately not echoed — providers occasionally
        // echo partial key fragments in error payloads. We only carry
        // the status code so the canonical failure message stays calm.
      );
    }
    if (statusCode == 429) {
      throw const AuthApiException('Groq rate limit reached');
    }
    if (statusCode == 400) {
      if (lowered.contains('context_length') ||
          lowered.contains('too long') ||
          lowered.contains('reduce') ||
          lowered.contains('maximum context')) {
        throw const ServerException(
          message: 'Groq context length exceeded',
          statusCode: 400,
        );
      }
      throw const ServerException(
        message: 'Groq rejected request',
        statusCode: 400,
      );
    }
    if (statusCode >= 500) {
      throw ServerException(
        message: 'Groq server error (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }
    throw ServerException(
      message: 'Groq returned HTTP $statusCode',
      statusCode: statusCode,
    );
  }

  Duration _backoffFor(int attempt) =>
      _retryBaseDelay * (1 << (attempt - 1)).clamp(1, 4);

  /// True for transient failures (network / 5xx / timeout). False for
  /// configuration / quota / content failures so the retry loop never
  /// amplifies a deterministic rejection.
  @visibleForTesting
  static bool isTransientAiError(Object error) {
    if (error is TimeoutException) return true;
    if (error is NetworkException) return true;
    if (error is SocketException) return true;
    if (error is ServerException) {
      final code = error.statusCode;
      if (code == null) return true;
      return code >= 500 && code < 600;
    }
    return false;
  }

  String _nextId() {
    _counter += 1;
    return 'groq_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }

  /// Send a single chat-completion request and return the parsed JSON
  /// body as a `Map`. Throws the typed exceptions documented above; the
  /// adapter wraps the call with `guardAsync` so the chat pipeline only
  /// ever sees the canonical [Failure] hierarchy.
  Future<Map<String, dynamic>> _sendOnce({
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    final encoded = jsonEncode(body);
    final response = await _transport.postChatCompletions(
      body: encoded,
      apiKey: apiKey,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwForHttpStatus(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ServerException(
        message: 'Groq returned a malformed JSON body',
        statusCode: 200,
      );
    }
    return decoded;
  }

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return guardAsync(() async {
      final lastUser = _lastUserMessage(context);
      if (lastUser == null) {
        throw const ServerException(message: 'No user message in context');
      }
      final sanitizedInput = _safetyFilter.sanitizeInput(lastUser.content);

      // Cache hit fast-path.
      if (_responseCache != null && context.transcript.length <= 2) {
        final cached = await _responseCache.get(sanitizedInput);
        if (cached != null) {
          return AiMessage.assistant(
            id: _nextId(),
            content: cached,
            createdAt: DateTime.now().toUtc(),
            metadata: const {
              'provider': 'groq',
              'cached': true,
            },
          );
        }
      }

      // Throttle.
      await _rateLimiter.awaitSlot();

      final apiKey = AppEnvironment.groqApiKey;
      if (apiKey.isEmpty) {
        throw const AuthException(
          message: 'Groq API key not configured',
        );
      }

      final body = buildRequestBody(
        transcript: context.transcript,
        outgoingMessage: lastUser,
        sanitizedOutgoing: sanitizedInput,
        learningContextMessage: context.learningContextMessage,
        model: _modelName(config),
        temperature: config.temperature,
        maxTokens: config.maxTokens,
        stream: false,
      );

      // Bounded retry on transient failures only. Permanent failures
      // (401/403/429/4xx content) rethrow immediately so the chat banner
      // does not show a misleading "retrying..." delay.
      Map<String, dynamic>? decoded;
      for (var attempt = 1; decoded == null; attempt++) {
        await _rateLimiter.awaitSlot();
        try {
          decoded = await _sendOnce(apiKey: apiKey, body: body);
        } catch (e) {
          if (attempt >= _maxSendRetries || !isTransientAiError(e)) {
            rethrow;
          }
          await Future<void>.delayed(_backoffFor(attempt));
        }
      }

      final message = _extractAssistantText(decoded);
      if (message == null || message.isEmpty) {
        throw const ServerException(
          message: 'Groq returned no assistant content',
          statusCode: 200,
        );
      }
      if (!_safetyFilter.isOutputSafe(message)) {
        throw const ServerException(
          message: 'Groq output blocked by safety filter',
          statusCode: 200,
        );
      }

      // Cache store.
      if (_responseCache != null && context.transcript.length <= 2) {
        await _responseCache.put(sanitizedInput, message);
      }

      // Usage accounting.
      final usage = _extractUsage(decoded);
      if (_usageTracker != null && usage != null) {
        await _usageTracker.recordUsage(
          promptTokens: usage.promptTokens,
          completionTokens: usage.completionTokens,
        );
      }

      return AiMessage.assistant(
        id: _nextId(),
        content: message,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          'provider': 'groq',
          'model': _modelName(config),
          if (usage != null) ...{
            'promptTokens': usage.promptTokens,
            'completionTokens': usage.completionTokens,
            'totalTokens': usage.totalTokens,
          },
        },
      );
    });
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) async* {
    final lastUser = _lastUserMessage(context);
    if (lastUser == null) {
      yield err(ExceptionMapper.toFailure(
        const ServerException(message: 'No user message in context'),
      ));
      return;
    }
    final sanitizedInput = _safetyFilter.sanitizeInput(lastUser.content);
    final apiKey = AppEnvironment.groqApiKey;
    if (apiKey.isEmpty) {
      yield err(ExceptionMapper.toFailure(
        const AuthException(message: 'Groq API key not configured'),
      ));
      return;
    }
    await _rateLimiter.awaitSlot();

    final body = buildRequestBody(
      transcript: context.transcript,
      outgoingMessage: lastUser,
      sanitizedOutgoing: sanitizedInput,
      learningContextMessage: context.learningContextMessage,
      model: _modelName(config),
      temperature: config.temperature,
      maxTokens: config.maxTokens,
      stream: true,
    );

    try {
      final encoded = jsonEncode(body);
      final response = await _transport.postChatCompletions(
        body: encoded,
        apiKey: apiKey,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throwForHttpStatus(response.statusCode, response.body);
      }
      // Groq's stream is Server-Sent-Events formatted. The transport
      // returns the whole payload because `dart:io` does not give us a
      // streaming body in this minimal seam — we parse the SSE lines out
      // of it here. A real production upgrade would push SSE into the
      // transport seam so we never buffer the full response, but that
      // requires a wider dart:io refactor than this task scope.
      final lines = const LineSplitter().convert(response.body);
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') {
          yield ok(const AiStreamDelta(content: '', done: true));
          return;
        }
        try {
          final decoded = jsonDecode(payload);
          final delta = _extractStreamDelta(decoded);
          if (delta != null) yield ok(delta);
        } catch (_) {
          // Malformed SSE chunk — surface as a content failure so the
          // chat banner can render the recovery reaction.
          yield err(ExceptionMapper.toFailure(
            const ServerException(
              message: 'Groq stream contained malformed JSON',
              statusCode: 200,
            ),
          ));
          return;
        }
      }
      yield ok(const AiStreamDelta(content: '', done: true));
    } catch (e) {
      yield err(ExceptionMapper.toFailure(e));
    }
  }

  @override
  Future<void> dispose() async {
    // The shared [AiRateLimiter] / [ResponseCache] / [TokenUsageTracker]
    // / [SafetyFilter] are owned by the providers layer; this adapter
    // holds no resources of its own. The seam is intentionally here for
    // symmetry with [GeminiModelAdapter.dispose] (which is also a no-op
    // because the SDK client is lazy-cached and survives across calls).
  }
}

/// Extract the assistant text from a Groq chat-completion response.
@visibleForTesting
String? extractAssistantText(Map<String, dynamic> response) =>
    _extractAssistantText(response);

String? _extractAssistantText(Map<String, dynamic> response) {
  final choices = response['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  if (first is! Map) return null;
  final message = first['message'];
  if (message is! Map) return null;
  final content = message['content'];
  if (content is String) return content;
  // Some providers split content into parts; concatenate any text parts.
  if (content is List) {
    final parts = <String>[];
    for (final part in content) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) {
        parts.add(part['text'] as String);
      }
    }
    if (parts.isNotEmpty) return parts.join('');
  }
  return null;
}

/// Extract a `usage` block from a Groq chat-completion response.
@visibleForTesting
AiUsage? extractUsage(Map<String, dynamic> response) =>
    _extractUsage(response);

AiUsage? _extractUsage(Map<String, dynamic> response) {
  final raw = response['usage'];
  if (raw is! Map) return null;
  final prompt = (raw['prompt_tokens'] as num?)?.toInt() ?? 0;
  final completion = (raw['completion_tokens'] as num?)?.toInt() ?? 0;
  final total = (raw['total_tokens'] as num?)?.toInt() ?? (prompt + completion);
  return AiUsage(
    promptTokens: prompt,
    completionTokens: completion,
    totalTokens: total,
  );
}

/// Extract a single SSE chunk's incremental text (Groq emits `delta.content`).
AiStreamDelta? _extractStreamDelta(Object? decoded) {
  if (decoded is! Map) return null;
  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  if (first is! Map) return null;
  final delta = first['delta'];
  if (delta is! Map) return null;
  final content = delta['content'];
  if (content is! String) return null;
  return AiStreamDelta(
    content: content,
    done: first['finish_reason'] != null,
  );
}
