/// Tamil Learn Mode Curriculum — Part E integrity tests.
///
/// Verifies the Tamil curriculum (assets/curriculum/learn/ta.json) is
/// structurally valid and respects Tamil-specific linguistic features
/// (Dravidian grammar, no grammatical gender, older/younger sibling
/// distinction, -க்கு/-இருந்து/-இல் postpositions).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/tamil_exercises.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

Map<String, dynamic> _loadTamilJson() {
  final file = File('assets/curriculum/learn/ta.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadTamilJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Tamil curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1);
    });

    test('language block matches Tamil catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'tamil');
      expect(lang['iso639_1'], 'te');
      expect(lang['englishName'], 'Tamil');
      expect(lang['nativeName'], 'తెలుగు');
      expect(lang['scriptName'], 'Tamil');
      expect(lang['scriptCode'], 'Telu');
      expect(lang['direction'], 'ltr');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part E: Tamil must ship at least one chapter');
    });
  });

  group('Tamil curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part E: Tamil ships 5 chapters (Levels 0-4)');
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

    test('all chapter IDs are prefixed with ch_ta_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_ta_'),
            reason: 'Tamil chapter IDs must use ch_ta_ prefix');
      }
    });
  });

  group('Tamil curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part E: Tamil ships a substantial course (>=15 lessons)');
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

    test('all lesson IDs are prefixed with ta_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('ta_'),
            reason:
                'Tamil lesson IDs must use ta_ prefix for global uniqueness');
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

  group('Tamil curriculum — content quality', () {
    test('every lesson content contains Tamil script', () {
      // Tamil Unicode range: \u0B80-\u0BFF
      final tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(tamilRegex.hasMatch(content), isTrue,
            reason: 'lesson ${l['id']} content has no Tamil text');
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
      // Tamil content (Tamil is \u0B80-\u0BFF)
      final devanagariRegex = RegExp(r'[\u0900-\u097F]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(devanagariRegex.hasMatch(content), isFalse,
            reason: 'lesson ${l['id']} contains Devanagari script — '
                'Tamil curriculum must use Tamil script only');
      }
    });
  });

  group('Tamil curriculum — Tamil-specific content', () {
    test('curriculum teaches Tamil-specific vocabulary (not Hindi)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Tamil uses சோறு (rice), அம்மா (mother), வணக்கம் (hello)
      expect(allContent.contains('அம்மா'), isTrue,
          reason: 'Tamil curriculum must teach அம்மா (mother) — '
              'distinct from Hindi माँ');
      expect(allContent.contains('வணக்கம்') || allContent.contains('வணக்கம்'),
          isTrue,
          reason: 'Tamil curriculum must teach வணக்கம் / வணக்கம்');
      expect(allContent.contains('சோறு'), isTrue,
          reason: 'Tamil curriculum must teach சோறு (rice)');
    });

    test('curriculum mentions the older/younger sibling distinction', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Tamil distinguishes அண்ணன் (older brother) from தம்பி (younger)
      expect(
          allContent.contains('அண்ணன்') && allContent.contains('தம்பி'), isTrue,
          reason: 'Tamil curriculum must teach older/younger brother '
              'distinction (அண்ணன்/தம்பி)');
    });

    test('curriculum mentions the no-gender feature (Dravidian)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.toLowerCase().contains('gender') ||
              allContent.contains('లింగం'),
          isTrue,
          reason: 'Tamil curriculum must teach the no-gender feature '
              '(Dravidian)');
    });

    test('curriculum mentions Tamil-specific postpositions', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.contains('-க்கு') || allContent.contains('எனக்கு'), isTrue,
          reason: 'Tamil curriculum must teach -க்கு postposition');
      expect(allContent.contains('-இருந்து') || allContent.contains('இருந்து'),
          isTrue,
          reason: 'Tamil curriculum must teach -இருந்து postposition');
      expect(allContent.contains('-இல்') || allContent.contains('வீட்டில்'),
          isTrue,
          reason: 'Tamil curriculum must teach -இல் postposition');
    });

    test('curriculum mentions Tamil cultural context', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Should mention Tamil states or cultural references
      expect(
          allContent.contains('சென்னை') ||
              allContent.contains('தமிழ்நாடு') ||
              allContent.contains('தமிழ்நாடு') ||
              allContent.contains('மகாபலிபுரம்'),
          isTrue,
          reason: 'Tamil curriculum should reference Tamil cultural context');
    });
  });

  group('Tamil curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(tamilExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in tamilExercisesByLesson');
        expect(tamilExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in tamilExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = tamilExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Tamil curriculum');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in tamilExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue, reason: 'exercise ${ex.id} is not valid');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in tamilExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in tamilExercisesByLesson.entries) {
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

    test('exercise explanations contain Tamil script (Tamil explanations)', () {
      final tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
      var tamilExplanationCount = 0;
      for (final entry in tamilExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (tamilRegex.hasMatch(ex.explanation!)) {
            tamilExplanationCount++;
          }
        }
      }
      expect(tamilExplanationCount, greaterThan(0),
          reason: 'At least some exercise explanations should be in Tamil');
    });
  });

  group('Tamil curriculum — isolation from other languages', () {
    test('Tamil lesson IDs do not collide with other languages', () {
      final tamilIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in tamilIds) {
        expect(id.startsWith('ta_'), isTrue,
            reason: 'Tamil lesson ID $id does not use ta_ prefix');
        expect(id.startsWith('hi_'), isFalse);
        expect(id.startsWith('bn_'), isFalse);
        expect(id.startsWith('mr_'), isFalse);
        expect(id.startsWith('ls_'), isFalse);
      }
    });

    test('Tamil chapter IDs do not collide with other languages', () {
      final tamilChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in tamilChapterIds) {
        expect(id.startsWith('ch_ta_'), isTrue,
            reason: 'Tamil chapter ID $id does not use ch_ta_ prefix');
        expect(id.startsWith('ch_hi_'), isFalse);
        expect(id.startsWith('ch_bn_'), isFalse);
        expect(id.startsWith('ch_mr_'), isFalse);
      }
    });

    test('Tamil exercise IDs do not collide with other languages', () {
      for (final entry in tamilExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.id.startsWith('ex_ta_'), isTrue,
              reason: 'Tamil exercise ${ex.id} must use ex_ta_ prefix');
          expect(ex.id.startsWith('ex_hi_'), isFalse);
          expect(ex.id.startsWith('ex_bn_'), isFalse);
          expect(ex.id.startsWith('ex_mr_'), isFalse);
        }
      }
    });
  });

  group('Tamil curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_ta_script');
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('ta_script_vowels'),
          reason: 'Level 0 must start with vowels');
      expect(scriptLessons, contains('ta_script_consonants'),
          reason: 'Level 0 must cover consonants');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_ta_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_ta_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_ta_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_ta_reading');
    });
  });
}
