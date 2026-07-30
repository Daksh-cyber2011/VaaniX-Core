/// VaaniX Result / Either Utilities
///
/// Re-exports dartz Either for use as a Result type throughout the domain layer.
/// Also provides helper extensions for cleaner usage.

export 'package:dartz/dartz.dart' show Either, Left, Right, left, right;

import 'package:dartz/dartz.dart';

import '../errors/failures.dart';

/// Convenience typedef for domain use cases and repositories.
typedef Result<T> = Either<Failure, T>;

/// Shorthand for a successful result.
Result<T> ok<T>(T value) => Right(value);

/// Shorthand for a failed result.
Result<T> err<T>(Failure failure) => Left(failure);
