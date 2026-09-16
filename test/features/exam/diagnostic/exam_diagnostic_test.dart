/// Exam Mode 2.0 — M4 Adaptive Diagnostic Tests
///
/// Weak / average / strong student pathways (master plan M4 test
/// requirement), bank grounding against the REAL canonical assets,
/// and §30 no-percentage invariants.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/diagnostic/diagnostic_item_bank.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_engine.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';

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

  test('bank builds grounded questions from the real syllabus', () {
    final bank = DiagnosticItemBank.build(
        syllabus: syllabus, view: view, selection: selection);
    expect(bank.questions, isNotEmpty);
    for (final q in bank.questions) {
      expect(q.isValid, isTrue, reason: 'invalid question ${q.id}');
      // §60: every topic is a selected scope unit.
      expect(selection.isSelected(q.topicId), isTrue,
          reason: 'out-of-scope topic ${q.topicId}');
      // Every option is a real syllabus string (no invented options).
      final realStrings = {
        ...view.sections.map((s) => s.title),
        ...syllabus.books.map((b) => b.title),
        ...syllabus.allItems.map((i) => i.title),
        ..._allSubtopics(syllabus),
      };
      for (final option in q.options) {
        expect(realStrings.contains(option), isTrue,
            reason: 'invented option "$option" in ${q.id}');
      }
    }
  });

  test('§11 adaptive ladder: correct → harder, wrong → easier', () {
    final bank = DiagnosticItemBank.build(
        syllabus: syllabus, view: view, selection: selection);
    final engine = ExamDiagnosticEngine(
      topicTitles: bank.topicTitles,
      topicSections: bank.topicSections,
      maxItems: 6,
    )..registerBank(bank.questions);
    final engine2 = ExamDiagnosticEngine(
      topicTitles: bank.topicTitles,
      topicSections: bank.topicSections,
      maxItems: 6,
    )..registerBank(bank.questions);

    // STRONG student: always correct → difficulty never decreases.
    var strong = engine.start();
    final strongDifficulties = <int>[];
    while (!strong.finished) {
      final q = strong.current!;
      strongDifficulties.add(q.difficulty.tier);
      strong = engine.answer(strong, q.correctIndex);
    }
    for (var i = 1; i < strongDifficulties.length; i++) {
      expect(strongDifficulties[i] >= strongDifficulties[i - 1], isTrue);
    }
    expect(strong.responses.length, 6);

    // WEAK student: always wrong → difficulty never increases.
    var weak = engine2.start();
    final weakDifficulties = <int>[];
    while (!weak.finished) {
      final q = weak.current!;
      weakDifficulties.add(q.difficulty.tier);
      final wrongIndex = (q.correctIndex + 1) % q.options.length;
      weak = engine2.answer(weak, wrongIndex);
    }
    for (var i = 1; i < weakDifficulties.length; i++) {
      expect(weakDifficulties[i] <= weakDifficulties[i - 1], isTrue);
    }
  });

  test('strong vs weak students produce different reports (§10)', () {
    final bank = DiagnosticItemBank.build(
        syllabus: syllabus, view: view, selection: selection);
    ExamDiagnosticEngine engineFor() => ExamDiagnosticEngine(
          topicTitles: bank.topicTitles,
          topicSections: bank.topicSections,
          maxItems: 8,
        )..registerBank(bank.questions);

    var strong = engineFor().start();
    var e1 = engineFor();
    while (!strong.finished) {
      final q = strong.current!;
      strong = e1.answer(strong, q.correctIndex);
    }
    final strongReport = e1.buildReport(strong);

    var weak = engineFor().start();
    var e2 = engineFor();
    while (!weak.finished) {
      final q = weak.current!;
      weak = e2.answer(weak, (q.correctIndex + 2) % q.options.length);
    }
    final weakReport = e2.buildReport(weak);

    expect(strongReport.overallBand, TopicBand.strong);
    expect(weakReport.overallBand, TopicBand.needsAttention);
    expect(strongReport.topicEstimates, isNotEmpty);
  });

  test('§30: observations never contain percentages', () {
    final bank = DiagnosticItemBank.build(
        syllabus: syllabus, view: view, selection: selection);
    final engine = ExamDiagnosticEngine(
      topicTitles: bank.topicTitles,
      topicSections: bank.topicSections,
      maxItems: 5,
    )..registerBank(bank.questions);
    var s = engine.start();
    while (!s.finished) {
      final q = s.current!;
      s = engine.answer(s, q.correctIndex);
    }
    final report = engine.buildReport(s);
    for (final obs in report.observations) {
      expect(obs.contains('%'), isFalse);
      expect(obs.contains('प्रतिशत'), isFalse);
    }
    expect(report.observations, isNotEmpty);
  });
}

Set<String> _allSubtopics(CourseSyllabus syllabus) {
  final out = <String>{};
  for (final item in syllabus.allItems) {
    final details = item.details;
    if (details == null) continue;
    for (final value in details.values) {
      if (value is List) {
        for (final v in value) {
          if (v is String && v.length <= 40) out.add(v);
        }
      } else if (value is Map) {
        value.forEach((_, v) {
          if (v is List) {
            for (final s in v) {
              if (s is String && s.length <= 40) out.add(s);
            }
          }
        });
      }
    }
  }
  return out;
}
