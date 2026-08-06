/// Noop Auth Repository — Offline Fallback
///
/// Used when Supabase is not configured (offline / demo mode). All operations
/// are no-ops: the session is always [AuthSession.empty], writes succeed
/// silently, and the session stream emits a single empty session and never
/// fires again. This lets the app run end-to-end without a backend so
/// onboarding, theme, settings, and the Van companion all work offline.
///
/// See [auth_providers.dart] for the wiring that selects this implementation
/// when [AppEnvironment.isSupabaseConfigured] is false.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:vaanix_app/core/auth/core_auth_session.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/auth/domain/auth_repository.dart';

class NoopAuthRepository implements AuthRepository {
  NoopAuthRepository();

  final StreamController<AuthSession> _controller =
      StreamController<AuthSession>.broadcast();

  bool _emitted = false;

  @override
  Stream<AuthSession> get sessionStream {
    if (!_emitted) {
      _emitted = true;
      // Emit the empty session once so subscribers have an initial value.
      // Scheduled post-frame so any synchronous subscribers are wired up
      // before the event is delivered (broadcast streams drop events with
      // no active listeners).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.isClosed) {
          _controller.add(AuthSession.empty);
        }
      });
    }
    return _controller.stream;
  }

  @override
  AuthSession get currentSession => AuthSession.empty;

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return const Right(AuthSession.empty);
  }

  @override
  Future<Result<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return const Right(AuthSession.empty);
  }

  @override
  Future<Result<void>> sendOtp({required String email}) async {
    return const Right(null);
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String email,
    required String token,
  }) async {
    return const Right(AuthSession.empty);
  }

  @override
  Future<Result<void>> signInWithOAuth({
    required String provider,
  }) async {
    return const Right(null);
  }

  @override
  Future<Result<AuthSession>> refresh() async {
    return const Right(AuthSession.empty);
  }

  @override
  Future<Result<void>> signOut() async {
    return const Right(null);
  }

  void dispose() {
    _controller.close();
  }
}
