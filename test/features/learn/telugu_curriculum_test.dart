/// Telugu Learn Mode Curriculum — Part D integrity tests.
///
/// Verifies the Telugu curriculum (assets/curriculum/learn/te.json) is
/// structurally valid and respects Telugu-specific linguistic features
/// (Dravidian grammar, no grammatical gender, older/younger sibling
/// distinction, -కి/-నుండి/-లో postpositions).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/telugu_exercises.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

Map<String, dynamic> _loadTeluguJson() {
  final file = File('assets/curriculum/learn/te.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final json = _loadTeluguJson();
  final chapters = (json['chapters'] as List).cast<Map<String, dynamic>>();
  final lessons = <Map<String, dynamic>>[];
  for (final ch in chapters) {
    for (final l in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
      lessons.add(l);
    }
  }

  group('Telugu curriculum — schema & metadata', () {
    test('schemaVersion is 1', () {
      expect(json['schemaVersion'], 1);
    });

    test('language block matches Telugu catalogue spec', () {
      final lang = json['language'] as Map<String, dynamic>;
      expect(lang['enum'], 'telugu');
      expect(lang['iso639_1'], 'te');
      expect(lang['englishName'], 'Telugu');
      expect(lang['nativeName'], 'తెలుగు');
      expect(lang['scriptName'], 'Telugu');
      expect(lang['scriptCode'], 'Telu');
      expect(lang['direction'], 'ltr');
    });

    test('chapters array is non-empty', () {
      expect(chapters, isNotEmpty,
          reason: 'Part D: Telugu must ship at least one chapter');
    });
  });

  group('Telugu curriculum — chapter structure', () {
    test('has exactly 5 chapters (one per level)', () {
      expect(chapters, hasLength(5),
          reason: 'Part D: Telugu ships 5 chapters (Levels 0-4)');
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

    test('all chapter IDs are prefixed with ch_te_', () {
      for (final ch in chapters) {
        expect(ch['id'] as String, startsWith('ch_te_'),
            reason: 'Telugu chapter IDs must use ch_te_ prefix');
      }
    });
  });

  group('Telugu curriculum — lesson structure', () {
    test('has at least 15 lessons across all chapters', () {
      expect(lessons.length, greaterThanOrEqualTo(15),
          reason: 'Part D: Telugu ships a substantial course (>=15 lessons)');
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

    test('all lesson IDs are prefixed with te_', () {
      for (final l in lessons) {
        expect(l['id'] as String, startsWith('te_'),
            reason:
                'Telugu lesson IDs must use te_ prefix for global uniqueness');
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

  group('Telugu curriculum — content quality', () {
    test('every lesson content contains Telugu script', () {
      // Telugu Unicode range: \u0C00-\u0C7F
      final teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(teluguRegex.hasMatch(content), isTrue,
            reason: 'lesson ${l['id']} content has no Telugu text');
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
      // Telugu content (Telugu is \u0C00-\u0C7F)
      final devanagariRegex = RegExp(r'[\u0900-\u097F]');
      for (final l in lessons) {
        final content = l['content'] as String;
        expect(devanagariRegex.hasMatch(content), isFalse,
            reason: 'lesson ${l['id']} contains Devanagari script — '
                'Telugu curriculum must use Telugu script only');
      }
    });
  });

  group('Telugu curriculum — Telugu-specific content', () {
    test('curriculum teaches Telugu-specific vocabulary (not Hindi)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Telugu uses అన్నం (rice), అమ్మ (mother), నమస్తే (hello)
      expect(allContent.contains('అమ్మ'), isTrue,
          reason: 'Telugu curriculum must teach అమ్మ (mother) — '
              'distinct from Hindi माँ');
      expect(allContent.contains('నమస్తే') || allContent.contains('నమస్కారం'),
          isTrue,
          reason: 'Telugu curriculum must teach నమస్తే / నమస్కారం');
      expect(allContent.contains('అన్నం'), isTrue,
          reason: 'Telugu curriculum must teach అన్నం (rice)');
    });

    test('curriculum mentions the older/younger sibling distinction', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Telugu distinguishes అన్న (older brother) from తమ్ముడు (younger)
      expect(
          allContent.contains('అన్న') && allContent.contains('తమ్ముడు'), isTrue,
          reason: 'Telugu curriculum must teach older/younger brother '
              'distinction (అన్న/తమ్ముడు)');
    });

    test('curriculum mentions the no-gender feature (Dravidian)', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(
          allContent.toLowerCase().contains('gender') ||
              allContent.contains('లింగం'),
          isTrue,
          reason: 'Telugu curriculum must teach the no-gender feature '
              '(Dravidian)');
    });

    test('curriculum mentions Telugu-specific postpositions', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      expect(allContent.contains('-కి') || allContent.contains('నాకు'), isTrue,
          reason: 'Telugu curriculum must teach -కి postposition');
      expect(
          allContent.contains('-నుండి') || allContent.contains('నుండి'), isTrue,
          reason: 'Telugu curriculum must teach -నుండి postposition');
      expect(
          allContent.contains('-లో') || allContent.contains('ఇంట్లో'), isTrue,
          reason: 'Telugu curriculum must teach -లో postposition');
    });

    test('curriculum mentions Telugu cultural context', () {
      final allContent = lessons.map((l) => l['content'] as String).join('\n');
      // Should mention Telugu states or cultural references
      expect(
          allContent.contains('హైదరాబాద్') ||
              allContent.contains('తెలంగాణ') ||
              allContent.contains('ఆంధ్రప్రదేశ్') ||
              allContent.contains('తిరుపతి'),
          isTrue,
          reason: 'Telugu curriculum should reference Telugu cultural context');
    });
  });

  group('Telugu curriculum — exercise coverage', () {
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();

    test('every curriculum lesson has at least one exercise', () {
      for (final id in lessonIds) {
        expect(teluguExercisesByLesson.containsKey(id), isTrue,
            reason: 'lesson $id has no exercises in teluguExercisesByLesson');
        expect(teluguExercisesByLesson[id]!, isNotEmpty,
            reason: 'lesson $id has an empty exercise list');
      }
    });

    test('every exercise references its lesson correctly', () {
      for (final entry in teluguExercisesByLesson.entries) {
        final lessonId = entry.key;
        for (final ex in entry.value) {
          expect(ex.lessonId, lessonId,
              reason: 'exercise ${ex.id} lessonId mismatch');
        }
      }
    });

    test('every exercise has a unique ID', () {
      final allIds = teluguExercisesByLesson.values
          .expand((list) => list)
          .map((e) => e.id)
          .toList();
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, allIds.length,
          reason: 'duplicate exercise IDs across Telugu curriculum');
    });

    test('every exercise is well-formed (isValid)', () {
      for (final entry in teluguExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.isValid, isTrue, reason: 'exercise ${ex.id} is not valid');
        }
      }
    });

    test('every exercise has an explanation (feedback quality)', () {
      for (final entry in teluguExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.explanation, isNotNull,
              reason: 'exercise ${ex.id} has no explanation');
          expect(ex.explanation!.isNotEmpty, isTrue,
              reason: 'exercise ${ex.id} has an empty explanation');
        }
      }
    });

    test('MCQ exercises have >= 2 options and valid correctIndex', () {
      for (final entry in teluguExercisesByLesson.entries) {
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

    test('exercise explanations contain Telugu script (Telugu explanations)',
        () {
      final teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
      var teluguExplanationCount = 0;
      for (final entry in teluguExercisesByLesson.entries) {
        for (final ex in entry.value) {
          if (teluguRegex.hasMatch(ex.explanation!)) {
            teluguExplanationCount++;
          }
        }
      }
      expect(teluguExplanationCount, greaterThan(0),
          reason: 'At least some exercise explanations should be in Telugu');
    });
  });

  group('Telugu curriculum — isolation from other languages', () {
    test('Telugu lesson IDs do not collide with other languages', () {
      final teluguIds = lessons.map((l) => l['id'] as String).toSet();
      for (final id in teluguIds) {
        expect(id.startsWith('te_'), isTrue,
            reason: 'Telugu lesson ID $id does not use te_ prefix');
        expect(id.startsWith('hi_'), isFalse);
        expect(id.startsWith('bn_'), isFalse);
        expect(id.startsWith('mr_'), isFalse);
        expect(id.startsWith('ls_'), isFalse);
      }
    });

    test('Telugu chapter IDs do not collide with other languages', () {
      final teluguChapterIds = chapters.map((c) => c['id'] as String).toSet();
      for (final id in teluguChapterIds) {
        expect(id.startsWith('ch_te_'), isTrue,
            reason: 'Telugu chapter ID $id does not use ch_te_ prefix');
        expect(id.startsWith('ch_hi_'), isFalse);
        expect(id.startsWith('ch_bn_'), isFalse);
        expect(id.startsWith('ch_mr_'), isFalse);
      }
    });

    test('Telugu exercise IDs do not collide with other languages', () {
      for (final entry in teluguExercisesByLesson.entries) {
        for (final ex in entry.value) {
          expect(ex.id.startsWith('ex_te_'), isTrue,
              reason: 'Telugu exercise ${ex.id} must use ex_te_ prefix');
          expect(ex.id.startsWith('ex_hi_'), isFalse);
          expect(ex.id.startsWith('ex_bn_'), isFalse);
          expect(ex.id.startsWith('ex_mr_'), isFalse);
        }
      }
    });
  });

  group('Telugu curriculum — progression by level', () {
    test('chapter 1 is the script foundation (Level 0)', () {
      final ch0 = chapters.firstWhere((c) => c['order'] == 0);
      expect(ch0['id'], 'ch_te_script');
      final scriptLessons = (ch0['lessons'] as List)
          .map((l) => (l as Map<String, dynamic>)['id'] as String)
          .toList();
      expect(scriptLessons, contains('te_script_vowels'),
          reason: 'Level 0 must start with vowels');
      expect(scriptLessons, contains('te_script_consonants'),
          reason: 'Level 0 must cover consonants');
    });

    test('chapter 2 is greetings (Level 1)', () {
      final ch1 = chapters.firstWhere((c) => c['order'] == 1);
      expect(ch1['id'], 'ch_te_greet');
    });

    test('chapter 3 is daily life (Level 2)', () {
      final ch2 = chapters.firstWhere((c) => c['order'] == 2);
      expect(ch2['id'], 'ch_te_daily');
    });

    test('chapter 4 is grammar (Level 3)', () {
      final ch3 = chapters.firstWhere((c) => c['order'] == 3);
      expect(ch3['id'], 'ch_te_grammar');
    });

    test('chapter 5 is reading (Level 4)', () {
      final ch4 = chapters.firstWhere((c) => c['order'] == 4);
      expect(ch4['id'], 'ch_te_reading');
    });
  });
}
