/// ExceptionMapper regression matrix (Phase 6).
///
/// Phase 6 removed the standalone Dio stack, so the mapper no longer handles
/// `DioException`. These tests pin the full retained mapping surface —
/// domain exceptions, Supabase auth errors, dart:async timeouts and the
/// unknown fallback — so future transport changes cannot silently corrupt
/// error semantics.
library;

import 'dart:async' as async;

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaanix_app/core/errors/exception_mapper.dart';
import 'package:vaanix_app/core/errors/exceptions.dart';
import 'package:vaanix_app/core/errors/failures.dart';

void main() {
  group('ExceptionMapper.toFailure', () {
    test('returns an existing Failure untouched', () {
      const original = NetworkFailure('offline');
      expect(ExceptionMapper.toFailure(original), same(original));
    });

    test('maps dart:async TimeoutException to TimeoutFailure', () {
      final failure = ExceptionMapper.toFailure(
        async.TimeoutException('slow'),
      );
      expect(failure, isA<TimeoutFailure>());
    });

    group('supabase.AuthException branches', () {
      Failure map(String message) =>
          ExceptionMapper.toFailure(supabase.AuthException(message));

      test('invalid credentials wording → InvalidCredentialsFailure', () {
        expect(map('Invalid credentials'), isA<InvalidCredentialsFailure>());
        expect(map('Wrong password provided'), isA<InvalidCredentialsFailure>());
        expect(
          map('Email not confirmed yet'),
          isA<InvalidCredentialsFailure>(),
        );
      });

      test('not-found wording → NotFoundFailure', () {
        expect(map('User not found'), isA<NotFoundFailure>());
      });

      test('already-registered wording → ConflictFailure', () {
        expect(map('User already registered'), isA<ConflictFailure>());
      });

      test('rate-limit wording → RateLimitFailure', () {
        expect(map('Rate limit exceeded'), isA<RateLimitFailure>());
      });

      test('anything else → UnauthenticatedFailure carrying the message', () {
        final failure = map('Something unusual happened');
        expect(failure, isA<UnauthenticatedFailure>());
        expect(failure.message, 'Something unusual happened');
      });
    });

    group('domain exceptions', () {
      test('NetworkException → NetworkFailure', () {
        expect(
          ExceptionMapper.toFailure(
            const NetworkException('dropped'),
          ),
          isA<NetworkFailure>(),
        );
      });

      test('app TimeoutException → TimeoutFailure', () {
        expect(
          ExceptionMapper.toFailure(
            const TimeoutException('timed out'),
          ),
          isA<TimeoutFailure>(),
        );
      });

      test('ServerException → ServerFailure with derived code', () {
        final failure = ExceptionMapper.toFailure(
          const ServerException(statusCode: 503, message: 'unavailable'),
        );
        expect(failure, isA<ServerFailure>());
        expect(failure.code, 'SERVER_503');
      });

      test('OtpException → OtpFailure', () {
        expect(
          ExceptionMapper.toFailure(const OtpException('bad otp')),
          isA<OtpFailure>(),
        );
      });

      test('credential wording in AuthException → InvalidCredentialsFailure',
          () {
        expect(
          ExceptionMapper.toFailure(
            const AuthException(message: 'password mismatch'),
          ),
          isA<InvalidCredentialsFailure>(),
        );
      });

      test('other AuthException → UnauthenticatedFailure', () {
        expect(
          ExceptionMapper.toFailure(const AuthException(message: 'mystery')),
          isA<UnauthenticatedFailure>(),
        );
      });

      test('AuthApiException not-found wording → NotFoundFailure', () {
        expect(
          ExceptionMapper.toFailure(
            const AuthApiException('provider not found'),
          ),
          isA<NotFoundFailure>(),
        );
      });

      test('AuthApiException conflict wording → ConflictFailure', () {
        expect(
          ExceptionMapper.toFailure(
            const AuthApiException('already exists'),
          ),
          isA<ConflictFailure>(),
        );
      });

      test('AuthApiException rate wording → RateLimitFailure', () {
        expect(
          ExceptionMapper.toFailure(
            const AuthApiException('too many attempts'),
          ),
          isA<RateLimitFailure>(),
        );
      });

      test('CacheException → CacheFailure', () {
        expect(
          ExceptionMapper.toFailure(const CacheException('disk full')),
          isA<CacheFailure>(),
        );
      });
    });

    test('unknown objects fall back to UnknownFailure with a message', () {
      final failure = ExceptionMapper.toFailure(StateError('boom'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('boom'));
    });
  });
}
