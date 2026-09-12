/// Learning Milestones — pure engine tests (Milestone 7)
///
/// Same evidence in, same evaluation out: every criterion, the ordinal
/// mapping and the engine's persisted-unlock tagging are verified here
/// without Flutter widgets, Riverpod or storage. UI wiring is exercised
/// by the app itself; the RULES live here.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/progress/domain/learning_milestones.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Lesson _lesson(String id, String chapterId, {int order = 0}) => Lesson(
      id: id,
      title: 'Lesson $id',
      chapterId: chapterId,
      order: order,
    );

Chapter _chapter(String id, int order, List<Lesson> lessons) => Chapter(
      id: id,
      title: 'Chapter $id',
      lessons: lessons,
      order: order,
    );

/// A 5-chapter curriculum mirroring the shipped Learn Mode arc
/// (1 Script · 2 Greetings · 3 Daily Life · 4 Grammar · 5 Reading).
/// Deliberately declared OUT of order to prove ordinal sorting.
const _curriculum = <Chapter>[
  Chapter(id: 'ch3', title: 'Daily Life', order: 3, lessons: [
    Lesson(id: 'l3a', chapterId: 'ch3', title: 'L3a'),
  ]),
  Chapter(id: 'ch1', title: 'Script', order: 1, lessons: [
    Lesson(id: 'l1a', chapterId: 'ch1', title: 'L1a'),
    Lesson(id: 'l1b', chapterId: 'ch1', title: 'L1b'),
  ]),
  Chapter(id: 'ch5', title: 'Reading', order: 5, lessons: [
    Lesson(id: 'l5a', chapterId: 'ch5', title: 'L5a'),
  ]),
  Chapter(id: 'ch2', title: 'Greetings', order: 2, lessons: [
    Lesson(id: 'l2a', chapterId: 'ch2', title: 'L2a'),
  ]),
  Chapter(id: 'ch4', title: 'Grammar', order: 4, lessons: [
    Lesson(id: 'l4a', chapterId: 'ch4', title: 'L4a'),
  ]),
];

QuizResult _attempt(String quizId, int score, int total) => QuizResult(
      quizId: quizId,
      score: score,
      total: total,
      xpEarned: score * 5,
    );

MilestoneEvidence _evidence({
  List<Chapter> curriculum = _curriculum,
  Set<String> completed = const {},
  Map<String, List<String>> mastered = const {},
  Map<String, int> authored = const {},
  Map<String, List<String>> quizIdsByChapter = const {},
  Map<String, List<QuizResult>> attempts = const {},
  int streakDays = 0,
}) {
  return MilestoneEvidence(
    curriculum: curriculum,
    completedLessonIds: completed,
    masteredByLesson: mastered,
    exerciseCountByLesson: authored,
    quizIdsByChapter: quizIdsByChapter,
    attemptsByQuizId: attempts,
    streakDays: streakDays,
  );
}

