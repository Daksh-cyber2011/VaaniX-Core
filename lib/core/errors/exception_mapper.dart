/// VaaniX Error Mapper
///
/// Single bridge between infrastructure-layer exceptions and domain-layer
/// [Failure] types.

import 'package:dio/dio.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';

abstract final class ExceptionMapper {
  /// Translate any caught object into a domain [Failure].
  static Failure toFailure(Object error) {
    if (error is Failure) return error;

    if (error is DioException) return _mapDio(error);

    switch (error) {
      case NetworkException():
        return const NetworkFailure();
      case TimeoutException():
        return const TimeoutFailure();
      case ServerException(:final statusCode, :final message):
        return ServerFailure(
          message: message,
          statusCode: statusCode,
          code: statusCode != null ? 'SERVER_$statusCode' : 'SERVER_ERROR',
        );
      case OtpException():
        return const OtpFailure();
      case AuthException(:final message):
        if (message.toLowerCase().contains('credential') ||
            message.toLowerCase().contains('password')) {
          return InvalidCredentialsFailure(message);
        }
        return UnauthenticatedFailure(message);
      case CacheException(:final message):
        return CacheFailure(message);
    }

    final type = error.runtimeType.toString();
    if (type.contains('Auth')) {
      final msg = _extractMessage(error);
      return UnauthenticatedFailure(msg);
    }

    return UnknownFailure(_extractMessage(error));
  }

  static Failure _mapDio(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        final serverMsg = _safeMessage(err.response?.data);
        switch (status) {
          case 401:
            return const UnauthenticatedFailure();
          case 403:
            return const UnauthenticatedFailure('You do not have access.');
          case 422:
            return ValidationFailure(message: serverMsg ?? 'Invalid input.');
          case >= 500:
            return ServerFailure(
              message: serverMsg ?? 'Server error occurred',
              statusCode: status,
            );
          default:
            return ServerFailure(
              message: serverMsg ?? 'Server error occurred',
              statusCode: status,
            );
        }
      case DioExceptionType.cancel:
        return const UnknownFailure('Request was cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Secure connection failed.');
      case DioExceptionType.unknown:
        return UnknownFailure(_extractMessage(err));
    }
  }

  static String? _safeMessage(dynamic data) {
    try {
      if (data is Map && data['message'] is String) return data['message'];
      if (data is String && data.isNotEmpty) return data;
    } catch (_) {
      // ignore
    }
    return null;
  }

  static String _extractMessage(Object error) {
    try {
      final s = error.toString();
      return s.isEmpty ? 'An unexpected error occurred' : s;
    } catch (_) {
      return 'An unexpected error occurred';
    }
  }
}
