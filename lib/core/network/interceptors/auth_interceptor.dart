/// Auth Interceptor
///
/// Attaches the Supabase JWT access token to every outgoing request
/// as a Bearer token in the Authorization header.
///
/// If there is no active session, the request proceeds without auth —
/// the backend will return 401 which is handled by the error interceptor.

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
      // which is handled downstream by the error interceptor.
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Surface the error unchanged. Token refresh / 401 handling is a
    // cross-cutting concern implemented as a dedicated interceptor on the
    // Dio instance (see dio_client.dart), not here.
    handler.next(err);
  }
}
