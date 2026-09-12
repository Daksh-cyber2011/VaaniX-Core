/// Exam Mode 2.0 — Exam Learner Profile Domain (M4, master plan §12/§29)
///
/// The persistent, evidence-driven LEARNER EXAM PROFILE for one track:
/// per-topic mastery built from REAL performance (diagnostic responses,
/// practice attempts), never from "lesson completed" flags.
///
/// Mastery rules (§29):
///  * topic-specific — one record per syllabus scope unit;
///  * evidence-driven — accuracy + repeated performance + application;
///  * student-facing language is QUALITATIVE: Learning / Practicing /
///    Strong / Mastered / Needs Review / Needs Attention. Internal
///    numeric strength exists for the engines only and is NEVER shown
///    as a percentage (§30).
///
/// Persistence: JSON round-trip with defensive parsing (§41/§57) —
/// corrupt entries degrade, they never crash.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// Student-facing mastery stage (§29 vocabulary — exact words).
enum TopicStage {
  learning,
  practicing,
  strong,
  mastered,
  needsReview,
  needsAttention,
}

TopicStage _stageFromName(String? name) => switch (name) {
      'practicing' => TopicStage.practicing,
      'strong' => TopicStage.strong,
      'mastered' => TopicStage.mastered,
      'needsReview' => TopicStage.needsReview,
      'needsAttention' => TopicStage.needsAttention,
      _ => TopicStage.learning,
    };

/// One topic's evidence-backed mastery (§29).
class TopicMastery extends Equatable {
  const TopicMastery({
    required this.topicId,
    required this.stage,
    this.strength = 0,
    this.correctCount = 0,
    this.attemptCount = 0,
    this.lastPracticedAtIso = '',
  });

  /// Strength EWMA decay: recent performance shapes the estimate, but
  /// history is not erased by one bad day (§29 "repeated performance").
  static const double _ewmaAlpha = 0.4;

  final String topicId;
  final TopicStage stage;

  /// 0..1 internal confidence. Engine-only; never student-facing (§30).
  final double strength;
  final int correctCount;
  final int attemptCount;
  final String lastPracticedAtIso;

  bool get hasEvidence => attemptCount > 0;

  /// Records one graded attempt and recomputes the stage.
  TopicMastery applyAttempt({required bool correct}) {
    final newCorrect = correctCount + (correct ? 1 : 0);
    final newAttempt = attemptCount + 1;
    final target = correct ? 1.0 : 0.0;
    final next = attemptCount == 0
        ? target
        : (strength * (1 - _ewmaAlpha)) + (target * _ewmaAlpha);
    return TopicMastery(
      topicId: topicId,
      strength: next.clamp(0.0, 1.0).toDouble(),
      correctCount: newCorrect,
      attemptCount: newAttempt,
      stage: _stageFor(
          strength: next.clamp(0.0, 1.0).toDouble(),
          attempts: newAttempt,
          correct: newCorrect),
      lastPracticedAtIso: DateTime.now().toIso8601String(),
    );
  }

  /// Evidence-driven stage ladder (§29):
  ///  * no accuracy floor reached → Needs Attention / Learning;
  ///  * sustained accuracy across enough attempts → Practicing → Strong;
  ///  * accuracy PLUS volume → Mastered;
  ///  * decayed strength after once being strong → Needs Review.
  static TopicStage _stageFor({
    required double strength,
    required int attempts,
    required int correct,
  }) {
    final accuracy = attempts == 0 ? 0.0 : correct / attempts;
    if (attempts < 2) {
      return accuracy >= 0.5 ? TopicStage.learning : TopicStage.learning;
    }
    if (accuracy < 0.4) return TopicStage.needsAttention;
    if (strength >= 0.8 && attempts >= 8 && accuracy >= 0.8) {
      return TopicStage.mastered;
    }
    if (strength >= 0.65 && accuracy >= 0.6) return TopicStage.strong;
    if (accuracy >= 0.5) return TopicStage.practicing;
    return TopicStage.learning;
  }

  TopicMastery copyWith({
    TopicStage? stage,
    double? strength,
    int? correctCount,
    int? attemptCount,
    String? lastPracticedAtIso,
  }) =>
      TopicMastery(
        topicId: topicId,
        stage: stage ?? this.stage,
        strength: strength ?? this.strength,
        correctCount: correctCount ?? this.correctCount,
        attemptCount: attemptCount ?? this.attemptCount,
        lastPracticedAtIso: lastPracticedAtIso ?? this.lastPracticedAtIso,
      );

