/// VaaniX Session Manager
///
/// Owns the auth session lifecycle from the app's perspective:
///   - Detects session expiry and triggers a refresh.
///   - Clears local state on sign-out.
///   - Exposes a reactive [sessionStateProvider] that unifies the
///     Supabase session stream with local-only (no-backend) mode.
///
/// Feature code should use [sessionStateProvider] rather than reaching
/// directly into [authRepositoryProvider], which keeps the auth plumbing
/// centralized here.
///
/// Relationship to the router:
///   The [GoRouterRefreshNotifier] already triggers re-evaluation on every
///   auth state change. [SessionManager] handles the *action* side
///   (refresh, sign-out cleanup), while the router handles the *navigation*
///   side. They operate independently and do not call each other.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import '../../features/auth/domain/auth_session.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Manages the session lifecycle, including expiry handling and refresh.
class SessionManager extends Notifier<AuthSession> {
  @override
  AuthSession build() {
    // Seed with the current known session.
    final initial = ref.read(authRepositoryProvider).currentSession;

    // React to every subsequent auth state change.
    ref.listen<AsyncValue<AuthSession>>(
      authSessionStreamProvider,
      (_, next) => _onSessionChange(next),
    );

    return initial;
  }

  void _onSessionChange(AsyncValue<AuthSession> value) {
    value.when(
      data: (session) {
        AppLogger.info(
          'Session changed → ${session.status.name}',
          tag: 'SessionManager',
        );
        state = session;

        // Auto-refresh if the token is about to expire (within 5 minutes).
        if (session.isAuthenticated && _isExpiringSoon(session)) {
          _refreshSession();
        }
      },
      loading: () => AppLogger.verbose('Session loading', tag: 'SessionManager'),
      error: (e, st) => AppLogger.error(
        'Session stream error',
        tag: 'SessionManager',
        error: e,
        stackTrace: st,
      ),
    );
  }

  /// Proactively refresh the token before it expires.
  Future<void> _refreshSession() async {
    AppLogger.info('Refreshing session token', tag: 'SessionManager');
    final result = await ref.read(authRepositoryProvider).refresh();
    result.fold(
      (failure) => AppLogger.warn(
        'Token refresh failed: ${failure.message}',
        tag: 'SessionManager',
      ),
      (session) => AppLogger.info('Token refreshed successfully', tag: 'SessionManager'),
    );
  }

  /// Signs the user out and clears local auth state.
  Future<void> signOut() async {
    AppLogger.info('Signing out', tag: 'SessionManager');
    final result = await ref.read(authRepositoryProvider).signOut();
    result.fold(
      (failure) => AppLogger.warn('Sign out error: ${failure.message}', tag: 'SessionManager'),
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
///
/// Feature repositories and UI should observe this instead of
/// [latestAuthSessionProvider] when they need lifecycle awareness.
final sessionManagerProvider = NotifierProvider<SessionManager, AuthSession>(
  SessionManager.new,
);
