/// VaaniX Theme Provider
///
/// Makes [ThemeMode] reactive — the user can toggle dark/light/system
/// from the Settings screen and the change propagates everywhere immediately.
///
/// Theme preference is persisted via [LocalStorageService] and restored on
/// every app launch. The [AppTheme] itself lives in [core/theme/app_theme.dart];
/// this file only manages which mode is active.
///
/// Consuming widgets:
/// ```dart
/// // Read the current mode:
/// final themeMode = ref.watch(themeModeProvider);
///
/// // Change it (e.g., from Settings):
/// ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../utils/logger.dart';

/// The [ThemeNotifier] persists and restores the user's preferred [ThemeMode].
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Restore persisted preference on first access.
    final storage = ref.watch(localStorageServiceProvider);
    final raw = storage.themeMode;
    return _fromString(raw);
  }

  /// Persist and apply a new [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(localStorageServiceProvider);
    await storage.setThemeMode(_toString(mode));
    AppLogger.info(
      'Theme changed to ${mode.name}',
      tag: 'ThemeNotifier',
    );
  }

  /// Toggle between dark and light (ignores system).
  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static ThemeMode _fromString(String? raw) {
    return switch (raw) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      _        => ThemeMode.system,
    };
  }

  static String _toString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

/// Provider for the [ThemeNotifier].
final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
