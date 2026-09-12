/// Exam Mode 2.0 — M1 Syllabus Model Tests
///
/// Pins the Layer-1 domain contract against the ACTUAL canonical JSON
/// shipped in `assets/syllabus/cbse/` (read from disk the same way
/// `exam_content_grounding_test.dart` pins the Learn curriculum).
///
/// Covers: JSON → model round-trips, track ID parsing, mark arithmetic
/// invariants, course isolation, pending-announcement flags, and the
/// board-agnostic identity model.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';

const List<String> kTrackIds = [
  'cbse_9_hindi_r1',
  'cbse_9_hindi_r2',
  'cbse_9_sanskrit',
  'cbse_10_hindi_a',
  'cbse_10_hindi_b',
  'cbse_10_sanskrit',
  'cbse_10_sanskrit_communicative',
];

CourseSyllabus loadCourse(String trackId) {
  final file = File('assets/syllabus/cbse/$trackId.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return CourseSyllabus.fromJson(json);
}

void main() {
  group('SyllabusTrackId', () {
    test('parses a simple track id', () {
      final id = SyllabusTrackId.parse('cbse_10_hindi_a');
      expect(id.board.value, 'cbse');
      expect(id.klass, 10);
      expect(id.subjectId, 'hindi');
      expect(id.courseId, 'a');
      expect(id.value, 'cbse_10_hindi_a');
      expect(id.assetPath, 'assets/syllabus/cbse/cbse_10_hindi_a.json');
    });

    test('parses a multi-word course segment', () {
      final id = SyllabusTrackId.parse('cbse_10_sanskrit_communicative');
      expect(id.courseId, 'sanskrit_communicative');
      expect(id.value, 'cbse_10_sanskrit_communicative');
    });

    test('parses single-course subjects (no course segment)', () {
      final id = SyllabusTrackId.parse('cbse_9_sanskrit');
      expect(id.board.value, 'cbse');
      expect(id.klass, 9);
      expect(id.subjectId, 'sanskrit');
      expect(id.courseId, isEmpty);
      expect(id.value, 'cbse_9_sanskrit');
      expect(id.assetPath, 'assets/syllabus/cbse/cbse_9_sanskrit.json');
    });

    test('rejects malformed ids', () {
      expect(() => SyllabusTrackId.parse('hindi'),
          throwsA(isA<FormatException>()));
      expect(() => SyllabusTrackId.parse('cbse_ten_hindi_a'),
          throwsA(isA<FormatException>()));
    });

    test('sameSubject distinguishes courses but not subjects', () {
      final a = SyllabusTrackId.parse('cbse_10_hindi_a');
      final b = SyllabusTrackId.parse('cbse_10_hindi_b');
      final sans = SyllabusTrackId.parse('cbse_10_sanskrit');
      expect(a.sameSubject(b), isTrue);
      expect(a.sameSubject(sans), isFalse);
      expect(a == b, isFalse);
    });
  });

  group('BoardId', () {
    test('cbse is the V1 board and is supported', () {
      expect(BoardId.cbse.value, 'cbse');
      expect(BoardId.cbse.isSupported, isTrue);
      expect(const BoardId('icse').isSupported, isTrue);
      expect(const BoardId('random').isSupported, isFalse);
    });
  });

  group('canonical course files parse and validate', () {
    for (final trackId in kTrackIds) {
      test('$trackId loads, validates, round-trips', () {
        final syllabus = loadCourse(trackId);

        // Identity wiring.
        expect(syllabus.id.value, trackId);
        expect(syllabus.board.value, 'cbse');
        expect(syllabus.syllabusVersion, '2026-27');
        expect(syllabus.sections, isNotEmpty);

        // Mark arithmetic (the no-invented-marks guarantee).
        expect(syllabus.validate(), isEmpty,
            reason: '$trackId failed mark validation');

        // JSON round-trip preserves structure.
        final roundTrip = CourseSyllabus.fromJson(syllabus.toJson());
        expect(roundTrip.id.value, trackId);
        expect(roundTrip.computedBoardMarks, syllabus.computedBoardMarks);
        expect(roundTrip.sections.length, syllabus.sections.length);
        expect(roundTrip.allItems.length, syllabus.allItems.length);
        expect(roundTrip.validate(), isEmpty);
      });
    }
  });

  group('board/internal assessment split', () {
    test('every course: 80 board marks + 20 internal marks', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        expect(s.boardExamTotalMarks, 80, reason: trackId);
        expect(s.internalAssessmentMarks, 20, reason: trackId);
        expect(s.computedBoardMarks, 80, reason: trackId);
        expect(s.boardExamDurationHours, 3, reason: trackId);
      }
    });

    test('internal components (when present) sum to 20', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        if (s.internalComponents.isNotEmpty) {
          final total =
              s.internalComponents.fold(0.0, (sum, c) => sum + c.marks);
          expect(total, 20, reason: trackId);
        }
      }
    });
  });

  group('course isolation (master plan §38)', () {
    test('every item/book/chapter id is prefixed by its track id', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        final ids = <String>[
          ...s.sections.map((sec) => sec.id),
          ...s.allItems.map((i) => i.id),
          ...s.books.map((b) => b.id),
          ...s.allChapters.map((c) => c.id),
        ];
        expect(ids, isNotEmpty, reason: trackId);
        for (final id in ids) {
          expect(id.startsWith('${trackId}_'), isTrue,
              reason: '$id must be namespaced by $trackId');
        }
      }
    });

    test('item sectionIds point at real sections', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        final sectionIds = s.sections.map((sec) => sec.id).toSet();
        for (final item in s.allItems) {
          expect(sectionIds.contains(item.sectionId), isTrue,
              reason: '${item.id} points at ${item.sectionId}');
        }
      }
    });

    test('all ids are unique within a course', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        final ids = <String>[
          ...s.sections.map((sec) => sec.id),
          ...s.allItems.map((i) => i.id),
          ...s.books.map((b) => b.id),
          ...s.allChapters.map((c) => c.id),
          ...s.internalComponents.map((c) => c.id),
        ];
        expect(ids.toSet().length, ids.length,
            reason: '$trackId has duplicate ids');
      }
    });

    test('no id space overlaps between two different courses', () {
      final a = loadCourse('cbse_10_hindi_a');
      final b = loadCourse('cbse_10_hindi_b');
      final aIds = a.allItems.map((i) => i.id).toSet();
      final bIds = b.allItems.map((i) => i.id).toSet();
      expect(aIds.intersection(bIds), isEmpty,
          reason: 'Hindi A and Hindi B must never share item ids');
    });
  });

  group('pending official announcements (Class 9)', () {
    test('Class 9 tracks flag literature as pending', () {
      for (final trackId in [
        'cbse_9_hindi_r1',
        'cbse_9_hindi_r2',
        'cbse_9_sanskrit',
      ]) {
        final s = loadCourse(trackId);
        expect(s.hasPendingLiterature, isTrue,
            reason: '$trackId literature must be flagged pending');
        expect(s.pending, isNotNull, reason: trackId);
        expect(s.pending!.sourceQuote, isNotEmpty);
        // Literature section exists structurally but has no published,
        // selectable chapters — content must never be invented.
        final lit =
            s.sections.firstWhere((sec) => sec.stableKey == 'literature');
        expect(lit.selectableItems, isEmpty,
            reason: '$trackId literature must have no selectable items yet');
      }
    });

    test('Class 10 tracks have published literature', () {
      for (final trackId in [
        'cbse_10_hindi_a',
        'cbse_10_hindi_b',
        'cbse_10_sanskrit',
        'cbse_10_sanskrit_communicative',
      ]) {
        final s = loadCourse(trackId);
        expect(s.hasPendingLiterature, isFalse, reason: trackId);
        expect(s.books, isNotEmpty, reason: trackId);
      }
    });
  });

  group('subject codes and course metadata', () {
    test('official subject codes are exact', () {
      expect(loadCourse('cbse_10_hindi_a').subjectCode, '002');
      expect(loadCourse('cbse_10_hindi_b').subjectCode, '085');
      expect(loadCourse('cbse_10_sanskrit').subjectCode, '122');
      expect(loadCourse('cbse_10_sanskrit_communicative').subjectCode, '119');
      expect(loadCourse('cbse_9_hindi_r1').subjectCode, isNull);
      expect(loadCourse('cbse_9_sanskrit').subjectCode, isNull);
    });

    test('source PDF attribution present on every course', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        expect(s.sourcePdf, isNotEmpty, reason: trackId);
        expect(s.sourcePdf.endsWith('.pdf'), isTrue, reason: trackId);
      }
    });
  });

  group('Class 10 Sanskrit prescribed chapters (122)', () {
    test('शेमुषी भाग-2 lists exactly the PDF table chapters (1-8, 10)', () {
      final s = loadCourse('cbse_10_sanskrit');
      final shemushi =
          s.books.firstWhere((b) => b.id == 'cbse_10_sanskrit_book_shemushi');
      final numbers = shemushi.chapters.map((c) => c.number).toList();
      // Chapter 9 is NOT listed by the official PDF table — never invent.
      expect(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 10]);
      expect(shemushi.chapters.length, 9);
      expect(shemushi.chapters.first.title, 'शुचिपर्यावरणम्');
      expect(shemushi.chapters.firstWhere((c) => c.number == 10).title,
          'अन्योक्तयः');
    });

    test('grammar books are also prescribed (अभ्यासवान् भव, व्याकरणवीथिः)', () {
      final s = loadCourse('cbse_10_sanskrit');
      expect(s.books.any((b) => b.title.contains('अभ्यासवान् भव')), isTrue);
      expect(s.books.any((b) => b.title.contains('व्याकरणवीथि')), isTrue);
    });
  });

  group('Class 10 Sanskrit Communicative (119)', () {
    test('मणिका भाग-2 lists 11 chapters; 10 & 11 are internal-only', () {
      final s = loadCourse('cbse_10_sanskrit_communicative');
      final manika = s.books.firstWhere(
          (b) => b.id == 'cbse_10_sanskrit_communicative_book_manika');
      expect(manika.chapters.length, 11);
      expect(manika.chapters.first.title, 'वाङ्मयं तपः');
      final ch10 = manika.chapters.firstWhere((c) => c.number == 10);
      final ch11 = manika.chapters.firstWhere((c) => c.number == 11);
      expect(ch10.isInternalOnly, isTrue);
      expect(ch11.isInternalOnly, isTrue);
      expect(manika.chapters.firstWhere((c) => c.number == 9).isInternalOnly,
          isFalse);
    });
  });

  group('Hindi A/B exclusion lists (official छूट पाठ)', () {
    test('Hindi A/B publish the supplied NCERT in-scope chapter lists', () {
      final hindiA = loadCourse('cbse_10_hindi_a');
      final kshitij = hindiA.books
          .firstWhere((b) => b.id == 'cbse_10_hindi_a_book_kshitij');
      final kritika = hindiA.books
          .firstWhere((b) => b.id == 'cbse_10_hindi_a_book_kritika');
      expect(kshitij.chapters.length, 12);
      expect(kritika.chapters.length, 3);
      expect(kshitij.chapters.first.title, 'सूरदास के पद');
      expect(kritika.chapters.last.author, 'अज्ञेय');

      final hindiB = loadCourse('cbse_10_hindi_b');
      final sparsh =
          hindiB.books.firstWhere((b) => b.id == 'cbse_10_hindi_b_book_sparsh');
      final sanchayan = hindiB.books
          .firstWhere((b) => b.id == 'cbse_10_hindi_b_book_sanchayan');
      expect(sparsh.chapters.length, 14);
      expect(sanchayan.chapters.length, 3);
      expect(sanchayan.chapters.first.title, 'हरिहर काका');
      expect(sanchayan.chapters.first.sourceFile, 'jhsy101.pdf');
    });

    test('Hindi A records the exact excluded chapters', () {
      final s = loadCourse('cbse_10_hindi_a');
      final prose = s.sections
          .firstWhere((sec) => sec.stableKey == 'literature')
          .items
          .firstWhere((i) => i.id.endsWith('kshitij_prose'));
      final poetry = s.sections
          .firstWhere((sec) => sec.stableKey == 'literature')
          .items
          .firstWhere((i) => i.id.endsWith('kshitij_poetry'));
      final kritika = s.sections
          .firstWhere((sec) => sec.stableKey == 'literature')
          .items
          .firstWhere((i) => i.id.endsWith('kritika'));

      expect((prose.details!['excludedChapters'] as List).length, 2);
      expect((poetry.details!['excludedChapters'] as List).length, 3);
      expect((kritika.details!['excludedChapters'] as List).length, 2);
    });

    test('Hindi B records the exact excluded chapters + संचयन untouched', () {
      final s = loadCourse('cbse_10_hindi_b');
      final literature =
          s.sections.firstWhere((sec) => sec.stableKey == 'literature');
      final poetry =
          literature.items.firstWhere((i) => i.id.endsWith('sparsh_poetry'));
      expect((poetry.details!['excludedChapters'] as List).length, 2);
      final sanchayan =
          literature.items.firstWhere((i) => i.id.endsWith('sanchayan'));
      expect(sanchayan.details!.containsKey('note'), isTrue);
    });
  });

  group('grammar section fidelity (spot checks)', () {
    test('Class 10 Sanskrit has 7 applied-grammar items summing to 25', () {
      final s = loadCourse('cbse_10_sanskrit');
      final grammar =
          s.sections.firstWhere((sec) => sec.stableKey == 'grammar');
      expect(grammar.marks, 25);
      expect(grammar.items.length, 7);
      final sandhi =
          grammar.items.firstWhere((i) => i.id.endsWith('grammar_sandhi'));
      expect(sandhi.title, contains('सन्धि'));
      expect(sandhi.details!.keys.toSet(),
          containsAll(['स्वरसन्धिः', 'व्यञ्जनसन्धिः', 'विसर्गसन्धिः']));
    });

    test('Class 9 Hindi आर-1 has the four official grammar topics', () {
      final s = loadCourse('cbse_9_hindi_r1');
      final grammar =
          s.sections.firstWhere((sec) => sec.stableKey == 'grammar');
      expect(grammar.marks, 16);
      expect(grammar.items.length, 4);
      expect(grammar.items.map((i) => i.id).toList(), [
        'cbse_9_hindi_r1_grammar_word_formation',
        'cbse_9_hindi_r1_grammar_parts_of_speech',
        'cbse_9_hindi_r1_grammar_sentence_types_meaning',
        'cbse_9_hindi_r1_grammar_alankar',
      ]);
    });

    test('Class 9 Hindi आर-2 grammar marks sum (4+4+2+6)', () {
      final s = loadCourse('cbse_9_hindi_r2');
      final grammar =
          s.sections.firstWhere((sec) => sec.stableKey == 'grammar');
      expect(grammar.marks, 16);
      final marks = grammar.items.map((i) => i.marks).toList();
      expect(marks, [4, 4, 2, 6]);
    });
  });

  group('OCR uncertainty flags are surfaced, not hidden', () {
    test('uncertain items carry ocrUncertain and exist across tracks', () {
      var total = 0;
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        for (final item in s.uncertainItems) {
          expect(item.ocrUncertain, isTrue);
          expect(item.note, isNotNull,
              reason: '${item.id} must explain its uncertainty');
        }
        total += s.uncertainItems.length;
      }
      // The Sanskrit tracks genuinely carry flagged items (Class 9 lists).
      expect(loadCourse('cbse_9_sanskrit').uncertainItems, isNotEmpty);
      expect(loadCourse('cbse_10_sanskrit').uncertainItems, isNotEmpty);
      // Sanity: not everything is flagged.
      expect(total, lessThan(50));
    });
  });

  group('content tags', () {
    test('every item carries at least one content tag', () {
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        for (final item in s.allItems) {
          expect(item.contentTags, isNotEmpty,
              reason: '${item.id} needs a contentTag for M6+ routing');
        }
      }
    });

    test('tags come from the closed vocabulary', () {
      const allowed = {
        'reading',
        'poetry',
        'grammar',
        'poetics',
        'writing',
        'vocabulary',
        'orthography',
        'literature',
        'prose',
        'drama',
        'translation',
      };
      for (final trackId in kTrackIds) {
        final s = loadCourse(trackId);
        for (final item in s.allItems) {
          for (final tag in item.contentTags) {
            expect(allowed.contains(tag), isTrue,
                reason: '${item.id} has unknown tag $tag');
          }
        }
      }
    });
  });
}
