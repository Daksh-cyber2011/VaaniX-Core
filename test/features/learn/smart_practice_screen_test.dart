/// Smart Practice Screen — M5 widget test.
///
/// Pins the dynamic-content experience over the REAL Hindi curriculum:
/// trusted-first resolution (zero AI for the trusted view), the honest
/// source labels, learner-triggered personalization rendered inline with
/// the "Made for you" label, the practice-preview honesty note, and the
/// §46 offline / no-language / stub-language safe states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_content_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/smart_practice_screen.dart';

/// Fake raw-text boundary that switches behaviour by prompt shape:
/// planner calls get garbage (forcing the deterministic plan), material
/// calls get a GROUNDED reply built from the trusted vocabulary the
/// prompt itself provided — exactly what a §16-obeying model would do.
class _ObeyingFakeClient implements PlannerTextClient {
  final List<String> calls = [];

  @override
  bool get isAvailable => true;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    calls.add(user);
    if (user.contains('TRUSTED VOCABULARY')) {
      final tokens = _vocabFromPrompt(user);
      if (tokens.length < 2) return '{"kind":"none"}';
      return '{"kind":"practice","language":"hi","title":"Quick check",'
          '"exercise":{"type":"mcq",'
          '"prompt":"Which one is ${tokens[0]}?",'
          '"options":["${tokens[0]}","${tokens[1]}"],'
          '"correctIndex":0,'
          '"explanation":"${tokens[0]} is the trusted word."}}';
    }
    // Planner call: garbage → the chain falls to the deterministic plan.
    return 'definitely not a plan';
  }

  /// Parses the trusted vocabulary line out of the user prompt.
  static List<String> _vocabFromPrompt(String user) {
    const marker = 'TRUSTED VOCABULARY (the only words you may rely on):';
    final start = user.indexOf(marker);
    if (start < 0) return const [];
    final rest = user.substring(start + marker.length);
    final lineEnd = rest.indexOf('\n');
    final line = (lineEnd < 0 ? rest : rest.substring(0, lineEnd)).trim();
    return line
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}

class _OfflineClient implements PlannerTextClient {
  int calls = 0;

  @override
  bool get isAvailable => false;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    calls++;
    throw StateError('offline');
  }
}

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
  PlannerTextClient? client,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(instance),
      if (client != null) plannerTextClientProvider.overrideWithValue(client),
    ],
  );
}

