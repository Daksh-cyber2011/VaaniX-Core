/// VaaniX Auth Repository
///
/// Contract for authentication operations.
///
/// The repository returns [Result]s — domain failures instead of throwing.
/// Implementations (e.g. [SupabaseAuthRepository]) live in the data layer and
/// translate platform exceptions via [ExceptionMapper].

import '../../../../core/utils/result.dart';
import 'auth_session.dart';

abstract class AuthRepository {
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
  Future<Result<AuthSession>> signInWithOAuth({required String provider});

  /// Refresh the current session if possible.
  Future<Result<AuthSession>> refresh();

  /// Sign out and clear local credentials.
  Future<Result<void>> signOut();
}
