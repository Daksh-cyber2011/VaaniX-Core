/// Exam Mode 2.0 — M9 PYQ Bank Tests (§25/§60 grounding, real assets)
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart'
    show PracticeQuestionKind;
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_bank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CourseSyllabus syllabus;
  late ExamScopeView view;
  late ExamScopeSelection selection;

  setUpAll(() async {
    final raw = await rootBundle
        .loadString('assets/syllabus/cbse/cbse_10_sanskrit.json');
    syllabus = CourseSyllabus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    view = ExamScopeView.fromSyllabus(syllabus);
    selection = ExamScopeSelection.empty(view.trackId)
        .selectAll(view.selectableUnitIds);
  });

  test('bank is non-empty and grounded in the official syllabus (§60)', () {
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
    );
    expect(bank, isNotEmpty);
    for (final q in bank) {
      expect(selection.isSelected(q.topicId), isTrue,
          reason: 'out-of-scope topic ${q.topicId}');
      expect(q.id.startsWith('pyq_'), isTrue,
          reason: 'PYQ ids must be pyq_-prefixed');
      expect(q.question.isValid, isTrue, reason: 'invalid question ${q.id}');
    }
  });

  test('§25: NOTHING generated is labeled an actual CBSE PYQ', () {
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
    );
    for (final q in bank) {
      expect(q.provenance, isNot(PyqProvenance.official),
          reason: 'the shipped registry is empty — no official items');
      expect(q.provenance.label.contains('CBSE'), isFalse);
    }
    // And at least one examPattern item exists (structure honored).
    expect(
      bank.any((q) => q.provenance == PyqProvenance.examPattern),
      isTrue,
    );
  });

  test('pattern-derived marks honor the official marksEach (§60)', () {
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
    );
    final patternItems =
        bank.where((q) => q.provenance == PyqProvenance.examPattern).toList();
    // Cross-check against the syllabus's own pattern data.
    final officialMarks = <String, double>{};
    for (final item in syllabus.allItems) {
      for (final p in item.questionPatterns) {
        officialMarks['${item.id}_${p.pattern}'] = p.marksEach ?? 1;
      }
    }
    for (final q in patternItems) {
      expect(q.marks, greaterThanOrEqualTo(0.5));
      expect(q.marks, lessThanOrEqualTo(5));
    }
    // Some pattern text from the official data must appear verbatim.
    final officialPatterns = {
      for (final item in syllabus.allItems)
        for (final p in item.questionPatterns) p.pattern,
    };
    expect(
      patternItems.any((q) => officialPatterns.contains(q.patternText)),
      isTrue,
      reason: 'pattern labels must come verbatim from the syllabus',
    );
  });

  test('§25 filter: by section id', () {
    final sectionId = view.sections.first.id;
    final filtered = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
      filter: PyqFilter(sectionIds: {sectionId}),
    );
    final sectionUnitIds = view.sections
        .firstWhere((s) => s.id == sectionId)
        .selectableUnits
        .map((u) => u.id)
        .toSet();
    for (final q in filtered) {
      expect(sectionUnitIds.contains(q.topicId), isTrue);
    }
  });

  test('§25 filter: by pattern kind (typed patterns)', () {
    final filtered = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
      filter: const PyqFilter(patternKinds: {'पूर्णवाक्यात्मक'}),
    );
    for (final q in filtered) {
      expect(q.patternText.contains('पूर्णवाक्यात्मक'), isTrue);
    }
  });

  test('limit bounds the bank', () {
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
      filter: const PyqFilter(limit: 3),
    );
    expect(bank.length, lessThanOrEqualTo(3));
  });

  test('typed PYQ questions only where sub-topic data exists (§24/§60)', () {
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: view,
      selection: selection,
    );
    for (final q in bank) {
      if (q.question.kind == PracticeQuestionKind.shortAnswer) {
        expect(q.question.acceptedAnswers, isNotEmpty);
        expect(q.question.requiredPoints, isNotEmpty,
            reason: 'typed PYQ needs the official rubric points');
      }
    }
  });

  test('availableSections lists only sections with PYQ data', () {
    final sections = PyqBank.availableSections(
      syllabus: syllabus,
      view: view,
      selection: selection,
    );
    expect(sections, isNotEmpty);
    final allSectionIds = view.sections.map((s) => s.id).toSet();
    for (final id in sections) {
      expect(allSectionIds.contains(id), isTrue);
    }
  });
}
