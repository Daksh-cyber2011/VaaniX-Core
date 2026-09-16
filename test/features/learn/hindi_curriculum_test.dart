/// Hindi Learn Mode Curriculum — Part A integrity tests.
///
/// Verifies the Hindi curriculum (assets/curriculum/learn/hi.json) is
/// structurally valid, pedagogically sound, and properly integrated with
/// the Learn Mode dispatch. Guards against:
///   - schema / metadata drift
///   - missing or empty lessons
///   - duplicate lesson IDs
///   - lessons without content
///   - broken chapter/lesson references
///   - exercises not matching curriculum lessons
///   - Hindi curriculum polluting the Sanskrit Exam Mode path
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Loads the Hindi curriculum JSON from disk.
Map<String, dynamic> _loadHindiJson() {
  final file = File('assets/curriculum/learn/hi.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadHindiJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Hindi curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1,
          reason: 'Hindi curriculum must use the stable schema version');
    });

    test('language block matches Hindi catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'hindi');
      expect(lang['iso639_1'], 'hi');
      expect(lang['englishName'], 'Hindi');
      expect(lang['nativeName'], 'हिन्दी');
      expect(lang['scriptName'], 'Devanagari');
      expect(lang['scriptCode'], 'Deva');
      expect(lang['direction'], 'ltr');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part A: Hindi must ship at least one chapter');
    });
  });

  group('Hindi curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part A: Hindi ships 5 chapters (Levels 0-4)');
    });

    test('every chapter has id, title, subtitle, order, lessons', () {
      for (final ch in chapters) {
        expect(ch['id'], isNotEmpty, reason: 'chapter id missing');
        expect(ch['title'], isNotEmpty, reason: 'chapter title missing');
        expect(ch['subtitle'], isNotEmpty, reason: 'chapter subtitle missing');
        expect(ch['order'], isA<int>(), reason: 'chapter order missing');
        expect(ch['lessons'], isA<List<dynamic>>(),
            reason: 'chapter lessons missing');
      }
    });

    test('chapter IDs are unique', () {
      final ids = chapters.map((c) => c['id'] as String).toSet();
      expect(ids.length, chapters.length, reason: 'duplicate chapter IDs');
    });

    test('chapters are ordered 0..4', () {
      final orders = chapters.map((c) => c['order'] as int).toList()..sort();
      expect(orders, [0, 1, 2, 3, 4],
          reason: 'chapters must be ordered 0 through 4');
    });

    test('all chapter IDs are prefixed with ch_hi_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_hi_'),
            reason: 'Hindi chapter IDs must use ch_hi_ prefix');
      }
    });
  });

  group('Hindi curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part A: Hindi ships a substantial course (>=15 lessons)');
    });

    test('every lesson has non-empty id, title, chapterId, content', () {
      for (final l in lessons) {
        expect(l['id'], isNotEmpty, reason: 'lesson id empty');
        expect(l['title'], isNotEmpty, reason: 'lesson title empty');
        expect(l['chapterId'], isNotEmpty, reason: 'lesson chapterId empty');
        expect(l['content'], isA<String>(), reason: 'lesson content missing');
        expect((l['content'] as String).isNotEmpty, isTrue,
            reason: 'lesson content empty');
      }
    });

    test('all lesson IDs are prefixed with hi_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('hi_'),
            reason:
                'Hindi lesson IDs must use hi_ prefix for global uniqueness');
      }
    });

    test('lesson IDs are globally unique', () {
      final ids = lessons.map((l) => l['id'] as String).toSet();
      expect(ids.length, lessons.length, reason: 'duplicate lesson IDs');
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
        expect((l['xpReward'] as num).toInt(), greaterThanOrEqualTo(10),
            reason: 'lesson ${l['id']} xpReward too low');
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

  group('Hindi curriculum — content quality', () {
    test('every lesson content contains Devanagari text', () {
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
      // Common mojibake patterns: â€‹, Ã, ï¿½
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

  group('Hindi curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(hindiExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in hindiExercisesByLesson');
        expect(hindiExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in hindiExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch: '
                  'expected $lessonId, got ${ex.lessonId}');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = hindiExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Hindi curriculum');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in hindiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue,
              reason: 'exercise ${ex.id} is not valid: '
                  'type=${ex.type}, options=${ex.options.length}, '
                  'correctIndex=${ex.correctIndex}, items=${ex.items.length}, '
                  'acceptedAnswers=${ex.acceptedAnswers.length}, '
                  'pairs=${ex.pairs.length}');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in hindiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in hindiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (ex.type == ExerciseType.mcq ||
              ex.type == ExerciseType.fillBlank) {
            expect(ex.options.length, greaterThanOrEqualTo(2),
                reason: '${ex.id}: MCQ needs >= 2 options');
            expect(ex.correctIndex, isNotNull,
                reason: '${ex.id}: MCQ needs a correctIndex');
            expect(ex.correctIndex!, greaterThanOrEqualTo(0),
                reason: '${ex.id}: correctIndex < 0');
            expect(ex.correctIndex!, lessThan(ex.options.length),
                reason: '${ex.id}: correctIndex out of range');
          }
        }
      }
    });
  });

  group('Hindi curriculum — isolation from Sanskrit Exam Mode', () {
    test('Hindi lesson IDs do not collide with Sanskrit lesson IDs', () {
      // Sanskrit lessons use ls_ prefix; Hindi uses hi_ prefix.
      // Verify no overlap.
      final hindiIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in hindiIds) {
        expect(id.startsWith('hi_'), isTrue,
            reason: 'Hindi lesson ID $id does not use hi_ prefix');
        expect(id.startsWith('ls_'), isFalse,
            reason: 'Hindi lesson ID $id collides with Sanskrit ls_ prefix');
      }
    });

    test('Hindi chapter IDs do not collide with Sanskrit chapter IDs', () {
      final hindiChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in hindiChapterIds) {
        expect(id.startsWith('ch_hi_'), isTrue,
            reason: 'Hindi chapter ID $id does not use ch_hi_ prefix');
      }
    });
  });

  group('Hindi curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_hi_script');
      // Script chapter should have lessons about vowels, consonants, matras
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('hi_script_vowels'),
          reason: 'Level 0 must start with vowels');
      expect(scriptLessons, contains('hi_script_consonants'),
          reason: 'Level 0 must cover consonants');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_hi_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_hi_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_hi_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_hi_reading');
    });
  });
}