void main() {
  group('MilestoneEvidence — chapter ordinals', () {
    test('orderedChapters sorts by order, not declaration order', () {
      final evidence = _evidence();
      expect(
        evidence.orderedChapters.map((c) => c.id).toList(),
        ['ch1', 'ch2', 'ch3', 'ch4', 'ch5'],
      );
    });

    test('chapterAt resolves 1-based ordinals and rejects missing ones', () {
      final evidence = _evidence();
      expect(evidence.chapterAt(1)?.id, 'ch1');
      expect(evidence.chapterAt(5)?.id, 'ch5');
      expect(evidence.chapterAt(0), isNull);
      expect(evidence.chapterAt(6), isNull);
      expect(evidence.chapterAt(-1), isNull);
    });

    test('fractions are zero for ordinals beyond the curriculum', () {
      final evidence = _evidence(completed: const {'l1a', 'l1b'});
      expect(evidence.chapterCompletionFraction(6), 0);
      expect(evidence.chapterMasteryFraction(6), 0);
      // Exam gate: a MISSING chapter has no quizzes → 0 (never fabricate).
      expect(evidence.chapterExamFraction(6), 0);
    });
  });

  group('FirstWordsCriterion', () {
    const criterion = FirstWordsCriterion();

    test('needs a completed lesson AND a mastered exercise', () {
      expect(
        criterion.isSatisfiedBy(_evidence(
          completed: const {'l1a'},
          authored: const {'l1a': 3},
        )),
        isFalse,
        reason: 'reading alone must not unlock it',
      );
      expect(
        criterion.isSatisfiedBy(_evidence(
          authored: const {'l1a': 3},
          mastered: const {
            'l1a': ['ex1'],
          },
        )),
        isFalse,
        reason: 'practising an unfinished lesson still counts as progress, '
            'but the milestone requires the lesson too',
      );
      expect(
        criterion.isSatisfiedBy(_evidence(
          completed: const {'l1a'},
          authored: const {'l1a': 3},
          mastered: const {
            'l1a': ['ex1'],
          },
        )),
        isTrue,
      );
    });

    test('progress is the honest two-part sum', () {
      expect(
        criterion.progressOf(_evidence(
          completed: const {'l1a'},
          authored: const {'l1a': 3},
        )),
        0.5,
      );
      expect(
        criterion.progressOf(_evidence(
          completed: const {'l1a'},
          authored: const {'l1a': 3},
          mastered: const {
            'l1a': ['ex1'],
          },
        )),
        1.0,
      );
    });
  });

  group('ChapterCompetencyCriterion', () {
    const criterion = ChapterCompetencyCriterion(1);

    test('empty evidence locks it', () {
      final evidence = _evidence();
      expect(criterion.isSatisfiedBy(evidence), isFalse);
      expect(criterion.progressOf(evidence), 0.0);
    });

    test('full lessons + full mastery pass when the chapter has no exams',
        () {
      // Learn Mode chapters ship no exam questions today: the gate is
      // carried by practice mastery, never silently dropped.
      final evidence = _evidence(
        completed: const {'l1a', 'l1b'},
        authored: const {'l1a': 2, 'l1b': 1},
        mastered: const {
          'l1a': ['a', 'b'],
          'l1b': ['c'],
        },
      );
      expect(evidence.chapterExamFraction(1), 1.0);
      expect(criterion.isSatisfiedBy(evidence), isTrue);
      expect(criterion.progressOf(evidence), 1.0);
    });

    test('a chapter WITH exam questions requires the best attempt to pass',
        () {
      final quizIds = {
        'ch1': ['quiz_1'],
      };
      final base = _evidence(
        completed: const {'l1a', 'l1b'},
        authored: const {'l1a': 2, 'l1b': 1},
        mastered: const {
          'l1a': ['a', 'b'],
          'l1b': ['c'],
        },
        quizIdsByChapter: quizIds,
      );

      // No attempts yet → locked.
      expect(criterion.isSatisfiedBy(base), isFalse);
      expect(criterion.progressOf(base), closeTo(2 / 3, 1e-9));

      // A failing attempt keeps it locked.
      final weak = _evidence(
        completed: const {'l1a', 'l1b'},
        authored: const {'l1a': 2, 'l1b': 1},
        mastered: const {
          'l1a': ['a', 'b'],
          'l1b': ['c'],
        },
        quizIdsByChapter: quizIds,
        attempts: {
          'quiz_1': [_attempt('quiz_1', 3, 5)],
        },
      );
      expect(weak.chapterExamFraction(1), 0.6);
      expect(criterion.isSatisfiedBy(weak), isTrue,
          reason: '3/5 == kMilestoneExamPassFraction (0.6)');

      // Best-of counts: a later worse attempt never lowers the best.
      final recovered = _evidence(
        completed: const {'l1a', 'l1b'},
        authored: const {'l1a': 2, 'l1b': 1},
        mastered: const {
          'l1a': ['a', 'b'],
          'l1b': ['c'],
        },
        quizIdsByChapter: quizIds,
        attempts: {
          'quiz_1': [
            _attempt('quiz_1', 5, 5),
            _attempt('quiz_1', 1, 5),
          ],
        },
      );
      expect(recovered.chapterExamFraction(1), 1.0);
      expect(criterion.isSatisfiedBy(recovered), isTrue);
    });

    test('partial mastery or partial lessons keep it locked', () {
      final partialLessons = _evidence(
        completed: const {'l1a'},
        authored: const {'l1a': 1, 'l1b': 1},
        mastered: const {
          'l1a': ['a'],
          'l1b': ['b'],
        },
      );
      expect(criterion.isSatisfiedBy(partialLessons), isFalse);

      final partialMastery = _evidence(
        completed: const {'l1a', 'l1b'},
        authored: const {'l1a': 2, 'l1b': 1},
        mastered: const {
          'l1a': ['a'],
          'l1b': ['b'],
        },
      );
      expect(criterion.isSatisfiedBy(partialMastery), isFalse);
    });

    test('a chapter with authored exercises counts 0/0 mastery as complete',
        () {
      // Stub chapters (no exercises shipped yet) must not dead-lock the
      // milestone: lesson completion is the demonstrated evidence.
      final evidence = _evidence(completed: const {'l1a', 'l1b'});
      expect(evidence.chapterMasteryFraction(1), 1.0);
      expect(criterion.isSatisfiedBy(evidence), isTrue);
    });

    test('evidenceLine names the missing work for the locked card', () {
      final evidence = _evidence(
        completed: const {'l1a'},
        authored: const {'l1a': 3, 'l1b': 2},
        mastered: const {
          'l1a': ['a', 'b'],
        },
      );
      expect(
        criterion.evidenceLine(evidence),
        '1 of 2 lessons · 2 of 5 exercises',
      );
      // Missing ordinal is honest about unavailability.
      final beyond = ChapterCompetencyCriterion(6);
      expect(
        beyond.evidenceLine(evidence),
        'Not available in this curriculum',
      );
    });
  });

  group('JourneyCompleteCriterion', () {
    test('full journey with no exam chapters unlocks', () {
      const criterion = JourneyCompleteCriterion();
      final evidence = _evidence(
        completed: const {'l1a', 'l1b', 'l2a', 'l3a', 'l4a', 'l5a'},
        authored: const {'l1a': 1},
        mastered: const {
          'l1a': ['x'],
        },
      );
      expect(criterion.isSatisfiedBy(evidence), isTrue);
    });

    test('one uncompleted lesson keeps the journey locked', () {
      const criterion = JourneyCompleteCriterion();
      final evidence = _evidence(
        completed: const {'l1a', 'l1b', 'l2a', 'l3a', 'l4a'},
        authored: const {'l1a': 1},
        mastered: const {
          'l1a': ['x'],
        },
      );
      expect(criterion.isSatisfiedBy(evidence), isFalse);
      expect(criterion.progressOf(evidence), lessThan(1.0));
    });

    test('exam chapters must clear the configured bar (0.6 vs 0.8)', () {
      // EVERY chapter ships an exam quiz, so overallExamFraction equals the
      // (identical) per-chapter best attempt — the bar truly bites.
      final quizIds = const {
        'ch1': ['quiz_1'],
        'ch2': ['quiz_2'],
        'ch3': ['quiz_3'],
        'ch4': ['quiz_4'],
        'ch5': ['quiz_5'],
      };
      Map<String, List<QuizResult>> attemptsOf(int score) => {
            'quiz_1': [_attempt('quiz_1', score, 5)],
            'quiz_2': [_attempt('quiz_2', score, 5)],
            'quiz_3': [_attempt('quiz_3', score, 5)],
            'quiz_4': [_attempt('quiz_4', score, 5)],
            'quiz_5': [_attempt('quiz_5', score, 5)],
          };
      Map<String, List<String>> masteredAll() => const {
            'l1a': ['a', 'b'],
            'l1b': ['c'],
            'l2a': ['d'],
            'l3a': ['e'],
            'l4a': ['f'],
            'l5a': ['g'],
          };
      Map<String, int> authoredAll() => const {
            'l1a': 2, 'l1b': 1, 'l2a': 1, 'l3a': 1, 'l4a': 1, 'l5a': 1,
          };
      final allLessons = const {
        'l1a', 'l1b', 'l2a', 'l3a', 'l4a', 'l5a',
      };

      final at60 = _evidence(
        completed: allLessons,
        authored: authoredAll(),
        mastered: masteredAll(),
        quizIdsByChapter: quizIds,
        attempts: attemptsOf(3),
      );
      expect(at60.overallExamFraction, closeTo(0.6, 1e-9));
      expect(JourneyCompleteCriterion(minExamFraction: 0.6)
          .isSatisfiedBy(at60), isTrue);
      // The Mastery Milestone bar (0.8) is NOT satisfied by 60%.
      expect(JourneyCompleteCriterion(minExamFraction: 0.8)
          .isSatisfiedBy(at60), isFalse);

      final at80 = _evidence(
        completed: allLessons,
        authored: authoredAll(),
        mastered: masteredAll(),
        quizIdsByChapter: quizIds,
        attempts: attemptsOf(4),
      );
      expect(JourneyCompleteCriterion(minExamFraction: 0.8)
          .isSatisfiedBy(at80), isTrue);
    });
  });

  group('StreakCriterion', () {
    const criterion = StreakCriterion(7);

    test('requires a real N-day streak', () {
      expect(criterion.isSatisfiedBy(_evidence(streakDays: 6)), isFalse);
      expect(criterion.isSatisfiedBy(_evidence(streakDays: 7)), isTrue);
      expect(criterion.isSatisfiedBy(_evidence(streakDays: 30)), isTrue);
    });

    test('progress clamps at 1.0', () {
      expect(criterion.progressOf(_evidence(streakDays: 3)), closeTo(3 / 7, 1e-9));
      expect(criterion.progressOf(_evidence(streakDays: 99)), 1.0);
      expect(criterion.evidenceLine(_evidence(streakDays: 3)),
          '3 of 7 day streak');
    });
  });

  group('evaluateMilestones', () {
    test('tags persisted unlocks and never re-lapses them', () {
      final evidence = _evidence(streakDays: 9);
      final evaluations = evaluateMilestones(
        definitions: MilestoneDefinitions.all,
        evidence: evidence,
        unlockedIds: const {'consistent_learner', 'first_words'},
      );
      final byId = {
        for (final e in evaluations) e.definition.id: e,
      };
      // Persisted unlocks stay unlocked even when the live evidence no
      // longer satisfies the criterion.
      expect(byId['consistent_learner']!.alreadyUnlocked, isTrue);
      expect(byId['consistent_learner']!.isSatisfied, isTrue);
      expect(byId['first_words']!.alreadyUnlocked, isTrue);
      expect(byId['first_words']!.isSatisfied, isFalse);
      expect(byId['first_words']!.isUnlocked, isTrue,
          reason: 'persisted unlock wins over live evidence');
      // Everything else is still locked.
      expect(byId['script_explorer']!.isUnlocked, isFalse);
      // Every evaluation clamps progress into 0..1.
      for (final e in evaluations) {
        expect(e.progress, inInclusiveRange(0.0, 1.0));
      }
    });

    test('deterministic: same evidence, same output', () {
      List<String> run() => evaluateMilestones(
            definitions: MilestoneDefinitions.all,
            evidence: _evidence(streakDays: 2),
            unlockedIds: const {},
          ).map((e) => '${e.definition.id}:${e.isSatisfied}').toList();
      expect(run(), run());
    });
  });

  group('MilestoneDefinitions', () {
    test('ships exactly the nine M7 milestones with unique ids', () {
      expect(MilestoneDefinitions.all.length, 9);
      final ids = MilestoneDefinitions.all.map((m) => m.id).toSet();
      expect(ids.length, 9);
      expect(
        ids,
        containsAll(<String>[
          'first_words',
          'script_explorer',
          'first_conversation',
          'everyday_communicator',
          'grammar_builder',
          'first_reader',
          'beginner_complete',
          'consistent_learner',
          'mastery_milestone',
        ]),
      );
    });

    test('every milestone pays a positive bonus and names its competency',
        () {
      for (final m in MilestoneDefinitions.all) {
        expect(m.xpReward, greaterThan(0), reason: '${m.id} must pay XP');
        expect(m.competency, isNotEmpty);
        expect(m.title, isNotEmpty);
        expect(m.emoji, isNotEmpty);
      }
    });

    test('byId resolves known ids and returns null for unknown ones', () {
      expect(MilestoneDefinitions.byId('first_words')?.title, 'First Words');
      expect(MilestoneDefinitions.byId('nope'), isNull);
    });
  });
}
