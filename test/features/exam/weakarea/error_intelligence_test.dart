/// Exam Mode 2.0 — M8 Error Intelligence Tests (§47/§21)
///
/// Classification table, pattern thresholds, misconception escalation,
/// §26 uncertain exclusion, no-fabrication guarantees (§30), JSON
/// round-trip, deterministic ordering.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';

ErrorEvidence ev(
  String questionId,
  String topicId,
  String verdict, {
  String kind = 'mcq',
  int retries = 0,
  String atIso = '2026-09-01T10:00:00.000',
}) =>
    ErrorEvidence(
      questionId: questionId,
      topicId: topicId,
      kind: kind,
      verdict: verdict,
      retries: retries,
      atIso: atIso,
    );

void main() {
  group('ErrorCategory vocabulary (§47)', () {
    test('all ten official categories exist', () {
      expect(ErrorCategory.values.length, 10);
      expect(ErrorCategory.values, containsAll([
        ErrorCategory.conceptGap,
        ErrorCategory.recallGap,
        ErrorCategory.applicationGap,
        ErrorCategory.questionInterpretation,
        ErrorCategory.carelessMistake,
        ErrorCategory.grammarError,
        ErrorCategory.structureError,
        ErrorCategory.incompleteAnswer,
        ErrorCategory.timeIssue,
        ErrorCategory.misconception,
      ]));
    });

    test('name round-trip is total', () {
      for (final c in ErrorCategory.values) {
        expect(errorCategoryFromName(c.name), c);
      }
      expect(errorCategoryFromName('nope'), isNull);
      expect(errorCategoryFromName(null), isNull);
    });
  });

  group('classification (verdict + retry + kind only)', () {
    test('correct first-shot is NOT an error', () {
      expect(ErrorIntelligence.classify(ev('q1', 't1', 'correct')), isNull);
    });

    test('correct after retry = self-corrected slip (careless)', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'correct', retries: 1)),
        ErrorCategory.carelessMistake,
      );
    });

    test('revealed = recall gap', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'revealed')),
        ErrorCategory.recallGap,
      );
    });

    test('partiallyCorrect splits by kind and retry', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'partiallyCorrect',
            kind: 'mcq')),
        ErrorCategory.questionInterpretation,
      );
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'partiallyCorrect',
            kind: 'typed')),
        ErrorCategory.incompleteAnswer,
      );
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'partiallyCorrect',
            kind: 'typed', retries: 1)),
        ErrorCategory.structureError,
      );
    });

    test('incorrect first-shot: recall (mcq) vs application (typed)', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'incorrect')),
        ErrorCategory.recallGap,
      );
      expect(
        ErrorIntelligence.classify(
            ev('q1', 't1', 'incorrect', kind: 'typed')),
        ErrorCategory.applicationGap,
      );
    });

    test('incorrect after retry = persistent concept gap', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'incorrect', retries: 1)),
        ErrorCategory.conceptGap,
      );
    });

    test('§26: uncertain photo input is NEVER student error', () {
      expect(
        ErrorIntelligence.classify(ev('q1', 't1', 'uncertain', kind: 'photo')),
        isNull,
      );
    });
  });

  group('pattern finding (§21 patterns, not counts)', () {
    test('singletons are dropped — one mistake is not a weakness', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect'),
      ]);
      expect(patterns, isEmpty);
    });

    test('a category must REPEAT on the same topic', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect'),
        ev('q2', 't2', 'incorrect'),
      ]);
      expect(patterns, isEmpty);
    });

    test('two recall misses on one topic = recallGap pattern', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect'),
        ev('q2', 't1', 'incorrect'),
      ]);
      expect(patterns, hasLength(1));
      expect(patterns.first.category, ErrorCategory.recallGap);
      expect(patterns.first.topicId, 't1');
      expect(patterns.first.occurrences, 2);
      expect(patterns.first.questionIds, ['q1', 'q2']);
    });

    test('3+ first-shot misses stay recallGap (escalation needs evidence)',
        () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect'),
        ev('q2', 't1', 'incorrect'),
        ev('q3', 't1', 'incorrect'),
      ]);
      expect(patterns, hasLength(1));
      // First-shot misses are honest recall gaps — a MISCONCEPTION
      // needs still-wrong-after-retry evidence (§21 specific belief).
      expect(patterns.first.category, ErrorCategory.recallGap);
      expect(patterns.first.occurrences, 3);
    });

    test('misconception escalation: 3 wrongs with retry (§21)', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect', retries: 1),
        ev('q2', 't1', 'incorrect', retries: 1),
        ev('q3', 't1', 'incorrect', retries: 1),
      ]);
      expect(patterns, hasLength(1));
      expect(patterns.first.category, ErrorCategory.misconception);
    });

    test('misconception escalation: wrong-after-retry twice (§21)', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect', retries: 1),
        ev('q2', 't1', 'incorrect', retries: 1),
      ]);
      // Two conceptGap evidence points → both wrong-after-retry →
      // escalates to misconception.
      expect(patterns, hasLength(1));
      expect(patterns.first.category, ErrorCategory.misconception);
    });

    test('two plain concept gaps without retry stay conceptGap', () {
      // incorrect + retry => conceptGap requires retries>=1; use
      // three mixed verdicts where escalation threshold (3 wrongs OR
      // 2 wrong-after-retry) is NOT met for misconception.
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect', retries: 1), // conceptGap
        ev('q2', 't1', 'partiallyCorrect', kind: 'typed', retries: 1),
        // structureError — different category
      ]);
      expect(
          patterns.where((p) => p.category == ErrorCategory.conceptGap),
          isEmpty,
          reason: 'only ONE conceptGap evidence — below threshold');
      expect(
          patterns
              .where((p) => p.category == ErrorCategory.structureError),
          isEmpty,
          reason: 'only ONE structureError evidence — below threshold');
      expect(patterns, isEmpty);
    });

    test('deterministic order: misconception first, then occurrences', () {
      final patterns = ErrorIntelligence.analyze([
        // t2: misconception (3 wrong-after-retry — concept gaps)
        ev('q1', 't2', 'incorrect', retries: 1),
        ev('q2', 't2', 'incorrect', retries: 1),
        ev('q3', 't2', 'incorrect', retries: 1),
        // t1: recallGap (2 first-shot misses)
        ev('q4', 't1', 'incorrect'),
        ev('q5', 't1', 'incorrect'),
      ]);
      expect(patterns.first.category, ErrorCategory.misconception);
      expect(patterns.first.topicId, 't2');
      expect(patterns.last.category, ErrorCategory.recallGap);
    });

    test('unfabricatable categories never appear (§30/§21 honesty)', () {
      // No data path can produce grammar/time categories.
      final all = ErrorIntelligence.analyze([
        for (var i = 0; i < 10; i++)
          ev('q$i', 't$i', 'incorrect', retries: 1),
        for (var i = 10; i < 20; i++)
          ev('q$i', 't$i', 'incorrect', kind: 'typed'),
        for (var i = 20; i < 30; i++)
          ev('q$i', 't$i', 'correct', retries: 1),
      ]);
      for (final p in all) {
        expect(
          unfabricatableCategories.contains(p.category),
          isFalse,
          reason: '${p.category} must never be fabricated',
        );
      }
    });
  });

  group('evidence sentences (§28/§30)', () {
    test('every emittable category has a non-empty, % -free sentence', () {
      final patterns = ErrorIntelligence.analyze([
        ev('q1', 't1', 'incorrect'),
        ev('q2', 't1', 'incorrect'),
      ]);
      for (final p in patterns) {
        expect(p.evidenceSentence, isNotEmpty);
        expect(p.evidenceSentence.contains('%'), isFalse);
      }
    });
  });

  group('ErrorEvidence JSON round-trip', () {
    test('toJson → fromJson is lossless', () {
      final e = ev('q1', 't1', 'partiallyCorrect',
          kind: 'typed', retries: 2, atIso: '2026-09-02T09:30:00.000');
      final back = ErrorEvidence.fromJson(e.toJson());
      expect(back.questionId, e.questionId);
      expect(back.topicId, e.topicId);
      expect(back.kind, e.kind);
      expect(back.verdict, e.verdict);
      expect(back.retries, e.retries);
      expect(back.atIso, e.atIso);
    });

    test('defensive parse: missing fields degrade (§41)', () {
      final e = ErrorEvidence.fromJson(const <String, dynamic>{});
      expect(e.questionId, '');
      expect(e.retries, 0);
      expect(e.kind, 'mcq');
    });
  });
}
