/// Exam Mode 2.0 — Exam Hub Snapshot Domain (M10)
///
/// The pure derivation behind the exam-mode HOME: which day of the
/// rolling plan is "today", what the student should CONTINUE with,
/// the honest one-line state of weak areas / revision / PYQ / mocks,
/// the readiness countdown, and the VAN context line.
///
/// Everything here is a pure function of its inputs — the provider
/// layer gathers REAL persisted state (plan, profile, weak-area
/// overview, PYQ/mock history, today's completed session kinds) and
/// this file decides what to SHOW. Nothing is invented: with no data
/// the snapshot says so ("no plan yet", "no mock yet"), and every
/// count comes from evidence the other milestones already persisted.
///
/// Pure Dart — no Flutter, no Riverpod, no I/O.
library;

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';

/// VAN's mood for the hub hero — mapped by the screen to VanState.
enum ExamHubVanMood { welcome, focus, care, celebrate }

/// One row of today's plan (a plan task + its done state).
class ExamHubTask {
  const ExamHubTask({
    required this.type,
    required this.title,
    required this.minutes,
    required this.topicId,
    required this.done,
  });

  final ExamTaskType type;
  final String title;
  final int minutes;
  final String topicId;
  final bool done;
}

/// Weak-area inputs, flattened from the M8 [WeakAreaOverview] so this
/// file stays independent of the weak-area engine types.
class ExamHubWeakInput {
  const ExamHubWeakInput({
    required this.findingCount,
    required this.topSeverityName,
    required this.recoveryRecommended,
    required this.recoveryDayIndex,
    required this.revisionDueCount,
  });

  /// Real §21 findings (0 when there is no evidence yet).
  final int findingCount;

  /// The most severe finding's band ('needsAttention' / 'developing'
  /// / 'retentionRisk' / '' when none).
  final String topSeverityName;

  /// The §22 decision: recovery recommended, and on which day index.
  final bool recoveryRecommended;
  final int recoveryDayIndex;

  /// §23 revision items due today (0 when none).
  final int revisionDueCount;
}

/// The full derived hub state for one track.
class ExamHubSnapshot {
  const ExamHubSnapshot({
    required this.now,
    required this.hasDiagnostic,
    required this.plan,
    required this.profile,
    required this.weak,
    required this.pyqAttemptedTotal,
    required this.pyqCorrectTotal,
    required this.lastMockBand,
    required this.lastMockKindName,
    required this.mockCount,
    required this.completedTaskTypeNames,
  });

  final DateTime now;

  /// Whether the M4 diagnostic has been completed for this track.
  final bool hasDiagnostic;

  final ExamPlan? plan;
  final ExamProfile? profile;
  final ExamHubWeakInput weak;

  /// Real PYQ-session totals (from the persisted §21 performance map).
  final int pyqAttemptedTotal;
  final int pyqCorrectTotal;

  /// Latest persisted mock result (§41 deterministic analysis).
  final String? lastMockBand;
  final String? lastMockKindName;
  final int mockCount;

  /// Plan task-type names completed TODAY (from finished sessions).
  final Set<String> completedTaskTypeNames;

  // ---- readiness ---------------------------------------------------------

