/// Exam Mode 2.0 — M8 Revision Schedule Tests (§23)
///
/// Expanding ladder, sharp contraction (relearning), schedule seeding
/// from mastery + patterns + history, dueToday ordering/limit, reviewMix
/// (mistake-first, round-robin mixing, never identical to the lesson),
/// JSON round-trip.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';

ErrorPattern pat(String topicId) => ErrorPattern(
      category: ErrorCategory.recallGap,
      topicId: topicId,
      occurrences: 2,
      questionIds: const ['q1', 'q2'],
      firstSeenIso: '2026-09-01T10:00:00.000',
      lastSeenIso: '2026-09-02T10:00:00.000',
    );

TopicMastery tm(String topicId, TopicStage stage, {double strength = 0.8}) =>
    TopicMastery(
      topicId: topicId,
      stage: stage,
      strength: strength,
      correctCount: 7,
      attemptCount: 8,
      lastPracticedAtIso: '2026-09-10T10:00:00.000',
    );

PracticeQuestion q(String id, String topicId, {int tier = 2}) =>
    PracticeQuestion(
      id: id,
      topicId: topicId,
      topicTitle: 'Topic $topicId',
      kind: PracticeQuestionKind.mcq,
      prompt: 'prompt $id',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      difficultyTier: tier,
    );

