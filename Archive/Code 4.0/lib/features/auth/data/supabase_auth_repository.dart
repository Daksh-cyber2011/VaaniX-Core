/// Supabase Auth Repository Implementation
///
/// Adapts the Supabase GoTrue client to the VaaniX [AuthRepository] contract.
///
/// Responsibilities:
///   - Map Supabase [Session] / [User] into VaaniX [AuthSession] / [AuthUser].
///   - Translate Supabase [AuthException]s into domain [Failure]s via
///     [ExceptionMapper] using the `guardAsync` helper.
///   - Expose a reactive [sessionStream] so the router and UI can respond to
///     sign-in / sign-out events without polling.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/exception_mapper.dart';
import '../../../core/utils/result.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  late final GoTrueClient _auth = _client.auth;

  StreamSubscription<AuthState>? _sub;
  final StreamController<AuthSession> _controller =
      StreamController<AuthSession>.broadcast();

  @override
  Stream<AuthSession> get sessionStream {
    // Lazily attach the Supabase listener the first time someone subscribes.
    if (_sub == null) {
      _sub = _auth.onAuthStateChange.listen(_onAuthStateChange);
      // Emit the current state immediately so late subscribers don't miss it.
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
  Future<Result<AuthSession>> signInWithOAuth({required String provider}) {
    return guardAsync(() async {
      // OAuth completes out-of-band via deep link redirect; this call launches
      // the browser/app. The session arrives later through [sessionStream].
      await _auth.signInWithOAuth(
        OAuthProvider.values.firstWhere(
          (p) => p.name == provider,
          orElse: () => OAuthProvider.google,
        ),
      );
      return currentSession;
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
      return event.eventName == 'TOKEN_REFRESHED'
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
      user: user == null ? null : _toUser(user),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : null,
    );
  }

  AuthUser _toUser(User user) {
    final meta = user.userMetadata;
    return AuthUser(
      id: user.id,
      email: user.email,
      phone: user.phone,
      displayName: (meta['name'] as String?) ??
          (meta['full_name'] as String?) ??
          (meta['user_name'] as String?),
      photoUrl: (meta['avatar_url'] as String?) ??
          (meta['picture'] as String?),
    );
  }

  /// Release the Supabase subscription. Safe to call multiple times.
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _controller.close();
  }
}
