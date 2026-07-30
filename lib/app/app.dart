/// VaaniX Root Application Widget
///
/// Sets up:
/// - MaterialApp.router with GoRouter
/// - Global VaaniX theme (light + dark) via [AppTheme]
/// - Reactive [ThemeMode] driven by [themeNotifierProvider]

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/app/router/app_router.dart';
import 'package:vaanix_app/core/theme/app_theme.dart';
import 'package:vaanix_app/core/theme/theme_notifier.dart';

class VaaniXApp extends ConsumerWidget {
  const VaaniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeNotifierProvider);

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