  /// Days from today to the readiness anchor (null when no valid
  /// profile / no computable anchor — shown as plain, not "0 days").
  int? get readinessDaysLeft {
    final anchor = profile?.readinessAnchor(now);
    if (anchor == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(anchor.year, anchor.month, anchor.day);
    return target.difference(today).inDays;
  }

  /// Honest readiness line: "28 days to your readiness target" /
  /// "ready in 6 weeks" / "readiness target is today" / '' when no
  /// anchor exists. Never a fabricated countdown.
  String get readinessLine {
    final days = readinessDaysLeft;
    if (days == null) return '';
    if (days > 0) return '$days day${days > 1 ? 's' : ''} to readiness';
    if (days == 0) return 'Readiness target is today';
    return 'Readiness target has passed — set a new one';
  }

  bool get readinessOverdue => (readinessDaysLeft ?? 0) < 0;

  // ---- today's plan ------------------------------------------------------

  /// The plan's day offset that maps onto today: 0 for a plan created
  /// today, N for a plan created N days ago. Clamped into the window;
  /// -1 when there is no plan.
  int get todayDayIndex {
    final p = plan;
    if (p == null || p.days.isEmpty) return -1;
    final created = DateTime.tryParse(p.createdAtIso);
    if (created == null) return 0;
    final createdDay = DateTime(created.year, created.month, created.day);
    final today = DateTime(now.year, now.month, now.day);
    final offset = today.difference(createdDay).inDays;
    return offset.clamp(0, p.days.length - 1);
  }

  /// True when the plan's rolling window no longer covers today
  /// (created > window ago) — §33 staleness the hub surfaces as a
  /// "replan" nudge instead of silently showing day 0 forever.
  bool get planWindowExhausted {
    final p = plan;
    if (p == null || p.days.isEmpty) return false;
    final created = DateTime.tryParse(p.createdAtIso);
    if (created == null) return false;
    final createdDay = DateTime(created.year, created.month, created.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(createdDay).inDays >= p.days.length;
  }

  /// Today's tasks with their honest done flags.
  List<ExamHubTask> get todayTasks {
    final p = plan;
    if (p == null || p.days.isEmpty) return const <ExamHubTask>[];
    final day = p.days[todayDayIndex.clamp(0, p.days.length - 1)];
    return [
      for (final t in day.tasks)
        ExamHubTask(
          type: t.type,
          title: t.title,
          minutes: t.minutes,
          topicId: t.topicId,
          done: completedTaskTypeNames.contains(t.type.name),
        ),
    ];
  }

  int get todayTotalMinutes =>
      todayTasks.fold(0, (sum, t) => sum + t.minutes);

  int get todayDoneCount => todayTasks.where((t) => t.done).length;

  bool get todayAllDone => todayTasks.isNotEmpty && todayDoneCount == todayTasks.length;

  /// The CONTINUE target: the first not-done task of today (M10
  /// "Continue"). Null when everything is done or no plan exists —
  /// the hub then celebrates / points to the next milestone.
  ExamHubTask? get continueTask {
    if (todayTasks.isEmpty) return null;
    for (final t in todayTasks) {
      if (!t.done) return t;
    }
    return null;
  }

  // ---- weak area / revision ---------------------------------------------

  bool get hasWeakEvidence => weak.findingCount > 0;

  /// Honest weak-area line. "No weak areas yet" is the honest state
  /// before evidence exists (never a fabricated reassurance).
  String get weakAreaLine {
    if (weak.findingCount == 0) {
      return 'No weak areas detected yet';
    }
    final severity = weak.topSeverityName.isEmpty
        ? 'developing'
        : weak.topSeverityName;
    return '${weak.findingCount} weak area'
        '${weak.findingCount > 1 ? 's' : ''} · $severity';
  }

  /// True when the §22 decision reserves TODAY as the recovery day.
  bool get recoveryToday =>
      weak.recoveryRecommended &&
      plan != null &&
      weak.recoveryDayIndex == todayDayIndex &&
      !completedTaskTypeNames.contains('weakArea');

  String get revisionLine {
    if (weak.revisionDueCount == 0) {
      return 'No revision due today';
    }
    return '${weak.revisionDueCount} topic'
        '${weak.revisionDueCount > 1 ? 's' : ''} due for revision';
  }

  // ---- PYQ / mock --------------------------------------------------------

  String get pyqLine {
    if (pyqAttemptedTotal == 0) return 'Not attempted yet';
    return '$pyqAttemptedTotal PYQ attempts';
  }

  String get mockLine {
    if (mockCount == 0 || lastMockBand == null) return 'No mock yet';
    final kind = lastMockKindName ?? 'mock';
    return 'Last $kind mock: $lastMockBand';
  }

  // ---- VAN context -------------------------------------------------------

  ExamHubVanMood get vanMood {
    if (recoveryToday || readinessOverdue) return ExamHubVanMood.care;
    if (weak.revisionDueCount > 0 || weak.findingCount > 0) {
      return ExamHubVanMood.focus;
    }
    if (todayAllDone) return ExamHubVanMood.celebrate;
    return ExamHubVanMood.welcome;
  }

  /// VAN's speech line for the hub hero — honest, state-derived.
  String get vanMessage {
    if (!hasDiagnostic) {
      return 'A short diagnostic will tell me where to start.';
    }
    if (plan == null || plan!.days.isEmpty) {
      return 'Let me build your study plan.';
    }
    if (planWindowExhausted) {
      return 'The plan window has passed — shall we rebuild it?';
    }
    if (recoveryToday) {
      return 'Today is your weak-area recovery day. We take it step by step.';
    }
    if (readinessOverdue) {
      return 'Your readiness target passed — setting a new one will re-aim the plan.';
    }
    if (weak.revisionDueCount > 0) {
      return 'You have revision due today — a quick review keeps it fresh.';
    }
    if (todayAllDone) {
      return 'Today\u2019s plan is complete. Wonderful consistency!';
    }
    final task = continueTask;
    if (task != null) {
      return 'Next: ${task.title} · ${task.minutes} min';
    }
    return 'Ready when you are.';
  }
}
