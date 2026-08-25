import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

void main() {
  group('Lesson JSON', () {
    test('round-trips through fromJson/toJson', () {
      const lesson = Lesson(
        id: 'ls_1',
        title: 'Vowels',
        chapterId: 'ch_alpha',
        subtitle: 'Sub',
        difficulty: Difficulty.intermediate,
        xpReward: 15,
        order: 2,
        content: 'Some content',
      );
      expect(Lesson.fromJson(lesson.toJson()), lesson);
    });

    test('applies safe defaults for missing optional fields', () {
      final lesson =
          Lesson.fromJson({'id': 'a', 'title': 'b', 'chapterId': 'c'});
      expect(lesson.difficulty, Difficulty.beginner);
      expect(lesson.xpReward, 10);
      expect(lesson.order, 0);
      expect(lesson.subtitle, isNull);
      expect(lesson.content, isNull);
    });

    test('copyWith replaces only the given field', () {
      const lesson = Lesson(id: 'a', title: 'b', chapterId: 'c', xpReward: 10);
      final copy = lesson.copyWith(xpReward: 20);
      expect(copy.xpReward, 20);
      expect(copy.title, 'b');
      expect(copy.chapterId, 'c');
    });
  });

  group('Chapter JSON', () {
    test('round-trips with nested lessons', () {
      const chapter = Chapter(
        id: 'ch_1',
        title: 'Alphabet',
        lessons: [Lesson(id: 'l1', title: 'A', chapterId: 'ch_1')],
        order: 1,
      );
      expect(Chapter.fromJson(chapter.toJson()), chapter);
    });

    test('missing lessons default to empty list', () {
      final chapter = Chapter.fromJson({'id': 'c', 'title': 't'});
      expect(chapter.lessons, isEmpty);
    });
  });

  group('QuizQuestion JSON', () {
    test('round-trips', () {
      const q = QuizQuestion(
        id: 'q1',
        prompt: 'P',
        options: ['a', 'b'],
        correctIndex: 1,
        explanation: 'e',
      );
      expect(QuizQuestion.fromJson(q.toJson()), q);
    });
  });

  group('QuizResult', () {
    test('percentage is 0 when total is 0', () {
      const r = QuizResult(quizId: 'q', score: 0, total: 0, xpEarned: 0);
      expect(r.percentage, 0);
    });

    test('percentage computes score/total', () {
      const r = QuizResult(quizId: 'q', score: 3, total: 4, xpEarned: 30);
      expect(r.percentage, 0.75);
    });

    test('round-trips through JSON', () {
      final r = QuizResult(
        quizId: 'q',
        score: 3,
        total: 4,
        xpEarned: 30,
        completedAt: DateTime(2026, 1, 1),
      );
      expect(QuizResult.fromJson(r.toJson()), r);
    });
  });

  group('Seed curriculum', () {
    test('implements four ordered syllabus chapters and thirteen lessons', () {
      expect(sanskritCurriculum, hasLength(4));
      expect(sanskritCurriculum.map((c) => c.id), [
        'ch_alphabet',
        'ch_words',
        'ch_sentences',
        'ch_grammar',
      ]);
      expect(sanskritCurriculum.map((c) => c.order), [0, 1, 2, 3]);
      final totalLessons =
          sanskritCurriculum.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(totalLessons, 13);
    });

    test('every lesson has non-empty id, title, and chapterId', () {
      for (final chapter in sanskritCurriculum) {
        for (final lesson in chapter.lessons) {
          expect(lesson.id, isNotEmpty);
          expect(lesson.title, isNotEmpty);
          expect(lesson.chapterId, chapter.id);
        }
      }
    });

    test('quizzes exist per chapter with valid options', () {
      expect(chapterQuizzes.keys,
          containsAll(
              ['ch_alphabet', 'ch_words', 'ch_sentences', 'ch_grammar']));
      chapterQuizzes.forEach((chapterId, questions) {
        expect(questions, isNotEmpty, reason: 'no quiz for $chapterId');
        for (final q in questions) {
          expect(q.correctIndex, greaterThanOrEqualTo(0));
          expect(q.correctIndex, lessThan(q.options.length),
              reason: 'bad correctIndex in $chapterId/${q.id}');
          expect(q.options.length, greaterThanOrEqualTo(2));
        }
      });
    });
  });
}
