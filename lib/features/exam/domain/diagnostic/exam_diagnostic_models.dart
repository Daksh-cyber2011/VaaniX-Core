/// Exam Mode 2.0 — Adaptive Diagnostic Domain Models (M4, §10–§11)
///
/// The SHORT adaptive diagnostic (§10: ~5–10 minutes, feels like a
/// VaaniX challenge, never a boring exam) that runs before the
/// personalized plan is built.
///
/// What the diagnostic estimates (§10): syllabus familiarity,
/// conceptual understanding, application ability, weak and strong
/// topics — expressed as PER-TOPIC qualitative bands. What it must
/// NEVER produce (§10/§30): "You are 83% ready", fake psychological
/// scores, or any percentage.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// The skill dimension a diagnostic question probes (§10 mixture of
/// question types / dimensions).
enum DiagnosticSkill { recall, application, interpretation }

/// Difficulty tier of a diagnostic question (§11 adaptive ladder).
enum DiagnosticDifficulty { easy, medium, hard }

extension DiagnosticDifficultyX on DiagnosticDifficulty {
  int get tier => switch (this) {
        DiagnosticDifficulty.easy => 1,
        DiagnosticDifficulty.medium => 2,
        DiagnosticDifficulty.hard => 3,
      };
}

/// One diagnostic question, GROUNDED in canonical syllabus data only
/// (§60: no invented curriculum — every string comes from the official
/// syllabus JSON).
class DiagnosticQuestion extends Equatable {
  const DiagnosticQuestion({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.sectionTitle,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.skill,
  });

  final String id;

  /// Syllabus scope unit id this question probes (course-isolated).
  final String topicId;
  final String topicTitle;
  final String sectionTitle;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final DiagnosticDifficulty difficulty;
  final DiagnosticSkill skill;

  bool get isValid =>
      options.length == 4 &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      prompt.trim().isNotEmpty &&
      topicId.trim().isNotEmpty;

  @override
  List<Object?> get props =>
      [id, topicId, prompt, correctIndex, difficulty, skill];
}

/// The student's answer to one diagnostic question.
class DiagnosticResponse extends Equatable {
  const DiagnosticResponse({
    required this.questionId,
    required this.topicId,
    required this.selectedIndex,
    required this.correct,
    required this.difficulty,
    required this.skill,
    this.elapsedMs = 0,
  });

  final String questionId;
  final String topicId;
  final int selectedIndex;
  final bool correct;
  final DiagnosticDifficulty difficulty;
  final DiagnosticSkill skill;
  final int elapsedMs;

  @override
  List<Object?> get props =>
      [questionId, selectedIndex, correct, difficulty, skill];
}

/// Qualitative topic band (never numeric to the student, §30).
enum TopicBand { strong, learning, needsAttention }

extension TopicBandX on TopicBand {
  /// Student-facing qualitative sentence fragments (§10: "Strong in
  /// literature recall." style observations).
  String get label => switch (this) {
        TopicBand.strong => 'मज़बूत',
        TopicBand.learning => 'सीख रहे हैं',
        TopicBand.needsAttention => 'ध्यान चाहिए',
      };
}

/// One topic's estimate after the diagnostic.
class TopicEstimate extends Equatable {
  const TopicEstimate({
    required this.topicId,
    required this.topicTitle,
    required this.sectionTitle,
    required this.attempts,
    required this.correct,
    required this.band,
  });

  final String topicId;
  final String topicTitle;
  final String sectionTitle;
  final int attempts;
  final int correct;

  /// Qualitative band — the student-facing estimate (§30).
  final TopicBand band;

  @override
  List<Object?> get props => [topicId, attempts, correct, band];
}

/// The final diagnostic report (§10: meaningful observations).
class DiagnosticReport extends Equatable {
  const DiagnosticReport({
    required this.trackId,
    required this.completedAtIso,
    required this.responses,
    required this.topicEstimates,
    required this.overallBand,
    required this.observations,
  });

  final String trackId;
  final String completedAtIso;
  final List<DiagnosticResponse> responses;
  final List<TopicEstimate> topicEstimates;

  /// Qualitative overall band (strong / learning / needsAttention).
  final TopicBand overallBand;

  /// Student-facing qualitative observations, e.g. "साहित्य recall मज़बूत
  /// है।" — specific, never percentages (§10/§30).
  final List<String> observations;

  Map<String, ({int attempts, int correct})> get estimatePairs => {
        for (final e in topicEstimates)
          e.topicId: (attempts: e.attempts, correct: e.correct),
      };

  @override
  List<Object?> get props => [trackId, responses, topicEstimates, overallBand];
}
