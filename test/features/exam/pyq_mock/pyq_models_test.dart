/// Exam Mode 2.0 — M9 PYQ Model Tests (§25 provenance, §30 bands)
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

PracticeQuestion baseQ(String id) => PracticeQuestion(
      id: id,
      topicId: 'cbse_10_sanskrit_a',
      topicTitle: 'A',
      kind: PracticeQuestionKind.mcq,
      prompt: 'p',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
    );

PyqQuestion q(
  String id, {
  PyqProvenance provenance = PyqProvenance.examPattern,
  double marks = 1,
  String pattern = 'अतिलघूत्तरात्मकौ 2×1',
  String? year,
}) =>
    PyqQuestion(
      question: baseQ(id),
      provenance: provenance,
      patternText: pattern,
      marks: marks,
      officialYear: year,
    );

void main() {
  group('§25 provenance labels', () {
    test('only registry items are official', () {
      expect(PyqProvenance.official.isOfficial, isTrue);
      expect(PyqProvenance.examPattern.isOfficial, isFalse);
      expect(PyqProvenance.pyqStyle.isOfficial, isFalse);
    });

    test('generated labels NEVER claim to be actual CBSE PYQs', () {
      // The §25 honesty rule: the words "आधिकारिक CBSE" appear ONLY
      // on the official (registry) label.
      expect(PyqProvenance.pyqStyle.label.contains('CBSE'), isFalse);
      expect(PyqProvenance.examPattern.label.contains('CBSE'), isFalse);
      expect(PyqProvenance.official.label.contains('CBSE'), isTrue);
      expect(PyqProvenance.pyqStyle.label, isNotEmpty);
      expect(PyqProvenance.examPattern.label, isNotEmpty);
    });

    test('name round-trip', () {
      for (final p in PyqProvenance.values) {
        expect(pyqProvenanceFromName(p.name), p);
      }
      expect(pyqProvenanceFromName('bogus'), PyqProvenance.pyqStyle);
      expect(pyqProvenanceFromName(null), PyqProvenance.pyqStyle);
    });
  });

  group('identityLine (§25 visible identity)', () {
    test('pattern + marks always shown', () {
      final line = q('pyq_a_0', marks: 2).identityLine;
      expect(line.contains('अतिलघूत्तरात्मकौ 2×1'), isTrue);
      expect(line.contains('2 अंक'), isTrue);
    });

    test('half marks render without a trailing .0', () {
      expect(q('x', marks: 0.5).identityLine.contains('0.5 अंक'), isTrue);
      expect(q('x', marks: 1).identityLine.contains('1 अंक'), isTrue);
    });

    test('official items append year/source (§25 preserved fields)', () {
      final line = q('o1', provenance: PyqProvenance.official, year: '2024')
          .identityLine;
      expect(line.contains('2024'), isTrue);
    });
  });

  group('PyqFilter (§25 filtering)', () {
    test('empty filter matches everything', () {
      const filter = PyqFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(q('x'), 'sec1'), isTrue);
    });

    test('section / topic / marks / pattern criteria (AND)', () {
      const filter = PyqFilter(
        sectionIds: {'sec1'},
        topicIds: {'cbse_10_sanskrit_a'},
        minMarks: 1,
        maxMarks: 3,
        patternKinds: {'अतिलघूत्तरात्मक'},
      );
      expect(filter.matches(q('x', marks: 2), 'sec1'), isTrue);
      expect(filter.matches(q('x', marks: 2), 'sec2'), isFalse);
      expect(filter.matches(q('x', marks: 5), 'sec1'), isFalse);
      expect(
        filter.matches(
            q('x', marks: 2, pattern: 'पूर्णवाक्यात्मक 3×2'), 'sec1'),
        isFalse,
      );
      expect(filter.matches(q('x', marks: 2, pattern: 'MCQ 1×2'), 'sec1'),
          isFalse,
          reason: 'MCQ pattern kind excluded by typed marker');
    });
  });

  group('PyqTopicPerformance (§21 pyqPerformance, §30 bands)', () {
    test('no evidence below 2 attempts → learning band, honestly', () {
      const p = PyqTopicPerformance(topicId: 't', attempted: 1, correct: 0);
      expect(p.hasEvidence, isFalse);
      expect(p.band, 'learning');
    });

    test('band ladder: weak / building / strong', () {
      const weak = PyqTopicPerformance(topicId: 't', attempted: 5, correct: 1);
      const mid = PyqTopicPerformance(topicId: 't', attempted: 5, correct: 3);
      const strong = PyqTopicPerformance(topicId: 't', attempted: 5, correct: 4);
      expect(weak.band, 'needsAttention');
      expect(mid.band, 'learning');
      expect(strong.band, 'strong');
    });

    test('merge accumulates evidence', () {
      const a = PyqTopicPerformance(topicId: 't', attempted: 2, correct: 1);
      const b = PyqTopicPerformance(topicId: 't', attempted: 3, correct: 1);
      expect(a.merge(b),
          const PyqTopicPerformance(topicId: 't', attempted: 5, correct: 2));
    });

    test('JSON round-trip + defensive parse', () {
      const p = PyqTopicPerformance(topicId: 't', attempted: 4, correct: 3);
      final back = PyqTopicPerformance.fromJson(p.toJson());
      expect(back.attempted, 4);
      expect(back.correct, 3);
      final empty = PyqTopicPerformance.fromJson(const {});
      expect(empty.topicId, '');
      expect(empty.attempted, 0);
    });
  });
}
