/// VaaniX Auth Providers (Dependency Injection)
///
/// Wires the [AuthRepository] to the Supabase implementation and exposes
/// reactive accessors consumed by the router and UI.
///
/// Layering:
///   - [authRepositoryProvider] : the contract
///   - [supabaseAuthRepositoryProvider] : Supabase impl, disposed on scope end
///   - [authSessionStreamProvider] : raw [AuthSession] stream
///   - [authSessionProvider] : the latest session as async state
///   - [isAuthenticatedProvider] : synchronous boolean for router guards

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// The polymorphic [AuthRepository]. Override in tests with a fake.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final repo = SupabaseAuthRepository(client);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Emits the current [AuthSession] and every subsequent change.
final authSessionStreamProvider = StreamProvider<AuthSession>(
  (ref) => ref.watch(authRepositoryProvider).sessionStream,
);

/// Latest [AuthSession] as [AsyncValue]. Used by widgets that want the
/// loading/data/error pattern; router guards should prefer
/// [isAuthenticatedProvider] / [latestAuthSessionProvider].
final authSessionProvider = Provider<AsyncValue<AuthSession>>((ref) {
  return ref.watch(authSessionStreamProvider);
});

/// Synchronous accessor for the latest known session.
///
/// Defaults to [AuthSession.empty] until the first stream event arrives so
/// router guards have a stable value to read.
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
