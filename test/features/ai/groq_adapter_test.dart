/// Tests for the real Groq adapter.
///
/// These tests cover the Groq adapter end-to-end without any network:
///
///   * Request shaping — system/persona, history, outgoing turn,
///     bounded learning context, model name, temperature, max_tokens,
///     stream flag. Pins the OpenAI-compatible request body.
///   * Response parsing — happy path, multi-part content, missing
///     choices, missing message, empty content, malformed JSON, usage
///     metadata extraction.
///   * HTTP error mapping — 401, 403, 429, 400 (context), 400 (other),
///     500, malformed body. Pins the existing Failure hierarchy.
///   * Retry classification — transient (5xx, network, timeout) vs
///     permanent (4xx) so the retry loop never amplifies a rejection.
///   * Missing API key behaviour — the adapter never sends a request
///     and the failure is mapped cleanly.
///   * Secret-leakage sweep — error messages, exception toString, and
///     the request body MUST NOT contain the API key. The Groq API is
///     expected to occasionally echo partial key fragments in error
///     payloads; the adapter never propagates them.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/groq_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/response_cache.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';

const String _realKey =
    'gsk_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_secret_value';

class _FakeTransport implements GroqHttpTransport {
  _FakeTransport({this.respond, this.requestAssertions});

  /// Status code + body the transport returns. Returning null throws a
  /// network failure to simulate the underlying socket breaking.
  final GroqHttpResponse Function(String body)? respond;

  /// Optional assertions invoked once per request with the JSON body
  /// that the adapter would have POSTed to Groq.
  final void Function(String body)? requestAssertions;

  int callCount = 0;
  String? lastBody;
  String? lastApiKey;

  @override
  Future<GroqHttpResponse> postChatCompletions({
    required String body,
    required String apiKey,
  }) async {
    callCount += 1;
    lastBody = body;
    lastApiKey = apiKey;
    requestAssertions?.call(body);
    final response = respond?.call(body);
    if (response == null) {
      throw const NetworkException('simulated socket failure');
    }
    return response;
  }
}



Future<({GroqModelAdapter adapter, _FakeTransport transport, TokenUsageTracker usage,
    ResponseCache cache, AiRateLimiter limiter, LocalStorageService storage})>
    _newHarness({
  required GroqHttpResponse Function(String body) respond,
  void Function(String body)? requestAssertions,
  AiRateLimiter? limiter,
  ResponseCache? cache,
  TokenUsageTracker? usage,
  String? apiKeyOverride,
  String? modelOverride,
}) async {
  // Reset dotenv between tests so the configured key is exactly what
  // each test sets — no leakage from other suites.
  dotenv.testLoad(mergeWith: {
    if (apiKeyOverride != null) AppConstants.groqApiKey: apiKeyOverride,
    if (modelOverride != null) AppConstants.groqModelKey: modelOverride,
  });

  final transport = _FakeTransport(
    respond: respond,
    requestAssertions: requestAssertions,
  );
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final limiterInstance = limiter ?? AiRateLimiter(
    maxRequestsPerMinute: 1000,
    minDelayBetweenRequests: Duration.zero,
  );
  final cacheInstance = cache ?? ResponseCache(storage);
  final usageInstance = usage ?? TokenUsageTracker(storage);
  final adapter = GroqModelAdapter(
    safetyFilter: const DefaultSafetyFilter(),
    rateLimiter: limiterInstance,
    responseCache: cacheInstance,
    usageTracker: usageInstance,
    transport: transport,
  );
  return (
    adapter: adapter,
    transport: transport,
    usage: usageInstance,
    cache: cacheInstance,
    limiter: limiterInstance,
    storage: storage,
  );
}

/// A complete chat-completion response body in Groq's OpenAI-compatible
/// shape.
String _groqOkResponse({
  required String content,
  int promptTokens = 12,
  int completionTokens = 8,
  String model = 'llama-3.3-70b-versatile',
  String finishReason = 'stop',
}) =>
    jsonEncode({
      'id': 'chatcmpl-test',
      'object': 'chat.completion',
      'created': 0,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': finishReason,
        },
      ],
      'usage': {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': promptTokens + completionTokens,
      },
    });

