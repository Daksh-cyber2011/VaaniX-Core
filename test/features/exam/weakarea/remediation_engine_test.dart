/// Exam Mode 2.0 — M8 Remediation Engine Tests (§22/§29)
///
/// Phase splitting (mistake retry / targeted / held-aside recheck),
/// recheck freshness (never previously-wrong, never seen), viability
/// floor, mastery-recheck judging, outcome summary honesty.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/remediation_engine.dart';

PracticeQuestion pq(String id, {int tier = 2}) => PracticeQuestion(
      id: id,
      topicId: 't1',
      topicTitle: 'Sandhi',
      kind: tier == 1
          ? PracticeQuestionKind.mcq
          : PracticeQuestionKind.shortAnswer,
      prompt: 'prompt $id',
      options: tier == 1 ? const ['a', 'b', 'c', 'd'] : const [],
      correctIndex: tier == 1 ? 0 : null,
      acceptedAnswers: tier == 1 ? const [] : const ['उत्तर'],
      difficultyTier: tier,
    );

void main() {
  group('phase splitting (§22)', () {
    test('previously-wrong questions go to the retry phase first', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: ['a', 'b']),
        topicPool: [pq('w1'), pq('w2'), pq('f1'), pq('f2'), pq('f3')],
        previouslyWrongQuestionIds: const {'w1', 'w2'},
      );
      expect(plan.mistakeRetryQuestions.map((q) => q.id), ['w1', 'w2']);
      expect(plan.recheckQuestions.length, RemediationEngine.recheckSize);
      expect(plan.isViable, isTrue);
      // No question appears in two phases.
      final ids = [
        ...plan.mistakeRetryQuestions,
        ...plan.targetedQuestions,
        ...plan.recheckQuestions,
      ].map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('mistake retries are bounded (§18 spirit)', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [
          for (var i = 0; i < 8; i++) pq('w$i'),
          for (var i = 0; i < 4; i++) pq('f$i'),
        ],
        previouslyWrongQuestionIds: {
          for (var i = 0; i < 8; i++) 'w$i',
        },
      );
      expect(plan.mistakeRetryQuestions.length,
          RemediationEngine.maxMistakeRetries);
    });

    test('recheck questions are FRESH (never previously wrong)', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [pq('w1'), pq('w2'), pq('f1'), pq('f2'), pq('f3')],
        previouslyWrongQuestionIds: const {'w1', 'w2'},
      );
      for (final q in plan.recheckQuestions) {
        expect(q.id.startsWith('w'), isFalse,
            reason: 'recheck must never re-serve a previously-wrong id');
      }
    });

    test('recheck prefers tier-2 (application-grade) when available', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [
          pq('w1'),
          pq('t1easy', tier: 1),
          pq('t2easy', tier: 1),
          pq('f1', tier: 2),
          pq('f2', tier: 2),
        ],
        previouslyWrongQuestionIds: const {'w1'},
      );
      expect(plan.recheckQuestions.every((q) => q.difficultyTier == 2), isTrue);
    });

    test('thin pool tops up the recheck from any tier', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [pq('w1'), pq('e1', tier: 1), pq('e2', tier: 1)],
        previouslyWrongQuestionIds: const {'w1'},
      );
      expect(plan.recheckQuestions.length, RemediationEngine.recheckSize);
    });

    test('viability: recheck empty → not viable (honest floor)', () {
      // Only previously-wrong questions → no fresh recheck possible.
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [pq('w1'), pq('w2')],
        previouslyWrongQuestionIds: const {'w1', 'w2'},
      );
      expect(plan.recheckQuestions, isEmpty);
      expect(plan.isViable, isFalse);
    });

    test('viability: no main questions → not viable', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [pq('f1'), pq('f2')],
        previouslyWrongQuestionIds: const {},
      );
      expect(plan.mistakeRetryQuestions, isEmpty);
      expect(plan.targetedQuestions, isEmpty);
      expect(plan.isViable, isFalse);
    });
  });

  group('mastery recheck judging (§22/§29)', () {
    test('all correct → recovered', () {
      final outcome = RemediationEngine.judgeRecheck(recheckAttempts: [
        (questionId: 'f1', verdict: 'correct'),
        (questionId: 'f2', verdict: 'correct'),
      ]);
      expect(outcome, RemediationOutcome.recovered);
    });

    test('any incorrect verdict → stillNeedsWork (no curve)', () {
      final outcome = RemediationEngine.judgeRecheck(recheckAttempts: [
        (questionId: 'f1', verdict: 'correct'),
        (questionId: 'f2', verdict: 'incorrect'),
      ]);
      expect(outcome, RemediationOutcome.stillNeedsWork);
    });

    test('partiallyCorrect recheck answers pass (§29 contract)', () {
      // §22/§29: partially-correct counts as mastered evidence, the
      // same way practice mastery updates treat it.
      final outcome = RemediationEngine.judgeRecheck(recheckAttempts: [
        (questionId: 'f1', verdict: 'correct'),
        (questionId: 'f2', verdict: 'partiallyCorrect'),
      ]);
      expect(outcome, RemediationOutcome.recovered);
    });

    test('too few attempts → stillNeedsWork (never a lucky pass)', () {
      final outcome = RemediationEngine.judgeRecheck(recheckAttempts: [
        (questionId: 'f1', verdict: 'correct'),
      ]);
      expect(outcome, RemediationOutcome.stillNeedsWork);
    });

    test('empty → stillNeedsWork', () {
      expect(
        RemediationEngine.judgeRecheck(recheckAttempts: const []),
        RemediationOutcome.stillNeedsWork,
      );
    });
  });

  group('outcome summaries (§28/§30)', () {
    test('non-empty, no percentages, name round-trip', () {
      for (final o in RemediationOutcome.values) {
        final s = RemediationEngine.outcomeSummary(o);
        expect(s, isNotEmpty);
        expect(s.contains('%'), isFalse);
      }
      expect(remediationOutcomeFromName('recovered'),
          RemediationOutcome.recovered);
      expect(remediationOutcomeFromName('bogus'), RemediationOutcome.notRun);
      expect(remediationOutcomeFromName(null), RemediationOutcome.notRun);
    });
  });

  group('recap text (§15 grounded, §28 tone)', () {
    test('official title + section + sub-topic bullets', () {
      const recap = RemediationRecap(
        topicTitle: 'संधि',
        sectionTitle: 'व्याकरणम्',
        subtopics: ['स्वर संधि', 'व्यंजन संधि', 'विसर्ग संधि'],
      );
      final text = recap.recapText;
      expect(text.contains('संधि'), isTrue);
      expect(text.contains('व्याकरणम्'), isTrue);
      expect(text.contains('• स्वर संधि'), isTrue);
      expect(recap.recapText, isNotEmpty);
    });

    test('empty subtopics → honest official fallback line', () {
      const recap =
          RemediationRecap(topicTitle: 'T', sectionTitle: 'S', subtopics: []);
      expect(recap.recapText, isNotEmpty);
    });
  });

  group('mainQuestions order (§22/§23)', () {
    test('mistake retries come before targeted practice', () {
      final plan = RemediationEngine.build(
        topicId: 't1',
        recap: const RemediationRecap(
            topicTitle: 'T', sectionTitle: 'S', subtopics: []),
        topicPool: [pq('w1'), pq('f1'), pq('f2'), pq('f3')],
        previouslyWrongQuestionIds: const {'w1'},
      );
      expect(plan.mainQuestions.first.id, 'w1');
      expect(
          plan.totalQuestions,
          plan.mistakeRetryQuestions.length +
              plan.targetedQuestions.length +
              plan.recheckQuestions.length);
    });
  });
}
