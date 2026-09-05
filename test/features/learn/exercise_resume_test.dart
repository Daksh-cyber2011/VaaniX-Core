/// Exercise Session Resume Tests (Phase 2)
///
/// Practice used to restart from question 1 whenever the app died or the
/// learner navigated away mid-session. The session is now snapshotted to
/// storage after every state change and restored on screen entry:
///   - engine level: restoreSession applies only to a FRESH notifier,
///     maps mastered ids back to indices, clamps the index and re-derives
///     the score from the mastered set,
///   - widget level: entering the screen with a persisted snapshot resumes
///     at the saved question (with a visible snackbar) and answering
///     persists a fresh snapshot; finishing expires it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Lesson _lesson(String id) =>
    Lesson(id: id, title: 'Resume Lesson', chapterId: 'ch_x', xpReward: 10);

Widget _app(ProviderContainer container, Lesson lesson) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ExerciseScreen(lesson: lesson)),
  );
}

void _answerCorrectly(ExerciseNotifier notifier) {
  final ex = notifier.current;
  switch (ex.type) {
    case ExerciseType.ordering:
      for (final item in ex.items) {
        notifier.addChosenItem(item);
      }
    case ExerciseType.translation:
      notifier.setAnswerText(ex.acceptedAnswers.first);
    case ExerciseType.matching:
      for (var p = 0; p < ex.pairs.length; p++) {
        notifier.addMatch(p, notifier.currentPairIndexByDisplay[p]);
      }
    case ExerciseType.mcq || ExerciseType.fillBlank:
      notifier.select(notifier.currentCorrectDisplayIndex);
  }
  notifier.submit();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lessonId = 'ls_alphabet_vowels';
  final lessonExercises = exercisesByLesson[lessonId]!;

  group('ExerciseNotifier.restoreSession (engine)', () {
    test('restores index, mastered ids and a truthful score', () {
      final notifier = ExerciseNotifier(lessonExercises);
      final mastered = [
        lessonExercises[0].id,
        lessonExercises[2].id,
      ];

      final applied = notifier.restoreSession(
        currentIndex: 3,
        score: 99, // stale/incorrect on purpose — re-derived from mastered
        masteredIds: mastered,
      );

      expect(applied, isTrue);
      expect(notifier.state.currentIndex, 3);
      // Score is re-derived from the mastered set, never trusted blindly.
      expect(notifier.state.score, 2);
      expect(notifier.masteredExerciseIds, mastered);
    });

    test('rejects restore when the session already advanced', () {
      final notifier = ExerciseNotifier(lessonExercises);
      _answerCorrectly(notifier);
      notifier.next();
      expect(notifier.state.currentIndex, 1,
          reason: 'precondition: the session really advanced');

      final applied = notifier.restoreSession(
        currentIndex: 2,
        score: 1,
        masteredIds: const ['whatever'],
      );

      expect(applied, isFalse,
          reason: 'a restore must never clobber real in-session progress');
      expect(notifier.state.currentIndex, 1);
    });

    test('rejects a second restore and empty snapshots', () {
      final notifier = ExerciseNotifier(lessonExercises);
      expect(
        notifier.restoreSession(currentIndex: 1, score: 0),
        isTrue,
      );
      expect(
        notifier.restoreSession(currentIndex: 2, score: 0),
        isFalse,
        reason: 'already restored/advanced — second application must no-op',
      );

      final fresh = ExerciseNotifier(lessonExercises);
      expect(
        fresh.restoreSession(currentIndex: 0, score: 0),
        isFalse,
        reason: 'nothing meaningful to resume',
      );
    });

    test('clamps out-of-range indices and ignores unknown exercise ids', () {
      final notifier = ExerciseNotifier(lessonExercises);

      final applied = notifier.restoreSession(
        currentIndex: 999,
        score: 0,
        masteredIds: ['ex_does_not_exist', lessonExercises[1].id],
      );

      expect(applied, isTrue);
      expect(notifier.state.currentIndex, notifier.total - 1);
      expect(notifier.state.score, 1);
      expect(notifier.masteredExerciseIds, [lessonExercises[1].id]);
    });
  });

  group('ExerciseScreen resume (widget)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );

    testWidgets('resumes a persisted snapshot at the saved question',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final masteredIds = [lessonExercises[0].id, lessonExercises[1].id];
      await prefs.setString(
        'exercise_session_$lessonId',
        jsonEncode({
          'v': 1,
          'currentIndex': 2,
          'score': 2,
          'masteredIds': masteredIds,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(container, _lesson(lessonId)));
      await tester
          .pump(const Duration(milliseconds: 50)); // postFrame restore

      expect(find.text('Q 3 / ${lessonExercises.length}'), findsOneWidget,
          reason: 'the session must resume at the persisted index');
      expect(find.textContaining('Picked up where you left off'),
          findsOneWidget,
          reason: 'the resume must be visible, not silent');

      final state = container.read(exerciseSessionProvider(lessonId));
      expect(state.currentIndex, 2);
      expect(state.score, 2);
    });

    testWidgets('answering persists a fresh snapshot; finishing expires it',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(container, _lesson(lessonId)));
      await tester.pump(const Duration(milliseconds: 50));
      final storage = container.read(localStorageServiceProvider);
      expect(storage.getString('exercise_session_$lessonId'), isNull,
          reason: 'a fresh session must not hold a snapshot');

      // Answer the first exercise correctly -> snapshot with progress.
      final notifier =
          container.read(exerciseSessionProvider(lessonId).notifier);
      _answerCorrectly(notifier);
      await tester.pump();

      final snapRaw = storage.getString('exercise_session_$lessonId');
      expect(snapRaw, isNotNull,
          reason: 'real progress must be snapshotted immediately');
      final snap = jsonDecode(snapRaw!) as Map<String, dynamic>;
      expect(snap['v'], 1);
      expect(snap['currentIndex'], 0);
      expect(snap['score'], 1);

      // Finish the whole session -> snapshot expires.
      while (!notifier.state.finished) {
        if (notifier.state.answered) {
          notifier.next();
        } else {
          final ex = notifier.current;
          if (ex.type == ExerciseType.ordering) {
            for (final item in ex.items) {
              notifier.addChosenItem(item);
            }
          } else if (ex.type == ExerciseType.translation) {
            notifier.setAnswerText(ex.acceptedAnswers.first);
          } else if (ex.type == ExerciseType.matching) {
            for (var p = 0; p < ex.pairs.length; p++) {
              notifier.addMatch(p, notifier.currentPairIndexByDisplay[p]);
            }
          } else {
            notifier.select(notifier.currentCorrectDisplayIndex);
          }
          notifier.submit();
        }
      }
      await tester.pump();

      expect(storage.getString('exercise_session_$lessonId'), isNull,
          reason: 'a finished session must not keep a resumable snapshot');
    });
  });
}
