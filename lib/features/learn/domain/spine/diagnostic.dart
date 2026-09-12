/// Learn Mode 2.0 — Diagnostic Model (M1 Architecture Spine)
///
/// The structured result contract of the adaptive placement test
/// (Master Brief §11/§12). The diagnostic FLOW itself (VAN-led, game-like,
/// difficulty-adaptive) arrives in M3; M1 locks the shape everything else
/// will consume:
///
/// - planners read [DiagnosticResult] as structured input (Master Brief §13);
/// - the UI renders [DiagnosticResult.friendlySummary] — raw internal
///   scores are NEVER exposed (Master Brief §11);
/// - [DiagnosticProbe] is the trusted-seed descriptor M3's item selector
///   fills from real curriculum/exercise banks.
///
/// Only dimensions the app can actually test are declared — no fabricated
/// listening scores when no audio exists (Master Brief §11).
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Skill dimensions the diagnostic can assess.
enum DiagnosticDimension {
  script('script recognition'),
  vocabulary('vocabulary'),
  grammar('grammar'),
  reading('reading'),
  comprehension('comprehension'),
  sentenceFormation('sentence building'),
  practical('practical language'),
  listening('listening');

  const DiagnosticDimension(this.label);

  /// Human-readable name used inside friendly summaries.
  final String label;

  static DiagnosticDimension? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}

/// Score of one dimension: fraction correct + how sure the adaptive
/// engine is about that estimate (both 0..1).
class DimensionScore extends Equatable {
  const DimensionScore({
    required this.dimension,
    required this.score,
    required this.confidence,
    this.asked = 0,
    this.correct = 0,
  });

  final DiagnosticDimension dimension;

  /// 0..1 estimated ability for this dimension.
  final double score;

  /// 0..1 confidence in [score] (more probes → higher confidence).
  final double confidence;

  /// How many probes produced this score (0 = seeded estimate).
  final int asked;
  final int correct;

  DimensionScore copyWith({double? score, double? confidence}) {
    return DimensionScore(
      dimension: dimension,
      score: DimensionScore.clamp01(score ?? this.score),
      confidence: DimensionScore.clamp01(confidence ?? this.confidence),
      asked: asked,
      correct: correct,
    );
  }

  static double clamp01(double raw) => raw.clamp(0.0, 1.0).toDouble();

