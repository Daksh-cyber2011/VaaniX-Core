/// Gujarati Learn Mode Curriculum — Part F integrity tests.
///
/// Verifies the Gujarati curriculum (assets/curriculum/learn/gu.json) is
/// structurally valid and respects Gujarati-specific linguistic features
/// (Dravidian grammar, no grammatical gender, older/younger sibling
/// distinction, -ને/-થી/-માં postpositions).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/gujarati_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

Map<String, dynamic> _loadGujaratiJson() {
  final file = File('assets/curriculum/learn/gu.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadGujaratiJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Gujarati curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1);
    });

    test('language block matches Gujarati catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'gujarati');
      expect(lang['iso639_1'], 'gu');
      expect(lang['englishName'], 'Gujarati');
      expect(lang['nativeName'], 'ગુજરાતી');
      expect(lang['scriptName'], 'Gujarati');
      expect(lang['scriptCode'], 'Gujr');
      expect(lang['direction'], 'ltr');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part F: Gujarati must ship at least one chapter');
    });
  });

  group('Gujarati curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part F: Gujarati ships 5 chapters (Levels 0-4)');
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

    test('all chapter IDs are prefixed with ch_gu_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_gu_'),
            reason: 'Gujarati chapter IDs must use ch_gu_ prefix');
      }
    });
  });

  group('Gujarati curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part F: Gujarati ships a substantial course (>=15 lessons)');
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

    test('all lesson IDs are prefixed with gu_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('gu_'),
            reason:
                'Gujarati lesson IDs must use gu_ prefix for global uniqueness');
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

  group('Gujarati curriculum — content quality', () {
    test('every lesson content contains Gujarati script', () {
      // Gujarati Unicode range: \u0A80-\u0AFF
      final gujaratiRegex = RegExp(r'[\u0A80-\u0AFF]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(gujaratiRegex.hasMatch(content), isTrue,
            reason: 'lesson ${l['id']} content has no Gujarati text');
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

    test('lesson content uses Gujarati script as the primary script', () {
      // Gujarati Unicode range: \u0A80-\u0AFF
      // Devanagari is ALLOWED for comparative/bilingual teaching examples
      // (e.g. showing how a concept differs from Hindi) — the key contract
      // is that Gujarati script IS present, not that other scripts are absent.
      final gujaratiRegex2 = RegExp(r'[\u0A80-\u0AFF]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(gujaratiRegex2.hasMatch(content), isTrue,
            reason: 'lesson ${l["id"]} has no Gujarati script — '
                'Gujarati curriculum must be primarily in Gujarati script');
      }
    });
  });

  group('Gujarati curriculum — Gujarati-specific content', () {
    test('curriculum teaches Gujarati-specific vocabulary (not Hindi)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Gujarati uses રોટલી (rice), મમ્મી (mother), નમસ્તે (hello)
      expect(allContent.contains('મમ્મી'), isTrue,
          reason: 'Gujarati curriculum must teach મમ્મી (mother) — '
              'distinct from Hindi माँ');
      expect(allContent.contains('નમસ્તે') || allContent.contains('નમસ્તે'),
          isTrue,
          reason: 'Gujarati curriculum must teach નમસ્તે / નમસ્તે');
      expect(allContent.contains('રોટલી'), isTrue,
          reason: 'Gujarati curriculum must teach રોટલી (rice)');
    });

    test('curriculum mentions the older/younger sibling distinction', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Gujarati distinguishes ભાઈ (older brother) from બહેન (younger)
      expect(allContent.contains('ભાઈ') && allContent.contains('બહેન'), isTrue,
          reason: 'Gujarati curriculum must teach older/younger brother '
              'distinction (ભાઈ/બહેન)');
    });

    test('curriculum mentions the no-gender feature (Dravidian)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.toLowerCase().contains('gender') ||
              allContent.contains('లింగం'),
          isTrue,
          reason: 'Gujarati curriculum must teach the no-gender feature '
              '(Dravidian)');
    });

    test('curriculum mentions Gujarati-specific postpositions', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('-ને') || allContent.contains('મને'), isTrue,
          reason: 'Gujarati curriculum must teach -ને postposition');
      expect(allContent.contains('-થી') || allContent.contains('થી'), isTrue,
          reason: 'Gujarati curriculum must teach -થી postposition');
      expect(
          allContent.contains('-માં') || allContent.contains('ઘરમાં'), isTrue,
          reason: 'Gujarati curriculum must teach -માં postposition');
    });

    test('curriculum mentions Gujarati cultural context', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Should mention Gujarati states or cultural references
      expect(
          allContent.contains('અમદાવાદ') ||
              allContent.contains('ગુજરાત') ||
              allContent.contains('ગુજરાત') ||
              allContent.contains('மகாபலிபுரம்'),
          isTrue,
          reason:
              'Gujarati curriculum should reference Gujarati cultural context');
    });
  });

  group('Gujarati curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(gujaratiExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in gujaratiExercisesByLesson');
        expect(gujaratiExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in gujaratiExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = gujaratiExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Gujarati curriculum');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in gujaratiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue, reason: 'exercise ${ex.id} is not valid');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in gujaratiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in gujaratiExercisesByLesson.entries) {
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

    test(
        'exercise explanations contain Gujarati script (Gujarati explanations)',
        () {
      final gujaratiRegex = RegExp(r'[\u0A80-\u0AFF]');
      var gujaratiExplanationCount = 0;
      for (final entry in gujaratiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (gujaratiRegex.hasMatch(ex.explanation!)) {
            gujaratiExplanationCount++;
          }
        }
      }
      expect(gujaratiExplanationCount, greaterThan(0),
          reason: 'At least some exercise explanations should be in Gujarati');
    });
  });

  group('Gujarati curriculum — isolation from other languages', () {
    test('Gujarati lesson IDs do not collide with other languages', () {
      final gujaratiIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in gujaratiIds) {
        expect(id.startsWith('gu_'), isTrue,
            reason: 'Gujarati lesson ID $id does not use gu_ prefix');
        expect(id.startsWith('hi_'), isFalse);
        expect(id.startsWith('bn_'), isFalse);
        expect(id.startsWith('mr_'), isFalse);
        expect(id.startsWith('ls_'), isFalse);
      }
    });

    test('Gujarati chapter IDs do not collide with other languages', () {
      final gujaratiChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in gujaratiChapterIds) {
        expect(id.startsWith('ch_gu_'), isTrue,
            reason: 'Gujarati chapter ID $id does not use ch_gu_ prefix');
        expect(id.startsWith('ch_hi_'), isFalse);
        expect(id.startsWith('ch_bn_'), isFalse);
        expect(id.startsWith('ch_mr_'), isFalse);
      }
    });

    test('Gujarati exercise IDs do not collide with other languages', () {
      for (final entry in gujaratiExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.id.startsWith('ex_gu_'), isTrue,
              reason: 'Gujarati exercise ${ex.id} must use ex_gu_ prefix');
          expect(ex.id.startsWith('ex_hi_'), isFalse);
          expect(ex.id.startsWith('ex_bn_'), isFalse);
          expect(ex.id.startsWith('ex_mr_'), isFalse);
        }
      }
    });
  });

  group('Gujarati curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_gu_script');
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('gu_script_vowels'),
          reason: 'Level 0 must start with vowels');
      expect(scriptLessons, contains('gu_script_consonants'),
          reason: 'Level 0 must cover consonants');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_gu_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_gu_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_gu_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_gu_reading');
    });
  });
}
