/// Exam Mode 2.0 — M2 Domain Tests (Exam Scope)
///
/// Grounded in the REAL canonical JSON (same file-reading pattern as the M1
/// syllabus tests), so the selection semantics are pinned against actual
/// official data: chapter-based literature units (Sanskrit), pending Class 9
/// literature (never selectable), internal-only chapters (never selectable),
/// course isolation, revision counting, pruning, and marks coverage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';

CourseSyllabus loadCourse(String trackId) {
  final file = File('assets/syllabus/cbse/$trackId.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return CourseSyllabus.fromJson(json);
}

void main() {
  group('ExamScopeView building', () {
    test('Class 10 Sanskrit (122): literature units are the chapters', () {
      final view = ExamScopeView.fromSyllabus(loadCourse('cbse_10_sanskrit'));
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      final chapters = lit.units.where((u) => u.isChapter).toList();
      expect(chapters.length, 9, reason: 'शेमुषी chapters 1–8, 10');
      expect(chapters.every((u) => u.selectable), isTrue);
      expect(chapters.first.title, 'शुचिपर्यावरणम्');
      // Question-format items are replaced by chapters.
      expect(lit.units.where((u) => !u.isChapter), isEmpty);
    });

    test('Class 10 Communicative (119): ch 10 & 11 are NOT selectable', () {
      final view = ExamScopeView.fromSyllabus(
          loadCourse('cbse_10_sanskrit_communicative'));
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      final ch10 =
          lit.units.firstWhere((u) => u.isChapter && u.titleEn == 'Chapter 10');
      final ch11 =
          lit.units.firstWhere((u) => u.isChapter && u.titleEn == 'Chapter 11');
      final ch9 =
          lit.units.firstWhere((u) => u.isChapter && u.titleEn == 'Chapter 9');
      expect(ch10.selectable, isFalse);
      expect(ch11.selectable, isFalse);
      expect(ch9.selectable, isTrue);
      expect(ch10.subtitle, contains('आंतरिक मूल्यांकन'));
    });

    test('Class 9 Sanskrit: literature is pending and unselectable', () {
      final view = ExamScopeView.fromSyllabus(loadCourse('cbse_9_sanskrit'));
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      expect(lit.isPending, isTrue);
      expect(lit.pendingNote, isNotNull);
      expect(lit.pendingNote, contains('आधिकारिक'));
      expect(lit.selectableUnits, isEmpty);
      expect(view.hasPendingSections, isTrue);
      // Grammar section is fully selectable even when literature is pending.
      final grammar = view.sections.firstWhere((s) => s.stableKey == 'grammar');
      expect(grammar.selectableUnits, isNotEmpty);
    });

    test('Class 9 Hindi R-1: literature pending, grammar selectable', () {
      final view = ExamScopeView.fromSyllabus(loadCourse('cbse_9_hindi_r1'));
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      expect(lit.isPending, isTrue);
      expect(view.selectableUnitIds, isNotEmpty);
    });

    test('Hindi A literature units are the book-section items', () {
      final view = ExamScopeView.fromSyllabus(loadCourse('cbse_10_hindi_a'));
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      // 3 book-section units: क्षितिज गद्य, क्षितिज काव्य, कृतिका.
      expect(lit.units.length, 3);
      expect(lit.units.every((u) => !u.isChapter), isTrue);
      expect(lit.units.every((u) => u.selectable), isTrue);
    });

    test('every section of every track renders units or a pending state', () {
      for (final trackId in [
        'cbse_9_hindi_r1',
        'cbse_9_hindi_r2',
        'cbse_9_sanskrit',
        'cbse_10_hindi_a',
        'cbse_10_hindi_b',
        'cbse_10_sanskrit',
        'cbse_10_sanskrit_communicative',
      ]) {
        final view = ExamScopeView.fromSyllabus(loadCourse(trackId));
        for (final section in view.sections) {
          expect(section.units.isNotEmpty || section.isPending, isTrue,
              reason: '$trackId/${section.stableKey} renders nothing');
        }
        expect(view.boardMarks, 80, reason: trackId);
      }
    });

    test('selectableUnitIds are namespaced by the track (isolation)', () {
      for (final trackId in [
        'cbse_9_sanskrit',
        'cbse_10_hindi_b',
        'cbse_10_sanskrit_communicative',
      ]) {
        final view = ExamScopeView.fromSyllabus(loadCourse(trackId));
        for (final id in view.selectableUnitIds) {
          expect(id.startsWith('${trackId}_'), isTrue, reason: id);
        }
      }
    });

    test('unitById resolves known and misses unknown ids', () {
      final view = ExamScopeView.fromSyllabus(loadCourse('cbse_10_sanskrit'));
      expect(view.unitById('cbse_10_sanskrit_grammar_sandhi'), isNotNull);
      expect(view.unitById('cbse_10_hindi_a_grammar_vachya'), isNull);
      expect(view.unitById('nope'), isNull);
    });
  });

  group('ExamScopeSelection semantics', () {
    const track = 'cbse_10_sanskrit';
    late ExamScopeView view;

    setUp(() {
      view = ExamScopeView.fromSyllabus(loadCourse(track));
    });

    test('empty selection + JSON round-trip', () {
      final empty = ExamScopeSelection.empty(track);
      expect(empty.isEmpty, isTrue);
      final restored = ExamScopeSelection.fromJson(empty.toJson());
      expect(restored.selectedUnitIds, isEmpty);
      expect(restored.revision, 0);
      expect(restored.trackId, track);
    });

    test('toggle selects, deselects, and bumps revision', () {
      var selection = ExamScopeSelection.empty(track);
      const unitId = '${track}_grammar_sandhi';

      selection = selection.toggle(unitId)!;
      expect(selection.isSelected(unitId), isTrue);
      expect(selection.revision, 1);
      expect(selection.updatedAtIso, isNotEmpty);

      selection = selection.toggle(unitId)!;
      expect(selection.isSelected(unitId), isFalse);
      expect(selection.revision, 2);
      expect(selection.isEmpty, isTrue);
    });

    test('course isolation: foreign ids are rejected (null result)', () {
      final selection = ExamScopeSelection.empty(track);
      expect(selection.toggle('cbse_10_hindi_a_grammar_vachya'), isNull);
      expect(
          selection
              .toggle('cbse_10_sanskrit_communicative_grammar_sandhi'),
          isNull);
      expect(selection.revision, 0, reason: 'no change, no revision bump');
      expect(selection.isEmpty, isTrue);
    });

    test('selectAll selects every selectable unit of the view', () {
      final selection =
          ExamScopeSelection.empty(track).selectAll(view.selectableUnitIds);
      expect(selection.selectedUnitIds.length, view.selectableUnitIds.length);
      // Chapters carry no per-chapter marks (the PDF allocates 30 marks to
      // the whole literature section) — coverage counts marks-bearing
      // units only: 10 (unread) + 15 (writing) + 25 (grammar) = 50.
      expect(selection.coveredMarks(view), 50);
    });

    test('selectAll on a fully item-marks track covers all 80', () {
      const hindiB = 'cbse_10_hindi_b';
      final hindiView = ExamScopeView.fromSyllabus(loadCourse(hindiB));
      final selection =
          ExamScopeSelection.empty(hindiB).selectAll(hindiView.selectableUnitIds);
      expect(selection.coveredMarks(hindiView), 80);
    });

    test('selectAll ignores foreign ids (isolation)', () {
      final selection = ExamScopeSelection.empty(track).selectAll([
        ...view.selectableUnitIds,
        'cbse_10_hindi_a_grammar_vachya',
      ]);
      expect(selection.selectedUnitIds.length, view.selectableUnitIds.length);
      expect(
          selection.selectedUnitIds
              .every((id) => id.startsWith('${track}_')),
          isTrue);
    });

    test('clearAll empties and still bumps revision', () {
      final selected =
          ExamScopeSelection.empty(track).selectAll(view.selectableUnitIds);
      final cleared = selected.clearAll();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.revision, selected.revision + 1);
    });

    test('toggleSection selects all of a section, then deselects all', () {
      var selection = ExamScopeSelection.empty(track);
      final grammar = view.sections.firstWhere((s) => s.stableKey == 'grammar');
      final grammarIds = grammar.selectableUnits.map((u) => u.id).toList();

      selection = selection.toggleSection(grammarIds);
      expect(grammarIds.every(selection.isSelected), isTrue);

      selection = selection.toggleSection(grammarIds);
      expect(grammarIds.any(selection.isSelected), isFalse);
    });

    test('toggleSection ignores foreign ids', () {
      final selection = ExamScopeSelection.empty(track)
          .toggleSection(['cbse_10_hindi_a_grammar_vachya']);
      expect(selection.isEmpty, isTrue);
      expect(selection.revision, 0);
    });

    test('pruneTo drops ids removed from the syllabus', () {
      const staleId = '${track}_removed_topic';
      final selection = ExamScopeSelection.fromJson({
        'trackId': track,
        'selectedUnitIds': [
          staleId,
          '${track}_grammar_sandhi',
        ],
        'revision': 7,
        'updatedAtIso': '2026-01-01T00:00:00.000',
      });

      final pruned = selection.pruneTo(view);
      expect(pruned.selectedUnitIds, {'${track}_grammar_sandhi'});
      expect(pruned.revision, 7, reason: 'prune is not a user action');
      // No-change prune returns the same instance.
      expect(identical(pruned.pruneTo(view), pruned), isTrue);
    });

    test('coveredMarks sums only selectable units with marks', () {
      var selection = ExamScopeSelection.empty(track);
      final grammar = view.sections.firstWhere((s) => s.stableKey == 'grammar');
      final sandhi =
          grammar.selectableUnits.firstWhere((u) => u.id.endsWith('sandhi'));

      selection = selection.toggle(sandhi.id)!;
      expect(selection.coveredMarks(view), sandhi.marks);
      // Chapters (no per-chapter marks) add 0 to coverage.
      final lit = view.sections.firstWhere((s) => s.stableKey == 'literature');
      final ch1 = lit.selectableUnits.first;
      if (ch1.marks == null) {
        final withChapter = selection.toggle(ch1.id)!;
        expect(withChapter.coveredMarks(view), sandhi.marks);
      }
    });

    test('selectedCount against eligible ids', () {
      final grammarIds = view.sections
          .firstWhere((s) => s.stableKey == 'grammar')
          .selectableUnits
          .map((u) => u.id)
          .toSet();
      final selection =
          ExamScopeSelection.empty(track).toggle(grammarIds.first)!;
      expect(selection.selectedCount(grammarIds), 1);
      expect(selection.selectedCount(view.selectableUnitIds), 1);
    });
  });

  group('JSON round-trip of a full selection', () {
    test('ids stay sorted and stable', () {
      const track = 'cbse_10_hindi_b';
      final view = ExamScopeView.fromSyllabus(loadCourse(track));
      final selection =
          ExamScopeSelection.empty(track).selectAll(view.selectableUnitIds);
      final json = selection.toJson();
      final ids = (json['selectedUnitIds'] as List).cast<String>();
      expect(ids.length, view.selectableUnitIds.length);
      // Sorted + equal as sets.
      final sorted = [...ids]..sort();
      expect(ids, sorted);
      expect(ids.toSet(), view.selectableUnitIds);
      final restored = ExamScopeSelection.fromJson(json);
      expect(restored.selectedUnitIds, selection.selectedUnitIds);
      expect(restored.revision, selection.revision);
    });
  });
}