  factory TopicMastery.fromJson(Map<String, dynamic> json) => TopicMastery(
        topicId: json['topicId'] as String? ?? '',
        stage: _stageFromName(json['stage'] as String?),
        strength: (json['strength'] as num?)?.toDouble() ?? 0,
        correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        lastPracticedAtIso: json['lastPracticedAtIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'stage': stage.name,
        'strength': strength,
        'correctCount': correctCount,
        'attemptCount': attemptCount,
        'lastPracticedAtIso': lastPracticedAtIso,
      };

  @override
  List<Object?> get props =>
      [topicId, stage, strength, correctCount, attemptCount];
}

/// The learner's exam profile for one track (§12).
class ExamLearnerProfile extends Equatable {
  const ExamLearnerProfile({
    required this.trackId,
    required this.topics,
    this.diagnosticCompletedAtIso = '',
    this.diagnosticOverallBand = '',
    this.schemaVersion = currentSchemaVersion,
    this.updatedAtIso = '',
  });

  static const int currentSchemaVersion = 1;

  /// Overall qualitative diagnostic band: strong / learning /
  /// needsAttention (never a percentage, §30).
  static const Set<String> knownBands = {'strong', 'learning', 'needsAttention'};

  final String trackId;

  /// topicId → mastery. Absent record = "never started" (no fabrication).
  final Map<String, TopicMastery> topics;

  final String diagnosticCompletedAtIso;
  final String diagnosticOverallBand;
  final int schemaVersion;
  final String updatedAtIso;

  static ExamLearnerProfile empty(String trackId) => ExamLearnerProfile(
        trackId: trackId,
        topics: const {},
      );

  bool get hasDiagnostic => diagnosticCompletedAtIso.isNotEmpty;

  /// Weakest topics first (Needs Attention → decayed → low strength) —
  /// the priority order the M5 deterministic planner follows.
  List<TopicMastery> weakTopicsFirst({int limit = 20}) {
    final list = topics.values.where((t) => t.attemptCount > 0).toList()
      ..sort((a, b) {
        int rank(TopicMastery t) => switch (t.stage) {
              TopicStage.needsAttention => 0,
              TopicStage.needsReview => 1,
              TopicStage.learning => 2,
              TopicStage.practicing => 3,
              TopicStage.strong => 4,
              TopicStage.mastered => 5,
            };
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return a.strength.compareTo(b.strength);
      });
    return list.take(limit).toList();
  }

  /// Records one graded attempt on a topic (M6 practice loop).
  ExamLearnerProfile recordAttempt({
    required String topicId,
    required bool correct,
  }) {
    final current = topics[topicId] ??
        TopicMastery(topicId: topicId, stage: TopicStage.learning);
    final next = current.applyAttempt(correct: correct);
    return ExamLearnerProfile(
      trackId: trackId,
      topics: {...topics, topicId: next},
      diagnosticCompletedAtIso: diagnosticCompletedAtIso,
      diagnosticOverallBand: diagnosticOverallBand,
      schemaVersion: schemaVersion,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  /// Seeds/merges topic estimates from a diagnostic report (M4).
  /// Diagnostic evidence counts as ONE attempt per topic estimate —
  /// real later practice can move the estimate either way.
  ExamLearnerProfile mergeDiagnosticEstimates(
      Map<String, ({int attempts, int correct})> estimates) {
    final next = {...topics};
    estimates.forEach((topicId, e) {
      final current = next[topicId] ??
          TopicMastery(topicId: topicId, stage: TopicStage.learning);
      var merged = current;
      for (var i = 0; i < e.attempts; i++) {
        merged = merged.applyAttempt(correct: i < e.correct);
      }
      next[topicId] = merged;
    });
    return ExamLearnerProfile(
      trackId: trackId,
      topics: next,
      diagnosticCompletedAtIso: DateTime.now().toIso8601String(),
      diagnosticOverallBand: diagnosticOverallBand,
      schemaVersion: schemaVersion,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  factory ExamLearnerProfile.fromJson(Map<String, dynamic> json) {
    final topicsJson =
        (json['topics'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final topics = <String, TopicMastery>{};
    topicsJson.forEach((id, value) {
      try {
        topics[id] = TopicMastery.fromJson(
            (value as Map<String, dynamic>).cast<String, dynamic>());
      } catch (_) {
        // Corrupt single entry — skip, keep the rest (§41).
      }
    });
    final band = json['diagnosticOverallBand'] as String? ?? '';
    return ExamLearnerProfile(
      trackId: json['trackId'] as String? ?? '',
      topics: topics,
      diagnosticCompletedAtIso:
          json['diagnosticCompletedAtIso'] as String? ?? '',
      diagnosticOverallBand:
          knownBands.contains(band) ? band : '',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      updatedAtIso: json['updatedAtIso'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'trackId': trackId,
        'topics': {
          for (final e in topics.entries) e.key: e.value.toJson(),
        },
        'diagnosticCompletedAtIso': diagnosticCompletedAtIso,
        'diagnosticOverallBand': diagnosticOverallBand,
        'updatedAtIso': updatedAtIso,
      };

  @override
  List<Object?> get props => [trackId, topics, diagnosticCompletedAtIso];
}
