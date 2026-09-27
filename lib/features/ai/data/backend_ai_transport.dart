/// Server-side AI transport for production deployments.
///
/// In production the Flutter app MUST NOT carry provider API keys
/// (mobile secrets can be extracted from the APK). Instead, the AI
/// adapters POST their chat-completion request to the VaaniX backend
/// at `/api/v1/ai/chat` — the backend authenticates the user, enforces
/// per-user rate limits, and forwards the call to Groq / Gemini using
/// server-side credentials.
///
/// This transport implements the same [GroqHttpTransport] seam the
/// direct Groq adapter uses, so swapping from development (direct
/// call) to production (proxied call) is a single line in
/// [ai_providers.dart].
///
/// The contract shape is identical to the OpenAI chat-completions
/// format. The backend normalises the response back into the same
/// shape, so the adapter does not need to know whether the request
/// was proxied or direct.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/features/ai/data/groq_model_adapter.dart';

/// Concrete [GroqHttpTransport] that POSTs to the VaaniX backend
/// instead of Groq directly. Both Gemini and Groq adapters can use
/// this transport — the backend picks the provider server-side.
class BackendAiTransport implements GroqHttpTransport {
  BackendAiTransport({required VaanixApiClient apiClient})
      : _client = apiClient;

  /// The Gemini and Groq adapters POST their OpenAI-compatible
  /// chat-completion body verbatim; the backend forwards the same
  /// shape to the chosen provider. The only contract change is the
  /// URL — everything else is identical.
  final VaanixApiClient _client;

  @override
  Future<GroqHttpResponse> postChatCompletions({
    required String body,
    required String apiKey,
  }) async {
    // Decode the OpenAI-compatible body the adapter constructed so we
    // can extract the provider/model — these decide which backend
    // route the request lands on. (Adapters call this with `apiKey`
    // as a placeholder; the backend ignores the header value and
    // picks credentials itself.)
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(body);
      payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      payload = const <String, dynamic>{};
    }
    final result = await _client.postJson(
      '/ai/chat',
      body: payload,
    );

    // Map the typed Result back to the GroqHttpResponse shape.
    return result.fold(
      (failure) {
        // Translate our domain failure into the Groq adapter's typed
        // exceptions so the adapter's retry/error classification
        // works without modification.
        if (failure.code == 'RATE_LIMIT') {
          throw const AuthApiException('Provider rate limit reached');
        }
        throw ServerException(
          message: 'Backend AI proxy failed: ${failure.message}',
          statusCode: null,
        );
      },
      (decodedResponse) {
        // The backend normalises its response to the OpenAI shape.
        return GroqHttpResponse(
          statusCode: 200,
          body: jsonEncode(decodedResponse),
        );
      },
    );
    // ignore: dead_code  // keeps the analyzer quiet on the unreachable
    //                       // expression below; preserved for symmetry.
    // ignore: unused_local_variable
    // final _ = provider;
  }
}

/// Convenience constructor that builds a [BackendAiTransport] from
/// the existing [VaanixApiClient] provider wiring.
BackendAiTransport defaultBackendAiTransport(VaanixApiClient client) =>
    BackendAiTransport(apiClient: client);
