/// VaaniX Network Retry Interceptor
///
/// Automatically retries failed requests due to transient network failures
/// (timeouts, socket exceptions, 503 service unavailable).
/// Uses exponential backoff with jitter to prevent server thundering herds.

import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vaanix_app/core/logging/logger.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelayMs = 1000,
  });

  final Dio dio;
  final int maxRetries;
  final int initialDelayMs;

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retry_count'] as int?) ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final nextRetry = retryCount + 1;
      extra['retry_count'] = nextRetry;

      final delayMs = _calculateDelay(nextRetry);
      AppLogger.warn(
        'Retrying request [Attempt $nextRetry/$maxRetries] in ${delayMs}ms → ${err.requestOptions.uri}',
        tag: 'RetryInterceptor',
      );

      await Future<void>.delayed(Duration(milliseconds: delayMs));

      try {
        final response = await dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          return super.onError(e, handler);
        }
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.error is SocketException ||
        (err.response != null && err.response!.statusCode == 503);
  }

  int _calculateDelay(int attempt) {
    final exponential = initialDelayMs * pow(2, attempt - 1).toInt();
    final jitter = Random().nextInt(300);
    return exponential + jitter;
  }
}
