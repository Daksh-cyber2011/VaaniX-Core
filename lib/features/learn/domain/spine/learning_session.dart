/// Learn Mode 2.0 — Learning Session (M1 Architecture Spine)
///
/// The session model between PLAN and EVALUATION:
///
///   LearningPlan → LearningSession → EvaluationResult → MasteryUpdate
///
/// A session executes one plan's activities; its outcome carries the
/// evaluation plus gamification deltas (XP, minutes) computed locally by
/// deterministic logic (Master Brief §61 — AI never handles XP/mastery
/// math).
///
/// The live session ENGINE (driving the exercise screen through session
/// kinds) arrives in M6; M1 locks the typed model.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/evaluation.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';

/// Lifecycle of a session.
enum SessionStatus { active, completed, abandoned }

/// A learning session executing a [LearningPlan].
class LearningSession extends Equatable {
  const LearningSession({
    required this.id,
    required this.planId,
    required this.languageCode,
    required this.kind,
    required this.startedAt,
    this.status = SessionStatus.active,
    this.activityIds = const <String>[],
  });

  final String id;

  /// Plan this session executes.
  final String planId;

  /// ISO 639-1 code of the language being learned.
  final String languageCode;

  /// What kind of session this is (mirrors the plan's activity focus).
  final ActivityKind kind;

  final DateTime startedAt;
  final SessionStatus status;

  /// [LearningActivity.id]s from the plan that belong to this session.
  final List<String> activityIds;

  LearningSession copyWith({
    String? id,
    String? planId,
    String? languageCode,
    ActivityKind? kind,
    DateTime? startedAt,
    SessionStatus? status,
    List<String>? activityIds,
  }) {
    return LearningSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      languageCode: languageCode ?? this.languageCode,
      kind: kind ?? this.kind,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      activityIds: activityIds ?? this.activityIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'languageCode': languageCode,
        'kind': kind.name,
        'startedAt': startedAt.toIso8601String(),
        'status': status.name,
        'activityIds': activityIds,
      };

  factory LearningSession.fromJson(Map<String, dynamic> json) {
    return LearningSession(
      id: json['id'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      languageCode: json['languageCode'] as String? ?? '',
      kind: ActivityKind.tryParse(json['kind'] as String?) ??
          ActivityKind.practice,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      status: SessionStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String?),
        orElse: () => SessionStatus.active,
      ),
      activityIds: (json['activityIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }

  @override
  List<Object?> get props => [
        id, planId, languageCode, kind, startedAt, status, activityIds,
      ];
}

/// End-of-session outcome: evaluation + locally-computed gamification.
class SessionOutcome extends Equatable {
  const SessionOutcome({
    required this.sessionId,
    required this.evaluation,
    required this.xpEarned,
    required this.minutesSpent,
    required this.completedAt,
  });

  final String sessionId;
  final EvaluationResult evaluation;

  /// XP computed by deterministic local logic (never by AI).
  final int xpEarned;

  /// Wall-clock minutes spent (feeds the daily-goal loop, M7).
  final int minutesSpent;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'evaluation': evaluation.toJson(),
        'xpEarned': xpEarned,
        'minutesSpent': minutesSpent,
        'completedAt': completedAt.toIso8601String(),
      };

  factory SessionOutcome.fromJson(Map<String, dynamic> json) {
    return SessionOutcome(
      sessionId: json['sessionId'] as String? ?? '',
      evaluation: EvaluationResult.fromJson(
        json['evaluation'] as Map<String, dynamic>? ?? {},
      ),
      xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
      minutesSpent: (json['minutesSpent'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [sessionId, evaluation, xpEarned, minutesSpent, completedAt];
}
