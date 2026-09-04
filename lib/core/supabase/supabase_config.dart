/// VaaniX Supabase Configuration
///
/// Provides typed access to the Supabase client and its sub-clients
/// (auth, database, storage) via Riverpod providers.
///
/// This file exposes ONLY raw Supabase infrastructure. Authentication
/// *state* (current user, session status, sign-in / sign-out events) is
/// owned by the auth feature (`features/auth/.../auth_providers.dart`),
/// which maps Supabase types into VaaniX domain types so the rest of the
/// app never depends on Supabase directly.
///
/// The Supabase instance is initialized in main.dart before runApp().
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialized Supabase client.
/// Throws if accessed before Supabase.initialize() is called.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Supabase GoTrue Auth client (raw access for repositories).
final supabaseAuthProvider = Provider<GoTrueClient>(
  (ref) => ref.watch(supabaseClientProvider).auth,
);

/// Supabase Realtime + PostgREST client for direct DB queries.
/// (Used for simple CRUD; complex operations go through FastAPI.)
final supabaseDatabaseProvider =
    Provider<SupabaseQueryBuilder Function(String)>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return (tableName) => client.from(tableName);
  },
);

/// Supabase Storage client.
final supabaseStorageProvider = Provider<SupabaseStorageClient>(
  (ref) => ref.watch(supabaseClientProvider).storage,
);
