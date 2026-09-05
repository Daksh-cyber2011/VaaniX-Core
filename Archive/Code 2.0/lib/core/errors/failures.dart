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

/// Input validation failed
class ValidationFailure extends Failure {
  const ValidationFailure({required String message, String? field})
      : super(message: message, code: 'VALIDATION_ERROR');
}

// ============================================================
// UNKNOWN
// ============================================================

/// Catch-all for unexpected errors
class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unexpected error occurred'])
      : super(message: message, code: 'UNKNOWN');
}
