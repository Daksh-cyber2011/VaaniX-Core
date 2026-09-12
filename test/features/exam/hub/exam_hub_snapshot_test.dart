/// Exam Mode 2.0 — M10 Hub Snapshot Tests
///
/// The pure derivation behind the exam-mode HOME: today's day of the
/// rolling plan, the CONTINUE target, honest one-line states, the
/// readiness countdown and the VAN context ladder.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';

ExamPlanTask task(ExamTaskType type, String topic, int minutes) =>
    ExamPlanTask(
      type: type,
      topicId: topic,
      title: 'Task $topic',
      minutes: minutes,
    );

ExamPlan plan(List<ExamDayPlan> days, {String? createdAtIso}) => ExamPlan(
      id: 'plan-t',
      trackId: 't',
      source: ExamPlanSource.deterministic,
      scopeRevision: 1,
      focusSummary: 'focus',
      rationale: 'rationale',
      days: days,
      createdAtIso:
          createdAtIso ?? '2026-09-12T09:00:00.000',
    );

ExamProfile profile({DateTime? target, int? weeks}) => ExamProfile(
      trackId: 't',
      dailyStudyMinutes: 30,
      studyDaysPerWeek: 5,
      readinessTargetDate: target,
      readinessDurationWeeks: weeks,
    );

const weak = ExamHubWeakInput(
  findingCount: 0,
  topSeverityName: '',
  recoveryRecommended: false,
  recoveryDayIndex: 0,
  revisionDueCount: 0,
);

