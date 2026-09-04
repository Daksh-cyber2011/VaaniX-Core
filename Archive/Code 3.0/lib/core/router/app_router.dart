/// VaaniX Router Configuration
///
/// Uses go_router for declarative navigation with named routes.
/// All route name constants are in [RouteNames].
///
/// Route structure mirrors the app architecture from PRD Section 7.
///
/// Navigation guards:
///   - Unauthenticated users who try to access main app routes are
///     redirected to onboarding (checked via SharedPreferences).
///   - The splash screen handles the initial routing decision.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/router/splash_screen.dart';
import 'package:vaanix_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_screen.dart';
import 'package:vaanix_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vaanix_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:vaanix_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:vaanix_app/features/van_profile/presentation/screens/van_profile_screen.dart';

/// Riverpod provider for [GoRouter].
///
/// The router reads [sharedPreferencesProvider] once on creation to set up
/// the redirect guard. Since SharedPreferences is an in-memory cache backed
/// by disk, `prefs.getBool(...)` always returns the current value even after
/// `markOnboardingComplete()` writes it — so the guard stays accurate.
final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,

    /// Navigation guard: blocks access to main app routes until onboarding
    /// is complete. The splash screen handles the first routing decision;
    /// this redirect is a safety net for deep links and back-navigation.
    redirect: (BuildContext context, GoRouterState state) {
      final isComplete =
          prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

      // Routes that are always accessible regardless of onboarding state
      const publicRoutes = {
        RouteNames.splash,
        RouteNames.onboarding,
        RouteNames.auth,
      };

      if (!isComplete && !publicRoutes.contains(state.matchedLocation)) {
        return RouteNames.onboarding;
      }
      return null;
    },

    routes: [
      // ----------------------------------------------------------
      // SPLASH
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.splash,
        name: RouteNames.splashName,
        builder: (context, state) => const SplashScreen(),
      ),

      // ----------------------------------------------------------
      // ONBOARDING (7 screens — PRD Section 8.1)
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.onboarding,
        name: RouteNames.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ----------------------------------------------------------
      // AUTH
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.auth,
        name: RouteNames.authName,
        builder: (context, state) => const AuthScreen(),
      ),

      // ----------------------------------------------------------
      // MAIN APP SHELL — Shell route with bottom navigation
      // ----------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _AppShell(
          navigationShell: navigationShell,
        ),
        branches: [
          // HOME — The Nest
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: RouteNames.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // LEARN MODE
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.learn,
                name: RouteNames.learnName,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),

          // EXAM MODE
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.exam,
                name: RouteNames.examName,
                builder: (context, state) => const ExamScreen(),
              ),
            ],
          ),

          // PROGRESS
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.progress,
                name: RouteNames.progressName,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),

          // VAN PROFILE
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.vanProfile,
                name: RouteNames.vanProfileName,
                builder: (context, state) => const VanProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ----------------------------------------------------------
      // SETTINGS (pushed on top, not in bottom nav)
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.settings,
        name: RouteNames.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// App shell with bottom navigation bar.
/// Stateful so each branch preserves its scroll position and state.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Exam',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_nature_outlined),
            selectedIcon: Icon(Icons.emoji_nature),
            label: 'Van',
          ),
        ],
      ),
    );
  }
}
