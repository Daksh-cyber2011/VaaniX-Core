/// VaaniX Router Configuration
///
/// Declarative navigation with go_router. Route paths and names live in
/// [RouteNames]; the structure mirrors the app architecture (PRD §7).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/navigation/navigator_keys.dart';
import 'package:vaanix_app/app/router/go_router_refresh_notifier.dart';
import 'package:vaanix_app/app/router/splash_screen.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:vaanix_app/features/ai/presentation/screens/chat_screen.dart';
import 'package:vaanix_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_profile_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_diagnostic_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_plan_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_hub_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_practice_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_pyq_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_mock_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_weak_area_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_scope_selection_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_scope_summary_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_track_selection_screen.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/presentation/screens/diagnostic_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_language_selection_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_profile_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/smart_practice_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/session_screen.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/presentation/screens/lesson_content_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:vaanix_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:vaanix_app/features/van_profile/presentation/screens/van_profile_screen.dart';
import 'package:vaanix_app/shared/widgets/widgets.dart';

/// Routes reachable without onboarding completion or a session.
const _publicRoutes = <String>{
  RouteNames.splash,
  RouteNames.onboarding,
  RouteNames.auth,
};

/// Routes that additionally require authentication (only enforced when
/// Supabase is configured — see [AppEnvironment.isSupabaseConfigured]).
///
/// Phase 5 (audit defect #17): `/chat` and `/achievements` are pushed on
/// top of the shell and were missing from this set — with Supabase
/// configured, a deep link straight to either screen bypassed the auth
/// gate that every other screen honors. Both are protected now, and the
/// match is prefix-aware so nested sub-routes (e.g. `/learn/lesson/:id`)
/// cannot slip through either.
@visibleForTesting
const protectedRoutes = <String>{
  RouteNames.home,
  RouteNames.learn,
  RouteNames.exam,
  RouteNames.progress,
  RouteNames.vanProfile,
  RouteNames.settings,
  RouteNames.chat,
  RouteNames.achievements,
};

/// True when [location] is exactly a protected route or nested under one.
@visibleForTesting
bool isProtectedLocation(String location) {
  if (protectedRoutes.contains(location)) return true;
  return protectedRoutes
      .any((route) => location.startsWith('$route/'));
}

/// The redirect decision, extracted as a pure function so the gate
/// matrix (onboarding × auth × every route family) is unit-testable
/// without building a [GoRouter] or touching the static environment.
///
/// 1. Onboarding gate — nothing outside [_publicRoutes] is reachable
///    before onboarding completes.
/// 2. Auth gate — protected locations additionally require a session,
///    but only when a real backend is configured (the offline/noop auth
///    repository never has a session, so gating on it would lock
///    offline users out of the whole app).
@visibleForTesting
String? guardRedirect({
  required String location,
  required bool onboardingComplete,
  required bool supabaseConfigured,
  required bool isAuthenticated,
}) {
  if (!onboardingComplete && !_publicRoutes.contains(location)) {
    return RouteNames.onboarding;
  }
  if (supabaseConfigured &&
      isProtectedLocation(location) &&
      !isAuthenticated) {
    return RouteNames.auth;
  }
  return null;
}

