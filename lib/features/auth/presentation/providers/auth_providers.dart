/// VaaniX Auth Providers (Dependency Injection)
///
/// Wires the [AuthRepository] to the Supabase implementation and exposes
/// reactive accessors consumed by the router and UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/auth/core_auth_repository.dart';
import 'package:vaanix_app/core/providers/session_manager.dart';
import 'package:vaanix_app/core/supabase/supabase_config.dart';
import 'package:vaanix_app/features/auth/data/supabase_auth_repository.dart';
import 'package:vaanix_app/features/auth/domain/auth_repository.dart';
import 'package:vaanix_app/features/auth/domain/auth_session.dart';

/// The polymorphic [AuthRepository]. Override in tests with a fake.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final repo = SupabaseAuthRepository(client);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Exposes the concrete [AuthRepository] as a core-level [CoreAuthRepository].
///
/// This is the dependency-inversion seam: `core`'s [SessionManager] reads
/// [coreAuthRepositoryProvider] without importing feature code, and this
/// provider (in the feature layer) supplies the live implementation. The
/// alias keeps a single source of truth — the Supabase repo built above.
final coreAuthRepositoryProvider = Provider<CoreAuthRepository>((ref) {
  return ref.watch(authRepositoryProvider);
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