  Map<String, dynamic> toJson() => {
        'dimension': dimension.name,
        'score': score,
        'confidence': confidence,
        'asked': asked,
        'correct': correct,
      };

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      dimension: DiagnosticDimension.tryParse(json['dimension'] as String?) ??
          DiagnosticDimension.vocabulary,
      score: clamp01((json['score'] as num?)?.toDouble() ?? 0),
      confidence: clamp01((json['confidence'] as num?)?.toDouble() ?? 0),
      asked: (json['asked'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [dimension, score, confidence, asked, correct];
}

/// A descriptor of one probe the M3 diagnostic engine should present.
///
/// This is a SPEC, not content: the engine resolves it against trusted
/// banks (exercise ids / lesson content) when building the live test, so
/// the diagnostic can never drift from validated material.
class DiagnosticProbe extends Equatable {
  const DiagnosticProbe({
    required this.id,
    required this.dimension,
    required this.difficulty,
    this.conceptId,
  });

  final String id;
  final DiagnosticDimension dimension;
  final Difficulty difficulty;

  /// Concept the probe evaluates (drives prerequisite fallback in the
  /// adaptive strategy — Master Brief §12).
  final String? conceptId;

  @override
  List<Object?> get props => [id, dimension, difficulty, conceptId];
}

/// Structured outcome of one diagnostic run.
class DiagnosticResult extends Equatable {
  const DiagnosticResult({
    required this.language,
    required this.overallLevel,
    required this.dimensionScores,
    required this.confidence,
    required this.completedAt,
    this.duration = const Duration(),
  });

  /// Internal 0..4 level estimate (0 = starter … 4 = advanced).
  final int overallLevel;

  final LearnLanguage language;
  final Map<DiagnosticDimension, DimensionScore> dimensionScores;

  /// 0..1 overall confidence across all dimensions.
  final double confidence;

  final Duration duration;
  final DateTime completedAt;

  /// The weakest scored dimension with meaningful data (the "biggest
  /// opportunity" line), or `null` when nothing was measured.
  DiagnosticDimension? get weakestDimension {
    DiagnosticDimension? weakest;
    double weakestScore = 2.0;
    for (final entry in dimensionScores.entries) {
      if (entry.value.asked == 0) continue; // never fabricate from seeds
      if (entry.value.score < weakestScore) {
        weakestScore = entry.value.score;
        weakest = entry.key;
      }
    }
    return weakest;
  }

  /// Below this a measured dimension counts as genuinely weak for the
  /// friendly summary (Master Brief §44 — never tell a strong learner
  /// they have a "biggest opportunity").
  static const double kWeakDimensionThreshold = 0.6;

  /// The weakest dimension that is actually WEAK — measured and below
  /// [kWeakDimensionThreshold]. `null` when nothing measured is weak
  /// (e.g. a perfect run). The M1 [weakestDimension] contract stays
  /// untouched; the M3 friendly summary uses this honest variant.
  DiagnosticDimension? get weakDimension {
    DiagnosticDimension? weakest;
    double weakestScore = 2.0;
    for (final entry in dimensionScores.entries) {
      if (entry.value.asked == 0) continue; // never fabricate from seeds
      if (entry.value.score >= kWeakDimensionThreshold) continue;
      if (entry.value.score < weakestScore) {
        weakestScore = entry.value.score;
        weakest = entry.key;
      }
    }
    return weakest;
  }

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'overallLevel': overallLevel,
        'dimensionScores': {
          for (final e in dimensionScores.entries) e.key.name: e.value.toJson(),
        },
        'confidence': confidence,
        'durationMs': duration.inMilliseconds,
        'completedAt': completedAt.toIso8601String(),
      };

  factory DiagnosticResult.fromJson(Map<String, dynamic> json) {
    final language = LearnLanguage.values.firstWhere(
      (l) => l.name == (json['language'] as String?),
      orElse: () => LearnLanguage.hindi,
    );
    final rawScores = json['dimensionScores'] as Map<String, dynamic>? ?? {};
    final scores = <DiagnosticDimension, DimensionScore>{};
    for (final e in rawScores.entries) {
      final dim = DiagnosticDimension.tryParse(e.key);
      if (dim == null) continue; // unknown dimension — skip, never crash
      if (e.value is Map<String, dynamic>) {
        scores[dim] = DimensionScore.fromJson(e.value as Map<String, dynamic>);
      }
    }
    return DiagnosticResult(
      language: language,
      overallLevel: ((json['overallLevel'] as num?)?.toInt() ?? 0)
          .clamp(0, 4)
          .toInt(),
      dimensionScores: scores,
      confidence: DimensionScore.clamp01(
        (json['confidence'] as num?)?.toDouble() ?? 0,
      ),
      duration: Duration(
        milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
      ),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Friendly internal level name (Master Brief §29 wording — VaaniX
  /// internal levels, never CEFR). For display only; raw scores stay
  /// internal (Master Brief §11).
  String get levelLabel {
    const names = <String>[
      'Starter',
      'Beginner',
      'Elementary',
      'Intermediate',
      'Advanced',
    ];
    return names[overallLevel.clamp(0, 4).toInt()];
  }

  /// Friendly, human result lines (Master Brief §11 + §44 — no raw
  /// numbers, no jargon). Examples:
  ///   "You're starting around Beginner level."
  ///   "You already recognize quite a few words."
  ///   "Your biggest opportunity is sentence building."
  List<String> friendlySummary() {
    final lines = <String>[];

    final level = overallLevel.clamp(0, 4).toInt();
    if (level <= 1) {
      lines.add("You're starting around $levelLabel level.");
    } else {
      lines.add('You already have a solid $levelLabel foundation.');
    }

    final vocab = dimensionScores[DiagnosticDimension.vocabulary];
    if (vocab != null && vocab.asked > 0 && vocab.score >= 0.5) {
      lines.add('You already recognize quite a few words.');
    }

    final weakest = weakDimension;
    if (weakest != null) {
      final headline = <DiagnosticDimension, String>{
        DiagnosticDimension.script: 'the script itself',
        DiagnosticDimension.vocabulary: 'building your vocabulary',
        DiagnosticDimension.grammar: 'how sentences fit together',
        DiagnosticDimension.reading: 'reading flow',
        DiagnosticDimension.comprehension: 'understanding what you hear '
            'and read',
        DiagnosticDimension.sentenceFormation: 'sentence building',
        DiagnosticDimension.practical: 'everyday phrases',
        DiagnosticDimension.listening: 'listening practice',
      }[weakest];
      lines.add('Your biggest opportunity is $headline.');
    }

    return lines;
  }

  @override
  List<Object?> get props =>
      [language, overallLevel, dimensionScores, confidence, duration,
       completedAt];
}
