/// VaaniX Theme Provider
///
/// Holds the user's [ThemeMode] choice (light / dark / system) and
/// persists it via [PreferencesService]. The root [VaaniXApp] watches
/// [themeModeProvider] to drive `MaterialApp.router.themeMode`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/preferences_service.dart';
import 'app_providers.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs) : super(_resolve(_prefs.getThemeMode()));

  final PreferencesService _prefs;

  static ThemeMode _resolve(String stored) {
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode.name);
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

/// The active [ThemeMode], persisted across launches.
final themeModeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(preferencesProvider);
  return ThemeNotifier(prefs);
});

// Re-export so callers can `import 'theme_provider.dart'` for everything
// theme-related without needing app_providers.dart too.
export 'app_providers.dart' show preferencesProvider;
