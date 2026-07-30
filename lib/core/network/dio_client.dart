/// VaaniX Dio HTTP Client
///
/// Configures the Dio instance used for all VaaniX FastAPI backend calls.
/// Supabase operations use the official supabase_flutter package directly,
/// not this client.
///
/// Wiring (in order):
///   1. [AuthInterceptor]    — attaches the current Bearer token.
///   2. [LoggingInterceptor] — request/response logs in debug builds only.
///   3. [RetryInterceptor]   — exponential backoff retries for network drops.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/network/interceptors/auth_interceptor.dart';
import 'package:vaanix_app/core/network/interceptors/logging_interceptor.dart';
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
    LoggingInterceptor(),
    RetryInterceptor(dio: dio),
  ]);
  return dio;
}