void main() {
  final now = DateTime(2026, 9, 12, 15, 0);

  test('no data at all: honest empties, welcome VAN', () {
    final s = ExamHubSnapshot(
      now: now,
      hasDiagnostic: false,
      plan: null,
      profile: null,
      weak: weak,
      pyqAttemptedTotal: 0,
      pyqCorrectTotal: 0,
      lastMockBand: null,
      lastMockKindName: null,
      mockCount: 0,
      completedTaskTypeNames: const {},
    );
    expect(s.hasDiagnostic, isFalse);
    expect(s.readinessLine, isEmpty);
    expect(s.todayTasks, isEmpty);
    expect(s.continueTask, isNull);
    expect(s.weakAreaLine, 'No weak areas detected yet');
    expect(s.revisionLine, 'No revision due today');
    expect(s.pyqLine, 'Not attempted yet');
    expect(s.mockLine, 'No mock yet');
    expect(s.vanMood, ExamHubVanMood.welcome);
    expect(s.vanMessage,
        'A short diagnostic will tell me where to start.');
  });

  group('readiness countdown (§8 anchor)', () {
    test('target date → days left', () {
      final s = ExamHubSnapshot(
        now: now,
        hasDiagnostic: true,
        plan: null,
        profile: profile(target: DateTime(2026, 10, 10)),
        weak: weak,
        pyqAttemptedTotal: 0,
        pyqCorrectTotal: 0,
        lastMockBand: null,
        lastMockKindName: null,
        mockCount: 0,
        completedTaskTypeNames: const {},
      );
      expect(s.readinessDaysLeft, 28);
      expect(s.readinessLine, '28 days to readiness');
      expect(s.readinessOverdue, isFalse);
    });

    test('today / overdue anchors are honest, never negative-minted', () {
      final today = ExamHubSnapshot(
        now: now,
        hasDiagnostic: true,
        plan: null,
        profile: profile(target: DateTime(2026, 9, 12)),
        weak: weak,
        pyqAttemptedTotal: 0,
        pyqCorrectTotal: 0,
        lastMockBand: null,
        lastMockKindName: null,
        mockCount: 0,
        completedTaskTypeNames: const {},
      );
      expect(today.readinessLine, 'Readiness target is today');
      final overdue = ExamHubSnapshot(
        now: now,
        hasDiagnostic: true,
        plan: null,
        profile: profile(target: DateTime(2026, 9, 5)),
        weak: weak,
        pyqAttemptedTotal: 0,
        pyqCorrectTotal: 0,
        lastMockBand: null,
        lastMockKindName: null,
        mockCount: 0,
        completedTaskTypeNames: const {},
      );
      expect(overdue.readinessLine, 'Readiness target has passed — set a new one');
      expect(overdue.readinessOverdue, isTrue);
    });
  });

  group("today's plan + continue", () {
    ExamHubSnapshot withPlan(
      List<ExamDayPlan> days, {
      String? createdAtIso,
      Set<String> completed = const {},
      bool diagnostic = true,
    }) =>
        ExamHubSnapshot(
          now: now,
          hasDiagnostic: diagnostic,
          plan: plan(days, createdAtIso: createdAtIso),
          profile: profile(weeks: 6),
          weak: weak,
          pyqAttemptedTotal: 0,
          pyqCorrectTotal: 0,
          lastMockBand: null,
          lastMockKindName: null,
          mockCount: 0,
          completedTaskTypeNames: completed,
        );

    test('plan created today → day 0 is today', () {
      final s = withPlan([
        ExamDayPlan(dayIndex: 0, tasks: [
          task(ExamTaskType.practice, 'a', 10),
          task(ExamTaskType.pyq, 'b', 10),
        ]),
        ExamDayPlan(dayIndex: 1, tasks: [task(ExamTaskType.review, 'c', 5)]),
      ]);
      expect(s.todayDayIndex, 0);
      expect(s.todayTasks.length, 2);
      expect(s.todayTotalMinutes, 20);
      expect(s.todayAllDone, isFalse);
      expect(s.continueTask!.type, ExamTaskType.practice);
    });

    test('3 days old → today is day 3 (clamped into window)', () {
      final s = withPlan([
        for (var i = 0; i < 5; i++)
          ExamDayPlan(dayIndex: i, tasks: [task(ExamTaskType.learn, 't$i', 10)]),
      ], createdAtIso: '2026-09-09T08:00:00.000');
      expect(s.todayDayIndex, 3);
      expect(s.todayTasks.first.topicId, 't3');
    });

    test('window exhausted → staleness surfaces, never fake day 0', () {
      final s = withPlan([
        ExamDayPlan(dayIndex: 0, tasks: [task(ExamTaskType.learn, 'a', 10)]),
      ], createdAtIso: '2026-09-01T08:00:00.000');
      expect(s.planWindowExhausted, isTrue);
      expect(
        s.vanMessage,
        'The plan window has passed — shall we rebuild it?',
      );
    });

    test('finished session marks its task type done + continue moves', () {
      final s = withPlan([
        ExamDayPlan(dayIndex: 0, tasks: [
          task(ExamTaskType.practice, 'a', 10),
          task(ExamTaskType.pyq, 'b', 10),
          task(ExamTaskType.mock, 'c', 20),
        ]),
      ], completed: {'practice'});
      expect(s.todayTasks[0].done, isTrue);
      expect(s.continueTask!.type, ExamTaskType.pyq);
      expect(s.todayDoneCount, 1);
    });

    test('all done → celebrate, no continue task', () {
      final s = withPlan([
        ExamDayPlan(dayIndex: 0, tasks: [
          task(ExamTaskType.practice, 'a', 10),
        ]),
      ], completed: {'practice'});
      expect(s.todayAllDone, isTrue);
      expect(s.continueTask, isNull);
      expect(s.vanMood, ExamHubVanMood.celebrate);
      expect(s.vanMessage, 'Today\u2019s plan is complete. Wonderful consistency!');
    });
  });

  group('weak area / revision / VAN ladder', () {
    ExamHubSnapshot withWeak(ExamHubWeakInput w) => ExamHubSnapshot(
          now: now,
          hasDiagnostic: true,
          plan: plan([
            ExamDayPlan(dayIndex: 0, tasks: [task(ExamTaskType.practice, 'a', 10)]),
          ]),
          profile: profile(weeks: 6),
          weak: w,
          pyqAttemptedTotal: 0,
          pyqCorrectTotal: 0,
          lastMockBand: null,
          lastMockKindName: null,
          mockCount: 0,
          completedTaskTypeNames: const {},
        );

    test('findings produce the honest weak-area line', () {
      final s = withWeak(const ExamHubWeakInput(
        findingCount: 3,
        topSeverityName: 'needsAttention',
        recoveryRecommended: false,
        recoveryDayIndex: 2,
        revisionDueCount: 0,
      ));
      expect(s.weakAreaLine, '3 weak areas · needsAttention');
      expect(s.vanMood, ExamHubVanMood.focus);
    });

    test('recovery today → care mood + recovery message', () {
      final s = withWeak(const ExamHubWeakInput(
        findingCount: 2,
        topSeverityName: 'needsAttention',
        recoveryRecommended: true,
        recoveryDayIndex: 0,
        revisionDueCount: 1,
      ));
      expect(s.recoveryToday, isTrue);
      expect(s.revisionLine, '1 topic due for revision');
      expect(s.vanMood, ExamHubVanMood.care);
      expect(s.vanMessage,
          'Today is your weak-area recovery day. We take it step by step.');
    });

    test('recovery on another day is NOT today', () {
      final s = withWeak(const ExamHubWeakInput(
        findingCount: 2,
        topSeverityName: 'developing',
        recoveryRecommended: true,
        recoveryDayIndex: 4,
        revisionDueCount: 0,
      ));
      expect(s.recoveryToday, isFalse);
    });

    test('recovery already done today is not nagged again', () {
      final s = ExamHubSnapshot(
        now: now,
        hasDiagnostic: true,
        plan: plan([
          ExamDayPlan(dayIndex: 0, tasks: [
            task(ExamTaskType.weakArea, 'a', 15),
          ]),
        ]),
        profile: profile(weeks: 6),
        weak: const ExamHubWeakInput(
          findingCount: 2,
          topSeverityName: 'needsAttention',
          recoveryRecommended: true,
          recoveryDayIndex: 0,
          revisionDueCount: 0,
        ),
        pyqAttemptedTotal: 0,
        pyqCorrectTotal: 0,
        lastMockBand: null,
        lastMockKindName: null,
        mockCount: 0,
        completedTaskTypeNames: const {'weakArea'},
      );
      expect(s.recoveryToday, isFalse);
    });
  });

  group('PYQ / mock lines', () {
    test('real totals and latest mock band surface', () {
      final s = ExamHubSnapshot(
        now: now,
        hasDiagnostic: true,
        plan: null,
        profile: profile(weeks: 6),
        weak: weak,
        pyqAttemptedTotal: 17,
        pyqCorrectTotal: 9,
        lastMockBand: 'learning',
        lastMockKindName: 'mini',
        mockCount: 2,
        completedTaskTypeNames: const {},
      );
      expect(s.pyqLine, '17 PYQ attempts');
      expect(s.mockLine, 'Last mini mock: learning');
    });
  });
}
