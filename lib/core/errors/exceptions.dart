/// VaaniX Infrastructure Exception Types
///
/// Exceptions are thrown by data-layer code (datasources, repositories)
/// and caught at repository boundaries, then converted to [Failure] types.
///
/// These are NOT propagated to the domain layer.

/// Base infrastructure exception
abstract class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

// ============================================================
// NETWORK EXCEPTIONS
// ============================================================

class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection'])
      : super(message: message);
}

class ServerException extends AppException {
  const ServerException({
    String message = 'Server error',
    this.statusCode,
    Object? cause,
  }) : super(message: message, cause: cause);

  final int? statusCode;
}

class TimeoutException extends AppException {
  const TimeoutException([String message = 'Connection timed out'])
      : super(message: message);
}

// ============================================================
// AUTH EXCEPTIONS
// ============================================================

class AuthException extends AppException {
  const AuthException({required String message, Object? cause})
      : super(message: message, cause: cause);
}

/// Thrown when an auth API call fails for a non-credential reason
/// (e.g., unknown OAuth provider, rate limit, user-not-found).
/// Distinct from [AuthException] so ExceptionMapper can route it to
/// the appropriate Failure type (NotFound / Conflict / RateLimit).
class AuthApiException extends AppException {
  const AuthApiException(String message, {Object? cause})
      : super(message: message, cause: cause);
}

class OtpException extends AppException {
  const OtpException([String message = 'OTP verification failed'])
      : super(message: message);
}

// ============================================================
// CACHE EXCEPTIONS
// ============================================================

class CacheException extends AppException {
  const CacheException([String message = 'Cache operation failed'])
      : super(message: message);
}
