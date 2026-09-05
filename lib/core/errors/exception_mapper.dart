/// VaaniX Error Mapper
///
/// Single bridge between infrastructure-layer exceptions and domain-layer
/// [Failure] types.
library;

import 'dart:async' as async;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';

abstract final class ExceptionMapper {
  /// Translate any caught object into a domain [Failure].
  static Failure toFailure(Object error) {
    if (error is Failure) return error;

    if (error is async.TimeoutException) return const TimeoutFailure();

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

  static String _extractMessage(Object error) {
    try {
      final s = error.toString();
      return s.isEmpty ? 'An unexpected error occurred' : s;
    } catch (_) {
      return 'An unexpected error occurred';
    }
  }
}
