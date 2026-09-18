/// Weak-section detection thresholds (§21 / §29).
///
/// Why this file exists
/// --------------------
/// The only coverage for "the mock notices a weak section" used to live in
/// the persona-I journey simulation, whose weak section answers wrongly
/// 100% of the time. That proves the engine spots a TOTAL failure, which
/// survives almost any regression: cut the weak band from `< 0.40` to
/// `< 0.20` and a 0%-accuracy section still trips it, so the journey test
/// stays green while real weak sections stop being reported.
///
/// The journey test cannot be tightened into this role. Its correctness is
/// drawn from a deterministic hash (`hashOf(seed) % 100 < percent`) over
/// whichever question salts the generated paper happens to use, so a 15%
/// persona can legitimately land on 1-of-2 correct (50%) in a small
/// section — above the weak band — and fail for sampling reasons rather
/// than a defect. Percentage inputs to a simulation are not a threshold
/// test.
///
/// These cases pin the boundary itself, exactly and without randomness, so
/// any move of the band edges or the evidence gate fails here loudly.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';

MockSectionResult _section(
  String id, {
  required int attempted,
  required int correct,
}) =>
    MockSectionResult(
      sectionId: id,
      title: id,
      attempted: attempted,
      correct: correct,
    );

MockResult _mock(List<MockSectionResult> sections) => MockResult(
      paperId: 'p1',
      kind: MockKind.section,
      trackId: 't1',
      sectionResults: sections,
      totalAttempted: sections.fold(0, (sum, s) => sum + s.attempted),
      totalCorrect: sections.fold(0, (sum, s) => sum + s.correct),
      completedAtIso: '2026-01-01T00:00:00.000Z',
    );

void main() {
  group('MockSectionResult.band boundaries', () {
    test('below 40% accuracy is needsAttention', () {
      // 39/100 — the last value inside the weak band.
      expect(_section('s', attempted: 100, correct: 39).band, 'needsAttention');
    });

    test('exactly 40% accuracy leaves the weak band', () {
      expect(_section('s', attempted: 100, correct: 40).band, 'learning');
    });

    test('just under 60% accuracy is still learning', () {
      expect(_section('s', attempted: 100, correct: 59).band, 'learning');
    });

    test('60% accuracy and above is strong', () {
      expect(_section('s', attempted: 100, correct: 60).band, 'strong');
    });
  });

  group('evidence gate', () {
    test('a single attempt is not enough evidence to judge a section', () {
      final thin = _section('s', attempted: 1, correct: 0);
      expect(thin.hasEvidence, isFalse);
      // 0% accuracy, but too small to call weak honestly (§21).
      expect(thin.band, 'learning');
      expect(_mock([thin]).weakSections, isEmpty);
    });

    test('two attempts are enough', () {
      final thin = _section('s', attempted: 2, correct: 0);
      expect(thin.hasEvidence, isTrue);
      expect(thin.band, 'needsAttention');
    });
  });

  group('MockResult.weakSections', () {
    test('reports only the sections in the weak band', () {
      final result = _mock([
        _section('strong', attempted: 10, correct: 8),
        _section('middling', attempted: 10, correct: 5),
        _section('weak', attempted: 10, correct: 3),
      ]);

      expect(result.weakSections.map((s) => s.sectionId), ['weak']);
      expect(result.hasWeakSection, isTrue);
    });

    test('a marginally weak section is still reported', () {
      // 39% — the case a loosened threshold would silently drop, and the
      // case the 0%-accuracy journey persona cannot detect.
      final result = _mock([
        _section('marginal', attempted: 100, correct: 39),
      ]);

      expect(result.weakSections.map((s) => s.sectionId), ['marginal']);
    });

    test('no weak sections when every section has evidence and holds up', () {
      final result = _mock([
        _section('a', attempted: 10, correct: 6),
        _section('b', attempted: 10, correct: 10),
      ]);

      expect(result.weakSections, isEmpty);
      expect(result.hasWeakSection, isFalse);
    });
  });
}
