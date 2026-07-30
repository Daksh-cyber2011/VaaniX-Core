/// VaaniX Core Infrastructure Providers
///
/// Lowest-level Riverpod providers shared across the entire app.
/// No feature code should be defined here — only infrastructure.
///
/// Dependency rule: features depend on core; core never imports features.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
