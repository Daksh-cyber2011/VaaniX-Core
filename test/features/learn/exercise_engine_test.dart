import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';

Exercise _mcq(String id) => Exercise(
      id: id,
      lessonId: 'ls_x',
      type: ExerciseType.mcq,
      prompt: 'p',
      options: const ['a', 'b', 'c'],
      correctIndex: 1,
      explanation: 'e',
    );

Exercise _ordering() => const Exercise(
      id: 'ex_order',
      lessonId: 'ls_x',
      type: ExerciseType.ordering,
      prompt: 'order',
      items: ['ka', 'kā', 'ki'],
      explanation: 'e',
    );

void main() {
  group('determinism helpers', () {
    test('seedFromText is stable', () {
      expect(seedFromText('ex_ls_alphabet_vowels_1'),
          seedFromText('ex_ls_alphabet_vowels_1'));
      expect(seedFromText('a'), isNot(seedFromText('b')));
    });

    test('deterministicShuffle is a permutation and stable per seed', () {
      const input = ['a', 'b', 'c', 'd'];
      final run1 = deterministicShuffle(input, 42);
      final run2 = deterministicShuffle(input, 42);
      expect(run1, run2, reason: 'same seed must give identical order');
      expect(run1..sort(), ['a', 'b', 'c', 'd'],
          reason: 'must be a permutation of the input');
      expect(deterministicShuffle(input, 7),
          isNot(deterministicShuffle(input, 8)));
    });

    test('prepareExerciseOptions keeps the correct answer tracked', () {
      final e = _mcq('ex_m1');
      final prepared = prepareExerciseOptions(e, 0);
      expect(prepared.options.length, e.options.length);
      expect(prepared.options, containsAll(e.options));
      expect(
          prepared.options[prepared.correctIndex], e.options[e.correctIndex!]);
      // Records with List fields compare by identity, so compare fields.
      final first = prepareExerciseOptions(e, 0);
      final second = prepareExerciseOptions(e, 0);
      expect(first.options, second.options,
          reason: 'same seed => same option order');
      expect(first.correctIndex, second.correctIndex);
    });
  });

  group('ExerciseNotifier', () {
    test('total reflects the exercise count', () {
      expect(ExerciseNotifier([_mcq('a'), _mcq('b')]).total, 2);
      expect(ExerciseNotifier(const []).total, 0);
    });

    test('correct first-try answer scores a point', () {
      final n = ExerciseNotifier([_mcq('ex_1')]);
      n.select(n.currentCorrectDisplayIndex);
      n.submit();
      expect(n.state.score, 1);
      expect(n.state.answered, isTrue);
      expect(n.currentAnswerIsCorrect, isTrue);
    });

    test(
        'wrong first-try answer scores nothing and retry stays 0 until correct',
        () {
      final n = ExerciseNotifier([_mcq('ex_2')]);
      // Pick a display index that is NOT the correct one, wherever the
      // shuffle placed the right answer.
      final wrongIndex = List<int>.generate(n.currentOptions.length, (i) => i)
          .firstWhere((i) => i != n.currentCorrectDisplayIndex);
      n.select(wrongIndex);
      n.submit();
      expect(n.state.score, 0);
      expect(n.currentAnswerIsCorrect, isFalse);

      // Retry the same exercise: choose the correct display option now.
      n.retry();
      expect(n.state.answered, isFalse);
      n.select(n.currentCorrectDisplayIndex);
      n.submit();
      expect(n.state.score, 1,
          reason: 'first-try-only scoring: retry then correct = 1 point');
    });

    test('next advances and finishes on the last exercise', () {
      final n = ExerciseNotifier([_mcq('ex_3a'), _mcq('ex_3b')]);
      n.select(0);
      n.submit();
      n.next();
      expect(n.state.currentIndex, 1);
      expect(n.state.answered, isFalse);
      n.select(0);
      n.submit();
      n.next();
      expect(n.state.finished, isTrue);
    });

    test('ordering: items are chosen, removed, checked, and scored', () {
      final n = ExerciseNotifier([_ordering()]);
      expect(n.currentOptions, _ordering().items);

      n.addChosenItem('ki');
      n.addChosenItem('ka');
      // Not complete yet -> submit is a no-op.
      n.submit();
      expect(n.state.answered, isFalse);

      // Complete in the WRONG order -> no score, answered.
      n.addChosenItem('kā');
      n.submit();
      expect(n.state.answered, isTrue);
      expect(n.currentAnswerIsCorrect, isFalse);
      expect(n.state.score, 0);

      // Retry in the correct order -> mastered (score 1, never double-counts).
      n.retry();
      n.addChosenItem('ka');
      n.addChosenItem('kā');
      n.addChosenItem('ki');
      n.submit();
      expect(n.state.answered, isTrue);
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1);

      n.retry();
      n.addChosenItem('ka');
      n.addChosenItem('kā');
      n.addChosenItem('ki');
      n.submit();
      expect(n.state.score, 1,
          reason: 'retry of a mastered exercise adds nothing');
    });

    test('restart resets the session', () {
      final n = ExerciseNotifier([_mcq('ex_4'), _mcq('ex_5')]);
      n.select(0);
      n.submit();
      n.next();
      n.restart();
      expect(n.state.currentIndex, 0);
      expect(n.state.score, 0);
      expect(n.state.finished, isFalse);
      expect(n.state.answered, isFalse);
    });
  });

  group('every lesson plays end-to-end', () {
    test('each curriculum lesson can be answered to full mastery', () {
      var lessonsChecked = 0;
      for (final chapter in sanskritCurriculum) {
        for (final lesson in chapter.lessons) {
          final exercises = exercisesByLesson[lesson.id] ?? const [];
          if (exercises.isEmpty) continue; // empty-state handled elsewhere
          lessonsChecked++;
          final notifier = ExerciseNotifier(exercises);
          for (var i = 0; i < notifier.total; i++) {
            if (notifier.current.type == ExerciseType.ordering) {
              // Ordering exercises need every item tapped in order.
              for (final item in notifier.current.items) {
                notifier.addChosenItem(item);
              }
            } else {
              notifier.select(notifier.currentCorrectDisplayIndex);
            }
            notifier.submit();
            expect(notifier.currentAnswerIsCorrect, isTrue,
                reason: '${lesson.id} exercise $i must be answerable');
            notifier.next();
          }
          expect(notifier.state.finished, isTrue,
              reason: '${lesson.id} session must finish');
          expect(notifier.masteredExerciseIds, hasLength(notifier.total),
              reason: '${lesson.id} must reach full mastery');
        }
      }
      expect(lessonsChecked, greaterThanOrEqualTo(8),
          reason: 'the sweep should cover all authored lessons');
    });

    test('retry after a wrong answer never double-counts mastery', () {
      for (final exercises in exercisesByLesson.values) {
        if (exercises.isEmpty) continue;
        final notifier = ExerciseNotifier(exercises);
        // Answer the first exercise wrong, then correctly on retry.
        final wrong = [for (var i = 0; i < exercises.length; i++) i]
            .firstWhere((i) => i != notifier.currentCorrectDisplayIndex);
        notifier.select(wrong);
        notifier.submit();
        expect(notifier.currentAnswerIsCorrect, isFalse);
        notifier.retry();
        notifier.select(notifier.currentCorrectDisplayIndex);
        notifier.submit();
        expect(notifier.currentAnswerIsCorrect, isTrue);
        expect(notifier.masteredExerciseIds, hasLength(1));
        notifier.next();
        // Second exercise, right first try.
        notifier.select(notifier.currentCorrectDisplayIndex);
        notifier.submit();
        expect(notifier.masteredExerciseIds, hasLength(2));
      }
    });
  });

  group('seeded content', () {
    test('every curriculum lesson has at least 2 exercises', () {
      for (final chapter in sanskritCurriculum) {
        for (final lesson in chapter.lessons) {
          final exercises = exercisesByLesson[lesson.id] ?? const [];
          expect(exercises.length, greaterThanOrEqualTo(2),
              reason: '${lesson.id} needs practice content');
        }
      }
    });

    test('every exercise is well-formed and ids are unique', () {
      final ids = <String>{};
      for (final exercises in exercisesByLesson.values) {
        for (final e in exercises) {
          expect(e.isValid, isTrue, reason: '${e.id} malformed');
          expect(ids.add(e.id), isTrue, reason: 'duplicate id ${e.id}');
          expect(e.lessonId, isNotEmpty);
        }
      }
    });
  });

  group('mastery tracking', () {
    test('masteredExerciseIds lists first-try-correct ids in order', () {
      final notifier = ExerciseNotifier([_mcq('ex_a'), _mcq('ex_b')]);
      // Wrong answer first, then a retry-correct answer: never counted.
      final wrong =
          [0, 1, 2].firstWhere((i) => i != notifier.currentCorrectDisplayIndex);
      notifier.select(wrong);
      notifier.submit();
      expect(notifier.currentAnswerIsCorrect, isFalse);
      notifier.retry();
      notifier.select(notifier.currentCorrectDisplayIndex);
      notifier.submit();
      expect(notifier.currentAnswerIsCorrect, isTrue);
      expect(notifier.masteredExerciseIds, ['ex_a']);
      // Advance and answer the second exercise correctly first try.
      notifier.next();
      notifier.select(notifier.currentCorrectDisplayIndex);
      notifier.submit();
      expect(notifier.masteredExerciseIds, ['ex_a', 'ex_b']);
      expect(notifier.masteredIndices, {0, 1});
    });

    test('restart clears session mastery', () {
      final notifier = ExerciseNotifier([_mcq('ex_a'), _mcq('ex_b')]);
      notifier.select(notifier.currentCorrectDisplayIndex);
      notifier.submit();
      expect(notifier.masteredExerciseIds, ['ex_a']);
      notifier.restart();
      expect(notifier.masteredExerciseIds, isEmpty);
    });

    test('hint is optional, preserved, and does not affect validity', () {
      const withHint = Exercise(
        id: 'ex_h',
        lessonId: 'ls_x',
        type: ExerciseType.mcq,
        prompt: 'p',
        options: ['a', 'b'],
        correctIndex: 1,
        hint: 'try the second one',
      );
      expect(withHint.hint, 'try the second one');
      expect(_mcq('ex_n').hint, isNull);
      expect(withHint.isValid, isTrue);
    });
  });
}
