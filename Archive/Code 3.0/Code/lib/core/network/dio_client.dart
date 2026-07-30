/// VaaniX Dio HTTP Client
///
/// Configures the Dio instance used for all VaaniX FastAPI backend calls.
/// Supabase operations use the official supabase_flutter package directly,
/// not this client.

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Riverpod provider for the configured Dio instance.
final dioClientProvider = Provider<Dio>((ref) {
  return _buildDioClient();
});

Dio _buildDioClient() {
  final baseUrl = dotenv.env[AppConstants.apiBaseUrlKey] ?? 'http://localhost:8000/api/v1';

  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
    receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
    sendTimeout: const Duration(milliseconds: AppConstants.sendTimeoutMs),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client': 'vaanix-flutter',
    },
  );

  final dio = Dio(options);

  // Order matters: auth first, then logging
  dio.interceptors.addAll([
    AuthInterceptor(),
    LoggingInterceptor(),
  ]);

  return dio;
}
