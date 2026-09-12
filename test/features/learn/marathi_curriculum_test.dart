/// Marathi Learn Mode Curriculum — Part C integrity tests.
///
/// Verifies the Marathi curriculum (assets/curriculum/learn/mr.json) is
/// structurally valid and respects Marathi-specific linguistic features
/// (NOT a Hindi translation).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/marathi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

Map<String, dynamic> _loadMarathiJson() {
  final file = File('assets/curriculum/learn/mr.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadMarathiJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Marathi curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1);
    });

    test('language block matches Marathi catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'marathi');
      expect(lang['iso639_1'], 'mr');
      expect(lang['englishName'], 'Marathi');
      expect(lang['nativeName'], 'मराठी');
      expect(lang['scriptName'], 'Devanagari');
      expect(lang['scriptCode'], 'Deva');
      expect(lang['direction'], 'ltr');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part C: Marathi must ship at least one chapter');
    });
  });

  group('Marathi curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part C: Marathi ships 5 chapters (Levels 0-4)');
    });

    test('every chapter has id, title, subtitle, order, lessons', () {
      for (final ch in chapters) {
        expect(ch['id'], isNotEmpty);
        expect(ch['title'], isNotEmpty);
        expect(ch['subtitle'], isNotEmpty);
        expect(ch['order'], isA<int>());
        expect(ch['lessons'], isA<List>());
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

    test('all chapter IDs are prefixed with ch_mr_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_mr_'),
            reason: 'Marathi chapter IDs must use ch_mr_ prefix');
      }
    });
  });

  group('Marathi curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part C: Marathi ships a substantial course (>=15 lessons)');
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

    test('all lesson IDs are prefixed with mr_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('mr_'),
            reason:
                'Marathi lesson IDs must use mr_ prefix for global uniqueness');
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

  group('Marathi curriculum — content quality', () {
    test('every lesson content contains Devanagari script', () {
      // Devanagari Unicode range: \u0900-\u097F
      final devanagariRegex = RegExp(r'[\u0900-\u097F]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(devanagariRegex.hasMatch(content), isTrue,
            reason: 'lesson ${l['id']} content has no Devanagari text');
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
  });

  group('Marathi curriculum — Marathi-specific content', () {
    test('curriculum teaches the ळ sound (Marathi distinctive)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('ळ'), isTrue,
          reason: 'Marathi curriculum must teach ळ — the retroflex lateral '
              'that is unique to Marathi among major Indian languages');
    });

    test('curriculum mentions the three-gender system', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Look for mentions of neuter gender (Marathi's distinctive feature)
      expect(
          allContent.toLowerCase().contains('neuter') ||
              allContent.contains('नपुंसकलिंग') ||
              allContent.contains(' neuter'),
          isTrue,
          reason: 'Marathi curriculum must teach the neuter gender — '
              'Marathi has 3 genders, Hindi has only 2');
    });

    test('curriculum teaches Marathi-specific vocabulary (not Hindi)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Marathi uses भाजी (vegetable), पोळी (flatbread), आई (mother) —
      // different from Hindi's सब्ज़ी, रोटी, माँ
      expect(allContent.contains('आई'), isTrue,
          reason: 'Marathi curriculum must teach आई (mother) — '
              'distinct from Hindi माँ');
      expect(allContent.contains('नमस्कार'), isTrue,
          reason: 'Marathi curriculum must teach नमस्कार — '
              'the Marathi greeting');
    });

    test('curriculum mentions Marathi-specific number words', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // षण्ण (6) and शंभर (100) are distinctive Marathi numbers
      expect(allContent.contains('षण्ण'), isTrue,
          reason: 'Marathi curriculum must teach षण्ण (6) — '
              'distinct from Hindi छह');
      expect(allContent.contains('शंभर'), isTrue,
          reason: 'Marathi curriculum must teach शंभर (100) — '
              'distinct from Hindi सौ');
    });

    test('curriculum mentions Marathi-specific negation (नाही/नको)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('नाही'), isTrue,
          reason: 'Marathi curriculum must teach नाही (negation)');
      expect(allContent.contains('नको'), isTrue,
          reason: 'Marathi curriculum must teach नको (don\'t want/command)');
    });

    test('curriculum mentions Marathi cultural context', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Should mention Maharashtra, Ganesh festival, or Marathi cities
      expect(
          allContent.contains('महाराष्ट्र') ||
              allContent.contains('गणेशोत्सव') ||
              allContent.contains('मुंबई') ||
              allContent.contains('पुणे'),
          isTrue,
          reason: 'Marathi curriculum should reference Maharashtra / '
              'Marathi cultural context');
    });
  });

  group('Marathi curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(marathiExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in marathiExercisesByLesson');
        expect(marathiExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in marathiExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = marathiExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Marathi curriculum');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in marathiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue, reason: 'exercise ${ex.id} is not valid');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in marathiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in marathiExercisesByLesson.entries) {
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

    test('exercise explanations contain Devanagari (Marathi explanations)', () {
      final devanagariRegex = RegExp(r'[\u0900-\u097F]');
      var marathiExplanationCount = 0;
      for (final entry in marathiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (devanagariRegex.hasMatch(ex.explanation!)) {
            marathiExplanationCount++;
          }
        }
      }
      expect(marathiExplanationCount, greaterThan(0),
          reason: 'At least some exercise explanations should be in Marathi');
    });
  });

  group('Marathi curriculum — isolation from other languages', () {
    test('Marathi lesson IDs do not collide with Hindi, Bengali, or Sanskrit',
        () {
      final marathiIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in marathiIds) {
        expect(id.startsWith('mr_'), isTrue,
            reason: 'Marathi lesson ID $id does not use mr_ prefix');
        expect(id.startsWith('hi_'), isFalse,
            reason: 'Marathi lesson ID $id collides with Hindi');
        expect(id.startsWith('bn_'), isFalse,
            reason: 'Marathi lesson ID $id collides with Bengali');
        expect(id.startsWith('ls_'), isFalse,
            reason: 'Marathi lesson ID $id collides with Sanskrit');
      }
    });

    test('Marathi chapter IDs do not collide with other languages', () {
      final marathiChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in marathiChapterIds) {
        expect(id.startsWith('ch_mr_'), isTrue,
            reason: 'Marathi chapter ID $id does not use ch_mr_ prefix');
        expect(id.startsWith('ch_hi_'), isFalse);
        expect(id.startsWith('ch_bn_'), isFalse);
      }
    });

    test('Marathi exercise IDs do not collide with other languages', () {
      for (final entry in marathiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.id.startsWith('ex_mr_'), isTrue,
              reason: 'Marathi exercise ${ex.id} must use ex_mr_ prefix');
          expect(ex.id.startsWith('ex_hi_'), isFalse);
          expect(ex.id.startsWith('ex_bn_'), isFalse);
        }
      }
    });
  });

  group('Marathi curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_mr_script');
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('mr_script_vowels'),
          reason: 'Level 0 must start with vowels');
      expect(scriptLessons, contains('mr_script_consonants'),
          reason: 'Level 0 must cover consonants (including ळ)');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_mr_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_mr_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_mr_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_mr_reading');
    });
  });
}
