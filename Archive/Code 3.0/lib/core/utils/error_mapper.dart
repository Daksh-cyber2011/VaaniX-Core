/// VaaniX Error Mapper
///
/// Single source of truth for translating infrastructure [AppException]s
/// raised by data sources / [ApiService] into domain [Failure]s returned
/// from repositories via `Result<T>`.
///
/// Keeps repository methods free of repetitive try/catch boilerplate:
///
///   try {
///     final res = await _api.get(...);
///     return ok(Model.fromJson(res.data));
///   } on AppException catch (e) {
///     return err(mapException(e));
///   }

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// Maps any [AppException] to the most specific matching [Failure].
Failure mapException(AppException exception) {
  if (exception is TimeoutException) {
    return const TimeoutFailure();
  }
  if (exception is NetworkException) {
    return const NetworkFailure();
  }
  if (exception is ServerException) {
    return ServerFailure(
      message: exception.message,
      statusCode: exception.statusCode,
    );
  }
  if (exception is CacheException) {
    return const CacheFailure();
  }
  if (exception is AuthException) {
    return InvalidCredentialsFailure(exception.message);
  }
  if (exception is OtpException) {
    return const OtpFailure();
  }
  return UnknownFailure(exception.message);
}

/// Maps a Supabase [AuthException] to an auth-specific [Failure].
///
/// Supabase throws `AuthException` directly (not our [AppException]),
/// so auth repositories need a dedicated mapper.
Failure mapAuthException(AuthException exception) {
  final message = exception.message;
  // Heuristics on Supabase error messages — keep broad and safe.
  final lower = message.toLowerCase();
  if (lower.contains('invalid login') ||
      lower.contains('invalid credentials') ||
      lower.contains('wrong password')) {
    return const InvalidCredentialsFailure();
  }
  if (lower.contains('not confirmed') || lower.contains('email not confirmed')) {
    return const InvalidCredentialsFailure(
        'Please verify your email before signing in');
  }
  if (lower.contains('session') && lower.contains('expired')) {
    return const SessionExpiredFailure();
  }
  return InvalidCredentialsFailure(message);
}

/// Convenience: run [action] and convert any thrown [AppException] into a
/// `Result<T>` failure, leaving successful values as `ok`.
Future<Result<T>> guardResult<T>(Future<T> Function() action) async {
  try {
    final value = await action();
    return ok(value);
  } on AppException catch (e) {
    return err(mapException(e));
  } on Exception catch (e) {
    return err(UnknownFailure(e.toString()));
  }
}
