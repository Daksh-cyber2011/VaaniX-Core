/// VaaniX Result / Either Utilities
///
/// Re-exports dartz Either for use as a Result type throughout the domain layer.
/// Also provides helper extensions for cleaner usage.

export 'package:dartz/dartz.dart' show Either, Left, Right, left, right;

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/exception_mapper.dart';
import 'package:vaanix_app/core/errors/failures.dart';

/// Convenience typedef for domain use cases and repositories.
typedef Result<T> = Either<Failure, T>;

/// Shorthand for a successful result.
Result<T> ok<T>(T value) => Right(value);

/// Shorthand for a failed result.
Result<T> err<T>(Failure failure) => Left(failure);

/// Wrap a possibly-throwing synchronous operation in a [Result].
///
/// Repositories use this to keep their public API failure-first without
/// sprinkling try/catch everywhere:
///
/// ```dart
/// Result<User> getUser(String id) =>
///   guard(() => remoteDataSource.fetchUser(id));
/// ```
Result<T> guard<T>(T Function() action) {
  try {
    return ok(action());
  } catch (e) {
    return err(ExceptionMapper.toFailure(e));
  }
}

/// Asynchronous variant of [guard] for `Future`-returning operations.
Future<Result<T>> guardAsync<T>(Future<T> Function() action) async {
  try {
    return ok(await action());
  } catch (e) {
    return err(ExceptionMapper.toFailure(e));
  }
}

