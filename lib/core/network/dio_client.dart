/// VaaniX Dio HTTP Client
///
/// Configures the Dio instance used for all VaaniX FastAPI backend calls.
/// Supabase operations use the official supabase_flutter package directly,
/// not this client.
///
/// Wiring (in order):
///   1. [AuthInterceptor]         — attaches the current Bearer token.
///   2. [RefreshTokenInterceptor] — refreshes on 401 and retries the request.
///   3. [LoggingInterceptor]      — request/response logs in debug builds only.
///   4. [RetryInterceptor]        — exponential backoff retries for network drops.
///
/// Status: The Dio client is configured and ready but not yet consumed by any
/// repository. FastAPI integration is deferred to a later milestone. This
/// client will be wired into an API service layer when the backend is ready.
/// See lib/core/network/interceptors/refresh_token_interceptor.dart for the
/// 401-refresh logic that was previously a false docstring claim (Segment 5).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/network/interceptors/auth_interceptor.dart';
import 'package:vaanix_app/core/network/interceptors/logging_interceptor.dart';
import 'package:vaanix_app/core/network/interceptors/refresh_token_interceptor.dart';
import 'package:vaanix_app/core/network/interceptors/retry_interceptor.dart';

/// Riverpod provider for the configured [Dio] instance.
final dioClientProvider = Provider<Dio>((ref) {
  return _buildDioClient();
});

Dio _buildDioClient() {
  final options = BaseOptions(
    baseUrl: AppEnvironment.apiBaseUrl,
    connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
    receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
    sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client': 'vaanix-flutter',
    },
  );

  final dio = Dio(options);
  dio.interceptors.addAll([
    AuthInterceptor(),
    RefreshTokenInterceptor(dio: dio),
    LoggingInterceptor(),
    RetryInterceptor(dio: dio),
  ]);
  return dio;
}
