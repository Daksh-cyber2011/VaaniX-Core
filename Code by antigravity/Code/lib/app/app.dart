/// VaaniX Root Application Widget
///
/// Sets up:
/// - MaterialApp.router with GoRouter
/// - Global VaaniX theme (light + dark)
/// - Locale configuration (English + Hindi planned)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class VaaniXApp extends ConsumerWidget {
  const VaaniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'VaaniX',
      debugShowCheckedModeBanner: false,

      // --- Theme ---
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // --- Router ---
      routerConfig: router,

      // --- Locale ---
      // TODO: Add flutter_localizations + arb files for EN/HI in a later phase
    );
  }
}
