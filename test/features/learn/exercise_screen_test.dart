/// Exercise Screen Widget Tests
///
/// Verifies the practice screen as a real learning surface: the friendly
/// empty state for lessons without exercises, and the full
/// answer -> feedback -> finish -> result -> mastery-persisted flow on a
/// curriculum lesson with real grounded exercises.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

Lesson _lesson(String id, String title) =>
    Lesson(id: id, title: title, chapterId: 'ch_widget', xpReward: 10);

Widget _app(ProviderContainer container, Lesson lesson) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ExerciseScreen(lesson: lesson)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lesson without exercises shows the empty practice state',
      (tester) async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, _lesson('ls_none', 'Empty')));

    expect(find.text('No practice exercises for this lesson yet.'),
        findsOneWidget);
    expect(find.text('Back to lesson'), findsOneWidget);
  });

  testWidgets('answering a full practice session finishes and persists mastery',
      (tester) async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    const lessonId = 'ls_alphabet_vowels';
    await tester.pumpWidget(_app(container, _lesson(lessonId, 'Vowels')));

    final notifier = container.read(exerciseSessionProvider(lessonId).notifier);
    expect(notifier.total, greaterThanOrEqualTo(2));

    // Tall viewport: question, options and the action button all fit
    // without scrolling (avoids lazy-ListView finder issues).
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 50));

    for (var i = 0; i < notifier.total; i++) {
      final ci = notifier.currentCorrectDisplayIndex;
      await tester.tap(find.text(String.fromCharCode(65 + ci)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Submit'));
      await tester.pump(const Duration(milliseconds: 200));
      if (i + 1 < notifier.total) {
        await tester.tap(find.text('Next'));
        await tester.pump(const Duration(milliseconds: 200));
      } else {
        await tester.tap(find.text('Finish'));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // Result view: score and mastery.
    expect(find.text('${notifier.total} / ${notifier.total}'), findsOneWidget);
    expect(find.text('100% mastered'), findsOneWidget);

    // Mastery was persisted (fire-and-forget completed during pumps).
    // Let Van's speech-bubble auto-dismiss timers (2.6 s) fire so the
    // test framework's pending-timer check stays quiet.
    await tester.pump(const Duration(seconds: 3));
    final mastered = container
        .read(progressRepositoryProvider)
        .getMasteredExercises(lessonId)
        .fold<List<String>>((_) => const [], (v) => v);
    expect(mastered, hasLength(notifier.total));
    for (final e in notifier.masteredExerciseIds) {
      expect(mastered, contains(e));
    }
  });
}