Widget _wrap(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/learn/smart',
    routes: [
      GoRoute(
        path: '/learn',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Learn home'))),
      ),
      GoRoute(
        path: '/learn/smart',
        builder: (_, __) => const SmartPracticeScreen(),
      ),
      GoRoute(
        path: '/learn/lesson/:lessonId',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Lesson'))),
      ),
      GoRoute(
        path: '/learn/lesson/:lessonId/practice',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Practice'))),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps the widget tester until the Smart Practice phase reaches a
/// terminal state — `ready` (trusted view rendered) or `unavailable`
/// (honest empty state). Used by every test in this file. The
/// trusted-first pipeline resolves asynchronously (curriculum asset
/// load + plan provider + registry build), so a single 300 ms pump is
/// not a reliable signal that the screen has settled. Returns once the
/// phase is no longer `idle` or `loading`, with a sane upper bound to
/// surface hangs as test failures.
Future<void> _waitUntilResolved(
  WidgetTester tester,
  ProviderContainer container, {
  Duration step = const Duration(milliseconds: 50),
  int maxSteps = 160, // ~8 s — Hindi asset load can be slow
}) async {
  for (var i = 0; i < maxSteps; i++) {
    final phase = container.read(smartPracticeProvider).phase;
    if (phase == SmartPracticePhase.ready ||
        phase == SmartPracticePhase.unavailable) {
      // Drain one more frame so the screen's switch completes.
      await tester.pump();
      return;
    }
    await tester.pump(step);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('without a language shows the safe empty state', (tester) async {
    _useTallSurface(tester);
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nothing to personalize yet.'), findsOneWidget);
    expect(find.text('Back to Learn'), findsOneWidget);
  });

  testWidgets('a stub language (no trusted material) stays honest',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'kannada'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await _waitUntilResolved(tester, container);

    // Surface what happened so a regression doesn't disappear silently.
    final phase = container.read(smartPracticeProvider).phase;
    debugPrint('=== stub-language phase: $phase ===');
    debugPrint(
        '=== selectedLearnLanguage: '
        '${container.read(selectedLearnLanguageProvider)} ===');

    expect(find.text('Nothing to personalize yet.'), findsOneWidget);
    expect(find.textContaining('trusted material'), findsOneWidget);
  });

  testWidgets('ready view is trusted-first with honest labels', (tester) async {
    _useTallSurface(tester);
    final client = _ObeyingFakeClient();
    final container = await _container(
      prefs: {'learn_language': 'hindi'},
      client: client,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await _waitUntilResolved(tester, container);

    // Trusted section rendered — and resolving it made NO AI call.
    expect(find.text('TRUSTED MATERIAL'), findsOneWidget);
    expect(find.text('Trusted lesson'), findsOneWidget);
    expect(find.text('Read lesson'), findsOneWidget);
    expect(find.text('MAKE IT PERSONAL'), findsOneWidget);
    expect(find.text('Explain differently'), findsOneWidget);
    expect(find.text('Show examples'), findsOneWidget);
    expect(find.text('Quick quiz'), findsOneWidget);
    // The deterministic plan produced the focus (source label present).
    expect(
      find.textContaining('Daily mix'),
      findsOneWidget,
      reason: 'the plan source label is shown honestly',
    );
    expect(client.calls, isEmpty);
  });

  testWidgets(
      'personalization generates grounded material and labels it '
      '"Made for you"', (tester) async {
    _useTallSurface(tester);
    final client = _ObeyingFakeClient();
    final container = await _container(
      prefs: {'learn_language': 'hindi'},
      client: client,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await _waitUntilResolved(tester, container);

    await tester.tap(find.text('Quick quiz'));
    await tester.pump();
    // The personalize call is async (one client.complete + state write).
    for (var i = 0; i < 40; i++) {
      if (container.read(smartPracticeProvider).material != null) break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Exactly one AI call (the material); the trusted view stays.
    expect(client.calls.length, 1);
    expect(find.text('Made for you · AI'), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);

    // Answer the generated mcq correctly through the real UI: the
    // display order is the same deterministic preparation the engine
    // uses, and the correct answer comes from the validated Exercise.
    final state = container.read(smartPracticeProvider);
    final exercise = state.material!.content.exercise!;
    final display = prepareExerciseOptions(exercise, 0);
    await tester.tap(find.text(display.options[display.correctIndex]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Correct!'), findsOneWidget);
    // The honesty footer for the preview.
    expect(find.textContaining('never counted towards'), findsOneWidget);
  });

  testWidgets('offline AI keeps the trusted view and explains honestly',
      (tester) async {
    _useTallSurface(tester);
    final client = _OfflineClient();
    final container = await _container(
      prefs: {'learn_language': 'hindi'},
      client: client,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await _waitUntilResolved(tester, container);

    expect(find.text('TRUSTED MATERIAL'), findsOneWidget);

    await tester.tap(find.text('Explain differently'));
    await tester.pump();
    // The personalization returns immediately (isAvailable == false).
    for (var i = 0; i < 40; i++) {
      if (container.read(smartPracticeProvider).materialError != null) break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(client.calls, isEmpty);
    expect(
      find.textContaining('AI helper is offline'),
      findsOneWidget,
    );
    // The trusted material is still there (§46: never a dead end).
    expect(find.text('Trusted lesson'), findsOneWidget);
    expect(find.text('Read lesson'), findsOneWidget);
  });
}