void main() {
  final t = DateTime(2026, 9, 12);

  group('ladder math (§23 expanding intervals)', () {
    test('expand climbs the ladder and sets the next due date', () {
      final item = RevisionItem(
        topicId: 't1',
        intervalIndex: 0,
        lastReviewedIso: t.toIso8601String(),
        dueIso: t.toIso8601String(),
      );
      final expanded = RevisionEngine.expand(item, t);
      expect(expanded.intervalIndex, 1);
      expect(expanded.intervalDays, 2);
      expect(expanded.dueIso, t.add(const Duration(days: 2)).toIso8601String());
      expect(expanded.lastReviewedIso, t.toIso8601String());
    });

    test('expand saturates at the top (30 days)', () {
      final top = RevisionItem(
        topicId: 't1',
        intervalIndex: kRevisionIntervalDays.length - 1,
        lastReviewedIso: '',
        dueIso: '',
      );
      final expanded = RevisionEngine.expand(top, t);
      expect(expanded.intervalIndex, kRevisionIntervalDays.length - 1);
    });

    test('contract drops sharply (relearning) with a floor of index 0', () {
      final item = RevisionItem(
        topicId: 't1',
        intervalIndex: 4,
        lastReviewedIso: '',
        dueIso: '',
      );
      final contracted = RevisionEngine.contract(item, t);
      expect(contracted.intervalIndex, 2); // -contractStep(2)
      final bottom = RevisionEngine.contract(contracted, t);
      expect(bottom.intervalIndex, 0);
      final floored = RevisionEngine.contract(bottom, t);
      expect(floored.intervalIndex, 0);
    });

    test('intervalDays clamps for corrupt indices (§41)', () {
      final bad = RevisionItem(
          topicId: 't1', intervalIndex: 99, lastReviewedIso: '', dueIso: '');
      expect(bad.intervalDays, kRevisionIntervalDays.last);
    });
  });

  group('risk bands (§30 qualitative)', () {
    test('fresh / due / overdue classification', () {
      final fresh = RevisionItem(
        topicId: 't1',
        intervalIndex: 3,
        lastReviewedIso: '',
        dueIso: t.add(const Duration(days: 3)).toIso8601String(),
      );
      final due = RevisionItem(
        topicId: 't2',
        intervalIndex: 3,
        lastReviewedIso: '',
        dueIso: t.toIso8601String(),
      );
      final overdue = RevisionItem(
        topicId: 't3',
        intervalIndex: 3,
        lastReviewedIso: '',
        dueIso: t.subtract(const Duration(days: 2)).toIso8601String(),
      );
      expect(fresh.bandOf(t), RevisionRiskBand.fresh);
      expect(due.bandOf(t), RevisionRiskBand.due);
      expect(overdue.bandOf(t), RevisionRiskBand.overdue);
      expect(due.bandLabel, isNotEmpty);
      expect(overdue.bandLabel, isNotEmpty);
      // Due 12h ago is still "due" (same-day grace), not overdue.
      final sameDay = RevisionItem(
        topicId: 't4',
        intervalIndex: 1,
        lastReviewedIso: '',
        dueIso: t.subtract(const Duration(hours: 12)).toIso8601String(),
      );
      expect(sameDay.bandOf(t), RevisionRiskBand.due);
    });
  });

  group('schedule building (evidence, §23)', () {
    test('persisted history is authoritative', () {
      final history = {
        't1': RevisionItem(
          topicId: 't1',
          intervalIndex: 3,
          lastReviewedIso: '2026-09-01T10:00:00.000',
          dueIso: '2026-09-08T10:00:00.000',
        ),
      };
      final items = RevisionEngine.schedule(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {'t1': tm('t1', TopicStage.mastered)},
        ),
        patterns: const [],
        history: history,
        now: t,
      );
      final t1 = items.firstWhere((i) => i.topicId == 't1');
      expect(t1.intervalIndex, 3);
      expect(t1.dueIso, '2026-09-08T10:00:00.000');
    });

    test('error-pattern topics re-enter as relearning due tomorrow', () {
      final items = RevisionEngine.schedule(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [pat('t1')],
        history: const {},
        now: t,
      );
      expect(items, hasLength(1));
      expect(items.first.intervalIndex, 0);
      expect(
          items.first.dueIso, t.add(const Duration(days: 1)).toIso8601String());
    });

    test('history keeps an even-sooner relearning entry (min due)', () {
      final history = {
        't1': RevisionItem(
          topicId: 't1',
          intervalIndex: 0,
          lastReviewedIso: '',
          // due TODAY — sooner than the pattern's tomorrow re-entry.
          dueIso: t.toIso8601String(),
        ),
      };
      final items = RevisionEngine.schedule(
        learner: ExamLearnerProfile(trackId: 'x', topics: const {}),
        patterns: [pat('t1')],
        history: history,
        now: t,
      );
      expect(items.first.dueIso, t.toIso8601String());
    });

    test('mastered topics seed HIGHER than strong topics', () {
      final items = RevisionEngine.schedule(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {
            'm1': tm('m1', TopicStage.mastered),
            's1': tm('s1', TopicStage.strong),
          },
        ),
        patterns: const [],
        history: const {},
        now: t,
      );
      final m = items.firstWhere((i) => i.topicId == 'm1');
      final s = items.firstWhere((i) => i.topicId == 's1');
      expect(m.intervalIndex, 2); // 4-day interval
      expect(s.intervalIndex, 1); // 2-day interval
    });

    test('learning topics are NOT scheduled (weak-area owns them)', () {
      final items = RevisionEngine.schedule(
        learner: ExamLearnerProfile(
          trackId: 'x',
          topics: {'l1': tm('l1', TopicStage.learning)},
        ),
        patterns: const [],
        history: const {},
        now: t,
      );
      expect(items.where((i) => i.topicId == 'l1'), isEmpty);
    });
  });

  group('dueToday (§23 schedule execution)', () {
    test('overdue first, due next, fresh excluded, limit honored', () {
      final items = [
        RevisionItem(
            topicId: 'a_fresh',
            intervalIndex: 1,
            lastReviewedIso: '',
            dueIso: t.add(const Duration(days: 5)).toIso8601String()),
        RevisionItem(
            topicId: 'b_due',
            intervalIndex: 1,
            lastReviewedIso: '',
            dueIso: t.toIso8601String()),
        RevisionItem(
            topicId: 'c_overdue',
            intervalIndex: 1,
            lastReviewedIso: '',
            dueIso: t.subtract(const Duration(days: 3)).toIso8601String()),
        RevisionItem(
            topicId: 'd_overdue',
            intervalIndex: 1,
            lastReviewedIso: '',
            dueIso: t.subtract(const Duration(days: 1)).toIso8601String()),
      ];
      final due = RevisionEngine.dueToday(items, t, limit: 3);
      // Overdue first (c, d — c earlier); then due (b). Deterministic.
      expect(due.map((i) => i.topicId), ['c_overdue', 'd_overdue', 'b_due']);
    });
  });

  group('reviewMix (§23 never the original lesson)', () {
    test('previously-wrong questions come first', () {
      final pool = [
        q('w1', 't1'),
        q('n1', 't1'),
        q('n2', 't2'),
        q('w2', 't2'),
      ];
      final mix = RevisionEngine.reviewMix(
        questions: pool,
        previouslyWrongQuestionIds: const {'w1', 'w2'},
        dueTopicIds: const {'t1', 't2'},
      );
      expect(mix.first.id, 'w1');
      expect(mix[1].id, 'w2');
      // The remaining slots are the fresh ones.
      expect(mix.length, 4);
    });

    test('round-robin: consecutive questions differ in topic when possible',
        () {
      final pool = [
        q('t1a', 't1'),
        q('t1b', 't1'),
        q('t1c', 't1'),
        q('t2a', 't2'),
        q('t2b', 't2'),
        q('t2c', 't2'),
      ];
      final mix = RevisionEngine.reviewMix(
        questions: pool,
        previouslyWrongQuestionIds: const {},
        dueTopicIds: const {'t1', 't2'},
      );
      // No two adjacent questions share a topic (round-robin proof).
      for (var i = 1; i < mix.length; i++) {
        expect(mix[i].topicId == mix[i - 1].topicId, isFalse,
            reason: 'adjacent topics must differ at $i');
      }
    });

    test('targetSize bounds the mix and dedupes', () {
      final pool = [
        q('a', 't1'),
        q('b', 't1'),
        q('c', 't2'),
        q('d', 't2'),
        q('e', 't3'),
        q('f', 't3'),
      ];
      final mix = RevisionEngine.reviewMix(
        questions: pool,
        previouslyWrongQuestionIds: const {},
        dueTopicIds: const {'t1', 't2', 't3'},
        targetSize: 4,
      );
      expect(mix.length, 4);
      expect(mix.toSet().length, 4, reason: 'no duplicate questions');
    });

    test('questions from non-due topics are excluded', () {
      final pool = [q('a', 't1'), q('b', 'other')];
      final mix = RevisionEngine.reviewMix(
        questions: pool,
        previouslyWrongQuestionIds: const {},
        dueTopicIds: const {'t1'},
      );
      expect(mix.map((m) => m.topicId), ['t1']);
    });
  });

  group('RevisionItem JSON round-trip (§12/§57)', () {
    test('toJson → fromJson is lossless', () {
      final item = RevisionItem(
        topicId: 't1',
        intervalIndex: 3,
        lastReviewedIso: '2026-09-01T10:00:00.000',
        dueIso: '2026-09-08T10:00:00.000',
      );
      final back = RevisionItem.fromJson(item.toJson());
      expect(back.topicId, item.topicId);
      expect(back.intervalIndex, item.intervalIndex);
      expect(back.lastReviewedIso, item.lastReviewedIso);
      expect(back.dueIso, item.dueIso);
    });

    test('defensive parse (§41)', () {
      final back = RevisionItem.fromJson(const <String, dynamic>{});
      expect(back.topicId, '');
      expect(back.intervalIndex, 0);
    });
  });
}
