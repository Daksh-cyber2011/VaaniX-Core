/// VaaniX Supabase Higher-Level Providers
///
/// The primitive Supabase providers (`supabaseClientProvider`,
/// `supabaseAuthProvider`) live in `core/providers/app_providers.dart`
/// to avoid duplicate definitions. This file exposes the higher-level
/// reactive auth helpers built on top of them.
///
/// Supabase itself is initialized in main.dart before runApp().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_providers.dart';

/// Supabase Realtime + PostgREST client for direct DB queries.
/// (Used for simple CRUD; complex operations go through FastAPI.)
final supabaseDatabaseProvider =
    Provider<SupabaseQueryBuilder Function(String)>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (tableName) => client.from(tableName);
});

/// Supabase Storage client.
final supabaseStorageProvider = Provider<SupabaseStorageClient>(
  (ref) => ref.watch(supabaseClientProvider).storage,
);

/// Current user from Supabase auth session (nullable).
///
/// Refreshed whenever the [authStateProvider] stream emits, so consumers
/// always see the latest signed-in user.
final currentUserProvider = Provider<User?>((ref) {
  // Watch the auth-state stream so this provider recomputes on change.
  ref.watch<AsyncValue<AuthState>>(authStateProvider);
  return ref.watch(supabaseAuthProvider).currentUser;
});

/// Auth state stream — emits [AuthState] events on sign in / sign out.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseAuthProvider).onAuthStateChange,
);
