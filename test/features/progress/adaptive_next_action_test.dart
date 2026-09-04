/// Adaptive Next-Action Engine Tests
///
/// The engine derives one deterministic recommendation from REAL persisted
/// state. These tests pin the full decision table: fresh start, mid-journey,
/// weak-topic practice, chapter-exam readiness, exam failure/retake, and the
/// complete syllabus state.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Chapter _chapter(String id, List<Lesson> lessons) => Chapter(
      id: id,
      title: 'Chapter $id',
      subtitle: 'Subtitle',
      order: 0,
      lessons: lessons,
    );

Lesson _lesson(String id) => Lesson(
      id: id,
      title: 'Lesson $id',
      chapterId: 'ch',
      xpReward: 10,
      order: 0,
    );

QuizResult _attempt(String quizId, int score, int total) => QuizResult(
    quizId: quizId, score: score, total: total, xpEarned: score * 10);

const _chapterQuizIds = {
  'ch1': ['quiz_ch1_beginner', 'quiz_ch1_intermediate'],
  'ch2': ['quiz_ch2_beginner'],
};

void main() {
  final curriculum = [
    _chapter('ch1', [
      _lesson('ls_1'),
      _lesson('ls_2'),
      _lesson('ls_3'),
    ]),
    _chapter('ch2', [
      _lesson('ls_4'),
      _lesson('ls_5'),
    ]),
  ];

  NextAction compute({
    Set<String> completed = const {},
    Map<String, List<String>> mastered = const {},
    Map<String, int> counts = const {},
    Map<String, List<QuizResult>> attempts = const {},
  }) {
    return computeNextAction(
      curriculum: curriculum,
      completedLessons: completed,
      masteredExerciseIdsByLesson: mastered,
      exerciseCountByLesson: counts,
      quizIdsByChapter: _chapterQuizIds,
      attemptsByQuizId: attempts,
    );
  }

  group('adaptive engine', () {
    test('fresh learner starts the journey with the first lesson', () {
      final action = compute();
      expect(action.action, AdaptiveAction.startJourney);
      expect(action.lessonId, 'ls_1');
      expect(action.label, 'Start Learning');
    });

    test('mid-journey continues with the next unfinished lesson', () {
      final action = compute(completed: {'ls_1', 'ls_2'});
      expect(action.action, AdaptiveAction.continueLesson);
      expect(action.lessonId, 'ls_3');
    });

    test(
        'completed lesson with unmastered exercises is recommended for practice',
        () {
      final action = compute(
        completed: {'ls_1'},
        mastered: {
          'ls_1': ['ex_1', 'ex_2']
        },
        counts: {'ls_1': 4},
      );
      expect(action.action, AdaptiveAction.practiceWeakTopic);
      expect(action.lessonId, 'ls_1');
      expect(action.subtitle, contains('2 of 4'));
    });

    test('fully mastered lessons never trigger the weak-topic action', () {
      final action = compute(
        completed: {'ls_1'},
        mastered: {
          'ls_1': ['ex_1', 'ex_2', 'ex_3', 'ex_4']
        },
        counts: {'ls_1': 4},
      );
      expect(action.action, AdaptiveAction.continueLesson);
      expect(action.lessonId, 'ls_2');
    });

    test('chapter with all lessons done but no exam suggests the exam', () {
      final action = compute(completed: {'ls_1', 'ls_2', 'ls_3'});
      expect(action.action, AdaptiveAction.takeChapterExam);
      expect(action.chapterId, 'ch1');
    });

    test('failing best attempt (< 60%) keeps the exam recommendation', () {
      final action = compute(
        completed: {'ls_1', 'ls_2', 'ls_3'},
        attempts: {
          'quiz_ch1_beginner': [_attempt('quiz_ch1_beginner', 2, 5)],
        },
      );
      expect(action.action, AdaptiveAction.takeChapterExam);
      expect(action.chapterId, 'ch1');
    });

    test('passing best attempt (>= 60%) clears the chapter exam gate', () {
      final action = compute(
        completed: {'ls_1', 'ls_2', 'ls_3'},
        attempts: {
          'quiz_ch1_beginner': [_attempt('quiz_ch1_beginner', 3, 5)],
        },
      );
      expect(action.action, AdaptiveAction.continueLesson);
      expect(action.lessonId, 'ls_4');
    });

    test('later chapter exam gates are evaluated independently', () {
      final all = {'ls_1', 'ls_2', 'ls_3', 'ls_4', 'ls_5'};
      final action = compute(
        completed: all,
        attempts: {
          'quiz_ch1_beginner': [_attempt('quiz_ch1_beginner', 5, 5)],
          // ch2 exam never attempted
        },
      );
      expect(action.action, AdaptiveAction.takeChapterExam);
      expect(action.chapterId, 'ch2');
    });

    test('complete syllabus with every exam passed celebrates revision', () {
      final action = compute(
        completed: {'ls_1', 'ls_2', 'ls_3', 'ls_4', 'ls_5'},
        attempts: {
          'quiz_ch1_beginner': [_attempt('quiz_ch1_beginner', 5, 5)],
          'quiz_ch1_intermediate': [_attempt('quiz_ch1_intermediate', 4, 5)],
          'quiz_ch2_beginner': [_attempt('quiz_ch2_beginner', 5, 5)],
        },
      );
      expect(action.action, AdaptiveAction.allDone);
      expect(action.label, 'Revise with VAN');
    });

    test('empty curriculum degrades to a safe start action', () {
      final action = computeNextAction(
        curriculum: const [],
        completedLessons: const {},
        masteredExerciseIdsByLesson: const {},
        exerciseCountByLesson: const {},
        quizIdsByChapter: const {},
        attemptsByQuizId: const {},
      );
      expect(action.action, AdaptiveAction.startJourney);
      expect(action.lessonId, isNull);
    });
  });
}
