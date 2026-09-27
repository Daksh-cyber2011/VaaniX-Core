/// VaaniX HTTP API client.
///
/// The Flutter app talks to the VaaniX backend at `apiBaseUrl`
/// (`AppEnvironment.apiBaseUrl`, default `http://localhost:8000/api/v1`).
/// The client:
///
/// * injects the current Supabase bearer token (forwarded so the
///   backend can talk to PostgREST as the authenticated user — this is
///   how row-level security is honored);
/// * maps HTTP errors to the existing [Failure] hierarchy via
///   [ExceptionMapper];
/// * never logs or echoes API keys.
///
/// The client is provider-agnostic. The AI gateway uses it through a
/// [BackendAiTransport] seam; the sync service uses it through
/// [VaanixApiClient.post]. Nothing else in the Flutter app needs to
/// call `dart:io` directly.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/utils/result.dart';

/// Function signature that returns the current bearer token, or `null`
/// when the user is unauthenticated (guest / offline).
typedef BearerTokenProvider = Future<String?> Function();

/// Thin wrapper over the `http` package. Lives at `core/api/` so
/// feature repositories can depend on it without coupling to the
/// underlying transport.
class VaanixApiClient {
  VaanixApiClient({
    http.Client? httpClient,
    BearerTokenProvider? tokenProvider,
    Duration? timeout,
    Uri? baseUrlOverride,
  })  : _client = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider ?? _defaultTokenProvider,
        _timeout = timeout ?? const Duration(seconds: 15),
        _baseUrlOverride = baseUrlOverride;

  final http.Client _client;
  final BearerTokenProvider _tokenProvider;
  final Duration _timeout;
  final Uri? _baseUrlOverride;

  Uri _resolve(String path) {
    final base = _baseUrlOverride ?? Uri.parse(AppEnvironment.apiBaseUrl);
    // path may be absolute ("/api/v1/foo") or relative ("foo").
    if (path.startsWith('/')) {
      // Treat as relative to the API base's host root.
      final baseRoot = base.replace(
        path: '',
        queryParameters: null,
      );
      return baseRoot.resolve(path.substring(1));
    }
    return base.resolve(path);
  }

  /// GET helper. Returns a typed [Result] — never throws.
  Future<Result<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    return _send(() => Uri.parse(
          _resolve(path).toString(),
        ).replace(queryParameters: query));
  }

  /// POST helper. The [body] is JSON-encoded. Returns a typed [Result].
  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    return _send(
      () => Uri.parse(_resolve(path).toString()).replace(queryParameters: query),
      method: 'POST',
      jsonBody: body ?? const <String, dynamic>{},
    );
  }

  /// Releases the underlying HTTP client. Idempotent.
  void close() => _client.close();

  // ---------------------------------------------------------------------

  static Future<String?> _defaultTokenProvider() async => null;

  Future<Result<Map<String, dynamic>>> _send(
    Uri Function() buildUri, {
    String method = 'GET',
    Object? jsonBody,
  }) async {
    return guardAsync(() async {
      final uri = buildUri();
      final token = await _tokenProvider();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (jsonBody != null) {
        headers['Content-Type'] = 'application/json';
      }
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final http.Response resp;
      try {
        if (method == 'POST' && jsonBody != null) {
          resp = await _client
              .post(uri, headers: headers, body: jsonEncode(jsonBody))
              .timeout(_timeout);
        } else {
          resp = await _client
              .get(uri, headers: headers)
              .timeout(_timeout);
        }
      } on TimeoutException {
        throw const TimeoutException('VaaniX API request timed out');
      } catch (e) {
        throw NetworkException('VaaniX API transport failure: $e');
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw AuthException(
          message: 'VaaniX API rejected the request: ${resp.statusCode}',
        );
      }
      if (resp.statusCode == 429) {
        throw const AuthApiException('VaaniX API rate limit reached');
      }
      if (resp.statusCode >= 500) {
        throw ServerException(
          message: 'VaaniX API server error: ${resp.statusCode}',
          statusCode: resp.statusCode,
        );
      }
      if (resp.statusCode >= 400) {
        throw ServerException(
          message: 'VaaniX API client error: ${resp.statusCode}',
          statusCode: resp.statusCode,
        );
      }
      if (resp.body.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'VaaniX API returned a malformed JSON body',
          statusCode: 200,
        );
      }
      return decoded;
    });
  }
}
