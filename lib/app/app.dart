/// VaaniX Root Application Widget
///
/// Sets up:
/// - MaterialApp.router with GoRouter
/// - Global VaaniX theme (light + dark) via [AppTheme]
/// - Reactive [ThemeMode] driven by [themeNotifierProvider]
/// - Keeps [sessionManagerProvider] and the app lifecycle observer alive so
///   token refresh, sign-out, and foreground/background hooks are active for
///   the lifetime of the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/app/router/app_router.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/lifecycle/app_lifecycle_observer.dart';
import 'package:vaanix_app/core/providers/session_manager.dart';
import 'package:vaanix_app/core/theme/app_theme.dart';
import 'package:vaanix_app/core/theme/theme_notifier.dart';

class VaaniXApp extends ConsumerWidget {
  const VaaniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    // Touch the session manager so it initializes its stream subscription
    // and the lifecycle observer so it starts tracking foreground state.
    ref.watch(sessionManagerProvider);
    ref.watch(appLifecycleProvider);

    // Fire the one-shot appOpened analytics event (computes once per
    // container lifetime, so this is exactly one log per cold start).
    ref.watch(appOpenedEventProvider);

    return MaterialApp.router(
      title: 'VaaniX',
      debugShowCheckedModeBanner: false,

      // --- Theme ---
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // --- Router ---
      routerConfig: router,
    );
  }
}
