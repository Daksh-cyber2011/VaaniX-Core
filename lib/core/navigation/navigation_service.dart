/// VaaniX Navigation Service
///
/// Provides programmatic navigation capabilities that do not require a
/// [BuildContext]. This is essential for:
///   - Navigating after async operations in repositories or services.
///   - Navigation triggered from background tasks (e.g. deep links).
///   - Displaying global snackbars, dialogs, and bottom sheets.
///
/// The service wraps [GoRouter] and exposes typed helper methods so feature
/// code never hard-codes route strings. All route names come from [RouteNames].
///
/// The [navigationServiceProvider] is defined in `app/router/app_router.dart`
/// (the only place that imports both this service and the GoRouter instance)
/// to avoid a `core ↔ app` circular dependency.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/navigation/navigator_keys.dart';

/// Wraps [GoRouter] to provide context-free programmatic navigation.
class NavigationService {
  NavigationService(this._router);

  final GoRouter _router;

  /// Access the root navigator context if available.
  BuildContext? get currentContext => rootNavigatorKey.currentContext;

  // ─── Core Navigation Methods ──────────────────────────────────────────────

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
  void pop<T extends Object?>([T? result]) {
    if (_router.canPop()) _router.pop(result);
  }

  // ─── Dialog & UI Overlay Helpers ──────────────────────────────────────────

  /// Shows a modal dialog using the root navigator.
  Future<T?> showDialogHelper<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final context = currentContext;
    if (context == null) return Future.value(null);
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// Shows a modal bottom sheet using the root navigator.
  Future<T?> showBottomSheetHelper<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    final context = currentContext;
    if (context == null) return Future.value(null);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  /// Shows a snackbar notification globally.
  void showSnackBar(String message, {bool isError = false}) {
    final context = currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ─── Typed Route Helpers ──────────────────────────────────────────────────

  void goSplash() => go(RouteNames.splash);
  void goOnboarding() => go(RouteNames.onboarding);
  void goAuth() => go(RouteNames.auth);
  void goHome() => go(RouteNames.home);
  void goLearn() => go(RouteNames.learn);
  void goExam() => go(RouteNames.exam);
  void goProgress() => go(RouteNames.progress);
  void goVanProfile() => go(RouteNames.vanProfile);
  void goSettings() => push(RouteNames.settings);
}
