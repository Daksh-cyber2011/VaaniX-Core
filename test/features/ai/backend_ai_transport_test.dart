/// Tests for the BackendAiTransport — the production-side seam that
/// POSTs chat-completion requests through the VaaniX backend instead
/// of Groq directly.
///
/// Pins:
///   * The transport POSTs to `/ai/chat` regardless of which provider
///     the request targets.
///   * Successful backend reply is converted back into the
///     OpenAI-compatible response shape so the Groq adapter does not
///     need to know whether the call was proxied.
///   * Backend Failure maps to a typed adapter exception (rate-limit
///     → AuthApiException; everything else → ServerException).
///   * Bearer token is forwarded by [VaanixApiClient] — the
///     transport never handles provider secrets.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/backend_ai_transport.dart';

class _FakeApiClient implements VaanixApiClient {
  _FakeApiClient(this._respond);

  /// `respond` returns either a `Map<String, dynamic>` or a
  /// `Failure` to simulate the backend.
  final Future<Object> Function(String path, Map<String, dynamic> body) _respond;

  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    lastPath = path;
    lastBody = body;
    final r = await _respond(path, body ?? const <String, dynamic>{});
    if (r is Failure) return err(r);
    return ok(Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<Result<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? query,
  }) async =>
      ok(<String, dynamic>{});

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('routes the request to /ai/chat with the provider embedded',
      () async {
    final api = _FakeApiClient((path, body) async => {
          'provider': 'groq',
          'model': 'llama-3.3-70b-versatile',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            }
          ],
        });
    final transport = BackendAiTransport(apiClient: api);
    final resp = await transport.postChatCompletions(
      body: '{"provider":"groq","model":"llama-3.3-70b-versatile",'
          '"messages":[{"role":"user","content":"hi"}]}',
      apiKey: 'placeholder-from-adapter',
    );
    expect(resp.statusCode, 200);
    expect(api.lastPath, '/ai/chat');
    expect(api.lastBody?['provider'], 'groq');
    expect(resp.body.contains('"content":"ok"'), isTrue);
  });

  test('backend rate-limit → typed AuthApiException', () async {
    final api = _FakeApiClient(
      (_, __) async => const RateLimitFailure(),
    );
    final transport = BackendAiTransport(apiClient: api);
    expect(
      () => transport.postChatCompletions(body: '{}', apiKey: 'x'),
      throwsA(isA<AuthApiException>()),
    );
  });

  test('backend server error → typed ServerException', () async {
    final api = _FakeApiClient(
      (_, __) async => const ServerFailure(
        message: 'proxy failed',
      ),
    );
    final transport = BackendAiTransport(apiClient: api);
    expect(
      () => transport.postChatCompletions(body: '{}', apiKey: 'x'),
      throwsA(isA<ServerException>()),
    );
  });

  test('transport never references the supplied apiKey', () async {
    final api = _FakeApiClient((path, body) async => {
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            }
          ],
        });
    final transport = BackendAiTransport(apiClient: api);
    // The Groq adapter passes its direct-key value here; the
    // transport must NOT log it, NOT carry it into the body, and
    // NOT echo it back. The backend will reject it server-side.
    final apiKeyValue = 'gsk_supersecrettoken_should_never_propagate_12345';
    final resp = await transport.postChatCompletions(
      body: '{}',
      apiKey: apiKeyValue,
    );
    expect(resp.body.contains(apiKeyValue), isFalse,
        reason: 'the transport must never echo the adapter-supplied '
            'apiKey in the response body');
    expect(api.lastBody!.toString().contains(apiKeyValue), isFalse,
        reason: 'the transport must never forward the apiKey to the '
            'backend body — it travels in the Authorization header '
            'via the VaaniXApiClient');
  });
}
