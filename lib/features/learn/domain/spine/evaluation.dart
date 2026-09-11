/// Learn Mode 2.0 — Evaluation & Mastery Update (M1 Architecture Spine)
///
/// Typed result of evaluating one learning session, and the concept-level
/// mastery update it feeds (Master Brief §63 schemas: EvaluationResult,
/// MasteryUpdate).
///
/// M1 ships the vocabulary + a conservative, evidence-only stage
/// transition helper ([proposeMasteryTransition]). The full session-driven
/// mastery engine (review scheduling, forgetting curve handling) arrives
/// in M6 — this file deliberately does NOT fake it.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';

/// Evaluation evidence for ONE concept within a session.
class ConceptEvaluation extends Equatable {
  const ConceptEvaluation({
    required this.conceptId,
    required this.correct,
    required this.attempts,
    required this.firstTryCorrect,
  });

  final String conceptId;

  /// Whether the learner demonstrated the concept correctly this session.
  final bool correct;

  /// How many probes/attempts this evaluation is based on.
  final int attempts;

  /// True when the concept was correct on the FIRST attempt (the
  /// existing engine's quality signal — first-try-only scoring).
  final bool firstTryCorrect;

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'correct': correct,
        'attempts': attempts,
        'firstTryCorrect': firstTryCorrect,
      };

  factory ConceptEvaluation.fromJson(Map<String, dynamic> json) {
    return ConceptEvaluation(
      conceptId: json['conceptId'] as String? ?? '',
      correct: json['correct'] as bool? ?? false,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      firstTryCorrect: json['firstTryCorrect'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [conceptId, correct, attempts, firstTryCorrect];
}

/// Structured result of evaluating one session.
class EvaluationResult extends Equatable {
  const EvaluationResult({
    required this.sessionId,
    required this.conceptEvaluations,
    this.completedAt,
  });

  final String sessionId;
  final List<ConceptEvaluation> conceptEvaluations;
  final DateTime? completedAt;

  /// Session accuracy across all evaluated concepts (null when empty).
  double? get accuracy {
    if (conceptEvaluations.isEmpty) return null;
    final correct = conceptEvaluations.where((e) => e.correct).length;
    return correct / conceptEvaluations.length;
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'conceptEvaluations': [
          for (final e in conceptEvaluations) e.toJson(),
        ],
        'completedAt': completedAt?.toIso8601String(),
      };

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      sessionId: json['sessionId'] as String? ?? '',
      conceptEvaluations: (json['conceptEvaluations'] as List<dynamic>? ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(ConceptEvaluation.fromJson)
          .toList(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [sessionId, conceptEvaluations, completedAt];
}

/// A proposed concept-level mastery update (stage + evidence deltas).
/// Applying it is the M6 engine's job — M1 only produces/validates it.
class MasteryUpdate extends Equatable {
  const MasteryUpdate({
    required this.conceptId,
    required this.fromStage,
    required this.toStage,
    this.correctDelta = 0,
    this.attemptDelta = 0,
    this.reviewDueAt,
  });

  final String conceptId;

  /// Stage before the update (explicit so stale updates are detectable).
  final MasteryStage fromStage;
  final MasteryStage toStage;

  final int correctDelta;
  final int attemptDelta;

  /// Review scheduling output (M6 fills; null = untouched).
  final DateTime? reviewDueAt;

  /// True when this update would move the concept backwards (used by the
  /// M6 engine to decide between regression and review scheduling).
  bool get isRegression => toStage.index < fromStage.index;

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'fromStage': fromStage.name,
        'toStage': toStage.name,
        'correctDelta': correctDelta,
        'attemptDelta': attemptDelta,
        'reviewDueAt': reviewDueAt?.toIso8601String(),
      };

  factory MasteryUpdate.fromJson(Map<String, dynamic> json) {
    return MasteryUpdate(
      conceptId: json['conceptId'] as String? ?? '',
      fromStage: MasteryStage.tryParse(json['fromStage'] as String?) ??
          MasteryStage.introduced,
      toStage: MasteryStage.tryParse(json['toStage'] as String?) ??
          MasteryStage.introduced,
      correctDelta: (json['correctDelta'] as num?)?.toInt() ?? 0,
      attemptDelta: (json['attemptDelta'] as num?)?.toInt() ?? 0,
      reviewDueAt: json['reviewDueAt'] != null
          ? DateTime.tryParse(json['reviewDueAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        conceptId, fromStage, toStage, correctDelta, attemptDelta,
        reviewDueAt,
      ];
}

/// Conservative, evidence-only stage transition proposal.
///
/// Rules (all grounded in evidence the M1 engine actually has):
/// - a correct FIRST-TRY answer advances the concept ONE stage;
/// - a wrong answer never advances (M6 decides regression/review);
/// - the ladder never skips stages and never exceeds [MasteryStage.understood]
///   until M6 adds recall/application/mastery evidence.
MasteryUpdate proposeMasteryTransition({
  required ConceptMastery current,
  required bool correct,
  required bool firstTry,
}) {
  MasteryStage to = current.stage;
  if (correct && firstTry) {
    final ceiling = MasteryStage.understood;
    final next = current.stage.next;
    if (next != null && next.index <= ceiling.index) to = next;
  }
  return MasteryUpdate(
    conceptId: current.conceptId,
    fromStage: current.stage,
    toStage: to,
    correctDelta: correct ? 1 : 0,
    attemptDelta: 1,
  );
}
