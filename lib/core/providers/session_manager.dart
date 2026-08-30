/// VaaniX Session Manager
///
/// Owns the auth session lifecycle from the app's perspective:
///   - Detects session expiry and triggers a refresh.
///   - Clears local state on sign-out.
///   - Exposes a reactive [sessionManagerProvider] that unifies the
///     auth session stream.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/auth/core_auth_repository.dart';
import 'package:vaanix_app/core/auth/core_auth_session.dart';
import 'package:vaanix_app/core/logging/logger.dart';

/// Core-level handle to the active [CoreAuthRepository].
///
/// The concrete repository is supplied by the auth feature (see
/// `features/auth/presentation/providers/auth_providers.dart`), which overrides
/// this provider. Keeping the dependency inverted here lets [SessionManager]
/// live in `core` without importing feature code, preserving the layer rule:
/// `core` must never depend on `features`.
final coreAuthRepositoryProvider = Provider<CoreAuthRepository>((ref) {
  throw UnimplementedError(
    'coreAuthRepositoryProvider must be overridden by the auth feature '
    'at startup. See features/auth/presentation/providers/auth_providers.dart.',
  );
});

/// Manages the session lifecycle, including expiry handling and refresh.
class SessionManager extends Notifier<AuthSession> {
  late final StreamSubscription<AuthSession> _subscription;

  @override
  AuthSession build() {
    final repository = ref.read(coreAuthRepositoryProvider);

    // Seed with the current known session.
    final initial = repository.currentSession;

    // React to every subsequent auth state change directly from the
    // repository's session stream (a core-owned abstraction).
    _subscription = repository.sessionStream.listen(
      (session) => _onSession(session),
      onError: (Object e, StackTrace st) => AppLogger.error(
        'Session stream error',
        tag: 'SessionManager',
        error: e,
        stackTrace: st,
      ),
    );

    ref.onDispose(_subscription.cancel);

    return initial;
  }

  void _onSession(AuthSession session) {
    AppLogger.info(
      'Session changed → ${session.status.name}',
      tag: 'SessionManager',
    );
    state = session;

    // Auto-refresh if the token is about to expire (within 5 minutes).
    if (session.isAuthenticated && _isExpiringSoon(session)) {
      _refreshSession();
    }
  }

  /// Proactively refresh the token before it expires.
  Future<void> _refreshSession() async {
    AppLogger.info('Refreshing session token', tag: 'SessionManager');
    final result = await ref.read(coreAuthRepositoryProvider).refresh();
    result.fold(
      (failure) => AppLogger.warn(
        'Token refresh failed: ${failure.message}',
        tag: 'SessionManager',
      ),
      (session) =>
          AppLogger.info('Token refreshed successfully', tag: 'SessionManager'),
    );
  }

  /// Signs the user out and clears local auth state.
  Future<void> signOut() async {
    AppLogger.info('Signing out', tag: 'SessionManager');
    final result = await ref.read(coreAuthRepositoryProvider).signOut();
    result.fold(
      (failure) => AppLogger.warn('Sign out error: ${failure.message}',
          tag: 'SessionManager'),
      (_) => AppLogger.info('Signed out successfully', tag: 'SessionManager'),
    );
  }

  /// True when the session will expire within 5 minutes.
  bool _isExpiringSoon(AuthSession session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final threshold = DateTime.now().add(const Duration(minutes: 5));
    return expiresAt.isBefore(threshold);
  }
}

/// Reactive provider for the current [AuthSession].
final sessionManagerProvider = NotifierProvider<SessionManager, AuthSession>(
  SessionManager.new,
);
