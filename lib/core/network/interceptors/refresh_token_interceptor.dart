/// Refresh Token Interceptor
///
/// Catches HTTP 401 (Unauthorized) responses from the FastAPI backend,
/// refreshes the Supabase auth session, and retries the original request
/// with the new access token.
///
/// Guards against infinite retry loops via a per-request flag stored in
/// `RequestOptions.extra['refresh_attempted']`. If the refresh fails or
/// the retried request still returns 401, the error is surfaced as-is.
///
/// Wiring order in [dio_client.dart]:
///   1. AuthInterceptor         — attaches the current Bearer token
///   2. RefreshTokenInterceptor — refreshes on 401 and retries
///   3. LoggingInterceptor      — logs request/response/error (debug only)
///   4. RetryInterceptor        — retries on network errors / 503
///
/// This interceptor does NOT refresh on 403 (Forbidden) — 403 means
/// authenticated-but-not-permitted, which token refresh cannot fix.
library;

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RefreshTokenInterceptor extends Interceptor {
  RefreshTokenInterceptor({required this.dio});

  /// The Dio instance used to retry requests. Must be the same instance
  /// that this interceptor is attached to (so retries go through the full
  /// interceptor chain, including AuthInterceptor which re-attaches the
  /// refreshed token).
  final Dio dio;

  /// Key stored in RequestOptions.extra to prevent infinite refresh loops.
  static const String _refreshAttemptedKey = 'refresh_attempted';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;

    // Only attempt refresh on 401 Unauthorized — not 403 (Forbidden).
    if (status != 401) {
      handler.next(err);
      return;
    }

    // Prevent infinite loops: if we already attempted a refresh on this
    // request, surface the 401 as-is.
    final alreadyAttempted =
        err.requestOptions.extra[_refreshAttemptedKey] == true;
    if (alreadyAttempted) {
      handler.next(err);
      return;
    }

    // Attempt to refresh the Supabase session.
    _refreshAndRetry(err, handler);
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final client = Supabase.instance.client;
      final refreshResult = await client.auth.refreshSession();

      // If refresh failed (no session returned), surface the original 401.
      if (refreshResult.session == null) {
        handler.next(err);
        return;
      }

      // Mark this request as refresh-attempted to prevent loops.
      err.requestOptions.extra[_refreshAttemptedKey] = true;

      // Update the Authorization header with the new access token.
      // (AuthInterceptor will also re-attach on the retry pass, but we
      // set it here too in case AuthInterceptor is not in the chain.)
      err.requestOptions.headers['Authorization'] =
          'Bearer ${refreshResult.session!.accessToken}';

      // Retry the original request via the same Dio instance so the full
      // interceptor chain runs again (Auth re-attaches token, Logging
      // logs, Retry handles network errors).
      final response = await dio.fetch<dynamic>(err.requestOptions);

      handler.resolve(response);
    } on DioException catch (e) {
      // The retried request itself failed — surface that error.
      handler.next(e);
    } catch (_) {
      // Refresh failed (Supabase threw a non-Dio exception).
      // Surface the original 401 — the caller (ExceptionMapper) will
      // map it to UnauthenticatedFailure, and the router redirect will
      // bounce the user to /auth.
      handler.next(err);
    }
  }
}
