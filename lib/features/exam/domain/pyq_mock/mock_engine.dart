/// Exam Mode 2.0 — Mock Engine (M9, §25/§41)
///
/// Assembles mock papers (mini / section / full) from OFFICIAL exam
/// structure data in the canonical syllabus (§60 — no invention):
///
///  * full     → every BOARD section, official marks each, official
///               board total + duration (e.g. 80 marks / 3 hours);
///  * section  → ONE board section at its official marks, duration
///               scaled marks-proportionally (~2.25 min/mark);
///  * mini     → ONE board section capped at ~10 marks / 15 minutes —
///               the honest first rung of the ladder (never a fake
///               "full paper" shrunk);
///  * question content comes from the PYQ bank (pattern-derived,
///               grounded) so mocks and PYQ work share the §25
///               provenance discipline;
///  * [analyze] turns finished M6-loop attempts into a
///    [MockResult] — DETERMINISTIC scoring (§41: never AI), §30
///    qualitative bands, §21 weak-section detection.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

class MockEngine {
  const MockEngine._();

  /// Marks→minutes scale (board 80/180 ≈ 2.25 min per mark).
  static const double minutesPerMark = 2.25;

  /// Mini mock caps (honest small rung).
  static const double miniMaxMarks = 10;
  static const int miniMinMinutes = 15;

  /// Official board-exam minutes for a track (from syllabus data by
  /// the caller — full mocks use it verbatim).
  static int fullMockMinutes(int boardDurationHours) =>
      (boardDurationHours * 60).clamp(30, 240);

  /// Builds a mock paper of [kind] from the PYQ pool + official
  /// section structure.
  ///
  /// [boardSections] — (sectionId, title, officialMarks) for every
  /// BOARD section of the track (internal sections are never mocked).
  /// [boardTotalMarks]/[boardDurationHours] — official values.
  /// [questionsBySection] — the grounded PYQ pool, grouped by section.
  /// [focusSectionId] — required for section/mini kinds.
  static MockPaper build({
    required String trackId,
    required MockKind kind,
    required List<({String id, String title, double marks})> boardSections,
    required double boardTotalMarks,
    required int boardDurationHours,
    required Map<String, List<PyqQuestion>> questionsBySection,
    String? focusSectionId,
    int maxQuestionsPerSection = 6,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();

    List<PracticeQuestion> pick(String sectionId, double marksTarget) {
      final pool = questionsBySection[sectionId] ?? const <PyqQuestion>[];
      final out = <PracticeQuestion>[];
      var marks = 0.0;
      for (final q in pool) {
        if (out.length >= maxQuestionsPerSection) break;
        if (marks + q.marks > marksTarget + 0.5) continue;
        out.add(q.question);
        marks += q.marks;
      }
      // Pool too thin to hit the target — take what exists (honest).
      if (out.isEmpty && pool.isNotEmpty) {
        out.add(pool.first.question);
      }
      return out;
    }

    MockSectionSlice sliceOf(
      String sectionId,
      String title,
      double marks,
    ) =>
        MockSectionSlice(
          sectionId: sectionId,
          title: title,
          targetMarks: marks,
          questions: pick(sectionId, marks),
        );

    switch (kind) {
      case MockKind.full:
        final sections = [
          for (final s in boardSections)
            sliceOf(s.id, s.title, s.marks),
        ].where((s) => s.questions.isNotEmpty).toList();
        final total = sections.fold<double>(0, (sum, s) => sum + s.targetMarks);
        return MockPaper(
          id: 'mock-${trackId}-full-${t.millisecondsSinceEpoch}',
          kind: MockKind.full,
          trackId: trackId,
          sections: sections,
          totalMarks: total > 0 ? total : boardTotalMarks,
          timeLimitMinutes: fullMockMinutes(boardDurationHours),
          createdAtIso: t.toIso8601String(),
        );

      case MockKind.section:
        final focus = _resolveFocus(boardSections, focusSectionId);
        final sections = [
          sliceOf(focus.id, focus.title, focus.marks),
        ];
        return MockPaper(
          id: 'mock-${trackId}-section-${t.millisecondsSinceEpoch}',
          kind: MockKind.section,
          trackId: trackId,
          sections: sections,
          totalMarks: focus.marks,
          timeLimitMinutes:
              (focus.marks * minutesPerMark).round().clamp(10, 240),
          createdAtIso: t.toIso8601String(),
        );

      case MockKind.mini:
        final focus = _resolveFocus(boardSections, focusSectionId);
        final marks =
            focus.marks.clamp(1.0, miniMaxMarks).toDouble();
        final sections = [sliceOf(focus.id, focus.title, marks)];
        return MockPaper(
          id: 'mock-${trackId}-mini-${t.millisecondsSinceEpoch}',
          kind: MockKind.mini,
          trackId: trackId,
          sections: sections,
          totalMarks: marks,
          timeLimitMinutes: (marks * minutesPerMark)
              .round()
              .clamp(miniMinMinutes, 60),
          createdAtIso: t.toIso8601String(),
        );
    }
  }

  static ({String id, String title, double marks}) _resolveFocus(
    List<({String id, String title, double marks})> boardSections,
    String? focusSectionId,
  ) {
    if (boardSections.isEmpty) {
      return (id: '', title: '', marks: 0.0);
    }
    for (final s in boardSections) {
      if (s.id == focusSectionId) return s;
    }
    return boardSections.first;
  }

  /// Analyzes finished mock attempts into a [MockResult] — §41
  /// DETERMINISTIC (no AI anywhere in this path).
  ///
  /// [attempts] — the M6 loop's finalized PracticeAttempt list.
  /// [paper] — the paper that was run.
  static MockResult analyze({
    required MockPaper paper,
    required List<PracticeAttempt> attempts,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final questionSection = <String, String>{};
    for (final slice in paper.sections) {
      for (final q in slice.questions) {
        questionSection[q.id] = slice.sectionId;
      }
    }

    final sectionStats = <String, MockSectionResult>{};
    for (final slice in paper.sections) {
      sectionStats[slice.sectionId] = MockSectionResult(
        sectionId: slice.sectionId,
        title: slice.title,
        attempted: 0,
        correct: 0,
      );
    }
    var totalAttempted = 0;
    var totalCorrect = 0;
    for (final a in attempts) {
      totalAttempted++;
      final ok = a.verdict == 'correct' || a.verdict == 'partiallyCorrect';
      if (ok) totalCorrect++;
      final sectionId = questionSection[a.questionId] ?? '';
      final stat = sectionStats[sectionId];
      if (stat == null) continue;
      sectionStats[sectionId] = MockSectionResult(
        sectionId: stat.sectionId,
        title: stat.title,
        attempted: stat.attempted + 1,
        correct: stat.correct + (ok ? 1 : 0),
      );
    }

    return MockResult(
      paperId: paper.id,
      kind: paper.kind,
      trackId: paper.trackId,
      sectionResults: sectionStats.values.toList(),
      totalAttempted: totalAttempted,
      totalCorrect: totalCorrect,
      completedAtIso: t.toIso8601String(),
    );
  }
}
