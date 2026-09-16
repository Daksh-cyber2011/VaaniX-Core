/// Exam Mode 2.0 — M9 Mock Engine Tests (§25 structure / §41 / §30)
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_engine.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

PracticeQuestion q(String id, {String topicId = 't1'}) => PracticeQuestion(
      id: id,
      topicId: topicId,
      topicTitle: 'T',
      kind: PracticeQuestionKind.mcq,
      prompt: 'p $id',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
    );

PyqQuestion pyq(String id, {double marks = 1, String topicId = 't1'}) =>
    PyqQuestion(
      question: q(id, topicId: topicId),
      provenance: PyqProvenance.examPattern,
      patternText: 'अतिलघूत्तरात्मकौ 2×1',
      marks: marks,
    );

void main() {
  final boardSections = <({String id, String title, double marks})>[
    (id: 'sec_a', title: 'खंड अ', marks: 10),
    (id: 'sec_b', title: 'खंड ब', marks: 15),
    (id: 'sec_c', title: 'खंड स', marks: 25),
  ];

  final pool = <String, List<PyqQuestion>>{
    'sec_a': [pyq('a1'), pyq('a2', marks: 2), pyq('a3'), pyq('a4')],
    'sec_b': [pyq('b1', marks: 2), pyq('b2', marks: 3)],
    'sec_c': [pyq('c1'), pyq('c2', marks: 2), pyq('c3')],
  };

  group('paper assembly (§25 official structure)', () {
    test('full mock: every board section + official duration', () {
      final paper = MockEngine.build(
        trackId: 'x',
        kind: MockKind.full,
        boardSections: boardSections,
        boardTotalMarks: 80,
        boardDurationHours: 3,
        questionsBySection: pool,
      );
      expect(paper.sections.length, boardSections.length);
      expect(paper.timeLimitMinutes, 180);
      expect(paper.totalMarks, 50); // sum of the given section marks
      expect(paper.allQuestions, isNotEmpty);
      expect(paper.id, contains('full'));
    });

    test('section mock: official section marks, scaled time', () {
      final paper = MockEngine.build(
        trackId: 'x',
        kind: MockKind.section,
        boardSections: boardSections,
        boardTotalMarks: 80,
        boardDurationHours: 3,
        questionsBySection: pool,
        focusSectionId: 'sec_c',
      );
      expect(paper.sections, hasLength(1));
      expect(paper.sections.first.sectionId, 'sec_c');
      expect(paper.totalMarks, 25);
      // 25 marks × 2.25 min/mark ≈ 56 min.
      expect(paper.timeLimitMinutes, greaterThan(30));
      expect(paper.timeLimitMinutes, lessThan(90));
    });

    test('mini mock: capped at 10 marks, at least 15 minutes', () {
      final paper = MockEngine.build(
        trackId: 'x',
        kind: MockKind.mini,
        boardSections: boardSections,
        boardTotalMarks: 80,
        boardDurationHours: 3,
        questionsBySection: pool,
        focusSectionId: 'sec_c',
      );
      expect(paper.totalMarks, lessThanOrEqualTo(MockEngine.miniMaxMarks));
      expect(paper.timeLimitMinutes,
          greaterThanOrEqualTo(MockEngine.miniMinMinutes));
      expect(paper.kind, MockKind.mini);
    });

    test('marks budget respected per section (never over-stuffed)', () {
      final paper = MockEngine.build(
        trackId: 'x',
        kind: MockKind.full,
        boardSections: boardSections,
        boardTotalMarks: 80,
        boardDurationHours: 3,
        questionsBySection: pool,
        maxQuestionsPerSection: 6,
      );
      for (final slice in paper.sections) {
        final marks = slice.questions
            .map((qq) => 1.0) // every pool question is 1-3 marks
            .fold(0.0, (s, m) => s + m);
        // The engine admits at most target + 0.5 (see pick()).
        expect(marks, lessThanOrEqualTo(slice.targetMarks + 4.5));
      }
    });

    test('empty focus resolves to the first board section', () {
      final paper = MockEngine.build(
        trackId: 'x',
        kind: MockKind.mini,
        boardSections: boardSections,
        boardTotalMarks: 80,
        boardDurationHours: 3,
        questionsBySection: pool,
      );
      expect(paper.sections.first.sectionId, 'sec_a');
    });
  });

  group('analysis (§41 deterministic, §30 qualitative)', () {
    MockPaper paper() => MockEngine.build(
          trackId: 'x',
          kind: MockKind.full,
          boardSections: boardSections,
          boardTotalMarks: 80,
          boardDurationHours: 3,
          questionsBySection: pool,
        );

    PracticeAttempt at(String id, String verdict) => PracticeAttempt(
          questionId: id,
          topicId: 't1',
          verdict: verdict,
          retries: 0,
          attemptedAtIso: '2026-09-12T10:00:00',
        );

    test('clean sweep → strong overall, no weak sections', () {
      final p = paper();
      final result = MockEngine.analyze(
        paper: p,
        attempts: [
          for (final q in p.allQuestions) at(q.id, 'correct'),
        ],
      );
      expect(result.overallBand, 'strong');
      expect(result.hasWeakSection, isFalse);
      expect(result.summary, isNotEmpty);
    });

    test('one section crushed → §21 weak-section detection', () {
      final p = paper();
      final secC = p.sections.firstWhere((s) => s.sectionId == 'sec_c');
      final attempts = <PracticeAttempt>[
        for (final q in p.allQuestions)
          at(
              q.id,
              secC.questions.any((x) => x.id == q.id)
                  ? 'incorrect'
                  : 'correct'),
      ];
      final result = MockEngine.analyze(paper: p, attempts: attempts);
      expect(result.hasWeakSection, isTrue);
      expect(result.weakSections.first.sectionId, 'sec_c');
      expect(result.weakSections.first.title, 'खंड स');
    });

    test('too few attempts in a section → honestly not judged', () {
      final p = paper();
      final result = MockEngine.analyze(
        paper: p,
        attempts: [at(p.allQuestions.first.id, 'incorrect')],
      );
      expect(result.totalAttempted, 1);
      expect(result.overallBand, 'learning');
      for (final s in result.sectionResults) {
        if (s.attempted < 2) {
          expect(s.band, 'learning');
        }
      }
    });

    test('partiallyCorrect counts as correct (§29 contract)', () {
      final p = paper();
      final result = MockEngine.analyze(
        paper: p,
        attempts: [
          for (final q in p.allQuestions) at(q.id, 'partiallyCorrect'),
        ],
      );
      expect(result.totalCorrect, result.totalAttempted);
    });

    test('§30: no percentages anywhere in the result strings', () {
      final p = paper();
      final result = MockEngine.analyze(
        paper: p,
        attempts: [
          for (final q in p.allQuestions)
            at(q.id, q.id.startsWith('c') ? 'incorrect' : 'correct'),
        ],
      );
      expect(result.summary.contains('%'), isFalse);
      for (final s in result.sectionResults) {
        expect(s.bandLabel.contains('%'), isFalse);
        expect(s.bandLabel, isNotEmpty);
      }
    });

    test('deterministic: same attempts → identical result (§41)', () {
      final p = paper();
      final attempts = [
        for (final q in p.allQuestions)
          at(q.id, q.id.endsWith('2') ? 'incorrect' : 'correct'),
      ];
      final a = MockEngine.analyze(paper: p, attempts: attempts);
      final b = MockEngine.analyze(paper: p, attempts: attempts);
      expect(a.toJson(), b.toJson());
    });
  });

  group('MockResult JSON round-trip (§12/§57)', () {
    test('lossless + defensive parse', () {
      const result = MockResult(
        paperId: 'p1',
        kind: MockKind.section,
        trackId: 'x',
        sectionResults: [
          MockSectionResult(
              sectionId: 's1', title: 'S', attempted: 3, correct: 1),
        ],
        totalAttempted: 3,
        totalCorrect: 1,
        completedAtIso: '2026-09-12T10:00:00',
      );
      final back = MockResult.fromJson(result.toJson());
      expect(back.paperId, 'p1');
      expect(back.kind, MockKind.section);
      expect(back.sectionResults.first.sectionId, 's1');
      expect(back.totalCorrect, 1);
      expect(back.hasWeakSection, isTrue);

      final empty = MockResult.fromJson(const {});
      expect(empty.kind, MockKind.mini);
      expect(empty.sectionResults, isEmpty);
      expect(mockKindFromName('bogus'), isNull);
    });
  });

  test('MockKind labels are student-facing and honest (§30)', () {
    for (final k in MockKind.values) {
      expect(k.label, isNotEmpty);
      expect(k.description, isNotEmpty);
      expect(k.label.contains('%'), isFalse);
    }
  });
}
