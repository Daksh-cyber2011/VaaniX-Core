/// VaaniX Auth Providers (Dependency Injection)
///
/// Wires the [AuthRepository] to the Supabase implementation and exposes
/// reactive accessors consumed by the router and UI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/providers/sync_providers.dart';
import 'package:vaanix_app/core/storage/scoped_local_storage.dart';
import 'package:vaanix_app/core/supabase/supabase_config.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/data/supabase_auth_repository.dart';
import 'package:vaanix_app/features/auth/domain/auth_repository.dart';
import 'package:vaanix_app/features/auth/domain/auth_session.dart';

/// The polymorphic [AuthRepository]. Override in tests with a fake.
///
/// Uses [SupabaseAuthRepository] when Supabase is configured; falls back to
/// [NoopAuthRepository] for offline / unconfigured development builds so the
/// app remains fully functional without a backend.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppEnvironment.isSupabaseConfigured) {
    final client = ref.watch(supabaseClientProvider);
    final repo = SupabaseAuthRepository(client);
    ref.onDispose(repo.dispose);
    return repo;
  }
  final repo = NoopAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Emits the current [AuthSession] and every subsequent change.
final authSessionStreamProvider = StreamProvider<AuthSession>(
  (ref) => ref.watch(authRepositoryProvider).sessionStream,
);

/// Latest [AuthSession] as [AsyncValue].
final authSessionProvider = Provider<AsyncValue<AuthSession>>((ref) {
  return ref.watch(authSessionStreamProvider);
});

/// Synchronous accessor for the latest known session.
final latestAuthSessionProvider = Provider<AuthSession>((ref) {
  final async = ref.watch(authSessionStreamProvider);
  return async.maybeWhen(
    data: (session) => session,
    orElse: () => ref.read(authRepositoryProvider).currentSession,
  );
});

/// True only when an authenticated session is present.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(latestAuthSessionProvider).isAuthenticated,
);

/// Watches the auth session for user-id transitions and rebinds the
/// per-user infrastructure in one place: the [ScopedLocalStorage]
/// re-prefixes its keys, the [SyncService] stops draining the
/// previous user's outbox, and every user-owned Riverpod provider
/// invalidates its in-memory state.
///
/// Why a separate provider: this is the canonical place that knows
/// about BOTH `core/` and the per-user providers it needs to
/// invalidate. Keeping it here (in features/auth) instead of inside
/// the SessionManager preserves the layer rule: `core` never imports
/// features.
///
/// It watches [authSessionStreamProvider] rather than
/// [latestAuthSessionProvider] so there is no circular dependency:
/// the watcher *feeds* the scoped infrastructure, and
/// `latestAuthSessionProvider` must not depend on it.
final authTransitionWatcherProvider = Provider<void>((ref) {
  String? previousUserId;
  ref.listen<AsyncValue<AuthSession>>(authSessionStreamProvider,
      (previous, next) {
    final session = next.valueOrNull;
    if (session == null) return;
    final nextUserId = session.user?.id;
    if (nextUserId == previousUserId) return;
    previousUserId = nextUserId;

    // 1. Rebind the scoped storage so reads/writes go to the right
    //    namespace. The previous user's data remains on disk but is
    //    not surfaced to the new user.
    ref.read(scopedLocalStorageProvider).rebind(nextUserId);

    // 2. Rebind the sync service. Pending operations belonging to the
    //    previous user are NOT drained — they remain in storage for
    //    that user's next sign-in on this device.
    ref.read(syncServiceProvider).rebindUser(nextUserId);

    // 3. Invalidate every user-owned provider so the UI rebuilds
    //    against the new identity. Without this, in-memory state
    //    from User A would still be visible to User B until the
    //    next manual refresh.
    _invalidateUserScopedProviders(ref);
  });
});

/// The set of providers that hold user-owned in-memory state. Adding
/// a new provider here is the only action required for cross-user
/// isolation to take effect — the listener above drives the
/// invalidation.
void _invalidateUserScopedProviders(Ref ref) {
  // The AI conversation memory, response cache, and token usage
  // tracker are all keyed by user-scoped storage keys, so the
  // rebind above already routes their reads correctly — but their
  // in-memory caches (e.g. `ResponseCache._memory`) are NOT scoped.
  // Invalidate so the next read rebuilds from the new user.
  ref.invalidate(responseCacheProvider);
  ref.invalidate(tokenUsageTrackerProvider);
  ref.invalidate(conversationMemoryProvider);
}

