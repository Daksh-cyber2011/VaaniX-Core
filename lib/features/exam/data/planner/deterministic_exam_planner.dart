/// Exam Mode 2.0 — Deterministic Exam Planner (M5, §13/§17/§14; M8 §22/§23)
///
/// The ALWAYS-AVAILABLE planner (no network, no AI): the floor of the
/// §17 fallback chain. Deterministic, explainable, and honest about
/// its source.
///
/// Priorities (§13, §22):
///  * diagnostic weak topics (needsAttention → needsReview) come
///    FIRST;
///  * M8 weak-area connection: when the §22 recovery-day decision
///    reserves a day, THAT day carries the focus topic's recovery
///    session plus due revision instead of new material — "Do not
///    make every day weak-area day" is enforced by the decision
///    engine, not by this planner;
///  * M8 revision connection: due/overdue §23 revision items become
///    review tasks spread across the earliest days (evidence-based
///    spacing — never a blanket "revise every Sunday");
///  * no diagnostic yet → syllabus order, marks-weighted (official
///    marks signal exam weight — grounded priority, not invention);
///  * every day fits INSIDE the student's real budget (§9);
///  * learn + practice + review interleaved; one PYQ slot/week and a
///    mock slot in the last third of the window (§25: slots are
///    honest — content separation happens at content level).
library;

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_validator.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';

class DeterministicExamPlanner {
  const DeterministicExamPlanner();

