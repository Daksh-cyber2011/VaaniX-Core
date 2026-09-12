/// Exam Mode 2.0 — M8 Weak-Topic Engine Tests (§21/§29/§30)
///
/// Signal sources (mastery stages, error patterns, overdue revision),
/// severity ladder, ranking determinism, §48 cap, insufficient-evidence
/// honesty, M8 PYQ/mock honesty.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart'
    show MockSectionResult;
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart'
    show PyqTopicPerformance;
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';

ErrorPattern pattern(
  ErrorCategory category,
  String topicId,
  int occurrences,
) =>
    ErrorPattern(
      category: category,
      topicId: topicId,
      occurrences: occurrences,
      questionIds: [for (var i = 0; i < occurrences; i++) 'q$i'],
      firstSeenIso: '2026-09-01T10:00:00.000',
      lastSeenIso: '2026-09-03T10:00:00.000',
    );

TopicMastery mastery(
  String topicId,
  TopicStage stage, {
  double strength = 0.5,
  int correct = 2,
  int attempts = 4,
}) =>
    TopicMastery(
      topicId: topicId,
      stage: stage,
      strength: strength,
      correctCount: correct,
      attemptCount: attempts,
      lastPracticedAtIso: '2026-09-01T10:00:00.000',
    );

RevisionItem overdueItem(String topicId) => RevisionItem(
      topicId: topicId,
      intervalIndex: 2,
      lastReviewedIso: '2026-08-20T10:00:00.000',
      dueIso: '2026-08-24T10:00:00.000', // days ago → overdue
    );

