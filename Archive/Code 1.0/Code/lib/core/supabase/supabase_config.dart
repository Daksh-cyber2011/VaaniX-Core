/// VaaniX Supabase Configuration
///
/// Provides typed access to the Supabase client and its sub-clients
/// (auth, database, storage) via Riverpod providers.
///
/// The Supabase instance is initialized in main.dart before runApp().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialized Supabase client.
/// Throws if accessed before Supabase.initialize() is called.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Supabase GoTrue Auth client
final supabaseAuthProvider = Provider<GoTrueClient>(
  (ref) => ref.watch(supabaseClientProvider).auth,
);

/// Supabase Realtime + PostgREST client for direct DB queries
/// (Used for simple CRUD; complex operations go through FastAPI)
final supabaseDatabaseProvider = Provider<SupabaseQueryBuilder Function(String)>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return (tableName) => client.from(tableName);
  },
);

/// Supabase Storage client
final supabaseStorageProvider = Provider<SupabaseStorageClient>(
  (ref) => ref.watch(supabaseClientProvider).storage,
);

/// Current user from Supabase auth session (nullable)
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(supabaseAuthProvider).currentUser,
);

/// Auth state stream — emit [AuthState] events on sign in / sign out
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseAuthProvider).onAuthStateChange,
);
