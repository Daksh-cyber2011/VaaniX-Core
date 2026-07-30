/// VaaniX Core Infrastructure Providers
///
/// Lowest-level Riverpod providers shared across the entire app.
/// No feature code should be defined here — only infrastructure.
///
/// Dependency rule: features depend on core; core never imports features.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/preferences_service.dart';
import '../services/secure_storage_service.dart';

// ============================================================
// PRIMITIVE INFRASTRUCTURE
// ============================================================

/// Provides the initialized [SharedPreferences] instance.
///
/// **Must be overridden** in [ProviderScope] at app startup before runApp().
/// See main.dart for the override pattern.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope. '
    'See main.dart for the correct setup.',
  );
});

// ============================================================
// SERVICE LAYER
// ============================================================

/// Logger is a plain singleton — exposed as a provider for testability
/// and so feature code never imports the package directly.
final loggerProvider = Provider<AppLogger>((ref) => AppLogger());

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final preferencesProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(ref.watch(sharedPreferencesProvider));
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService(ref.watch(sharedPreferencesProvider));
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

// apiServiceProvider is exported from api_service.dart.
// Re-referenced here for convenience / discoverability only.
// (Avoid duplicate definition — see api_service.dart.)

// ============================================================
// SUPABASE
// ============================================================

/// The initialized Supabase client.
/// Throws if accessed before Supabase.initialize() is called.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Supabase GoTrue Auth client
final supabaseAuthProvider = Provider<GoTrueClient>(
  (ref) => ref.watch(supabaseClientProvider).auth,
);
