import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

QuizQuestion _q(String id, String chapter, Difficulty d) => QuizQuestion(
      id: id,
      prompt: 'prompt $id',
      options: const ['a', 'b'],
      correctIndex: 0,
      chapterId: chapter,
      difficulty: d,
    );

void main() {
  group('selectExamQuestions', () {
    final bank = [
      _q('q_z', 'ch_a', Difficulty.beginner),
      _q('q_m', 'ch_a', Difficulty.beginner),
      _q('q_a', 'ch_a', Difficulty.beginner),
      _q('q_words', 'ch_words', Difficulty.beginner),
      _q('q_inter', 'ch_a', Difficulty.intermediate),
      _q('q_adv', 'ch_a', Difficulty.advanced),
    ];

    test('filters by chapter + difficulty', () {
      final r = selectExamQuestions(bank,
          chapterId: 'ch_a', difficulty: Difficulty.intermediate);
      expect(r.map((e) => e.id), ['q_inter']);
    });

    test('sorts deterministically by id', () {
      final r = selectExamQuestions(bank,
          chapterId: 'ch_a', difficulty: Difficulty.beginner);
      expect(r.map((e) => e.id), ['q_a', 'q_m', 'q_z']);
    });

    test('chapterId null selects across chapters for a difficulty', () {
      final r = selectExamQuestions(bank, difficulty: Difficulty.beginner);
      expect(r.map((e) => e.id), ['q_a', 'q_m', 'q_words', 'q_z']);
    });

    test('returns empty list when nothing matches', () {
      final r = selectExamQuestions(bank,
          chapterId: 'ch_words', difficulty: Difficulty.advanced);
      expect(r, isEmpty);
    });

    test('does not mutate the input list', () {
      final before = List<QuizQuestion>.from(bank);
      selectExamQuestions(bank,
          chapterId: 'ch_a', difficulty: Difficulty.beginner);
      expect(bank.map((e) => e.id), before.map((e) => e.id));
    });
  });

  group('ExamConfig', () {
    test('quizId is deterministic and reflects the config', () {
      const c = ExamConfig(
          chapterId: 'ch_words', difficulty: Difficulty.intermediate);
      expect(c.quizId, 'quiz_ch_words_intermediate');
    });

    test('quizId falls back to "all" when chapter is unset', () {
      const c = ExamConfig(difficulty: Difficulty.beginner);
      expect(c.quizId, 'quiz_all_beginner');
    });

    test('value equality drives family-key reuse', () {
      const a = ExamConfig(chapterId: 'ch_a', difficulty: Difficulty.beginner);
      const b = ExamConfig(chapterId: 'ch_a', difficulty: Difficulty.beginner);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('QuizQuestion metadata', () {
    test('JSON round-trip preserves chapter + difficulty', () {
      const q = QuizQuestion(
        id: 'q_x',
        prompt: 'p',
        options: ['a', 'b'],
        correctIndex: 1,
        explanation: 'e',
        chapterId: 'ch_words',
        difficulty: Difficulty.advanced,
      );
      final restored = QuizQuestion.fromJson(q.toJson());
      expect(restored.chapterId, 'ch_words');
      expect(restored.difficulty, Difficulty.advanced);
      expect(restored.explanation, 'e');
    });

    test('fromJson defaults metadata when absent (backward compatible)', () {
      final q = QuizQuestion.fromJson(const {
        'id': 'q_y',
        'prompt': 'p',
        'options': ['a'],
        'correctIndex': 0,
      });
      expect(q.chapterId, '');
      expect(q.difficulty, Difficulty.beginner);
    });

    test('every seeded question carries its chapter + a valid difficulty', () {
      for (final entry in chapterQuizzes.entries) {
        for (final q in entry.value) {
          expect(q.chapterId, entry.key,
              reason: '${q.id} should belong to ${entry.key}');
          expect(Difficulty.values, contains(q.difficulty));
        }
      }
    });

    test('seeded beginner set is non-empty and deterministically ordered', () {
      final all = chapterQuizzes.values.expand((e) => e).toList();
      final beginner =
          selectExamQuestions(all, difficulty: Difficulty.beginner);
      expect(beginner, isNotEmpty);
      final ids = beginner.map((e) => e.id).toList();
      final sorted = [...ids]..sort();
      expect(ids, sorted);
    });
  });

  group('QuizNotifier (existing behavior)', () {
    final questions = [
      _q('q1', 'ch_a', Difficulty.beginner),
      _q('q2', 'ch_a', Difficulty.beginner),
    ];

    test('total reflects the question count', () {
      expect(QuizNotifier(questions).total, 2);
    });

    test('select + submit correct answer increments score', () {
      final n = QuizNotifier(questions);
      n.select(0); // correctIndex is 0
      n.submit();
      expect(n.state.score, 1);
      expect(n.state.answered, isTrue);
    });

    test('select + submit wrong answer does not increment score', () {
      final n = QuizNotifier(questions);
      n.select(1); // wrong option
      n.submit();
      expect(n.state.score, 0);
      expect(n.state.answered, isTrue);
    });

    test('next advances and marks finished on the last question', () {
      final n = QuizNotifier(questions);
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

    test('restart resets the attempt', () {
      final n = QuizNotifier(questions);
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
}
