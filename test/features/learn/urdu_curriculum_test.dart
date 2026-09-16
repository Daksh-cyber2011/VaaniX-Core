/// Urdu Learn Mode Curriculum — Part G integrity tests.
///
/// Verifies the Urdu curriculum (assets/curriculum/learn/ur.json) is
/// structurally valid and respects Urdu-specific linguistic features
/// (RTL Nastaliq script, three-level 'you' آپ/تم/تو, two genders,
/// نے past agent, Persian/Arabic vocabulary, postpositions
/// میں/پر/سے/کو/کا/کی/کے/نے).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/urdu_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

Map<String, dynamic> _loadUrduJson() {
  final file = File('assets/curriculum/learn/ur.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadUrduJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Urdu curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1);
    });

    test('language block matches Urdu catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'urdu');
      expect(lang['iso639_1'], 'ur');
      expect(lang['englishName'], 'Urdu');
      expect(lang['nativeName'], 'اُردُو');
      expect(lang['scriptName'], 'Nastaliq (Arabic)');
      expect(lang['scriptCode'], 'Arab');
      expect(lang['direction'], 'rtl');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part G: Urdu must ship at least one chapter');
    });
  });

  group('Urdu curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part G: Urdu ships 5 chapters (Levels 0-4)');
    });

    test('every chapter has id, title, subtitle, order, lessons', () {
      for (final ch in chapters) {
        expect(ch['id'], isNotEmpty);
        expect(ch['title'], isNotEmpty);
        expect(ch['subtitle'], isNotEmpty);
        expect(ch['order'], isA<int>());
        expect(ch['lessons'], isA<List<dynamic>>());
      }
    });

    test('chapter IDs are unique', () {
      final ids = chapters.map((c) => c['id'] as String).toSet();
      expect(ids.length, chapters.length);
    });

    test('chapters are ordered 0..4', () {
      final orders = chapters.map((c) => c['order'] as int).toList()..sort();
      expect(orders, [0, 1, 2, 3, 4]);
    });

    test('all chapter IDs are prefixed with ch_ur_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_ur_'),
            reason: 'Urdu chapter IDs must use ch_ur_ prefix');
      }
    });
  });

  group('Urdu curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part G: Urdu ships a substantial course (>=15 lessons)');
    });

    test('has exactly 20 lessons', () {
      expect(lessons.length, 20,
          reason: 'Part G: Urdu ships exactly 20 lessons (5+4+4+4+3)');
    });

    test('every lesson has non-empty id, title, chapterId, content', () {
      for (final l in lessons) {
        expect(l['id'], isNotEmpty);
        expect(l['title'], isNotEmpty);
        expect(l['chapterId'], isNotEmpty);
        expect(l['content'], isA<String>());
        expect((l['content'] as String).isNotEmpty, isTrue);
      }
    });

    test('all lesson IDs are prefixed with ur_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('ur_'),
            reason:
                'Urdu lesson IDs must use ur_ prefix for global uniqueness');
      }
    });

    test('lesson IDs are globally unique', () {
      final ids = lessons.map((l) => l['id'] as String).toSet();
      expect(ids.length, lessons.length);
    });

    test('every lesson references a valid chapterId', () {
      final chapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final l in lessons) {
        expect(chapterIds.contains(l['chapterId']), isTrue,
            reason:
                'lesson ${l['id']} references unknown chapter ${l['chapterId']}');
      }
    });

    test('every lesson has xpReward >= 10', () {
      for (final l in lessons) {
        expect((l['xpReward'] as num).toInt(), greaterThanOrEqualTo(10));
      }
    });

    test('lessons within each chapter are ordered 0..n', () {
      for (final ch in chapters) {
        final chLessons = (ch['lessons'] as List).cast<Map<String, dynamic>>();
        final orders =
            chLessons.map((l) => (l['order'] as num).toInt()).toList();
        final expected = List<int>.generate(orders.length, (i) => i);
        expect(orders, expected,
            reason: 'chapter ${ch['id']} lessons must be ordered 0..n');
      }
    });
  });

  group('Urdu curriculum — content quality', () {
    test('every lesson content contains Urdu (Arabic) script', () {
      // Arabic Unicode range: \u0600-\u06FF
      final urduRegex = RegExp(r'[\u0600-\u06FF]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(urduRegex.hasMatch(content), isTrue,
            reason: 'lesson ${l['id']} content has no Urdu text');
      }
    });

    test('every lesson content has at least one heading (#)', () {
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(content.contains('# '), isTrue,
            reason: 'lesson ${l['id']} content has no heading');
      }
    });

    test('lesson content has no placeholder text', () {
      final placeholders = [
        'TODO',
        'FIXME',
        'placeholder',
        'lorem ipsum',
        'coming soon',
        'Content coming soon',
      ];
      for (final l in lessons) {
        final content = l['content'] as String;
        for (final p in placeholders) {
          expect(content.toLowerCase().contains(p.toLowerCase()), isFalse,
              reason: 'lesson ${l['id']} contains placeholder "$p"');
        }
      }
    });

    test('lesson content has no malformed Unicode (mojibake)', () {
      final mojibakePatterns = ['â€‹', 'Ã', 'ï¿½', 'Â°'];
      for (final l in lessons) {
        final content = l['content'] as String;
        for (final p in mojibakePatterns) {
          expect(content.contains(p), isFalse,
              reason: 'lesson ${l['id']} has mojibake "$p"');
        }
      }
    });

    test('lesson content does NOT use Devanagari script (Hindi)', () {
      // Devanagari Unicode range: \u0900-\u097F — should NOT appear in
      // Urdu content (Urdu uses Arabic script \u0600-\u06FF)
      final devanagariRegex = RegExp(r'[\u0900-\u097F]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(devanagariRegex.hasMatch(content), isFalse,
            reason: 'lesson ${l['id']} contains Devanagari script — '
                'Urdu curriculum must use Nastaliq (Arabic) script only');
      }
    });
  });

  group('Urdu curriculum — Urdu-specific content', () {
    test('curriculum teaches Urdu-specific vocabulary (Persian/Arabic loans)',
        () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Urdu uses پانی (water), روٹی (bread), سلام (greeting) — Persian/Arabic loans
      expect(allContent.contains('پانی'), isTrue,
          reason: 'Urdu curriculum must teach پانی (water) — Persian loan');
      expect(allContent.contains('سلام'), isTrue,
          reason: 'Urdu curriculum must teach سلام (greeting) — Arabic loan');
      expect(allContent.contains('روٹی'), isTrue,
          reason: 'Urdu curriculum must teach روٹی (bread)');
    });

    test('curriculum teaches distinct Urdu kinship (امّاں/ابو)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Urdu uses امّاں (mother), ابو (father) — distinct from Hindi माँ/बाप
      expect(
          allContent.contains('امّاں') || allContent.contains('اماں'), isTrue,
          reason: 'Urdu curriculum must teach امّاں (mother)');
      expect(allContent.contains('ابو'), isTrue,
          reason: 'Urdu curriculum must teach ابو (father)');
      expect(allContent.contains('بھائی'), isTrue,
          reason: 'Urdu curriculum must teach بھائی (brother)');
      expect(allContent.contains('بہن'), isTrue,
          reason: 'Urdu curriculum must teach بہن (sister)');
    });

    test('curriculum teaches the three-level you system (آپ/تم/تو)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('آپ'), isTrue,
          reason: 'Urdu curriculum must teach آپ (formal you)');
      expect(allContent.contains('تم'), isTrue,
          reason: 'Urdu curriculum must teach تم (informal you)');
      expect(allContent.contains('تو'), isTrue,
          reason: 'Urdu curriculum must teach تو (intimate you)');
    });

    test('curriculum teaches Urdu gender system (مذکر/مؤنث)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.toLowerCase().contains('gender'), isTrue,
          reason: 'Urdu curriculum must teach the two-gender system');
    });

    test('curriculum teaches Urdu-specific postpositions', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.contains('میں') || allContent.contains('گھر میں'), isTrue,
          reason: 'Urdu curriculum must teach میں (in) postposition');
      expect(allContent.contains('پر'), isTrue,
          reason: 'Urdu curriculum must teach پر (on) postposition');
      expect(
          allContent.contains('سے') || allContent.contains('لاہور سے'), isTrue,
          reason: 'Urdu curriculum must teach سے (from) postposition');
      expect(allContent.contains('کو'), isTrue,
          reason: 'Urdu curriculum must teach کو (to) postposition');
    });

    test('curriculum teaches the نے past agent marker', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('نے'), isTrue,
          reason: 'Urdu curriculum must teach نے (past agent marker)');
    });

    test('curriculum mentions Urdu cultural context (Pakistan, Ghalib, Iqbal)',
        () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Should mention Pakistan, Ghalib, Iqbal, or ghazals
      expect(
          allContent.contains('پاکستان') ||
              allContent.contains('غالب') ||
              allContent.contains('اقبال') ||
              allContent.contains('غزل'),
          isTrue,
          reason: 'Urdu curriculum should reference Urdu cultural context');
    });

    test('curriculum mentions RTL direction', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.toLowerCase().contains('right-to-left') ||
              allContent.toLowerCase().contains('right to left') ||
              allContent.toLowerCase().contains('rtl'),
          isTrue,
          reason: 'Urdu curriculum must teach the RTL reading direction');
    });

    test('curriculum teaches Urdu numerals (۰-۹)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Eastern Arabic-Indic digits ۰-۹ (\u06F0-\u06F9)
      final urduDigitRegex = RegExp(r'[\u06F0-\u06F9]');
      expect(urduDigitRegex.hasMatch(allContent), isTrue,
          reason: 'Urdu curriculum must teach Urdu numerals (۰-۹)');
    });
  });

  group('Urdu curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(urduExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in urduExercisesByLesson');
        expect(urduExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in urduExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = urduExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Urdu curriculum');
    });

    test('total exercise count is at least 60', () {
      final count = urduExercisesByLesson.values.expand((list) => list).length;
      expect(count, greaterThanOrEqualTo(60),
          reason: 'Part G: Urdu must ship at least 60 exercises');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in urduExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue, reason: 'exercise ${ex.id} is not valid');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in urduExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in urduExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (ex.type == ExerciseType.mcq ||
              ex.type == ExerciseType.fillBlank) {
            expect(ex.options.length, greaterThanOrEqualTo(2),
                reason: '${ex.id}: MCQ needs >= 2 options');
            expect(ex.correctIndex, isNotNull);
            expect(ex.correctIndex!, greaterThanOrEqualTo(0));
            expect(ex.correctIndex!, lessThan(ex.options.length));
          }
        }
      }
    });

    test('exercise explanations contain Urdu script (Urdu explanations)', () {
      final urduRegex = RegExp(r'[\u0600-\u06FF]');
      var urduExplanationCount = 0;
      for (final entry in urduExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (urduRegex.hasMatch(ex.explanation!)) {
            urduExplanationCount++;
          }
        }
      }
      expect(urduExplanationCount, greaterThan(0),
          reason: 'At least some exercise explanations should be in Urdu');
    });
  });

  group('Urdu curriculum — isolation from other languages', () {
    test('Urdu lesson IDs do not collide with other languages', () {
      final urduIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in urduIds) {
        expect(id.startsWith('ur_'), isTrue,
            reason: 'Urdu lesson ID $id does not use ur_ prefix');
        expect(id.startsWith('hi_'), isFalse);
        expect(id.startsWith('bn_'), isFalse);
        expect(id.startsWith('mr_'), isFalse);
        expect(id.startsWith('te_'), isFalse);
        expect(id.startsWith('ta_'), isFalse);
        expect(id.startsWith('gu_'), isFalse);
        expect(id.startsWith('ls_'), isFalse);
      }
    });

    test('Urdu chapter IDs do not collide with other languages', () {
      final urduChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in urduChapterIds) {
        expect(id.startsWith('ch_ur_'), isTrue,
            reason: 'Urdu chapter ID $id does not use ch_ur_ prefix');
        expect(id.startsWith('ch_hi_'), isFalse);
        expect(id.startsWith('ch_bn_'), isFalse);
        expect(id.startsWith('ch_mr_'), isFalse);
        expect(id.startsWith('ch_te_'), isFalse);
        expect(id.startsWith('ch_ta_'), isFalse);
        expect(id.startsWith('ch_gu_'), isFalse);
      }
    });

    test('Urdu exercise IDs do not collide with other languages', () {
      for (final entry in urduExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.id.startsWith('ex_ur_'), isTrue,
              reason: 'Urdu exercise ${ex.id} must use ex_ur_ prefix');
          expect(ex.id.startsWith('ex_hi_'), isFalse);
          expect(ex.id.startsWith('ex_bn_'), isFalse);
          expect(ex.id.startsWith('ex_mr_'), isFalse);
          expect(ex.id.startsWith('ex_te_'), isFalse);
          expect(ex.id.startsWith('ex_ta_'), isFalse);
          expect(ex.id.startsWith('ex_gu_'), isFalse);
        }
      }
    });
  });

  group('Urdu curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_ur_script');
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('ur_script_letters'),
          reason: 'Level 0 must cover the Urdu letters');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_ur_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_ur_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_ur_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_ur_reading');
    });
  });
}
