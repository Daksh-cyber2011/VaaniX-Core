/// VaaniX App Lifecycle Provider
///
/// Surfaces the [AppLifecycleState] of the root widgets binding so that
/// other providers/listeners can react to resumed / paused / detached
/// events (e.g. refresh session on resume, stop syncs when paused).
///
/// State is `null` until the first lifecycle notification arrives.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that the root [WidgetsBindingObserver] (installed in
/// [VaaniXApp]) updates on every lifecycle change.
class AppLifecycleNotifier extends StateNotifier<AppLifecycleState?>
    with WidgetsBindingObserver {
  AppLifecycleNotifier() : super(WidgetsBinding.instance.lifecycleState) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Latest [AppLifecycleState], or `null` before the first event.
final appLifecycleProvider =
    StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState?>((ref) {
  return AppLifecycleNotifier();
});

/// Convenience: true when the app is in the foreground (resumed).
final isAppForegroundProvider = Provider<bool>((ref) {
  final lifecycle = ref.watch(appLifecycleProvider);
  return lifecycle == null || lifecycle == AppLifecycleState.resumed;
});
