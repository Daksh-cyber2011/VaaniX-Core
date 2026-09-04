/// Progress Screen - Weak Areas + Next Focus Widget Tests
///
/// Drives the screen with deterministic provider overrides (the engine's own
/// outputs) so the UI behavior is tested without depending on the platform
/// asset channel: recommendation card, weak-area list with real counts,
/// and the fresh-learner empty state. Uses a tall viewport because the
/// screen's ListView builds lazily - content below the fold is not built
/// in the default 600px test viewport.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/screens/progress_screen.dart';

const Lesson kWeakLesson = Lesson(
  id: 'ls_alphabet_consonants',
  chapterId: 'ch_alphabet',
  title: 'Consonants',
  order: 1,
);

const Lesson kWeakLesson2 = Lesson(
  id: 'ls_words_nouns',
  chapterId: 'ch_words',
  title: 'Nouns',
  order: 2,
);

Future<ProviderContainer> makeContainer({
  required NextAction nextAction,
  List<Lesson> weakLessons = const [],
  Map<String, double> chapterBest = const {},
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      adaptiveNextActionProvider.overrideWithValue(nextAction),
      weakLessonsProvider.overrideWithValue(weakLessons),
      chapterBestFractionProvider.overrideWithValue(chapterBest),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: ProgressScreen()),
      ),
    );
  }

  testWidgets('fresh learner sees the start-journey focus and guidance',
      (tester) async {
    useTallViewport(tester);
    final container = await makeContainer(
      nextAction: const NextAction(
        action: AdaptiveAction.startJourney,
        label: 'Start Learning',
        title: 'Your journey begins',
        subtitle: 'Vowels',
        vanMessage: 'Namaste! Let us begin.',
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    expect(find.text('NEXT FOCUS'), findsOneWidget);
    expect(find.text('Your journey begins'), findsOneWidget);
    expect(find.textContaining('Your journey starts now'), findsOneWidget,
        reason: 'fresh learner keeps the VAN welcome guidance');
    expect(find.text('Weak areas'), findsNothing,
        reason: 'no weak areas for a fresh learner');
    // Drain the speech-bubble timer started by the VanWidget.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('weak lessons are surfaced with real mastery counts',
      (tester) async {
    useTallViewport(tester);
    final container = await makeContainer(
      nextAction: const NextAction(
        action: AdaptiveAction.practiceWeakTopic,
        label: 'Practice: Consonants',
        title: 'Practice makes permanent',
        subtitle: '2 of 4 exercises mastered - finish them to lock in '
            'Consonants.',
        vanMessage: 'Let us master Consonants together.',
        lessonId: 'ls_alphabet_consonants',
      ),
      weakLessons: const [kWeakLesson, kWeakLesson2],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container));
    await tester.pump();

    expect(find.text('NEXT FOCUS'), findsOneWidget);
    expect(find.text('Practice makes permanent'), findsOneWidget);
    expect(find.text('Weak areas'), findsOneWidget);
    expect(find.text('Consonants'), findsWidgets);
    expect(find.text('Nouns'), findsOneWidget);
    // Counts come from REAL providers: the engine's recommendation subtitle
    // carries the true shortfall, and each tile shows the persisted mastery
    // (empty seed -> '0 of N').
    expect(find.textContaining('2 of 4 exercises mastered'), findsOneWidget);
    expect(find.textContaining('exercises mastered'), findsWidgets);
    // Drain the speech-bubble timer started by the VanWidget.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('completed-journey action renders the celebration focus',
      (tester) async {
    useTallViewport(tester);
    final container = await makeContainer(
      nextAction: const NextAction(
        action: AdaptiveAction.allDone,
        label: 'Revise with VAN',
        title: 'Syllabus complete!',
        subtitle: 'Every lesson and every exam - wonderful.',
        vanMessage: 'You did it!',
      ),
      weakLessons: const [],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container));
    await tester.pump();

    expect(find.text('NEXT FOCUS'), findsOneWidget);
    expect(find.text('Syllabus complete!'), findsOneWidget);
    expect(find.text('Weak areas'), findsNothing,
        reason: 'all mastered - no weak list to show');
    // Drain the speech-bubble timer started by the VanWidget.
    await tester.pump(const Duration(seconds: 2));
  });
}
