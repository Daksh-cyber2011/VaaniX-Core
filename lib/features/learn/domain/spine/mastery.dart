/// Learn Mode 2.0 — Concept Mastery Lifecycle (M1 Architecture Spine)
///
/// The mastery model is CONCEPT-based, not lesson-based (Master Brief §19):
///
///   introduced → practiced → understood → recalled → applied → mastered
///   → maintained
///
/// A learner can complete an activity WITHOUT mastering its concept; the
/// existing per-lesson mastered-exercise sets remain the raw evidence, while
/// this model expresses how far a concept has actually progressed.
///
/// M1 scope: the typed vocabulary + persistence shape (JSON round-trip) +
/// stage ordering. The engines that DRIVE stage transitions arrive in M3
/// (diagnostic seeds initial stages) and M6 (session evidence); nothing here
/// mutates app state on its own.
///
/// This file is pure Dart (no Flutter imports) so the whole spine stays
/// unit-testable without a widget binding.
library;

import 'package:equatable/equatable.dart';

/// Lifecycle stage of one concept for one learner.
///
/// Ordered by [index]; the implicit zero stage is "no evidence yet" and is
/// deliberately NOT part of the brief's seven-stage ladder — an absent
/// [ConceptMastery] record means "never started", so empty learners carry
/// no data at all.
enum MasteryStage {
  introduced,
  practiced,
  understood,
  recalled,
  applied,
  mastered,
  maintained;

  /// True when this stage is at or beyond [other].
  bool isAtLeast(MasteryStage other) => index >= other.index;

  /// The next stage in the ladder, or `null` when already [maintained].
  MasteryStage? get next => index >= MasteryStage.maintained.index
      ? null
      : MasteryStage.values[index + 1];

  /// Parses a persisted stage name; unknown values degrade to `null`
  /// (never throw — corrupt storage must not crash Learn Mode).
  static MasteryStage? tryParse(String? name) {
    if (name == null) return null;
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// The default stage a concept must reach before it counts as "mastered"
/// for milestone/mastery-check purposes (end of the Master Brief §19 ladder).
///
/// M6 makes this configurable per concept; M1 pins one honest default.
const MasteryStage kDefaultMasteryCriteriaStage = MasteryStage.mastered;

/// One concept's mastery for one learner.
///
/// [strength] is a 0..1 confidence signal derived from REAL evidence
/// (correct/attempt counters). It never fabricates: a concept with no
/// evidence has no [ConceptMastery] record at all.
class ConceptMastery extends Equatable {
  const ConceptMastery({
    required this.conceptId,
    required this.stage,
    this.strength = 0,
    this.correctCount = 0,
    this.attemptCount = 0,
    this.lastPracticedAt,
    this.reviewDueAt,
  });

  /// Concept this record belongs to (matches [LearnConcept.id]).
  final String conceptId;

  /// Current lifecycle stage.
  final MasteryStage stage;

  /// 0..1 evidence-backed confidence. Values outside the range are
  /// rejected at construction time via [clampStrength].
  final double strength;

  /// Total correct responses recorded for this concept.
  final int correctCount;

  /// Total responses recorded for this concept (correct + wrong).
  final int attemptCount;

  /// Last time the learner practised this concept (null = never directly).
  final DateTime? lastPracticedAt;

  /// When the review queue should surface this concept next
  /// (null = not scheduled; M6 fills this).
  final DateTime? reviewDueAt;

  /// Clamps a raw strength value into the valid 0..1 range.
  static double clampStrength(double raw) => raw.clamp(0.0, 1.0).toDouble();

  ConceptMastery copyWith({
    String? conceptId,
    MasteryStage? stage,
    double? strength,
    int? correctCount,
    int? attemptCount,
    DateTime? lastPracticedAt,
    DateTime? reviewDueAt,
    bool clearReviewDueAt = false,
  }) {
    return ConceptMastery(
      conceptId: conceptId ?? this.conceptId,
      stage: stage ?? this.stage,
      strength: strength ?? this.strength,
      correctCount: correctCount ?? this.correctCount,
      attemptCount: attemptCount ?? this.attemptCount,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      reviewDueAt: clearReviewDueAt ? null : (reviewDueAt ?? this.reviewDueAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'stage': stage.name,
        'strength': strength,
        'correctCount': correctCount,
        'attemptCount': attemptCount,
        'lastPracticedAt': lastPracticedAt?.toIso8601String(),
        'reviewDueAt': reviewDueAt?.toIso8601String(),
      };

  /// Defensive deserialization: unknown stage names degrade to
  /// [MasteryStage.introduced] rather than throwing; numeric fields fall
  /// back to safe defaults.
  factory ConceptMastery.fromJson(Map<String, dynamic> json) {
    return ConceptMastery(
      conceptId: json['conceptId'] as String? ?? '',
      stage: MasteryStage.tryParse(json['stage'] as String?) ??
          MasteryStage.introduced,
      strength: ConceptMastery.clampStrength(
        (json['strength'] as num?)?.toDouble() ?? 0,
      ),
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastPracticedAt: json['lastPracticedAt'] != null
          ? DateTime.tryParse(json['lastPracticedAt'] as String)
          : null,
      reviewDueAt: json['reviewDueAt'] != null
          ? DateTime.tryParse(json['reviewDueAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        conceptId,
        stage,
        strength,
        correctCount,
        attemptCount,
        lastPracticedAt,
        reviewDueAt,
      ];
}
