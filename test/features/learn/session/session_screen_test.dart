/// Guided Session Screen — M6 widget flow tests.
///
/// Drives the REAL screen over the real Hindi curriculum + banks:
///   - the happy path: two trusted exercises answered through the real
///     option tiles → friendly finish (no raw jargon) → honest footer;
///   - the honest safe state when no language is selected;
///   - VAN's encourage-first feedback beat after each answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/presentation/providers/session_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/session_screen.dart';

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

Widget _wrap(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/learn/session?kind=practice&concept=hi_script_vowels'
        '&knob=2',
    routes: [
      GoRoute(
        path: '/learn',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Learn home'))),
      ),
      GoRoute(
        path: '/learn/session',
        builder: (_, state) {
          final query = state.uri.queryParameters;
          return SessionScreen(
            kind: ActivityKind.values
                    .where((k) => k.name == (query['kind'] ?? ''))
                    .firstOrNull ??
                ActivityKind.practice,
            conceptId: query['concept'] ?? '',
            difficultyKnob: int.tryParse(query['knob'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/learn/smart',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Smart practice'))),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a correct run: real exercises → feedback beats → friendly '
      'finish', (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Active phase: the first trusted exercise of the bank.
    expect(find.text('Guided session'), findsOneWidget);
    expect(find.text('Warm-up'), findsOneWidget);

    var guard = 0;
    while (true) {
      final state = container.read(adaptiveSessionProvider);
      if (state.phase == AdaptiveSessionPhase.finished) break;
      expect(state.phase,
          anyOf(AdaptiveSessionPhase.active, AdaptiveSessionPhase.feedback));

      if (state.phase == AdaptiveSessionPhase.active) {
        final step = state.currentStep!;
        if (step.isSupport) {
          await tester.tap(find.text('Got it — continue'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          continue;
        }
        // Answer through the REAL UI (same display prep as the screen).
        final exercise = step.exercise!;
        final display = prepareExerciseOptions(exercise, 0);
        final correctOption = switch (exercise.type) {
          ExerciseType.mcq ||
          ExerciseType.fillBlank =>
            display.options[display.correctIndex],
          ExerciseType.translation => exercise.acceptedAnswers.first,
          ExerciseType.ordering => null, // not authored in this bank
          ExerciseType.matching => null, // not exercised in this test
        };
        if (correctOption != null) {
          await tester.tap(find.text(correctOption).last);
        } else {
          // Defensive: text-based answer path.
          await tester.enterText(
            find.byType(TextField),
            exercise.acceptedAnswers.first,
          );
          await tester.tap(find.text('Check'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        // Feedback beat — encourage-first copy from VAN.
        expect(find.text('Correct!'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      guard++;
      expect(guard, lessThan(40), reason: 'the flow must terminate');
    }

    // Friendly finish — no raw jargon, honest footer.
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.textContaining('steps answered'), findsOneWidget);
    expect(
      find.textContaining('Lesson XP and streaks'),
      findsOneWidget,
    );
    expect(find.text('Back to Learn'), findsOneWidget);
  });

  testWidgets('no language selected → honest unavailable state',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nothing to practise yet.'), findsOneWidget);
    expect(find.text('Back to Learn'), findsOneWidget);
  });
}
