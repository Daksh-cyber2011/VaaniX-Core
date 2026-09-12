/// Learn Mode 2.0 — Diagnostic model tests (M1 spine).
///
/// Pins the structured diagnostic contract: scores clamp into 0..1,
/// friendly summaries NEVER leak raw numbers (Master Brief §11), the
/// weakest-dimension derivation ignores seed-only dimensions, and the
/// JSON round-trip survives unknown dimensions without crashing.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';

DiagnosticResult _result({
  Map<DiagnosticDimension, DimensionScore> scores = const {},
  int level = 1,
  double confidence = 0.8,
}) {
  return DiagnosticResult(
    language: LearnLanguage.hindi,
    overallLevel: level,
    dimensionScores: scores,
    confidence: confidence,
    duration: const Duration(minutes: 4),
    completedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
}

void main() {
  group('DiagnosticResult', () {
    test('friendly summary never exposes raw scores', () {
      final result = _result(
        level: 1,
        scores: {
          DiagnosticDimension.vocabulary: const DimensionScore(
            dimension: DiagnosticDimension.vocabulary,
            score: 0.62,
            confidence: 0.7,
            asked: 5,
            correct: 3,
          ),
          DiagnosticDimension.sentenceFormation: const DimensionScore(
            dimension: DiagnosticDimension.sentenceFormation,
            score: 0.2,
            confidence: 0.7,
            asked: 3,
            correct: 1,
          ),
        },
      );
      final lines = result.friendlySummary();
      expect(lines, isNotEmpty);
      final all = lines.join(' ');
      expect(all.contains('0.62'), isFalse);
      expect(all.contains('0.2'), isFalse);
      expect(all, isNot(matches(RegExp(r'\b\d+\.\d+'))));
      expect(all, contains('Beginner'));
      expect(all, contains('sentence building'));
    });

    test('weakest dimension ignores seed-only (asked == 0) entries', () {
      final result = _result(scores: {
        DiagnosticDimension.vocabulary: const DimensionScore(
          dimension: DiagnosticDimension.vocabulary,
          score: 0.9,
          confidence: 0.4,
          asked: 2,
          correct: 2,
        ),
        // Seeded estimate only — no real probes yet:
        DiagnosticDimension.listening: const DimensionScore(
          dimension: DiagnosticDimension.listening,
          score: 0.0,
          confidence: 0.0,
        ),
      });
      expect(result.weakestDimension, DiagnosticDimension.vocabulary,
          reason: 'the seed-only listening estimate (asked == 0) must be '
              'ignored — the weakest MEASURED dimension wins');
    });

    test('weakest dimension picks the lowest MEASURED score', () {
      final result = _result(scores: {
        DiagnosticDimension.vocabulary: const DimensionScore(
          dimension: DiagnosticDimension.vocabulary,
          score: 0.8,
          confidence: 0.9,
          asked: 4,
          correct: 4,
        ),
        DiagnosticDimension.grammar: const DimensionScore(
          dimension: DiagnosticDimension.grammar,
          score: 0.3,
          confidence: 0.9,
          asked: 4,
          correct: 1,
        ),
      });
      expect(result.weakestDimension, DiagnosticDimension.grammar);
    });

    test('scores are clamped into 0..1 on construction paths', () {
      final clamped = DimensionScore(
        dimension: DiagnosticDimension.reading,
        score: DimensionScore.clamp01(2.5),
        confidence: DimensionScore.clamp01(-1),
      );
      expect(clamped.score, 1.0);
      expect(clamped.confidence, 0.0);
    });

    test('JSON round-trip preserves everything meaningful', () {
      final result = _result(
        level: 3,
        confidence: 0.66,
        scores: {
          DiagnosticDimension.script: const DimensionScore(
            dimension: DiagnosticDimension.script,
            score: 0.8,
            confidence: 0.9,
            asked: 5,
            correct: 4,
          ),
        },
      );
      final restored = DiagnosticResult.fromJson(result.toJson());
      expect(restored.language, LearnLanguage.hindi);
      expect(restored.overallLevel, 3);
      expect(restored.confidence, closeTo(0.66, 1e-9));
      expect(
        restored.dimensionScores[DiagnosticDimension.script]!.score,
        closeTo(0.8, 1e-9),
      );
    });

    test('unknown language / dimension / level in JSON never crash', () {
      final parsed = DiagnosticResult.fromJson({
        'language': 'klingon',
        'overallLevel': 99,
        'confidence': 5,
        'dimensionScores': {
          'telepathy': {'score': 1, 'confidence': 1},
          'vocabulary': {'score': 0.5, 'confidence': 0.5, 'asked': 2,
              'correct': 1},
        },
      });
      expect(parsed.language, LearnLanguage.hindi); // fallback
      expect(parsed.overallLevel, 4); // clamped
      expect(parsed.confidence, 1.0); // clamped
      expect(parsed.dimensionScores.length, 1); // unknown dimension dropped
      expect(
        parsed.dimensionScores[DiagnosticDimension.vocabulary],
        isNotNull,
      );
    });
  });

  group('DiagnosticProbe', () {
    test('carries dimension + difficulty + concept linkage', () {
      const probe = DiagnosticProbe(
        id: 'probe-1',
        dimension: DiagnosticDimension.script,
        difficulty: Difficulty.beginner,
        conceptId: 'hi_ls_1',
      );
      expect(probe.dimension, DiagnosticDimension.script);
      expect(probe.difficulty, Difficulty.beginner);
      expect(probe.conceptId, 'hi_ls_1');
    });
  });
}