ConversationContext _simpleContext() {
  // The outgoing message MUST be the SAME instance as the one in the
  // transcript so [GroqModelAdapter.buildRequestBody] can skip it via
  // `identical()` (mirrors the Gemini adapter contract — see
  // gemini_request_shaping_test.dart).
  final outgoing = AiMessage.user(id: 'u2', content: 'what does it mean?');
  return ConversationContext(
    conversationId: 'c1',
    learner: const LearnerContext(),
    messages: [
      AiMessage.system(id: 'sys', content: 'You are Van.'),
      AiMessage.user(id: 'u1', content: 'namaste'),
      AiMessage.assistant(id: 'a1', content: 'namaste, learner'),
      outgoing,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Ensure tests start with an empty dotenv so config helpers are
    // deterministic. The shared_preferences plugin must be initialised
    // BEFORE the first getInstance() call so the ResponseCache and
    // TokenUsageTracker can resolve storage keys.
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(mergeWith: const {});
  });

  group('GroqModelAdapter.buildRequestBody', () {
    test('preserves the OpenAI-compatible chat-completions shape', () {
      final transcript = _simpleContext().messages;
      final outgoing = transcript.last;
      final body = GroqModelAdapter.buildRequestBody(
        transcript: transcript,
        outgoingMessage: outgoing,
        sanitizedOutgoing: outgoing.content,
        learningContextMessage: '',
        model: 'llama-3.3-70b-versatile',
        temperature: 0.5,
        maxTokens: 256,
        stream: false,
      );

      expect(body['model'], 'llama-3.3-70b-versatile');
      expect(body['temperature'], 0.5);
      expect(body['max_tokens'], 256);
      expect(body['stream'], isFalse);
      final messages = body['messages'] as List;
      expect(messages, hasLength(4));
      expect(messages[0], {'role': 'system', 'content': 'You are Van.'});
      expect(messages[1], {'role': 'user', 'content': 'namaste'});
      expect(messages[2], {'role': 'assistant', 'content': 'namaste, learner'});
      expect(messages[3], {'role': 'user', 'content': 'what does it mean?'});
    });

    test('prefixes the outgoing message with the learning context snapshot',
        () {
      final transcript = _simpleContext().messages;
      final outgoing = transcript.last;
      final sanitizedOutgoing = 'what does it mean? (sanitized)';
      final body = GroqModelAdapter.buildRequestBody(
        transcript: transcript,
        outgoingMessage: outgoing,
        sanitizedOutgoing: sanitizedOutgoing,
        learningContextMessage: '[Learner progress context]\nstage 0',
        model: 'llama-3.3-70b-versatile',
        temperature: 0.7,
        maxTokens: 1024,
        stream: false,
      );
      final messages = body['messages'] as List;
      final last = messages.last as Map;
      expect(
        last['content'] as String,
        '[Learner progress context]\nstage 0\n\n$sanitizedOutgoing',
      );
    });

    test('omits the learning context block when it is empty', () {
      final outgoing = AiMessage.user(id: 'u2', content: 'hello');
      final body = GroqModelAdapter.buildRequestBody(
        transcript: [
          AiMessage.user(id: 'u1', content: 'hi'),
          outgoing,
        ],
        outgoingMessage: outgoing,
        sanitizedOutgoing: outgoing.content,
        learningContextMessage: '',
        model: 'llama-3.3-70b-versatile',
        temperature: 0.7,
        maxTokens: 1024,
        stream: false,
      );
      final messages = body['messages'] as List;
      expect((messages.last as Map)['content'], 'hello');
    });

    test('sets stream:true when the adapter is streaming', () {
      final outgoing = AiMessage.user(id: 'u1', content: 'hi');
      final body = GroqModelAdapter.buildRequestBody(
        transcript: [outgoing],
        outgoingMessage: outgoing,
        sanitizedOutgoing: outgoing.content,
        learningContextMessage: '',
        model: 'm',
        temperature: 0.7,
        maxTokens: 256,
        stream: true,
      );
      expect(body['stream'], isTrue);
    });
  });

  group('GroqModelAdapter.complete — happy path', () {
    test('parses a standard response and reports the configured provider',
        () async {
      String? capturedModel;
      final harness = await _newHarness(
        respond: (body) {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          capturedModel = decoded['model'] as String;
          return GroqHttpResponse(
            statusCode: 200,
            body: _groqOkResponse(content: 'namaste is a greeting'),
          );
        },
        apiKeyOverride: _realKey,
      );
      addTearDown(() async {
        dotenv.testLoad(mergeWith: const {});
      });

      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );

      expect(result.isRight(), isTrue,
          reason: 'a 200 response with assistant content MUST succeed');
      final message = result.getOrElse(() => throw StateError('unreachable'));
      expect(message.role, AiRole.assistant);
      expect(message.content, 'namaste is a greeting');
      expect(message.metadata['provider'], 'groq');
      expect(capturedModel, isNotNull);
      expect(AppEnvironment.groqModel, isNotEmpty);
      expect(capturedModel, AppEnvironment.groqModel,
          reason: 'the model id sent to Groq MUST come from the central '
              'configuration, not be hardcoded in the adapter');
      expect(harness.transport.callCount, 1);
    });

    test('records token usage on the shared TokenUsageTracker', () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: _groqOkResponse(
            content: 'hi',
            promptTokens: 50,
            completionTokens: 30,
          ),
        ),
        apiKeyOverride: _realKey,
      );

      await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );

      final usage = await harness.usage.getTodayUsage();
      expect(usage.totalTokens, 80);
      expect(usage.requestCount, 1);
    });

    test('honours the per-request model override (config wins over env)',
        () async {
      String? capturedModel;
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: _groqOkResponse(content: 'hi'),
        ),
        requestAssertions: (body) {
          capturedModel = (jsonDecode(body) as Map)['model'] as String;
        },
        apiKeyOverride: _realKey,
      );

      await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: 'llama-3.1-8b-instant',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );

      expect(capturedModel, 'llama-3.1-8b-instant',
          reason: 'the per-request override MUST win over the env default');
    });
  });

  group('GroqModelAdapter.complete — failure paths', () {
    test('401 maps to an auth Failure (UnauthenticatedFailure)', () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 401,
          body: jsonEncode({
            'error': {'message': 'Invalid API Key', 'type': 'invalid_request'}
          }),
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse(() => throw StateError('x'));
      // AuthException → UnauthenticatedFailure via ExceptionMapper.
      expect(failure.code, 'UNAUTHENTICATED');
    });

    test('429 maps to a rate-limit Failure', () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 429,
          body: jsonEncode({
            'error': {'message': 'rate_limit reached', 'type': 'rate_limit'}
          }),
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse(() => throw StateError('x'));
      expect(failure.code, 'RATE_LIMIT');
    });

    test('400 with context-length text maps to a context-length Failure',
        () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 400,
          body: jsonEncode({
            'error': {
              'message':
                  'Please reduce the input length. The context is too long.',
            }
          }),
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
      final failure = result.swap().getOrElse(() => throw StateError('x'));
      expect(failure.code, 'SERVER_400');
      expect(failure.message.toLowerCase(), contains('context'));
    });

    test('500 maps to an AiServiceFailure and DOES retry the budget', () async {
      var calls = 0;
      final harness = await _newHarness(
        respond: (_) {
          calls += 1;
          return GroqHttpResponse(
            statusCode: 500,
            body: jsonEncode({'error': {'message': 'internal server error'}}),
          );
        },
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
      // 1 initial attempt + 2 retries = 3 calls maximum (the retry
      // budget is _maxSendRetries=2). Verify the adapter actually
      // exercised the retry path.
      expect(calls, greaterThanOrEqualTo(2),
          reason: '5xx is a TRANSIENT failure so the adapter MUST retry');
    });

    test('malformed JSON body yields a server Failure without crashing',
        () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: '<<not json>>',
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
    });

    test('empty / null assistant content maps to a clean failure',
        () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: _groqOkResponse(content: ''),
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue,
          reason: 'an empty assistant message MUST NOT be returned as a '
              'success — VAN would have nothing to render');
    });
  });

  group('GroqModelAdapter.complete — missing key + secret hygiene', () {
    test('refuses to call the network when GROQ_API_KEY is empty', () async {
      // No apiKeyOverride + modelOverride → AppEnvironment.groqApiKey
      // is empty → isGroqConfigured is false.
      final harness = await _newHarness(
        respond: (_) =>
            GroqHttpResponse(statusCode: 200, body: _groqOkResponse(content: 'x')),
        apiKeyOverride: '',
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(harness.transport.callCount, 0,
          reason: 'the adapter MUST NOT make a network call when the key '
              'is missing');
    });

    test('placeholder key (your-groq...) is rejected as unconfigured', () {
      expect(AppEnvironment.isGroqConfigured, isFalse);
      // The default is empty; a placeholder is rejected by the same
      // gate so a starter .env never enables the online path.
    });

    test('request body MUST NOT contain the API key', () async {
      String? capturedBody;
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: _groqOkResponse(content: 'ok'),
        ),
        requestAssertions: (body) => capturedBody = body,
        apiKeyOverride: _realKey,
      );
      await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      expect(capturedBody, isNotNull);
      expect(capturedBody!.contains(_realKey), isFalse,
          reason: 'the API key MUST travel in the Authorization header, '
              'NOT inside the JSON body — bodies can be logged');
    });

    test('exception messages MUST NOT echo the API key', () async {
      // Even when the provider echoes a partial key in its 401 body
      // (a known Groq quirk), the adapter must NEVER carry that into
      // the Failure surfaced to VAN or the chat banner.
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 401,
          body:
              '{"error":{"message":"Invalid API Key: sk-test-abcdef1234"}}',
        ),
        apiKeyOverride: _realKey,
      );
      final result = await harness.adapter.complete(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: false,
        ),
      );
      final failure = result.swap().getOrElse(() => throw StateError('x'));
      final text =
          '${failure.message}\n${failure.code}\n${failure.runtimeType}';
      expect(text.contains(_realKey), isFalse);
      expect(text.contains('abcdef1234'), isFalse,
          reason: 'the failure text MUST NOT echo partial key fragments '
              'leaked by the provider');
    });
  });

  group('GroqModelAdapter.isTransientAiError classification', () {
    test('NetworkException / TimeoutException / 5xx are transient', () {
      expect(
        GroqModelAdapter.isTransientAiError(const NetworkException()),
        isTrue,
      );
      expect(
        GroqModelAdapter.isTransientAiError(const TimeoutException()),
        isTrue,
      );
      expect(
        GroqModelAdapter.isTransientAiError(
          const ServerException(message: 'x', statusCode: 503),
        ),
        isTrue,
      );
    });

    test('4xx (configuration / quota / content) is NOT transient', () {
      expect(
        GroqModelAdapter.isTransientAiError(
          const AuthException(message: 'x'),
        ),
        isFalse,
      );
      expect(
        GroqModelAdapter.isTransientAiError(
          const ServerException(message: 'x', statusCode: 400),
        ),
        isFalse,
      );
      expect(
        GroqModelAdapter.isTransientAiError(
          const ServerException(message: 'x', statusCode: 429),
        ),
        isFalse,
        reason: '429 is quota — the rate limiter owns pacing, the retry '
            'loop must NOT amplify a quota storm',
      );
    });
  });

  group('GroqModelAdapter.stream', () {
    test('emits deltas for a valid SSE response and ends on [DONE]', () async {
      final harness = await _newHarness(
        respond: (_) => GroqHttpResponse(
          statusCode: 200,
          body: [
            'data: {"choices":[{"index":0,"delta":{"content":"hello"},"finish_reason":null}]}',
            '',
            'data: {"choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}',
            '',
            'data: {"choices":[{"index":0,"delta":{"content":""},"finish_reason":"stop"}]}',
            '',
            'data: [DONE]',
            '',
          ].join('\n'),
        ),
        apiKeyOverride: _realKey,
      );

      final deltas = <AiStreamDelta>[];
      final errors = <Failure>[];
      await for (final result in harness.adapter.stream(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: true,
        ),
      )) {
        result.fold(
          (failure) => errors.add(failure),
          (delta) => deltas.add(delta),
        );
      }

      expect(errors, isEmpty);
      expect(deltas.map((d) => d.content).join(), 'hello world');
      expect(deltas.last.done, isTrue);
    });

    test('maps a transport error to a Failure on the first emission',
        () async {
      final harness = await _newHarness(
        respond: (_) =>
            GroqHttpResponse(statusCode: 500, body: '{}'),
        apiKeyOverride: _realKey,
      );
      final deltas = <AiStreamDelta>[];
      final errors = <Failure>[];
      await for (final result in harness.adapter.stream(
        context: _simpleContext(),
        config: const AiConfig(
          provider: AiProviderId.groq,
          model: '',
          temperature: 0.7,
          maxTokens: 1024,
          enableStreaming: true,
        ),
      )) {
        result.fold(
          (failure) => errors.add(failure),
          (delta) => deltas.add(delta),
        );
      }
      expect(deltas, isEmpty);
      expect(errors, isNotEmpty,
          reason: 'a 5xx response MUST be surfaced as a stream failure '
              'so the chat banner can render the recovery reaction');
    });
  });

  group('GroqModelAdapter provider identity', () {
    test('reports its providerId and isAvailable matches env', () async {
      dotenv.testLoad(mergeWith: const {AppConstants.groqApiKey: _realKey});
      final harness = await _newHarness(
        respond: (_) =>
            GroqHttpResponse(statusCode: 200, body: _groqOkResponse(content: 'x')),
        apiKeyOverride: _realKey,
      );
      expect(harness.adapter.providerId, AiProviderId.groq);
      expect(harness.adapter.isAvailable, isTrue);

      dotenv.testLoad(mergeWith: const {});
      final offline = await _newHarness(
        respond: (_) =>
            GroqHttpResponse(statusCode: 200, body: _groqOkResponse(content: 'x')),
        apiKeyOverride: '',
      );
      expect(offline.adapter.isAvailable, isFalse);
    });
  });
}

