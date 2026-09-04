/// Supabase Auth Repository Implementation
///
/// Adapts the Supabase GoTrue client to the VaaniX [AuthRepository] contract.
///
/// Note: We `hide AuthException` from supabase_flutter to avoid a name clash
/// with VaaniX's own `AuthException` (from lib/core/errors/exceptions.dart).
/// ExceptionMapper still handles Supabase's AuthException correctly because
/// it imports supabase_flutter with an `as supabase` prefix and pattern-matches
/// on `supabase.AuthException` explicitly. When Supabase throws an AuthException,
/// it flows through guardAsync → ExceptionMapper.toFailure → the supabase.AuthException
/// branch → correct Failure type (InvalidCredentialsFailure / NotFoundFailure /
/// ConflictFailure / RateLimitFailure / UnauthenticatedFailure).
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, AuthApiException, AuthUser;

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/auth/domain/auth_repository.dart';
import 'package:vaanix_app/features/auth/domain/auth_session.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  late final GoTrueClient _auth = _client.auth;

  StreamSubscription<AuthState>? _sub;
  final StreamController<AuthSession> _controller =
      StreamController<AuthSession>.broadcast();

  @override
  Stream<AuthSession> get sessionStream {
    if (_sub == null) {
      _sub = _auth.onAuthStateChange.listen(_onAuthStateChange);
      _controller.add(_mapSession(_auth.currentSession));
    }
    return _controller.stream;
  }

  void _onAuthStateChange(AuthState event) {
    _controller.add(_mapFromEvent(event));
  }

  @override
  AuthSession get currentSession => _mapSession(_auth.currentSession);

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return guardAsync(() async {
      final res = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _mapSession(res.session);
    });
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return guardAsync(() async {
      final res = await _auth.signUp(
        email: email,
        password: password,
      );
      return _mapSession(res.session);
    });
  }

  @override
  Future<Result<void>> sendOtp({required String email}) {
    return guardAsync(() async {
      await _auth.signInWithOtp(email: email);
    });
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String token,
  }) {
    return guardAsync(() async {
      final res = await _auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return _mapSession(res.session);
    });
  }

  @override
  Future<Result<void>> signInWithOAuth({required String provider}) {
    return guardAsync(() async {
      // Validate the provider name instead of silently defaulting to Google.
      // An unknown provider name now throws AuthException, which
      // ExceptionMapper maps to UnauthenticatedFailure (or
      // InvalidCredentialsFailure if the message contains 'credential').
      final oauthProvider = OAuthProvider.values.firstWhere(
        (p) => p.name == provider,
        orElse: () => throw Exception(
          'Unknown OAuth provider: "$provider". '
          'Supported providers: '
          '${OAuthProvider.values.map((p) => p.name).join(', ')}.',
        ),
      );
      // signInWithOAuth opens the browser; the session arrives later via
      // sessionStream (onAuthStateChange). Return void — callers should
      // listen to authSessionStreamProvider for the resulting session.
      await _auth.signInWithOAuth(oauthProvider);
    });
  }

  @override
  Future<Result<AuthSession>> refresh() {
    return guardAsync(() async {
      final res = await _auth.refreshSession();
      return _mapSession(res.session);
    });
  }

  @override
  Future<Result<void>> signOut() {
    return guardAsync(() async {
      await _auth.signOut();
    });
  }

  // ──────────────────────────────────────────────────────────────────
  // Mapping helpers
  // ──────────────────────────────────────────────────────────────────

  AuthSession _mapFromEvent(AuthState event) {
    final session = event.session;
    if (session == null) {
      return event.event == AuthChangeEvent.tokenRefreshed
          ? const AuthSession(status: AuthStatus.sessionExpired)
          : AuthSession.empty;
    }
    return _toSession(session);
  }

  AuthSession _mapSession(Session? session) {
    if (session == null) return AuthSession.empty;
    return _toSession(session);
  }

  AuthSession _toSession(Session session) {
    final user = session.user;
    return AuthSession(
      status: AuthStatus.authenticated,
      user: _toUser(user),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  AuthUser _toUser(User user) {
    final meta = user.userMetadata;
    // Use ?.toString() instead of `as String?` to avoid TypeError when
    // Supabase metadata contains a non-string value at these keys
    // (e.g., an int user id, or a Map for nested profile data).
    return AuthUser(
      id: user.id,
      email: user.email,
      phone: user.phone,
      displayName: meta?['name']?.toString() ??
          meta?['full_name']?.toString() ??
          meta?['user_name']?.toString(),
      photoUrl: meta?['avatar_url']?.toString() ?? meta?['picture']?.toString(),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _controller.close();
  }
}