void main() {
  final t = DateTime(2026, 9, 12);

  group('severity ladder (§29/§30 vocabulary)', () {
    test('needsAttention stage → needsAttention severity', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'cbse_10_sanskrit',
          topics: {
            't1': mastery('t1', TopicStage.needsAttention, strength: 0.2),
          },
        ),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings, hasLength(1));
      expect(report.findings.first.severity, WeakSeverity.needsAttention);
      expect(report.findings.first.signals, {WeakSignal.lowMastery});
    });

    test('decayed strong topic → forgotten concept', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {'t1': mastery('t1', TopicStage.needsReview)},
        ),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings.first.signals, {WeakSignal.forgottenConcept});
    });

    test('sustained low accuracy (3+, <0.4) → repeatedWrong', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            't1': mastery('t1', TopicStage.practicing,
                strength: 0.3, correct: 1, attempts: 4),
          },
        ),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings.first.signals, {WeakSignal.repeatedWrong});
    });

    test('two signals on one topic → focus severity', () {
      // lowMastery-adjacent: repeatedWrong accuracy 0.25 < 0.4 + an
      // overdue revision on the same topic.
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            't1': mastery('t1', TopicStage.practicing,
                strength: 0.3, correct: 1, attempts: 4),
          },
        ),
        patterns: const [],
        revisionItems: [overdueItem('t1')],
        now: t,
      );
      expect(report.findings.first.severity, WeakSeverity.focus);
      expect(report.findings.first.signals.length, greaterThanOrEqualTo(2));
    });
  });

  group('pattern mapping (§21/§47)', () {
    test('misconception pattern → repeatedMisconception + needsAttention', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [pattern(ErrorCategory.misconception, 't1', 3)],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings.first.signals,
          contains(WeakSignal.repeatedMisconception));
      expect(report.findings.first.severity, WeakSeverity.needsAttention);
    });

    test('structure/incomplete patterns → poorAnswerQuality', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [
          pattern(ErrorCategory.structureError, 't1', 2),
          pattern(ErrorCategory.incompleteAnswer, 't2', 2),
        ],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings, hasLength(2));
      for (final f in report.findings) {
        expect(f.signals, contains(WeakSignal.poorAnswerQuality));
      }
    });

    test('recall/application/concept patterns → repeatedWrong', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [
          pattern(ErrorCategory.recallGap, 't1', 2),
          pattern(ErrorCategory.applicationGap, 't2', 2),
        ],
        revisionItems: const [],
        now: t,
      );
      for (final f in report.findings) {
        expect(f.signals, contains(WeakSignal.repeatedWrong));
      }
    });

    test('unfabricatable pattern categories produce no signal', () {
      // Even if a fabricated pattern were injected, the engine maps
      // grammar/time to NOTHING (defense in depth).
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [
          pattern(ErrorCategory.grammarError, 't1', 5),
          pattern(ErrorCategory.timeIssue, 't2', 5),
        ],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings, isEmpty);
    });
  });

  group('overdue revision → forgotten concept (§23/§21)', () {
    test('overdue item creates a finding', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: [overdueItem('t9')],
        now: t,
      );
      expect(report.findings, hasLength(1));
      expect(report.findings.first.topicId, 't9');
      expect(report.findings.first.signals, {WeakSignal.forgottenConcept});
    });
  });

  group('ranking + §48 cap', () {
    test('max 5 findings, severity desc', () {
      final topics = <String, TopicMastery>{};
      for (var i = 0; i < 8; i++) {
        topics['t$i'] =
            mastery('t$i', TopicStage.needsAttention, strength: 0.1 + i * 0.01);
      }
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: topics),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings.length, WeakAreaEngine.maxFindings);
      // Weakest strength first within equal severity.
      expect(report.findings.first.topicId, 't0');
    });

    test('attentionFirst sorts needsAttention to the top', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            'watch1': mastery('watch1', TopicStage.needsReview),
            'att1': mastery('att1', TopicStage.needsAttention),
          },
        ),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.attentionFirst.first.topicId, 'att1');
      expect(report.hasAttentionFinding, isTrue);
    });
  });

  group('honesty floors (§21/§30)', () {
    test('no evidence at all → insufficientEvidence, no findings', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings, isEmpty);
      expect(report.insufficientEvidence, isTrue);
      expect(report.evidenceNote, isNotEmpty);
    });

    test('evidence exists but no findings → honest positive note', () {
      // Strong/mastered topics produce NO findings (nothing weak) but
      // the note is positive, not "insufficient".
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            't1': mastery('t1', TopicStage.strong,
                strength: 0.9, correct: 9, attempts: 10),
          },
        ),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(report.findings, isEmpty);
      expect(report.insufficientEvidence, isFalse);
    });

    test('M8 report NEVER contains PYQ/mock signals (M9 data required)', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            't1': mastery('t1', TopicStage.needsAttention),
            't2': mastery('t2', TopicStage.practicing, strength: 0.2),
          },
        ),
        patterns: [
          pattern(ErrorCategory.misconception, 't1', 3),
          pattern(ErrorCategory.recallGap, 't2', 2),
        ],
        revisionItems: [overdueItem('t1')],
        now: t,
      );
      expect(WeakAreaEngine.reportIsM8Honest(report), isTrue);
    });

    test('no evidence sentence contains a percentage', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {'t1': mastery('t1', TopicStage.needsAttention)},
        ),
        patterns: [pattern(ErrorCategory.misconception, 't1', 3)],
        revisionItems: [overdueItem('t2')],
        now: t,
      );
      for (final f in report.findings) {
        expect(f.evidenceSentence.contains('%'), isFalse);
      }
      expect(report.evidenceNote.contains('%'), isFalse);
    });
  });

  group('M9 PYQ/mock signals (§21 data-gated)', () {
    test('weakPyq emitted ONLY with real PYQ evidence', () {
      // No PYQ data → no weakPyq finding (M8 parity).
      final noData = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        now: t,
      );
      expect(WeakAreaEngine.reportIsM8Honest(noData), isTrue);

      // Real weak PYQ performance on t1 → weakPyq finding.
      final withData = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        pyqPerformance: const {
          't1': PyqTopicPerformance(topicId: 't1', attempted: 4, correct: 1),
        },
        now: t,
      );
      expect(WeakAreaEngine.reportIsM8Honest(withData), isFalse,
          reason: 'the weakPyq signal is now legitimately present');
      expect(withData.findings, hasLength(1));
      expect(withData.findings.first.topicId, 't1');
      expect(withData.findings.first.signals, {WeakSignal.weakPyq});
      expect(withData.findings.first.severity, WeakSeverity.watch);
    });

    test('strong PYQ performance produces NO finding (§21 honesty)', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        pyqPerformance: const {
          't1': PyqTopicPerformance(topicId: 't1', attempted: 4, correct: 4),
        },
        now: t,
      );
      expect(report.findings, isEmpty);
    });

    test('too-few PYQ attempts are not evidence (never a lucky guess)', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        pyqPerformance: const {
          't1': PyqTopicPerformance(topicId: 't1', attempted: 1, correct: 0),
        },
        now: t,
      );
      expect(report.findings, isEmpty);
    });

    test('weak mock section → weakMock finding keyed by section', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        weakMockSections: const [
          MockSectionResult(
              sectionId: 'sec_c', title: 'खंड स', attempted: 3, correct: 0),
        ],
        now: t,
      );
      expect(report.findings, hasLength(1));
      expect(report.findings.first.topicId, 'sec_c');
      expect(report.findings.first.signals, {WeakSignal.weakMock});
      expect(report.findings.first.evidenceSentence.contains('खंड स'), isTrue);
      expect(report.findings.first.evidenceSentence.contains('%'), isFalse);
    });

    test('healthy mock sections produce nothing (§21 honesty)', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: const [],
        revisionItems: const [],
        weakMockSections: const [
          MockSectionResult(
              sectionId: 'sec_a', title: 'A', attempted: 4, correct: 4),
        ],
        now: t,
      );
      expect(report.findings, isEmpty);
    });

    test('PYQ + mock + mastery evidence compound to focus/needsAttention', () {
      final report = WeakAreaEngine.build(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            't1': mastery('t1', TopicStage.needsAttention, strength: 0.2),
          },
        ),
        patterns: const [],
        revisionItems: const [],
        pyqPerformance: const {
          't1': PyqTopicPerformance(topicId: 't1', attempted: 5, correct: 1),
        },
        weakMockSections: const [
          MockSectionResult(
              sectionId: 'sec_a', title: 'A', attempted: 4, correct: 0),
        ],
        now: t,
      );
      final t1 = report.findings.firstWhere((f) => f.topicId == 't1');
      expect(
          t1.signals, containsAll({WeakSignal.lowMastery, WeakSignal.weakPyq}));
      expect(t1.severity, WeakSeverity.needsAttention);
      expect(
          report.findings.any((f) => f.signals.contains(WeakSignal.weakMock)),
          isTrue);
    });
  });
}
