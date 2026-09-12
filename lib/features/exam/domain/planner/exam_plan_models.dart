/// Exam Mode 2.0 — Personalized Plan Domain Models (M5, §13–§14)
///
/// The structured personalized plan the planner engines produce:
/// priorities, sequence, daily tasks (learn / practice / review / PYQ /
/// weak-area), bounded to a rolling 7-day window (§18 bounded output;
/// long horizons are replanned, not dumped at once).
///
/// §14 AI MUST NOT CONTROL EVERYTHING: the plan is a RECOMMENDATION.
/// The app validates it ([ExamPlanValidator]) before showing it, the
/// student can follow or choose differently (§20 student freedom), and
/// the deterministic engine can always rebuild it offline.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// The task archetypes a plan day can contain (§13, §19).
enum ExamTaskType { learn, practice, review, pyq, weakArea, mock }

ExamTaskType? examTaskTypeFromName(String? name) => switch (name) {
      'learn' => ExamTaskType.learn,
      'practice' => ExamTaskType.practice,
      'review' => ExamTaskType.review,
      'pyq' => ExamTaskType.pyq,
      'weakArea' => ExamTaskType.weakArea,
      'mock' => ExamTaskType.mock,
      _ => null,
    };

/// Where a plan came from (honest provenance, §63).
enum ExamPlanSource { ai, cached, deterministic }

ExamPlanSource examPlanSourceFromName(String? name) => switch (name) {
      'ai' => ExamPlanSource.ai,
      'cached' => ExamPlanSource.cached,
      _ => ExamPlanSource.deterministic,
    };

/// One task on one day.
class ExamPlanTask extends Equatable {
  const ExamPlanTask({
    required this.type,
    required this.topicId,
    required this.title,
    required this.minutes,
    this.detail,
  });

  /// Task archetype.
  final ExamTaskType type;

  /// The scope unit this task works on. Must be a selected unit id
  /// (validated — §16 rule 1: "Is the topic inside selected scope?").
  final String topicId;

  /// Student-facing task line (explainable plan, §13): e.g.
  /// "Revise Sandhi — 10 min" style.
  final String title;

  /// Planned minutes (per-day sums are validated against §9 budget).
  final int minutes;

  final String? detail;

  @override
  List<Object?> get props => [type, topicId, title, minutes];
}

/// One day of the rolling plan.
class ExamDayPlan extends Equatable {
  const ExamDayPlan({required this.dayIndex, required this.tasks});

  /// 0-based day offset from plan creation (day 0 = today).
  final int dayIndex;
  final List<ExamPlanTask> tasks;

  int get totalMinutes => tasks.fold(0, (sum, t) => sum + t.minutes);

  @override
  List<Object?> get props => [dayIndex, tasks];
}

/// The full personalized plan for one track.
class ExamPlan extends Equatable {
  const ExamPlan({
    required this.id,
    required this.trackId,
    required this.source,
    required this.scopeRevision,
    required this.focusSummary,
    required this.rationale,
    required this.days,
    required this.createdAtIso,
  });

  /// Stable id (plan-<track>-<scopeRevision>).
  final String id;
  final String trackId;
  final ExamPlanSource source;

  /// The scope revision this plan was built from — when the student
  /// edits the scope, this no longer matches and the plan is STALE
  /// (§33 adaptive replanning trigger).
  final int scopeRevision;

  /// One-line what-this-week-is-about (explainable, §13).
  final String focusSummary;

  /// Why the plan looks like this (explainable plan, §13).
  final String rationale;

  /// Rolling window, 1..7 days (§18 bounded output).
  final List<ExamDayPlan> days;

  final String createdAtIso;

  factory ExamPlan.fromJson(Map<String, dynamic> json) {
    final days = <ExamDayPlan>[];
    for (final d in (json['days'] as List<dynamic>? ?? [])) {
      final dayMap = (d as Map<String, dynamic>).cast<String, dynamic>();
      final tasks = <ExamPlanTask>[];
      for (final t in (dayMap['tasks'] as List<dynamic>? ?? [])) {
        final taskMap = (t as Map<String, dynamic>).cast<String, dynamic>();
        final type = examTaskTypeFromName(taskMap['type'] as String?);
        if (type == null) continue; // unknown type → drop task, keep plan
        tasks.add(ExamPlanTask(
          type: type,
          topicId: taskMap['topicId'] as String? ?? '',
          title: taskMap['title'] as String? ?? '',
          minutes: (taskMap['minutes'] as num?)?.toInt() ?? 0,
          detail: taskMap['detail'] as String?,
        ));
      }
      days.add(ExamDayPlan(
        dayIndex: (dayMap['dayIndex'] as num?)?.toInt() ?? days.length,
        tasks: tasks,
      ));
    }
    return ExamPlan(
      id: json['id'] as String? ?? '',
      trackId: json['trackId'] as String? ?? '',
      source: examPlanSourceFromName(json['source'] as String?),
      scopeRevision: (json['scopeRevision'] as num?)?.toInt() ?? 0,
      focusSummary: json['focusSummary'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      days: days,
      createdAtIso: json['createdAtIso'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'source': source.name,
        'scopeRevision': scopeRevision,
        'focusSummary': focusSummary,
        'rationale': rationale,
        'days': [
          for (final d in days)
            {
              'dayIndex': d.dayIndex,
              'tasks': [
                for (final t in d.tasks)
                  {
                    'type': t.type.name,
                    'topicId': t.topicId,
                    'title': t.title,
                    'minutes': t.minutes,
                    if (t.detail != null) 'detail': t.detail,
                  },
              ],
            },
        ],
        'createdAtIso': createdAtIso,
      };

  @override
  List<Object?> get props => [id, trackId, source, scopeRevision, days];
}
