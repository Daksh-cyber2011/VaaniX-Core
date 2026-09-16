/// Exam Mode 2.0 — M8 Planner Connection Tests (§22/§23 → §13)
///
/// The weak-area engines feed BOTH planner hops:
///  * deterministic: recovery-day reservation (weakArea task on the
///    decision's day/focus topic; no brand-new material that day),
///    due revision items become spaced review tasks, plan still
///    passes the §16 validator and the §9 budget;
///  * Gemini: the prompt carries the bounded weak-area digest when
///    evidence exists and omits the section entirely when it does not
///    (honest omission — never fabricated).
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:vaanix_app/features/exam/data/planner/deterministic_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/planner/gemini_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_validator.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CourseSyllabus syllabus;
  late ExamScopeView view;
  late ExamScopeSelection selection;
  late ExamProfile examProfile;
  late String focusTopicId;

  setUpAll(() async {
    final raw = await rootBundle
        .loadString('assets/syllabus/cbse/cbse_10_sanskrit.json');
    syllabus = CourseSyllabus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    view = ExamScopeView.fromSyllabus(syllabus);
    selection = ExamScopeSelection.empty(view.trackId)
        .selectAll(view.selectableUnitIds);
    examProfile = ExamProfile(
      trackId: view.trackId,
      dailyStudyMinutes: 45,
      studyDaysPerWeek: 6,
      readinessDurationWeeks: 8,
    );
    focusTopicId = selection.selectedUnitIds.first;
  });

  WeakAreaDayDecision recoveryDecision({required int dayIndex}) =>
      WeakAreaDayDecision(
        shouldRecover: true,
        frequency: RecoveryFrequency.frequent,
        dayIndex: dayIndex,
        focusTopicId: focusTopicId,
        rationale: 'कमज़ोर क्षेत्र की recovery इस दिन रखी गई है।',
      );

  DeterministicExamContext ctxWith(WeakAreaPlannerInput? weakArea) =>
      DeterministicExamContext(
        trackId: view.trackId,
        view: view,
        selection: selection,
        profile: examProfile,
        learner: ExamLearnerProfile.empty(view.trackId),
        scopeRevision: selection.revision,
        weakArea: weakArea,
      );

  test('M8 plan still passes the §16 validator + §9 budget', () {
    final plan = DeterministicExamPlanner.build(ctxWith(
      WeakAreaPlannerInput(
        decision: recoveryDecision(dayIndex: 2),
        revisionItems: [
          RevisionItem(
            topicId: focusTopicId,
            intervalIndex: 1,
            lastReviewedIso: '',
            // Overdue → becomes a review task.
            dueIso: DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
          ),
        ],
      ),
    ));
    expect(
      ExamPlanValidator.validate(
          plan: plan, view: view, selection: selection, profile: examProfile),
      isEmpty,
      reason: 'M8 plan must validate like the M5 plan',
    );
    for (final day in plan.days) {
      expect(day.totalMinutes <= examProfile.dailyStudyMinutes, isTrue);
    }
  });

  test('§22: the reserved day carries the recovery task of the focus topic',
      () {
    final dayIndex = 3;
    final plan = DeterministicExamPlanner.build(ctxWith(
      WeakAreaPlannerInput(
        decision: recoveryDecision(dayIndex: dayIndex),
        revisionItems: const [],
      ),
    ));
    final recoveryDay = plan.days.firstWhere((d) => d.dayIndex == dayIndex);
    final weakTasks = recoveryDay.tasks
        .where((t) => t.type == ExamTaskType.weakArea)
        .toList();
    expect(weakTasks, hasLength(1));
    expect(weakTasks.first.topicId, focusTopicId);
    expect(weakTasks.first.title, contains('recovery'));
    // §50: the decision rationale rides on the task detail.
    expect(weakTasks.first.detail, isNotNull);
    // New material deliberately waits — no "learn" tasks that day.
    expect(
      recoveryDay.tasks.where((t) => t.type == ExamTaskType.learn),
      isEmpty,
      reason: 'recovery day is reserved, not a normal day + extra',
    );
  });

  test('§22: non-recovery days keep the normal learn flow', () {
    final plan = DeterministicExamPlanner.build(ctxWith(
      WeakAreaPlannerInput(
        decision: recoveryDecision(dayIndex: 2),
        revisionItems: const [],
      ),
    ));
    final normalDay = plan.days.firstWhere((d) => d.dayIndex == 0);
    expect(normalDay.tasks.any((t) => t.type == ExamTaskType.learn), isTrue);
  });

  test('§23: overdue revision becomes review tasks, only in-scope ones', () {
    final inScopeOverdue = RevisionItem(
      topicId: focusTopicId,
      intervalIndex: 1,
      lastReviewedIso: '',
      dueIso:
          DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    );
    final plan = DeterministicExamPlanner.build(ctxWith(
      WeakAreaPlannerInput(
        decision: WeakAreaDayDecision(
          shouldRecover: false,
          frequency: RecoveryFrequency.none,
          dayIndex: -1,
          focusTopicId: '',
          rationale: '',
        ),
        revisionItems: [inScopeOverdue],
      ),
    ));
    final reviewTasks = <ExamPlanTask>[];
    for (final day in plan.days) {
      reviewTasks.addAll(day.tasks.where((t) => t.type == ExamTaskType.review));
    }
    expect(reviewTasks, isNotEmpty,
        reason: 'overdue item must surface as review work');
    expect(reviewTasks.first.topicId, focusTopicId);
  });

  test('null weak-area input = pre-M8 behavior (backward compat)', () {
    final plan = DeterministicExamPlanner.build(ctxWith(null));
    expect(
      ExamPlanValidator.validate(
          plan: plan, view: view, selection: selection, profile: examProfile),
      isEmpty,
    );
    expect(
        plan.days.first.tasks.any((t) => t.type == ExamTaskType.learn), isTrue);
  });

  test('§50: the plan rationale states the recovery reservation', () {
    final plan = DeterministicExamPlanner.build(ctxWith(
      WeakAreaPlannerInput(
        decision: recoveryDecision(dayIndex: 2),
        revisionItems: const [],
      ),
    ));
    expect(plan.rationale, contains('recovery'));
  });

  group('Gemini prompt digest (§18 bounded, §21 honest)', () {
    ExamPlannerContext plannerCtx(List<String> digest) => ExamPlannerContext(
          trackId: view.trackId,
          view: view,
          selection: selection,
          profile: examProfile,
          learner: ExamLearnerProfile.empty(view.trackId),
          scopeRevision: selection.revision,
          weakAreaDigest: digest,
        );

    test('digest present → WEAK AREA block appears in the prompt', () {
      final prompt = ExamPlannerPrompt.user(plannerCtx([
        '- weak topic $focusTopicId: needsAttention (lowMastery)',
        '- recommended recovery day: dayIndex 2 (focus topic $focusTopicId)',
      ]));
      expect(prompt, contains('WEAK AREA'));
      expect(prompt, contains(focusTopicId));
      expect(prompt, contains('dayIndex 2'));
    });

    test('no evidence → the block is absent entirely (never fabricated)', () {
      final prompt = ExamPlannerPrompt.user(plannerCtx(const []));
      expect(prompt.contains('WEAK AREA'), isFalse);
    });

    test('system prompt still demands the strict JSON schema', () {
      final sys = ExamPlannerPrompt.system();
      expect(sys, contains('STRICT JSON'));
      expect(sys, contains('weakArea'));
    });
  });
}