  /// Builds the rolling 7-day plan for [ctx].
  static ExamPlan build(DeterministicExamContext ctx) {
    final selected = <ScopeUnit>[];
    for (final section in ctx.view.sections) {
      for (final unit in section.selectableUnits) {
        if (ctx.selection.isSelected(unit.id)) selected.add(unit);
      }
    }

    // Priority order: weak-first (with diagnostic), else marks-weighted.
    final weakIds = ctx.learner.weakTopicsFirst(limit: 30)
        .map((t) => t.topicId)
        .toSet();
    final ordered = [...selected]..sort((a, b) {
        final aWeak = weakIds.contains(a.id) ? 0 : 1;
        final bWeak = weakIds.contains(b.id) ? 0 : 1;
        if (aWeak != bWeak) return aWeak.compareTo(bWeak);
        // Within a group: higher official marks first (grounded).
        final am = a.marks ?? 0;
        final bm = b.marks ?? 0;
        if (am != bm) return bm.compareTo(am);
        return a.title.compareTo(b.title);
      });

    // Study days: the plan emits exactly the student's study days
    // (day 0 = today always exists); non-study days are simply not
    // emitted — an honest rest day, never an empty "plan" day. The
    // rolling window is bounded by min(7, studyDaysPerWeek).
    final budget = ctx.profile.dailyStudyMinutes;
    // §9 hard guarantee: a task NEVER exceeds the daily budget itself.
    final taskMinutes = budget >= 45
        ? 15
        : (budget >= 10 ? 10 : budget);
    final tasksPerDay = (budget / taskMinutes).floor().clamp(1, 4);
    final dayCount = ctx.profile.studyDaysPerWeek.clamp(1, 7);

    final topicQueue = List<ScopeUnit>.from(ordered);
    var rotation = 0;

    // --- M8 §22: the reserved weak-area recovery day, if any.
    final decision = ctx.weakArea?.decision;
    final recoveryDay = (decision != null && decision.shouldRecover)
        ? decision.dayIndex
        : -1;

    // --- M8 §23: due/overdue revision items become review tasks,
    //     spread over the earliest days (overdue first). Only
    //     IN-SCOPE topics may become tasks (§16 rule 1).
    final inScopeIds = selected.map((u) => u.id).toSet();
    final revisionQueue = ctx.weakArea == null
        ? <RevisionItem>[]
        : RevisionEngine.dueToday(
            ctx.weakArea!.revisionItems,
            DateTime.now(),
            limit: 5,
          ).where((i) => inScopeIds.contains(i.topicId)).toList();
    var revisionUsed = 0;

    String? titleOf(String topicId) {
      for (final u in selected) {
        if (u.id == topicId) return u.title;
      }
      return null;
    }

    final days = <ExamDayPlan>[];
    for (var day = 0; day < dayCount; day++) {
      final tasks = <ExamPlanTask>[];
      int usedMinutes() => tasks.fold(0, (s, t) => s + t.minutes);

      if (day == recoveryDay && decision != null && decision.shouldRecover) {
        // §22 recovery day: the focus topic's recovery session leads,
        // then due revision fills the remaining budget. New material
        // deliberately waits ("reserve a day… for weak-area recovery").
        final focusTitle = titleOf(decision.focusTopicId);
        if (focusTitle != null) {
          tasks.add(ExamPlanTask(
            type: ExamTaskType.weakArea,
            topicId: decision.focusTopicId,
            title: 'कमज़ोर क्षेत्र recovery: $focusTitle',
            minutes: taskMinutes,
            detail: decision.rationale,
          ));
        }
        while (revisionUsed < revisionQueue.length &&
            usedMinutes() + taskMinutes <= budget) {
          final item = revisionQueue[revisionUsed++];
          final title = titleOf(item.topicId);
          if (title == null) continue;
          tasks.add(ExamPlanTask(
            type: ExamTaskType.review,
            topicId: item.topicId,
            title: 'दोहराव (भूलने का ख़तरा): $title',
            minutes: taskMinutes,
            detail: item.bandLabel,
          ));
        }
        // Budget still left → one light practice on the SAME focus
        // topic (§22 targeted practice), never brand-new material.
        if (focusTitle != null && usedMinutes() + 10 <= budget) {
          tasks.add(ExamPlanTask(
            type: ExamTaskType.practice,
            topicId: decision.focusTopicId,
            title: 'लक्षित अभ्यास: $focusTitle',
            minutes: 10,
          ));
        }
        days.add(ExamDayPlan(dayIndex: day, tasks: tasks));
        rotation++;
        if (topicQueue.isEmpty && selected.isNotEmpty) {
          topicQueue.addAll(ordered);
        }
        continue;
      }

      // --- M8 §23: a due revision takes the day's FIRST slot (review
      //     before new material — evidence-based spacing, not a
      //     blanket dump), but ONLY when an active backbone task can
      //     still fit after it (validator rule 5). Tiny-budget days
      //     (tasksPerDay == 1) keep the M5 shape.
      if (day != recoveryDay &&
          revisionUsed < revisionQueue.length &&
          tasksPerDay >= 2) {
        final item = revisionQueue[revisionUsed++];
        final title = titleOf(item.topicId);
        if (title != null) {
          tasks.add(ExamPlanTask(
            type: ExamTaskType.review,
            topicId: item.topicId,
            title: 'दोहराव: $title',
            minutes: taskMinutes,
            detail: item.bandLabel,
          ));
        }
      }

      if (topicQueue.isNotEmpty) {
        for (var t = tasks.length;
            t < tasksPerDay && topicQueue.isNotEmpty;
            t++) {
          final unit = topicQueue.removeAt(0);
          // Interleave: learn → practice → (review on 3rd slot).
          final type = t == 0
              ? ExamTaskType.learn
              : (t == 1 ? ExamTaskType.practice : ExamTaskType.review);
          tasks.add(ExamPlanTask(
            type: type,
            topicId: unit.id,
            title: _taskTitle(type, unit.title),
            minutes: taskMinutes,
          ));
        }
        // Weak-area reinforcement on the weakest topic of the day when
        // budget allows one extra slot (§22 weak-area first).
        if (weakIds.isNotEmpty &&
            tasks.isNotEmpty &&
            usedMinutes() + 10 <= budget) {
          final weakUnit = ordered
              .where((u) => weakIds.contains(u.id))
              .firstOrNull;
          if (weakUnit != null && !tasks.any((t) => t.topicId == weakUnit.id)) {
            tasks.add(ExamPlanTask(
              type: ExamTaskType.weakArea,
              topicId: weakUnit.id,
              title: 'कमज़ोर क्षेत्र: ${weakUnit.title}',
              minutes: 10,
            ));
          }
        }
        // One PYQ slot mid-window; one mock slot late (honest slots).
        if (day == 3 && ordered.isNotEmpty) {
          final u = ordered[rotation % ordered.length];
          if (usedMinutes() + 10 <= budget) {
            tasks.add(ExamPlanTask(
              type: ExamTaskType.pyq,
              topicId: u.id,
              title: 'PYQ अभ्यास — ${u.title}',
              minutes: 10,
            ));
          }
        }
        if (day == 5 && ordered.isNotEmpty) {
          final u = ordered[rotation % ordered.length];
          if (usedMinutes() + 10 <= budget) {
            tasks.add(ExamPlanTask(
              type: ExamTaskType.mock,
              topicId: u.id,
              title: 'मिनी mock — ${u.title}',
              minutes: 10,
            ));
          }
        }
        rotation++;
      }

      // Refill queue when the scope is small (7 days need material).
      if (topicQueue.isEmpty && selected.isNotEmpty) {
        topicQueue.addAll(ordered);
      }

      days.add(ExamDayPlan(dayIndex: day, tasks: tasks));
    }

    final focus = ordered.isEmpty
        ? 'Scope खाली है — पहले syllabus चुनें'
        : 'इस सप्ताह का लक्ष्य: ${ordered.take(3).map((u) => u.title).join(', ')}';
    var rationale = ctx.learner.hasDiagnostic
        ? 'डायग्नोस्टिक के आधार पर कमज़ोर विषय पहले — फिर अंक-भार के क्रम में। '
            'हर दिन आपके $budget मिनट के अंदर। (offline योजना)'
        : 'डायग्नोस्टिक अभी नहीं हुआ — आधिकारिक अंकों के क्रम में विषय। '
            'हर दिन आपके $budget मिनट के अंदर। (offline योजना)';
    // §50 explainability: the recovery-day reservation is stated, not
    // silent.
    if (recoveryDay >= 0 && decision != null && decision.shouldRecover) {
      rationale =
          '${decision.rationale} बाक़ी दिन डायग्नोस्टिक क्रम में — हर दिन '
          'आपके $budget मिनट के अंदर। (offline योजना)';
    }

    final plan = ExamPlan(
      id: 'plan-${ctx.trackId}-${ctx.scopeRevision}',
      trackId: ctx.trackId,
      source: ExamPlanSource.deterministic,
      scopeRevision: ctx.scopeRevision,
      focusSummary: focus,
      rationale: rationale,
      days: days,
      createdAtIso: DateTime.now().toIso8601String(),
    );

    // Self-check: the deterministic planner must ALWAYS pass its own
    // validator (§14 deterministic structures control the floor).
    assert(
      ExamPlanValidator.isValid(
        plan: plan,
        view: ctx.view,
        selection: ctx.selection,
        profile: ctx.profile,
      ),
      'Deterministic plan failed validation — budget math bug',
    );
    return plan;
  }