/// Riverpod provider for [GoRouter].
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate guards whenever auth state changes.
  final refreshNotifier =
      GoRouterRefreshNotifier(ref.watch(authRepositoryProvider).sessionStream);

  final storage = ref.watch(localStorageServiceProvider);

  String? redirect(BuildContext context, GoRouterState state) {
    return guardRedirect(
      location: state.matchedLocation,
      onboardingComplete: storage.isOnboardingComplete,
      supabaseConfigured: AppEnvironment.isSupabaseConfigured,
      isAuthenticated: ref.read(isAuthenticatedProvider),
    );
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: redirect,
    // Unknown / malformed locations render the branded not-found screen
    // (with a recovery route Home) instead of Flutter's default grey
    // error page. The onboarding/auth guards above still apply first, so
    // an invalid deep link from a cold start lands on onboarding.
    errorBuilder: (context, state) => _NotFoundScreen(
      location: state.uri.toString(),
    ),
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
      // ONBOARDING (6 pages — PRD §8.1 screens 2–7; the splash is
      // screen 1 and lives at its own route)
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
                  // Learn Mode language picker (Part 0 Foundation).
                  // Nested under /learn so back-nav returns to the
                  // lesson tree. Reachable from the Learn screen's
                  // AppBar action.
                  GoRoute(
                    path: 'language',
                    name: RouteNames.learnLanguageSelectionName,
                    builder: (context, state) =>
                        const LearnLanguageSelectionScreen(),
                  ),
                  // M2: per-language learner profile (goal / desired
                  // level / pace / self-report / daily goal). Nested so
                  // back-nav returns to the lesson tree. Automatically
                  // auth-gated: any '/learn/...' location is protected.
                  GoRoute(
                    path: 'profile',
                    name: RouteNames.learnProfileName,
                    builder: (context, state) =>
                        const LearnProfileScreen(),
                  ),
                  // M3: VAN-led adaptive placement game (Discover your
                  // level). Nested under /learn so back-nav returns to
                  // the lesson tree; auth-gated via the '/learn/'
                  // prefix like every other Learn sub-route.
                  GoRoute(
                    path: 'diagnostic',
                    name: RouteNames.learnDiagnosticName,
                    builder: (context, state) =>
                        const DiagnosticScreen(),
                  ),
                  // M5: Smart Practice — trusted-first content resolution
                  // for today's plan step, with learner-triggered AI
                  // personalization (validated, grounded, honestly
                  // labelled). Same '/learn/' auth-gate as the others.
                  GoRoute(
                    path: 'smart',
                    name: RouteNames.learnSmartPracticeName,
                    builder: (context, state) =>
                        const SmartPracticeScreen(),
                  ),
                  // M6: Guided session — the adaptive exercise engine
                  // (Master Brief §18): any of the six activity kinds,
                  // live ladder adaptation, mastery/review evidence.
                  // Query params: kind (ActivityKind name), concept
                  // (trusted concept id), optional knob (1..5). Same
                  // '/learn/' auth-gate as every other Learn route.
                  GoRoute(
                    path: 'session',
                    name: RouteNames.learnSessionName,
                    builder: (context, state) {
                      final query = state.uri.queryParameters;
                      final kind = ActivityKind.tryParse(query['kind']) ??
                          ActivityKind.practice;
                      return SessionScreen(
                        kind: kind,
                        conceptId: query['concept'] ?? '',
                        difficultyKnob:
                            int.tryParse(query['knob'] ?? ''),
                      );
                    },
                  ),
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
                routes: [
                  // Exam Mode 2.0 setup flow (M2): board → class → subject
                  // → course → official syllabus scope → summary. Nested
                  // under the exam branch so the shell stays mounted.
                  GoRoute(
                    path: 'setup',
                    name: RouteNames.examSetupName,
                    builder: (context, state) =>
                        const ExamTrackSelectionScreen(),
                    routes: [
                      GoRoute(
                        path: 'scope/:trackId',
                        name: RouteNames.examScopeName,
                        builder: (context, state) =>
                            ExamScopeSelectionScreen(
                          trackId:
                              state.pathParameters['trackId'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: 'summary/:trackId',
                        name: RouteNames.examScopeSummaryName,
                        builder: (context, state) =>
                            ExamScopeSummaryScreen(
                          trackId:
                              state.pathParameters['trackId'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  // Exam Mode 2.0 — post-setup flow (M3–M7): profile →
                  // diagnostic → plan → practice. Top-level under the
                  // exam branch: reachable both from the setup chain
                  // and later re-entry (edit profile, today's plan).
                  GoRoute(
                    path: 'profile/:trackId',
                    name: RouteNames.examProfileName,
                    builder: (context, state) => ExamProfileScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'diagnostic/:trackId',
                    name: RouteNames.examDiagnosticName,
                    builder: (context, state) => ExamDiagnosticScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'plan/:trackId',
                    name: RouteNames.examPlanName,
                    builder: (context, state) => ExamPlanScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  // Exam Mode 2.0 — M10: the exam-mode HOME. The smart
                  // gate lands here once scope + profile + diagnostic
                  // exist; today's plan, weak area, revision, PYQ,
                  // mock, XP/streak and VAN context live together.
                  GoRoute(
                    path: 'hub/:trackId',
                    name: RouteNames.examHubName,
                    builder: (context, state) => ExamHubScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'practice/:trackId',
                    name: RouteNames.examPracticeName,
                    builder: (context, state) => ExamPracticeScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  // Exam Mode 2.0 — M8: weak-area hub (report + revision
                  // schedule + recovery-day session). Reached from the
                  // plan's weakArea/review tasks.
                  GoRoute(
                    path: 'weakarea/:trackId',
                    name: RouteNames.examWeakAreaName,
                    builder: (context, state) => ExamWeakAreaScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  // Exam Mode 2.0 — M9: PYQ practice track (official
                  // exam-pattern + PYQ-style, §25 labels) and the mock
                  // ladder (mini / section / full).
                  GoRoute(
                    path: 'pyq/:trackId',
                    name: RouteNames.examPyqName,
                    builder: (context, state) => ExamPyqScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'mock/:trackId',
                    name: RouteNames.examMockName,
                    builder: (context, state) => ExamMockScreen(
                      trackId: state.pathParameters['trackId'] ?? '',
                    ),
                  ),
                ],
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

/// Branded fallback for unknown routes. Every reachable location has a
/// valid path; anything else lands here with a way back into the app.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyStateWidget(
        icon: Icons.explore_off_rounded,
        title: 'This page does not exist',
        description:
            'The path "$location" is not part of VaaniX. '
            'Head back to the Nest to keep learning.',
        actionLabel: 'Back to Home',
        onActionPressed: () => context.go(RouteNames.home),
      ),
    );
  }
}

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

/// Wrapper widget that looks up a [Lesson] by ID from [activeCurriculumProvider]
/// and renders [LessonContentScreen]. Shows loading, error, and not-found
/// states. The curriculum is loaded asynchronously and dispatches by the
/// selected Learn language (legacy Sanskrit when no language is selected,
/// the per-language Learn curriculum when one is).
class _LessonContentRoute extends ConsumerWidget {
  const _LessonContentRoute({required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(activeCurriculumProvider);

    return curriculumAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: VaaniXLoadingIndicator(message: 'Preparing your lesson...'),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ErrorStateWidget(
          title: 'Could not load curriculum',
          message:
              'Something interrupted the lesson data. Check your connection and try again.',
          retryLabel: 'Back to Lessons',
          onRetry: () => context.go(RouteNames.learn),
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
            body: EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Lesson not found',
              description:
                  'We could not find lesson $lessonId in the curriculum.',
              actionLabel: 'Back to Lessons',
              onActionPressed: () => context.go(RouteNames.learn),
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
    final curriculumAsync = ref.watch(activeCurriculumProvider);

    return curriculumAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: VaaniXLoadingIndicator(message: 'Preparing your lesson...'),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ErrorStateWidget(
          title: 'Could not load curriculum',
          message:
              'Something interrupted the lesson data. Check your connection and try again.',
          retryLabel: 'Back to Lessons',
          onRetry: () => context.go(RouteNames.learn),
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
            body: EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Lesson not found',
              description:
                  'We could not find lesson $lessonId in the curriculum.',
              actionLabel: 'Back to Lessons',
              onActionPressed: () => context.go(RouteNames.learn),
            ),
          );
        }
        return ExerciseScreen(lesson: lesson);
      },
    );
  }
}
