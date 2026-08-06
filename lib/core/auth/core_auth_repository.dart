/// VaaniX Core Auth Repository Contract
///
/// Abstract interface for authentication operations.
/// Feature-specific auth repositories implement this interface.

import 'package:vaanix_app/core/auth/core_auth_session.dart';
import 'package:vaanix_app/core/utils/result.dart';

abstract class CoreAuthRepository {
  /// Emits the current [AuthSession] and every subsequent change.
  Stream<AuthSession> get sessionStream;

  /// The current session snapshot.
  AuthSession get currentSession;

  /// Sign in with an email and password.
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with an email and password.
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Send a one-time password / magic link to [email].
  Future<Result<void>> sendOtp({required String email});

  /// Verify an OTP previously sent via [sendOtp].
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String token,
  });

  /// Sign in using a third-party OAuth provider (e.g. 'google', 'apple').
  ///
  /// Returns `Result<void>` because OAuth opens a browser/tab and the
  /// actual session arrives asynchronously via [sessionStream]. Callers
  /// should watch `authSessionStreamProvider` for the resulting session.
  Future<Result<void>> signInWithOAuth({required String provider});

  /// Refresh the current session if possible.
  Future<Result<AuthSession>> refresh();

  /// Sign out and clear local credentials.
  Future<Result<void>> signOut();
}
