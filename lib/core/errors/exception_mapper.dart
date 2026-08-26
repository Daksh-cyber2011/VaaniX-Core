/// VaaniX Error Mapper
///
/// Single bridge between infrastructure-layer exceptions and domain-layer
/// [Failure] types.

import 'package:dio/dio.dart';
import 'dart:async' as async;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';

abstract final class ExceptionMapper {
  /// Translate any caught object into a domain [Failure].
  static Failure toFailure(Object error) {
    if (error is Failure) return error;

    if (error is async.TimeoutException) return const TimeoutFailure();

    if (error is DioException) return _mapDio(error);

    // Supabase's AuthException — now visible because we removed `hide`
    // from supabase_auth_repository.dart. Map it explicitly instead of
    // the previous fragile runtimeType-name-contains-'Auth' heuristic.
    if (error is supabase.AuthException) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('invalid credentials') ||
          lower.contains('password') ||
          lower.contains('email not confirmed')) {
        return InvalidCredentialsFailure(msg);
      }
      if (lower.contains('not found') || lower.contains('no user found')) {
        return const NotFoundFailure();
      }
      if (lower.contains('already registered') ||
          lower.contains('already exists')) {
        return const ConflictFailure(
            'An account with this email already exists.');
      }
      if (lower.contains('rate limit') || lower.contains('too many')) {
        return const RateLimitFailure();
      }
      return UnauthenticatedFailure(msg);
    }

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
        // VaaniX's own AuthException (from exceptions.dart).
        if (message.toLowerCase().contains('credential') ||
            message.toLowerCase().contains('password')) {
          return InvalidCredentialsFailure(message);
        }
        return UnauthenticatedFailure(message);
      case AuthApiException(:final message):
        // Non-credential auth API errors (unknown OAuth provider, etc.).
        final lower = message.toLowerCase();
        if (lower.contains('unknown') || lower.contains('not found')) {
          return NotFoundFailure(message);
        }
        if (lower.contains('already') || lower.contains('exists')) {
          return ConflictFailure(message);
        }
        if (lower.contains('rate') || lower.contains('too many')) {
          return RateLimitFailure(message: message);
        }
        return UnauthenticatedFailure(message);
      case CacheException(:final message):
        return CacheFailure(message);
    }

    // Fallback: no more runtimeType-name matching (the previous
    // `.contains('Auth')` heuristic was too fragile).
    return UnknownFailure(_extractMessage(error));
  }

  static Failure _mapDio(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        final serverMsg = _safeMessage(err.response?.data);
        switch (status) {
          case 400:
            return ValidationFailure(message: serverMsg ?? 'Invalid input.');
          case 401:
            return const UnauthenticatedFailure();
          case 403:
            // 403 = authenticated but forbidden, NOT unauthenticated.
            // 401 = unauthenticated. Map them to distinct failures.
            return const ForbiddenFailure();
          case 404:
            return const NotFoundFailure();
          case 409:
            return const ConflictFailure();
          case 422:
            return ValidationFailure(message: serverMsg ?? 'Invalid input.');
          case 429:
            return const RateLimitFailure();
          case null:
            return ServerFailure(message: serverMsg ?? 'Server error occurred');
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

  /// Extracts a human-readable message from a response body.
  ///
  /// Handles common API conventions:
  /// - `{"message": "..."}` (Express, many REST APIs)
  /// - `{"error": "..."}` (common alternative)
  /// - `{"detail": "..."}` or `{"detail": [{"msg": "..."}]}` (FastAPI)
  /// - `{"errors": {...}}` (some validation formats)
  /// - Plain string body
  static String? _safeMessage(dynamic data) {
    try {
      if (data is String && data.isNotEmpty) return data;
      if (data is Map) {
        // Most common: {"message": "..."}
        if (data['message'] is String) return data['message'] as String;
        // Alternative: {"error": "..."}
        if (data['error'] is String) return data['error'] as String;
        // FastAPI: {"detail": "string"} or {"detail": [{...}]}
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
        // Some APIs nest under "errors"
        if (data['errors'] is String) return data['errors'] as String;
      }
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
