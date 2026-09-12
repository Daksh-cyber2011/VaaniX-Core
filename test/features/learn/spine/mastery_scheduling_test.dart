/// Mastery Scheduling — M6 tests (Master Brief §19/§20).
///
/// Pins the evidence gates on the §19 ladder (review→recalled→applied→
/// mastered→maintained), the practical §20 review policy (recently weak
/// → soon / strong aging → later / mastered → maintenance), the queue
/// merge + cap, and the evidence overlay's never-lower guarantee.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery_scheduling.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';

SessionConceptEvidence _evidence({
  required String conceptId,
  int attempts = 2,
  int correct = 2,
  int firstTry = 2,
}) =>
    SessionConceptEvidence(
      conceptId: conceptId,
      attempts: attempts,
      correctCount: correct,
      firstTryCount: firstTry,
      lastPracticedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('evidenceStageFor — the §19 uplift gates', () {
    test('review: recalled for practiced+, maintained for mastered+', () {
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a'),
          currentStage: MasteryStage.practiced,
        ),
        MasteryStage.recalled,
      );
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a'),
          currentStage: MasteryStage.understood,
        ),
        MasteryStage.recalled,
      );
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a'),
          currentStage: MasteryStage.mastered,
        ),
        MasteryStage.maintained,
      );
    });

    test('review: never recalls what was never learned', () {
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a'),
          currentStage: null,
        ),
        isNull,
        reason: 'nothing learned → nothing recalled',
      );
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a'),
          currentStage: MasteryStage.introduced,
        ),
        isNull,
        reason: 'introduced is not enough to count as recall',
      );
    });

    test('challenge: applied for practiced+; nothing for the unseen', () {
      expect(
        evidenceStageFor(
          kind: ActivityKind.challenge,
          evidence: _evidence(conceptId: 'a'),
          currentStage: MasteryStage.practiced,
        ),
        MasteryStage.applied,
      );
      expect(
        evidenceStageFor(
          kind: ActivityKind.challenge,
          evidence: _evidence(conceptId: 'a'),
          currentStage: null,
        ),
        isNull,
      );
    });

    test('masteryCheck: strict accuracy + attempts + understood gate', () {
      MasteryStage? check({
        required int attempts,
        required int firstTry,
        MasteryStage? stage,
      }) =>
          evidenceStageFor(
            kind: ActivityKind.masteryCheck,
            evidence: _evidence(
              conceptId: 'a',
              attempts: attempts,
              correct: firstTry,
              firstTry: firstTry,
            ),
            currentStage: stage ?? MasteryStage.understood,
          );

      expect(check(attempts: 2, firstTry: 2), MasteryStage.mastered);
      expect(check(attempts: 3, firstTry: 3), MasteryStage.mastered);
      expect(
        check(attempts: 1, firstTry: 1),
        isNull,
        reason: 'below minimum attempts',
      );
      expect(
        check(attempts: 4, firstTry: 2),
        isNull,
        reason: '50% accuracy does not certify mastery',
      );
      expect(
        check(attempts: 2, firstTry: 2, stage: MasteryStage.introduced),
        isNull,
        reason: 'checks certify understood material, not unseen',
      );
    });

    test('wrong answers and weak kinds never uplift', () {
      expect(
        evidenceStageFor(
          kind: ActivityKind.review,
          evidence: _evidence(conceptId: 'a', correct: 0, firstTry: 0),
          currentStage: MasteryStage.understood,
        ),
        isNull,
      );
      for (final kind in const [
        ActivityKind.practice,
        ActivityKind.weakRepair,
        ActivityKind.newLearning,
      ]) {
        expect(
          evidenceStageFor(
            kind: kind,
            evidence: _evidence(conceptId: 'a'),
            currentStage: MasteryStage.understood,
          ),
          isNull,
          reason: '$kind builds evidence but does not uplift stages',
        );
      }
    });
  });

  group('buildEvidenceMasteries', () {
    test('uplift raises the stage; counters accumulate with prior evidence',
        () {
      final prior = <String, ConceptMastery>{
          'a': ConceptMastery(
          conceptId: 'a',
          stage: MasteryStage.recalled,
          strength: 0.5,
          correctCount: 3,
          attemptCount: 4,
        ),
      };
      final merged = buildEvidenceMasteries(
        kind: ActivityKind.challenge,
        evidence: {'a': _evidence(conceptId: 'a')},
        priorEvidence: prior,
        currentStages: const {'a': MasteryStage.understood},
        at: DateTime(2026, 1, 2),
      );
      final record = merged['a']!;
      expect(record.stage, MasteryStage.applied); // uplift from challenge
      expect(record.correctCount, 5); // 3 + 2 accumulated
      expect(record.attemptCount, 6);
      expect(record.lastPracticedAt, DateTime(2026, 1, 2));
    });

    test('no uplift keeps the prior evidence stage', () {
      final prior = <String, ConceptMastery>{
          'a': ConceptMastery(
          conceptId: 'a',
          stage: MasteryStage.understood,
          strength: 0.4,
          correctCount: 1,
          attemptCount: 2,
        ),
      };
      final merged = buildEvidenceMasteries(
        kind: ActivityKind.practice,
        evidence: {'a': _evidence(conceptId: 'a', correct: 1, firstTry: 1)},
        priorEvidence: prior,
        currentStages: const {'a': MasteryStage.understood},
        at: DateTime(2026, 1, 2),
      );
      expect(merged['a']!.stage, MasteryStage.understood);
      expect(merged['a']!.correctCount, 2); // still accumulates
    });

    test('fresh evidence creates a record for unseen concepts', () {
      final merged = buildEvidenceMasteries(
        kind: ActivityKind.masteryCheck,
        evidence: {'x': _evidence(conceptId: 'x')},
        priorEvidence: const {},
        currentStages: const {'x': null},
        at: DateTime(2026, 1, 2),
      );
      // currentStage null → the check cannot uplift — the record keeps
      // the honest placeholder (introduced) with real counters.
      expect(merged['x']!.stage, MasteryStage.introduced);
      expect(merged['x']!.attemptCount, 2);
    });
  });

  group('scheduleReviewUpdates — the §20 policy', () {
    final now = DateTime(2026, 1, 10);

    test('a miss → recently weak, due tomorrow, high priority', () {
      final updates = scheduleReviewUpdates(
        kind: ActivityKind.practice,
        evidence: {
          'a': SessionConceptEvidence(
            conceptId: 'a',
            attempts: 2,
            correctCount: 1,
            firstTryCount: 1,
            lastPracticedAt: now,
          ),
        },
        currentStages: const {'a': MasteryStage.understood},
        lastPracticedByConcept: {'a': now},
        now: now,
      );
      expect(updates, hasLength(1));
      expect(updates.first.reason, ReviewReason.recentlyWeak);
      expect(updates.first.priority, greaterThan(0.7));
      expect(
        updates.first.dueAt,
        now.add(const Duration(days: ReviewPolicy.kReviewSoonDays)),
      );
    });

    test('strong but aging → review later', () {
      final lastWeek = now.subtract(const Duration(days: 6));
      final updates = scheduleReviewUpdates(
        kind: ActivityKind.practice,
        evidence: {'a': _evidence(conceptId: 'a')},
        currentStages: const {'a': MasteryStage.understood},
        lastPracticedByConcept: {'a': lastWeek},
        now: now,
      );
      expect(updates, hasLength(1));
      expect(updates.first.reason, ReviewReason.agingStrong);
      expect(
        updates.first.dueAt,
        now.add(const Duration(days: ReviewPolicy.kAgingReviewDays)),
      );
    });

    test('recently practiced + correct → nothing fabricated', () {
      final yesterday = now.subtract(const Duration(days: 1));
      final updates = scheduleReviewUpdates(
        kind: ActivityKind.practice,
        evidence: {'a': _evidence(conceptId: 'a')},
        currentStages: const {'a': MasteryStage.understood},
        lastPracticedByConcept: {'a': yesterday},
        now: now,
      );
      expect(updates, isEmpty,
          reason: 'a fresh correct answer must not fake an aging review');
    });

    test('mastered concepts get low-frequency maintenance', () {
      final updates = scheduleReviewUpdates(
        kind: ActivityKind.practice,
        evidence: {'m': _evidence(conceptId: 'm')},
        currentStages: const {'m': MasteryStage.mastered},
        lastPracticedByConcept: const {'m': null},
        now: now,
      );
      expect(updates, hasLength(1));
      expect(updates.first.reason, ReviewReason.maintenance);
      expect(
        updates.first.dueAt,
        now.add(const Duration(days: ReviewPolicy.kMaintenanceReviewDays)),
      );
    });

    test('unseen concepts with correct answers get no queue entry', () {
      final updates = scheduleReviewUpdates(
        kind: ActivityKind.practice,
        evidence: {'x': _evidence(conceptId: 'x')},
        currentStages: const {'x': null},
        lastPracticedByConcept: const {'x': null},
        now: now,
      );
      expect(updates, isEmpty);
    });
  });

  group('mergeReviewQueue', () {
    test('updates replace same-concept entries and priority sorts', () {
      final existing = [
        const ReviewEntry(
          conceptId: 'old',
          reason: ReviewReason.recentlyWeak,
          priority: 0.9,
        ),
        const ReviewEntry(
          conceptId: 'a',
          reason: ReviewReason.recentlyWeak,
          priority: 0.85,
        ),
      ];
      final merged = mergeReviewQueue(existing, [
        ReviewEntry(
          conceptId: 'a',
          reason: ReviewReason.maintenance,
          priority: 0.3,
          dueAt: DateTime(2026, 1, 17),
        ),
      ]);
      expect(merged.first.conceptId, 'old'); // highest priority first
      final a = merged.firstWhere((e) => e.conceptId == 'a');
      expect(a.reason, ReviewReason.maintenance); // fresh evidence wins
    });

    test('the queue is capped to keep the planner digest small', () {
      final existing = [
        for (var i = 0; i < 20; i++)
          ReviewEntry(
            conceptId: 'c$i',
            reason: ReviewReason.recentlyWeak,
            priority: 0.1 + i * 0.01,
          ),
      ];
      final merged = mergeReviewQueue(existing, const []);
      expect(merged.length, ReviewPolicy.kMaxQueueEntries);
    });
  });

  group('applyMasteryEvidence — the overlay', () {
    test('evidence raises stages but never lowers them', () {
      final derived = LearningState(
        languageCode: 'hi',
        conceptMasteries: {
          'a': ConceptMastery(
            conceptId: 'a',
            stage: MasteryStage.understood,
            strength: 0.8,
            correctCount: 9,
            attemptCount: 10,
          ),
          'b': const ConceptMastery(
            conceptId: 'b',
            stage: MasteryStage.mastered,
            strength: 0.9,
          ),
        },
      );
      final merged = applyMasteryEvidence(
        derived: derived,
        evidence: {
          'a': ConceptMastery(
            conceptId: 'a',
            stage: MasteryStage.recalled,
            strength: 0.4,
            lastPracticedAt: DateTime(2026, 1, 3),
            reviewDueAt: DateTime(2026, 1, 4),
          ),
          'b': const ConceptMastery(
            conceptId: 'b',
            stage: MasteryStage.practiced, // LOWER — must be ignored
            strength: 0.1,
          ),
        },
      );
      expect(merged.conceptMasteries['a']!.stage, MasteryStage.recalled);
      expect(merged.conceptMasteries['b']!.stage, MasteryStage.mastered);
    });

    test('derived counters stay authoritative; recency flows from evidence',
        () {
      final derived = LearningState(
        languageCode: 'hi',
        conceptMasteries: {
          'a': ConceptMastery(
            conceptId: 'a',
            stage: MasteryStage.understood,
            strength: 0.8,
            correctCount: 9,
            attemptCount: 10,
          ),
        },
      );
      final merged = applyMasteryEvidence(
        derived: derived,
        evidence: {
          'a': ConceptMastery(
            conceptId: 'a',
            stage: MasteryStage.understood,
            strength: 0.3, // weaker — keep derived
            correctCount: 99, // ignored — derivation owns counts
            attemptCount: 100,
            lastPracticedAt: DateTime(2026, 1, 3),
          ),
        },
      );
      final record = merged.conceptMasteries['a']!;
      expect(record.strength, 0.8);
      expect(record.correctCount, 9);
      expect(record.attemptCount, 10);
      expect(record.lastPracticedAt, DateTime(2026, 1, 3));
    });

    test('evidence for a lesson-not-completed concept is kept honestly', () {
      final derived = LearningState(languageCode: 'hi');
      final merged = applyMasteryEvidence(
        derived: derived,
        evidence: {
          'x': const ConceptMastery(
            conceptId: 'x',
            stage: MasteryStage.mastered,
            strength: 1.0,
            correctCount: 3,
            attemptCount: 3,
          ),
        },
      );
      expect(merged.conceptMasteries['x']!.stage, MasteryStage.mastered,
          reason: 'a passed mastery check is real evidence');
    });

    test('empty evidence returns the derived state untouched', () {
      final derived = LearningState(languageCode: 'hi');
      expect(
        identical(applyMasteryEvidence(derived: derived, evidence: const {}),
            derived),
        isTrue,
      );
    });
  });

  test('evidence masteries survive a LearningState JSON round-trip', () {
    final extras = LearningState(
      languageCode: 'hi',
      conceptMasteries: {
        'a': ConceptMastery(
          conceptId: 'a',
          stage: MasteryStage.recalled,
          strength: 0.75,
          correctCount: 3,
          attemptCount: 4,
          lastPracticedAt: DateTime(2026, 1, 2, 10),
          reviewDueAt: DateTime(2026, 1, 5),
        ),
      },
      reviewQueue: [
        ReviewEntry(
          conceptId: 'a',
          reason: ReviewReason.agingStrong,
          priority: 0.5,
          dueAt: DateTime(2026, 1, 5),
        ),
      ],
    );
    final restored = LearningState.fromJson(extras.toJson());
    final record = restored.conceptMasteries['a']!;
    expect(record.stage, MasteryStage.recalled);
    expect(record.correctCount, 3);
    expect(record.lastPracticedAt, DateTime(2026, 1, 2, 10));
    expect(record.reviewDueAt, DateTime(2026, 1, 5));
    expect(restored.reviewQueue.single.reason, ReviewReason.agingStrong);
  });

  test('evidenceFromRecords aggregates engine records per concept', () {
    final at = DateTime(2026, 1, 1);
    final evidence = evidenceFromRecords([
      SessionAnswerRecord(
        conceptId: 'a',
        exerciseId: 'ex-1',
        correct: true,
        firstTry: true,
        presentation: StepPresentation.normal,
        isGenerated: false,
      ),
      SessionAnswerRecord(
        conceptId: 'a',
        exerciseId: 'ex-2',
        correct: false,
        firstTry: true,
        presentation: StepPresentation.guided,
        isGenerated: false,
      ),
      SessionAnswerRecord(
        conceptId: 'b',
        exerciseId: 'ex-3',
        correct: true,
        firstTry: true,
        presentation: StepPresentation.normal,
        isGenerated: true,
      ),
    ], at: at);

    expect(evidence['a']!.attempts, 2);
    expect(evidence['a']!.correctCount, 1);
    expect(evidence['a']!.firstTryCount, 1);
    expect(evidence['b']!.attempts, 1);
    expect(evidence['b']!.correctCount, 1);
    expect(evidence['a']!.lastPracticedAt, at);
  });
}
