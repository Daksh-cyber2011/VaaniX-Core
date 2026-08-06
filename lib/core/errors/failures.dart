/// VaaniX Domain Failure Types
///
/// Failures represent domain-level errors propagated via Either<Failure, T>.
/// Each failure type maps to a specific category of problem.
///
/// Usage: return Left(NetworkFailure('No internet connection'));

import 'package:equatable/equatable.dart';

/// Base failure class — all failures extend this.
abstract class Failure extends Equatable {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

// ============================================================
// NETWORK FAILURES
// ============================================================

/// No internet connection or DNS failure
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection'])
      : super(message: message, code: 'NETWORK_ERROR');
}

/// Server returned a non-2xx response
class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'Server error occurred',
    String? code,
    this.statusCode,
  }) : super(message: message, code: code);

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Request timed out
class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'Request timed out'])
      : super(message: message, code: 'TIMEOUT');
}

// ============================================================
// AUTH FAILURES
// ============================================================

/// User is not authenticated
class UnauthenticatedFailure extends Failure {
  const UnauthenticatedFailure([String message = 'Please sign in to continue'])
      : super(message: message, code: 'UNAUTHENTICATED');
}

/// Credentials are wrong
class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(
      [String message = 'Invalid email or password'])
      : super(message: message, code: 'INVALID_CREDENTIALS');
}

/// OTP is wrong or expired
class OtpFailure extends Failure {
  const OtpFailure([String message = 'OTP is incorrect or expired'])
      : super(message: message, code: 'OTP_ERROR');
}

/// Session expired
class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([String message = 'Session expired'])
      : super(message: message, code: 'SESSION_EXPIRED');
}

/// Authenticated but forbidden (HTTP 403)
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
      String message = 'You do not have access to this resource.'])
      : super(message: message, code: 'FORBIDDEN');
}

// ============================================================
// CACHE / LOCAL STORAGE FAILURES
// ============================================================

/// Could not read/write local storage
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Could not access local storage'])
      : super(message: message, code: 'CACHE_ERROR');
}

// ============================================================
// VALIDATION FAILURES
// ============================================================

/// Input validation failed.
///
/// [field] optionally identifies the offending input field so the UI can
/// surface inline errors next to the relevant control.
class ValidationFailure extends Failure {
  const ValidationFailure({required String message, this.field})
      : super(message: message, code: 'VALIDATION_ERROR');

  final String? field;

  @override
  List<Object?> get props => [message, code, field];
}

// ============================================================
// HTTP STATUS FAILURES (4xx beyond auth)
// ============================================================

/// Resource was not found (HTTP 404)
class NotFoundFailure extends Failure {
  const NotFoundFailure([
      String message = 'The requested resource was not found.'])
      : super(message: message, code: 'NOT_FOUND');
}

/// Resource already exists / conflict (HTTP 409)
class ConflictFailure extends Failure {
  const ConflictFailure([
      String message = 'This resource already exists.'])
      : super(message: message, code: 'CONFLICT');
}

/// Rate limit exceeded (HTTP 429)
class RateLimitFailure extends Failure {
  const RateLimitFailure({
    String message = 'Too many requests. Please try again later.',
    this.retryAfter,
  }) : super(message: message, code: 'RATE_LIMIT');

  /// Hint from the server about how long to wait before retrying.
  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, code, retryAfter];
}

// ============================================================
// UNKNOWN
// ============================================================

/// Catch-all for unexpected errors
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unexpected error occurred'])
      : super(message: message, code: 'UNKNOWN');
}
