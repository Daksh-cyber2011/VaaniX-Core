/// Logging Interceptor
///
/// Logs all HTTP requests and responses in debug mode.
/// Disabled in production to avoid sensitive data in logs.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('→ [${options.method}] ${options.uri}');
      if (options.data != null) {
        debugPrint('  Body: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('← [${response.statusCode}] ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('✗ [${err.response?.statusCode}] ${err.requestOptions.uri}');
      debugPrint('  Error: ${err.message}');
    }
    handler.next(err);
  }
}
