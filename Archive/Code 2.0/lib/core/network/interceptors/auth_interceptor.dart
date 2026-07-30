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
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // TODO: Handle 401 token refresh when refresh tokens are implemented
    handler.next(err);
  }
}
