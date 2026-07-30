/// VaaniX API Service
///
/// Thin, typed convenience layer over the configured [Dio] instance.
/// Repositories call [ApiService.get/post/put/delete] instead of touching
/// Dio directly, so error mapping lives in exactly one place.
///
/// Network errors are translated into domain [Failure]s at the repository
/// boundary (see `core/utils/api_error_mapper.dart`); this service simply
/// surfaces the raw Dio responses/exceptions.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../errors/exceptions.dart';

class ApiService {
  ApiService(this._dio);

  final Dio _dio;

  // ── GET ─────────────────────────────────────────────────────
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── POST ────────────────────────────────────────────────────
  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── PUT ─────────────────────────────────────────────────────
  Future<Response<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────
  Future<Response<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Maps a [DioException] to a domain-agnostic [AppException].
  /// Repositories further translate to typed [Failure]s.
  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException('The request timed out');
      case DioExceptionType.connectionError:
        return const NetworkException('No internet connection');
      case DioExceptionType.badResponse:
        return ServerException(
          message: e.response?.statusMessage ?? 'Server error',
          statusCode: e.response?.statusCode,
          cause: e,
        );
      case DioExceptionType.cancel:
        return const ServerException(message: 'Request was cancelled');
      case DioExceptionType.badCertificate:
        return const ServerException(message: 'Certificate validation failed');
      case DioExceptionType.unknown:
        return ServerException(message: e.message ?? 'Unknown error', cause: e);
    }
  }
}

/// Riverpod provider for [ApiService].
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ApiService(dio);
});
