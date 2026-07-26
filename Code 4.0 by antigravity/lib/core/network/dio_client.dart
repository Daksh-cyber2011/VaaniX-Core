/// VaaniX Dio HTTP Client
///
/// Configures the Dio instance used for all VaaniX FastAPI backend calls.
/// Supabase operations use the official supabase_flutter package directly,
/// not this client.
///
/// Wiring (in order):
///   1. [AuthInterceptor]   — attaches the current Bearer token.
///   2. [LoggingInterceptor] — request/response logs in debug builds only.
///
/// When token refresh is needed, add a refresh interceptor here (single
/// retry on 401). It belongs at this seam so every backend call benefits.
///
/// Base URL and client headers come from [AppEnvironment], never from raw
/// dotenv reads scattered across the codebase.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Riverpod provider for the configured [Dio] instance.
///
/// Interceptors resolve auth/session lazily from the live Supabase client,
/// so this provider is safe to construct at app start.
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
  ]);
  return dio;
}
