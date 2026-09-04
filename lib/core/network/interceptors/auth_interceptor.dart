/// Auth Interceptor
///
/// Attaches the Supabase JWT access token to every outgoing request
/// as a Bearer token in the Authorization header.
///
/// If there is no active session, the request proceeds without auth —
/// the backend will return 401 which is handled by [RefreshTokenInterceptor].
///
/// Token refresh / 401 retry logic lives in [RefreshTokenInterceptor], not
/// here. This interceptor only attaches the token; it does not catch errors.
library;

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    } catch (_) {
      // Supabase not initialized (offline / unconfigured dev build).
      // Proceed without attaching an auth header — the backend returns 401
      // which RefreshTokenInterceptor attempts to handle via session refresh.
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Surface the error unchanged. 401 handling (token refresh + retry)
    // is implemented in RefreshTokenInterceptor, which runs after this
    // interceptor in the Dio chain (see dio_client.dart).
    handler.next(err);
  }
}
