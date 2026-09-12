/// Exam Mode 2.0 — Plan Validator (M5, §14/§16/§9)
///
/// The deterministic gate every plan passes BEFORE the student sees
/// it — AI or not (§14 "The app validates and enforces"). A plan that
/// fails ANY rule is rejected and the fallback chain serves the
/// deterministic plan instead.
///
/// Rules (§16 hallucination checks, translated to plan geometry):
///  1. every task topicId is INSIDE the current selected scope;
///  2. every day's total minutes fit inside the student's available
///     daily study time (§9: the planner must fit, never overflow);
///  3. task minutes are sane (1..90);
///  4. the rolling window is bounded (1..7 days, day 0 exists);
///  5. every day has at least one task; every day has an active
///     backbone — learn / practice / weakArea (M8: a §22 recovery
///     day IS intense practice, so a weakArea task counts; a
///     review-only day is still not a plan);
///  6. PYQ/mock tasks are clearly typed (never labeled official —
///     §25 separation happens at content level, but the plan only
///     schedules the SLOT).
library;

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';

class ExamPlanValidator {
  const ExamPlanValidator._();

  /// Validates [plan] against the CURRENT scope + profile. Returns the
  /// violation list (empty = valid).
  static List<String> validate({
    required ExamPlan plan,
    required ExamScopeView view,
    required ExamScopeSelection selection,
    required ExamProfile profile,
  }) {
    final errors = <String>[];
    final allowedTopics = selection.selectedUnitIds;

    if (plan.trackId != view.trackId) {
      errors.add('plan track ${plan.trackId} != scope track ${view.trackId}');
    }
    if (plan.days.isEmpty) {
      errors.add('plan has no days');
      return errors;
    }
    if (plan.days.length > 7) {
      errors.add('plan has ${plan.days.length} days (max 7)');
    }
    if (plan.days.first.dayIndex != 0) {
      errors.add('first day index is ${plan.days.first.dayIndex}, not 0');
    }

    for (final day in plan.days) {
      if (day.tasks.isEmpty) {
        errors.add('day ${day.dayIndex} has no tasks');
        continue;
      }
      if (day.totalMinutes > profile.dailyStudyMinutes) {
        // §9: NEVER overflow the student's real budget.
        errors.add('day ${day.dayIndex} needs ${day.totalMinutes}min > '
            'available ${profile.dailyStudyMinutes}min');
      }
      final hasBackbone = day.tasks.any((t) =>
          t.type == ExamTaskType.learn ||
          t.type == ExamTaskType.practice ||
          // M8: §22 recovery days are intense practice sessions.
          t.type == ExamTaskType.weakArea);
      if (!hasBackbone) {
        errors.add('day ${day.dayIndex} has no active task');
      }
      for (final task in day.tasks) {
        if (task.minutes < 1 || task.minutes > 90) {
          errors.add('task "${task.title}" minutes ${task.minutes} '
              'out of range 1..90');
        }
        if (!allowedTopics.contains(task.topicId)) {
          // §16 rule 1: hallucinated/out-of-scope topic → reject.
          errors.add('task "${task.title}" topicId ${task.topicId} '
              'is outside the selected scope');
        }
      }
    }
    return errors;
  }

  /// Convenience: valid ⇔ no violations.
  static bool isValid({
    required ExamPlan plan,
    required ExamScopeView view,
    required ExamScopeSelection selection,
    required ExamProfile profile,
  }) =>
      validate(plan: plan, view: view, selection: selection, profile: profile)
          .isEmpty;
}
