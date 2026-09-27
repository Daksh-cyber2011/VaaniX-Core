/// VaaniX Core Infrastructure Providers
///
/// Lowest-level Riverpod providers shared across the entire app.
/// No feature code should be defined here — only infrastructure.
///
/// Dependency rule: features depend on core; core never imports features.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/core/storage/scoped_local_storage.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';

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

/// Raw, un-scoped [LocalStorageService]. Reserved for use by the
/// scope manager itself and by tests. Feature code should depend on
/// [scopedLocalStorageProvider] instead so reads/writes are always
/// namespaced by the current user.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});

/// The per-user scoped storage. Every key read or written by feature
/// code goes through here, so two users signing in and out on the
/// same device cannot see each other's local data.
final scopedLocalStorageProvider = Provider<ScopedLocalStorage>((ref) {
  final inner = ref.watch(localStorageServiceProvider);
  final session = ref.watch(latestAuthSessionProvider);
  final scoped = ScopedLocalStorage(inner);
  scoped.rebind(session.user?.id);
  return scoped;
});
