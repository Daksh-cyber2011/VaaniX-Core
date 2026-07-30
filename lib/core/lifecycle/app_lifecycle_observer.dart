/// VaaniX App Lifecycle Observer
///
/// Observes the Flutter app lifecycle (foreground, background, inactive,
/// detached) and broadcasts changes to the rest of the app via Riverpod.
///
/// Why this matters for VaaniX:
///   - Pause Van's idle animation when the app goes to background.
///   - Refresh session / check connectivity on resume.
///   - Update the "last active date" for streak tracking when detaching.
///   - Throttle network requests when inactive.
///
/// Riverpod wiring:
/// ```dart
/// // In a widget:
/// final lifecycle = ref.watch(appLifecycleProvider);
/// if (lifecycle == AppLifecycleState.resumed) { /* refresh */ }
/// ```
///
/// Registration: attach [AppLifecycleObserver] in [VaaniXApp] or the
/// root [ConsumerStatefulWidget] using [WidgetsBinding.addObserver].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/logging/logger.dart';

/// Notifier that tracks the current [AppLifecycleState].
class _LifecycleNotifier extends Notifier<AppLifecycleState>
    with WidgetsBindingObserver {
  @override
  AppLifecycleState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.verbose('App lifecycle → ${state.name}', tag: 'Lifecycle');
    this.state = state;
  }
}

/// Reactive provider for the current [AppLifecycleState].
///
/// Observe this to react to app foreground / background transitions.
final appLifecycleProvider =
    NotifierProvider<_LifecycleNotifier, AppLifecycleState>(
  _LifecycleNotifier.new,
);

/// Convenience: true while the app is in the foreground and fully interactive.
final isAppInForegroundProvider = Provider<bool>((ref) {
  final state = ref.watch(appLifecycleProvider);
  return state == AppLifecycleState.resumed;
});
