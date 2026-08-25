/// VaaniX Router Configuration
///
/// Declarative navigation with go_router. Route paths and names live in
/// [RouteNames]; the structure mirrors the app architecture (PRD §7).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/navigation/navigator_keys.dart';
import 'package:vaanix_app/core/navigation/navigation_service.dart';
import 'package:vaanix_app/app/router/go_router_refresh_notifier.dart';
import 'package:vaanix_app/app/router/splash_screen.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:vaanix_app/features/ai/presentation/screens/chat_screen.dart';
import 'package:vaanix_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/lesson_content_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:vaanix_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:vaanix_app/features/van_profile/presentation/screens/van_profile_screen.dart';

/// Routes reachable without onboarding completion or a session.
const _publicRoutes = <String>{
  RouteNames.splash,
  RouteNames.onboarding,
  RouteNames.auth,
};

/// Routes that additionally require authentication (only enforced when
/// Supabase is configured — see [AppEnvironment.isSupabaseConfigured]).
const _protectedRoutes = <String>{
  RouteNames.home,
  RouteNames.learn,
  RouteNames.exam,
  RouteNames.progress,
  RouteNames.vanProfile,
  RouteNames.settings,
};

/// Riverpod provider for [GoRouter].
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate guards whenever auth state changes.
  final refreshNotifier =
      GoRouterRefreshNotifier(ref.watch(authRepositoryProvider).sessionStream);

  final storage = ref.watch(localStorageServiceProvider);

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // 1. Onboarding gate.
    final onboardingComplete = storage.isOnboardingComplete;
    if (!onboardingComplete && !_publicRoutes.contains(location)) {
      return RouteNames.onboarding;
    }

    // 2. Auth gate (only when a real backend is configured).
    if (AppEnvironment.isSupabaseConfigured &&
        _protectedRoutes.contains(location)) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      if (!isAuthenticated) {
        return RouteNames.auth;
      }
    }

    return null;
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: redirect,
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
      // ONBOARDING (7 screens — PRD §8.1)
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
      // MAIN APP SHELL — StatefulShellRoute with bottom navigation.
      // ----------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: RouteNames.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.learn,
                name: RouteNames.learnName,
                builder: (context, state) => const LearnScreen(),
                routes: [
                  // Lesson content — nested under /learn so back-nav
                  // returns to the lesson tree.
                  GoRoute(
                    path: 'lesson/:lessonId',
                    name: RouteNames.lessonContentName,
                    builder: (context, state) {
                      final lessonId = state.pathParameters['lessonId'] ?? '';
                      // Look up the lesson in the curriculum provider.
                      // We use a ConsumerWidget wrapper to read the
                      // provider at build time.
                      return _LessonContentRoute(lessonId: lessonId);
                    },
                  ),
                  GoRoute(
                    path: 'lesson/:lessonId/practice',
                    name: RouteNames.lessonPracticeName,
                    builder: (context, state) {
                      final lessonId = state.pathParameters['lessonId'] ?? '';
                      return _ExerciseRoute(lessonId: lessonId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.exam,
                name: RouteNames.examName,
                builder: (context, state) => const ExamScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.progress,
                name: RouteNames.progressName,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
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
      // SETTINGS (pushed on top, outside bottom nav)
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.settings,
        name: RouteNames.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ----------------------------------------------------------
      // CHAT (pushed on top, outside bottom nav)
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.chat,
        name: RouteNames.chatName,
        builder: (context, state) => const ChatScreen(),
      ),

      // ----------------------------------------------------------
      // ACHIEVEMENTS (pushed on top, outside bottom nav)
      // ----------------------------------------------------------
      GoRoute(
        path: RouteNames.achievements,
        name: RouteNames.achievementsName,
        builder: (context, state) => const AchievementsScreen(),
      ),
    ],
  );

  ref.onDispose(refreshNotifier.dispose);

  return router;
});

/// Riverpod provider for [NavigationService].
///
/// Defined here (in app/) because it wires GoRouter (from this file) into
/// NavigationService (from core/), which would otherwise create a core → app
/// circular dependency.
final navigationServiceProvider = Provider<NavigationService>((ref) {
  final router = ref.watch(appRouterProvider);
  return NavigationService(router);
});

/// App shell with bottom navigation bar.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
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

/// Wrapper widget that looks up a [Lesson] by ID from [curriculumProvider]
/// and renders [LessonContentScreen]. Shows loading, error, and not-found
/// states. The curriculum is now loaded asynchronously (Segment 8).
class _LessonContentRoute extends ConsumerWidget {
  const _LessonContentRoute({required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);

    return curriculumAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Could not load curriculum: $error',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go(RouteNames.learn),
                child: const Text('Back to Lessons'),
              ),
            ],
          ),
        ),
      ),
      data: (curriculum) {
        Lesson? lesson;
        for (final chapter in curriculum) {
          for (final l in chapter.lessons) {
            if (l.id == lessonId) {
              lesson = l;
              break;
            }
          }
          if (lesson != null) break;
        }

        if (lesson == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lesson Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Could not find lesson: $lessonId',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => context.go(RouteNames.learn),
                    child: const Text('Back to Lessons'),
                  ),
                ],
              ),
            ),
          );
        }

        return LessonContentScreen(lesson: lesson);
      },
    );
  }
}

/// Route wrapper resolving a lesson id to a [Lesson] for the practice screen.
class _ExerciseRoute extends ConsumerWidget {
  const _ExerciseRoute({required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);

    return curriculumAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Could not load curriculum: $error',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go(RouteNames.learn),
                child: const Text('Back to Lessons'),
              ),
            ],
          ),
        ),
      ),
      data: (curriculum) {
        Lesson? lesson;
        for (final chapter in curriculum) {
          for (final l in chapter.lessons) {
            if (l.id == lessonId) {
              lesson = l;
              break;
            }
          }
          if (lesson != null) break;
        }
        if (lesson == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lesson not found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go(RouteNames.learn),
                    child: const Text('Back to Lessons'),
                  ),
                ],
              ),
            ),
          );
        }
        return ExerciseScreen(lesson: lesson);
      },
    );
  }
}
