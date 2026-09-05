/// VaaniX Root Application Widget
///
/// Sets up:
/// - MaterialApp.router with GoRouter
/// - Global VaaniX theme (light + dark) via [AppTheme]
/// - Reactive [ThemeMode] driven by [themeNotifierProvider]
/// - Locale configuration (English + Hindi planned)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_notifier.dart';

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

      // --- Locale ---
      // TODO(i18n): Add flutter_localizations + arb files for EN/HI
    );
  }
}
