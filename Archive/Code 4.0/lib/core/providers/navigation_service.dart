/// VaaniX Navigation Service
///
/// Provides programmatic navigation capabilities that do not require a
/// [BuildContext]. This is essential for:
///   - Navigating after async operations in repositories or services.
///   - Navigation triggered from background tasks (e.g. deep links).
///   - Testing navigation logic without a widget tree.
///
/// The service wraps [GoRouter] and exposes typed helper methods so feature
/// code never hard-codes route strings. All route names come from [RouteNames].
///
/// Usage:
/// ```dart
/// // In a notifier or service (no BuildContext needed):
/// ref.read(navigationServiceProvider).goHome();
/// ref.read(navigationServiceProvider).goNamed(RouteNames.settings);
/// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_names.dart';
import '../router/app_router.dart';

/// Wraps [GoRouter] to provide context-free programmatic navigation.
class NavigationService {
  NavigationService(this._router);

  final GoRouter _router;

  // ─── Core methods ──────────────────────────────────────────────────────────

  /// Navigate to [location] (path-based), replacing the current entry.
  void go(String location) => _router.go(location);

  /// Push [location] onto the navigation stack.
  void push(String location) => _router.push(location);

  /// Navigate to a named route with optional parameters.
  void goNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
  }) {
    _router.goNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  /// Pop the current route. Does nothing if there is nothing to pop.
  void pop() {
    if (_router.canPop()) _router.pop();
  }

  // ─── Typed helpers ─────────────────────────────────────────────────────────

  void goSplash()     => go(RouteNames.splash);
  void goOnboarding() => go(RouteNames.onboarding);
  void goAuth()       => go(RouteNames.auth);
  void goHome()       => go(RouteNames.home);
  void goLearn()      => go(RouteNames.learn);
  void goExam()       => go(RouteNames.exam);
  void goProgress()   => go(RouteNames.progress);
  void goVanProfile() => go(RouteNames.vanProfile);
  void goSettings()   => push(RouteNames.settings); // Settings is pushed, not replaced
}

/// Riverpod provider for [NavigationService].
final navigationServiceProvider = Provider<NavigationService>((ref) {
  final router = ref.watch(appRouterProvider);
  return NavigationService(router);
});
