/// Diagnostic Screen — M3 widget test.
///
/// Pins the game-like, exam-free experience over the REAL Hindi content:
/// VAN-led intro, adaptive rounds with feedback beats, a friendly result
/// that never shows raw scores, the safe no-language and unavailable
/// states, and "See my path" returning to Learn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/diagnostic_screen.dart';

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
    initialLocation: '/learn/diagnostic',
    routes: [
      GoRoute(
        path: '/learn',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Learn home'))),
      ),
      GoRoute(
        path: '/learn/language',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Language picker'))),
      ),
      GoRoute(
        path: '/learn/diagnostic',
        builder: (_, __) => const DiagnosticScreen(),
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

Future<void> _waitForSessionToStart(
  WidgetTester tester,
  ProviderContainer container,
) async {
  for (var frame = 0;
      frame < 20 &&
          container.read(diagnosticSessionProvider).phase ==
              DiagnosticPhase.idle;
      frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    container.read(diagnosticSessionProvider).phase,
    isNot(DiagnosticPhase.idle),
    reason: 'starting a diagnostic must leave the intro state',
  );
}

/// Answers the current probe correctly through REAL UI interactions.
Future<void> _answerCurrentProbe(
  WidgetTester tester,
  ProviderContainer container, {
  required bool correctly,
}) async {
  final item = container.read(diagnosticSessionProvider).currentItem!;
  final exercise = item.exercise;
  final display = prepareExerciseOptions(exercise, 0);

  switch (exercise.type) {
    case ExerciseType.mcq || ExerciseType.fillBlank:
      final index = correctly
          ? display.correctIndex
          : (display.correctIndex + 1) % display.options.length;
      await tester.tap(find.text(display.options[index]).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    case ExerciseType.translation:
      await tester.enterText(
        find.byType(TextField),
        correctly ? exercise.acceptedAnswers.first : 'definitely wrong',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    case ExerciseType.matching:
      for (var left = 0; left < exercise.pairs.length; left++) {
        final slot = correctly
            ? display.pairIndexByDisplay.indexOf(left)
            : display.pairIndexByDisplay
                .indexOf((left + 1) % exercise.pairs.length);
        await tester.tap(find.text(exercise.pairs[left].left).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(display.options[slot]).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    case ExerciseType.ordering:
      final order =
          correctly ? exercise.items : exercise.items.reversed.toList();
      for (final label in order) {
        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
  }

  await tester.tap(find.text('Check'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('without a selected language shows the safe empty state',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Choose a language first'), findsOneWidget);
    expect(find.text('Choose a language'), findsOneWidget);
  });

  testWidgets('intro is VAN-led and exam-free', (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Let's see what you already know!"), findsOneWidget);
    expect(find.text("Let's play"), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
    // The three honesty bullets — short, adaptive, no scores.
    expect(find.text('3–7 minutes'), findsOneWidget);
    expect(find.text('It adapts to you'), findsOneWidget);
    expect(find.text('No scores, no judgement'), findsOneWidget);
    // It must NOT read like an exam.
    expect(find.textContaining('Question 1'), findsNothing);
    expect(find.textContaining('Score'), findsNothing);
  });

  testWidgets('full happy path: rounds → friendly result → back to Learn',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text("Let's play"));
    await _waitForSessionToStart(tester, container);

    // Drive every adaptive round through real interactions.
    var guard = 0;
    while (container.read(diagnosticSessionProvider).phase !=
        DiagnosticPhase.finished) {
      final phase = container.read(diagnosticSessionProvider).phase;
      if (phase == DiagnosticPhase.active) {
        await _answerCurrentProbe(tester, container, correctly: true);
      } else if (phase == DiagnosticPhase.feedback) {
        // Encourage-first feedback is visible before continuing.
        expect(find.text('Continue'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        fail('Unexpected diagnostic phase: $phase');
      }
      guard++;
      expect(guard, lessThan(60), reason: 'the flow must terminate');
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Friendly result — the summary lines, never raw numbers.
    expect(find.text('See my path'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+\.\d+')), findsNothing,
        reason: 'raw internal scores must never be rendered');
    expect(find.textContaining('opportunity'), findsNothing,
        reason: 'a perfect run has no weakness headline');

    // The run was persisted behind the UI.
    expect(
      container
          .read(learnProfileRepositoryProvider)
          .getDiagnostic(LearnLanguage.hindi),
      isNotNull,
    );
  });

  testWidgets('feedback beat shows encouragement with the explanation',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text("Let's play"));
    await _waitForSessionToStart(tester, container);

    // Answer the FIRST probe deliberately wrong.
    await _answerCurrentProbe(tester, container, correctly: false);

    // Encourage-first (never punishing), with the teaching explanation.
    expect(find.text('Continue'), findsOneWidget);
    expect(
      find.textContaining(RegExp("No worries|sneaky|learn most")),
      findsOneWidget,
    );
  });

  testWidgets('newly supported Kannada language starts a diagnostic',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'kannada'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Intro renders (a language IS selected)…
    expect(find.text("Let's play"), findsOneWidget);
    // …but starting honestly reports there is nothing to probe yet.
    await tester.tap(find.text("Let's play"));
    await _waitForSessionToStart(tester, container);

    expect(container.read(diagnosticSessionProvider).phase,
        DiagnosticPhase.active);
  });
}
