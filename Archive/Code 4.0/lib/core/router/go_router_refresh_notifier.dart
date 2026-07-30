/// VaaniX Router Refresh Notifier
///
/// Bridges Riverpod auth state into go_router's `refreshListenable` so the
/// router re-evaluates its redirect whenever the user signs in or out.
///
/// Pattern (go_router + Riverpod, codegen-free):
///   1. This [GoRouterRefreshNotifier] is a [ChangeNotifier].
///   2. It subscribes to the auth session stream and calls `notifyListeners()`
///      on every change.
///   3. [appRouterProvider] passes it to `GoRouter(refreshListenable: ...)`.
///   4. The provider owns its lifecycle and disposes the subscription.
///
/// This keeps a single source of truth (the auth stream) driving navigation.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_session.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Stream<AuthSession> sessionStream) {
    _subscription = sessionStream.asBroadcastStream().listen(
      _onSessionChanged,
    );
  }

  StreamSubscription<AuthSession>? _subscription;

  void _onSessionChanged(_) {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