  static String _taskTitle(ExamTaskType type, String unitTitle) =>
      switch (type) {
        ExamTaskType.learn => 'सीखें: $unitTitle',
        ExamTaskType.practice => 'अभ्यास: $unitTitle',
        ExamTaskType.review => 'दोहराव: $unitTitle',
        _ => unitTitle,
      };
}

/// The M8 weak-area planner input (§22 decision + §23 schedule).
/// Optional: the planner works identically without it (M5 behavior).
class WeakAreaPlannerInput {
  const WeakAreaPlannerInput({
    required this.decision,
    required this.revisionItems,
    this.findings = const [],
  });

  final WeakAreaDayDecision decision;
  final List<RevisionItem> revisionItems;

  /// §21 finding topic ids (engines never leak internals into
  /// student-facing text, §30).
  final List<String> findings;
}

/// Inputs mirror [ExamPlannerContext] but stay in the data layer's
/// own type so the deterministic engine has no AI-layer imports.
class DeterministicExamContext {
  const DeterministicExamContext({
    required this.trackId,
    required this.view,
    required this.selection,
    required this.profile,
    required this.learner,
    required this.scopeRevision,
    this.weakArea,
  });

  final String trackId;
  final ExamScopeView view;
  final ExamScopeSelection selection;
  final ExamProfile profile;
  final ExamLearnerProfile learner;
  final int scopeRevision;

  /// M8 weak-area connection (optional — absent = pre-M8 behavior).
  final WeakAreaPlannerInput? weakArea;
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
