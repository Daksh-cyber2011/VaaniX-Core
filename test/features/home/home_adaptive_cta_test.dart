/// Home Adaptive CTA Widget Tests
///
/// Home renders the adaptive next action end to end: the engine output
/// (proven by the unit + provider tests) drives the Nest card, the primary
/// button label and VAN's dialogue. The provider is overridden here with
/// the engine's exact outputs so the widget assertions are deterministic
/// (the real asset pipeline does not settle reliably in fake-async).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  NextAction action,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        adaptiveNextActionProvider.overrideWithValue(action),
        // The Supabase SDK throws NotInitializedError in tests (its
        // initialize() is only called by app bootstrap). Route the auth
        // chain through the offline repo so Home renders normally.
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _drainVan(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh learner action: Start Learning CTA + VAN welcome',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(
      tester,
      const NextAction(
        action: AdaptiveAction.startJourney,
        label: 'Start Learning',
        title: 'Your journey begins',
        subtitle: 'ls_alphabet_vowels',
        vanMessage: 'Namaste! I am ready whenever you are.',
        lessonId: 'ls_alphabet_vowels',
      ),
    );
    expect(find.text('Start Learning'), findsWidgets,
        reason: 'primary CTA must carry the start label');
    expect(find.textContaining('Namaste'), findsWidgets,
        reason: 'VAN must speak the action message');
    await _drainVan(tester);
  });

  testWidgets('chapter-exam action: Exam time card', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(
      tester,
      const NextAction(
        action: AdaptiveAction.takeChapterExam,
        label: 'Take the Devanagari exam',
        title: 'Exam time!',
        subtitle: 'You have completed every lesson.',
        vanMessage: 'You finished Devanagari! Ready to shine in the exam?',
        chapterId: 'ch_alphabet',
      ),
    );
    expect(find.text('Exam time!'), findsOneWidget,
        reason: 'Nest card must headline the exam recommendation');
    expect(find.text('Take the Devanagari exam'), findsOneWidget,
        reason: 'primary CTA must mirror the exam label');
    await _drainVan(tester);
  });

  testWidgets('journey-complete action: Revise with VAN card', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(
      tester,
      const NextAction(
        action: AdaptiveAction.allDone,
        label: 'Revise with VAN',
        title: 'Syllabus complete!',
        subtitle: 'Every lesson and every exam - wonderful.',
        vanMessage: 'You did it - the whole V1 syllabus is complete!',
      ),
    );
    expect(find.text('Syllabus complete!'), findsOneWidget);
    expect(find.text('Revise with VAN'), findsWidgets,
        reason: 'complete journey must recommend revision with VAN');
    await _drainVan(tester);
  });
}
