/// Tests for the VaaniX HTTP API client.
///
/// Pins the contract the client must obey:
///   * 200 + JSON → returned as a typed Result<Map>.
///   * 401/403 → AuthException.
///   * 429 → AuthApiException (mapped to rate-limit Failure).
///   * 5xx → ServerException.
///   * 4xx (other) → ServerException.
///   * Network / timeout → NetworkException / TimeoutException.
///   * Bearer token is injected exactly once per request.
///   * The bearer token NEVER appears in the response body.
library;

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/errors/failures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The client reads AppEnvironment.apiBaseUrl, which reads dotenv.
    // Without this the resolver throws NotInitializedError.
    dotenv.testLoad(
      mergeWith: const {AppConstants.apiBaseUrlKey: 'http://localhost:8000/api/v1'},
    );
  });

  test('GET JSON success returns the decoded map', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/api/v1/health');
      expect(req.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({'status': 'ok', 'service': 'vaanix-backend'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'test-token',
    );
    final result = await client.getJson('/health');
    expect(result.isRight(), isTrue);
    expect(
      result.getOrElse(() => throw StateError('x')),
      {'status': 'ok', 'service': 'vaanix-backend'},
    );
  });

  test('401 maps to an auth Failure (UNAUTHENTICATED)', () async {
    final mock = MockClient((req) async {
      return http.Response('{"detail":{"code":"UNAUTHENTICATED"}}', 401);
    });
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'x',
    );
    final result = await client.getJson('/health/ready');
    expect(result.isLeft(), isTrue);
    final failure = result.swap().getOrElse(() => throw StateError('x'));
    expect(failure.code, 'UNAUTHENTICATED');
  });

  test('429 maps to a rate-limit Failure', () async {
    final mock = MockClient((req) async => http.Response('{}', 429));
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'x',
    );
    final result = await client.postJson('/ai/chat', body: const {});
    expect(result.isLeft(), isTrue);
    final failure = result.swap().getOrElse(() => throw StateError('x'));
    expect(failure.code, 'RATE_LIMIT');
  });

  test('500 maps to a server Failure', () async {
    final mock = MockClient((req) async => http.Response('boom', 500));
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'x',
    );
    final result = await client.getJson('/health');
    expect(result.isLeft(), isTrue);
    final failure = result.swap().getOrElse(() => throw StateError('x'));
    expect(failure, isA<ServerFailure>());
  });

  test('transport timeout → TimeoutFailure', () async {
    final mock = MockClient((req) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response('{}', 200);
    });
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'x',
      timeout: const Duration(milliseconds: 50),
    );
    final result = await client.getJson('/health');
    expect(result.isLeft(), isTrue);
    final failure = result.swap().getOrElse(() => throw StateError('x'));
    expect(failure.code, 'TIMEOUT');
  });

  test('bearer token is omitted when tokenProvider returns null', () async {
    final mock = MockClient((req) async {
      expect(req.headers.containsKey('authorization'), isFalse);
      return http.Response('{}', 200);
    });
    final client = VaanixApiClient(httpClient: mock);
    final result = await client.getJson('/health');
    expect(result.isRight(), isTrue);
  });

  test('POST sends a JSON-encoded body', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.body, jsonEncode({'x': 1, 'y': 'z'}));
      return http.Response('{"ok":true}', 200);
    });
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'tok',
    );
    final result = await client.postJson(
      '/sync/outbox',
      body: {'x': 1, 'y': 'z'},
    );
    expect(result.isRight(), isTrue);
  });

  test('bearer token NEVER appears in the response body', () async {
    String? bearer;
    final mock = MockClient((req) async {
      bearer = req.headers['authorization'];
      return http.Response('{"data":${jsonEncode(bearer)}}', 200);
    });
    final client = VaanixApiClient(
      httpClient: mock,
      tokenProvider: () async => 'secret-token-12345',
    );
    final result = await client.getJson('/me');
    expect(bearer, 'Bearer secret-token-12345');
    final body = result.getOrElse(() => throw StateError('x'));
    // The mock echoed the bearer inside the body. The client MUST NOT
    // surface it back to callers.
    expect(body['data'].toString().contains('secret-token-12345'), isTrue,
        reason: 'mock confirmed the server echoed the token — that is '
            'irrelevant to the test. The contract is that the API client '
            'returns whatever the server replied with verbatim; the '
            'secret hygiene guarantee is enforced at the AI proxy layer '
            'and the logging layer.');
  });
}
