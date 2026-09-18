/// VaaniX Duplicate-Push Protection
///
/// Problem this solves
/// -------------------
/// Every stacked (non-shell) destination in the app is reached with
/// `context.push(...)` from a tappable widget. `push` is unconditional: two
/// pointer-up events delivered before the first pushed route finishes its
/// transition produce TWO identical pages on the navigator stack. The user
/// then has to press back twice to leave a screen they opened once, and any
/// screen holding a controller/stream (Chat, Session) runs two live copies.
///
/// Why this is not a debounce
/// --------------------------
/// A `bool _navigating` guard would need a timer to clear, would guess the
/// transition duration, and would swallow a legitimate second navigation to a
/// *different* destination that happens to arrive inside the window. Instead
/// this consults the router's own state: `GoRouter.push` mutates
/// `routerDelegate.currentConfiguration` synchronously (the returned Future
/// only completes with the pop result), so by the time a second tap handler
/// runs — even in the same frame — the delegate already reports the pushed
/// location as the current one. Comparing against it is therefore an exact
/// "is this destination already on top?" test rather than a time heuristic.
///
/// Scope (deliberately narrow)
/// ---------------------------
/// * No router rewrite: the [GoRouter] in `app_router.dart` is untouched and
///   no observer/navigator key is added.
/// * Back navigation is untouched: nothing here pops, intercepts
///   `PopScope`, or changes the stack shape.
/// * Only *duplicate* pushes are dropped. Pushing any other location, or
///   re-pushing a location that is on the stack but not on top (A → B → A),
///   proceeds normally.
/// * `goBranch` / `go` callers (bottom navigation, redirects) are not
///   affected — `go` replaces the stack and cannot duplicate.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Duplicate-safe `push` on the router itself, for call sites that already
/// hold a [GoRouter] instead of a [BuildContext].
extension UniquePushRouter on GoRouter {
  /// Pushes [location] unless it is already the current (top-most) location.
  ///
  /// Returns `null` immediately when the push is suppressed, which matches
  /// the `Future<T?>` contract of [GoRouter.push] (that future also completes
  /// with `null` when a route is popped without a result).
  Future<T?> pushUnique<T extends Object?>(String location, {Object? extra}) {
    if (isCurrentLocation(location)) {
      return Future<T?>.value();
    }
    return push<T>(location, extra: extra);
  }

  /// True when the router's current configuration already resolves to
  /// [location] — i.e. a push of [location] would stack a second copy of the
  /// page the user is looking at.
  ///
  /// Two public signals are consulted because go_router treats imperative
  /// pushes specially: an imperative match is appended to the match list
  /// WITHOUT rewriting the list's own `uri` (the list keeps the declarative
  /// location), while the appended match carries the pushed path in
  /// `matchedLocation`. Checking both covers the declarative case (`go`,
  /// deep link, redirect) and the imperative case (`push`).
  ///
  /// The comparison is deliberately fail-safe: if neither signal matches,
  /// the push proceeds. A missed duplicate degrades to today's behaviour,
  /// whereas a false positive would silently break real navigation.
  @visibleForTesting
  bool isCurrentLocation(String location) {
    final config = routerDelegate.currentConfiguration;
    if (config.isEmpty) return false;
    if (config.uri.toString() == location) return true;
    return config.matches.last.matchedLocation == location;
  }
}

/// Duplicate-safe `push` for widget call sites.
extension UniquePushContext on BuildContext {
  /// See [UniquePushRouter.pushUnique].
  Future<T?> pushUnique<T extends Object?>(String location, {Object? extra}) {
    return GoRouter.of(this).pushUnique<T>(location, extra: extra);
  }
}

/// [pushUnique] for the exam flow's `pushNamed(name, pathParameters: …)`
/// call sites, which build a parameterised location (e.g.
/// `'/exam/hub/:trackId'`) rather than a literal one.
///
/// [GoRouter.namedLocation] resolves name + parameters to the same location
/// string [GoRoute] would produce, so the duplicate check reduces to the
/// same [UniquePushRouter.isCurrentLocation] comparison used by the plain
/// `push` call sites — no separate name-aware comparison logic is needed.
extension UniquePushNamedRouter on GoRouter {
  Future<T?> pushNamedUnique<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    final location = namedLocation(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
    if (isCurrentLocation(location)) {
      return Future<T?>.value();
    }
    return pushNamed<T>(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}

extension UniquePushNamedContext on BuildContext {
  /// See [UniquePushNamedRouter.pushNamedUnique].
  Future<T?> pushNamedUnique<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    return GoRouter.of(this).pushNamedUnique<T>(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}
