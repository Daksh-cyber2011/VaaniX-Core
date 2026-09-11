/// M9 — All-Ten-Languages Support Matrix (Master Brief §74 checklist).
///
/// For EVERY language in the locked catalogue, verifies the full
/// support checklist:
///   language profile / script / direction          → catalogue spec
///   knowledge data (curriculum)                    → assets JSON
///   content mapping (lesson ↔ concept anchors)     → id conventions
///   exercise support                               → exercise banks
///   diagnostic support (banks derive from curriculum; non-empty here)
///   planner support (graph derives from curriculum; non-empty here)
///   mastery support (mastery keys off lesson ids — present)
///   milestones (ordinal criteria resolvable — 5 chapters)
///
/// Plus the §76 Urdu RTL guard, §77 Indic Unicode safety (no mojibake,
/// no wrong-script characters) and §84 Exam Mode isolation (Learn
/// assets never touch the Sanskrit Exam Mode path).
///
/// Shared engine + language-specific DATA only — this test itself
/// contains zero per-language logic beyond data expectations
/// (Master Brief §74 "must not require HindiLearningEngine …").
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/bengali_exercises.dart';
import 'package:vaanix_app/features/learn/data/gujarati_exercises.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/data/kannada_exercises.dart';
import 'package:vaanix_app/features/learn/data/malayalam_exercises.dart';
import 'package:vaanix_app/features/learn/data/marathi_exercises.dart';
import 'package:vaanix_app/features/learn/data/odia_exercises.dart';
import 'package:vaanix_app/features/learn/data/tamil_exercises.dart';
import 'package:vaanix_app/features/learn/data/telugu_exercises.dart';
import 'package:vaanix_app/features/learn/data/urdu_exercises.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';

/// ISO 15924 block ranges used by the M5 generated-content validator
/// (mirrored here for §77 Unicode safety checks).
const Map<String, (int, int)> kScriptBlocks = {
  'Deva': (0x0900, 0x097F),
  'Beng': (0x0980, 0x09FF),
  'Gujr': (0x0A80, 0x0AFF),
  'Orya': (0x0B00, 0x0B7F),
  'Taml': (0x0B80, 0x0BFF),
  'Telu': (0x0C00, 0x0C7F),
  'Knda': (0x0C80, 0x0CFF),
  'Mlym': (0x0D00, 0x0D7F),
  'Arab': (0x0600, 0x06FF),
};

bool _touchesScriptBlock(String text, String scriptCode) {
  final (start, end) = kScriptBlocks[scriptCode]!;
  return text.runes.any((r) => r >= start && r <= end);
}

bool _touchesForeignIndicBlock(String text, String ownScript) {
  for (final entry in kScriptBlocks.entries) {
    if (entry.key == ownScript) continue;
    final (start, end) = entry.value;
    if (text.runes.any((r) => r >= start && r <= end)) return true;
  }
  return false;
}

final _banks = <String, Map<String, List<dynamic>>>{
  'hi': hindiExercisesByLesson,
  'bn': bengaliExercisesByLesson,
  'mr': marathiExercisesByLesson,
  'te': teluguExercisesByLesson,
  'ta': tamilExercisesByLesson,
  'gu': gujaratiExercisesByLesson,
  'ur': urduExercisesByLesson,
  'kn': kannadaExercisesByLesson,
  'ml': malayalamExercisesByLesson,
  'or': odiaExercisesByLesson,
};

void main() {
  group('M9 catalogue — language profile / script / direction (§74)', () {
    test('exactly 10 languages, locked order', () {
      expect(kLearnLanguageCatalogue.length, 10);
      expect(
        kLearnLanguageCatalogue.map((s) => s.code).toList(),
        ['hi', 'bn', 'mr', 'te', 'ta', 'gu', 'ur', 'kn', 'ml', 'or'],
      );
    });

    test('Urdu is the ONLY RTL language (§76)', () {
      for (final spec in kLearnLanguageCatalogue) {
        if (spec.language == LearnLanguage.urdu) {
          expect(spec.isRTL, isTrue, reason: 'Urdu must remain RTL');
          expect(spec.scriptCode, 'Arab');
        } else {
          expect(spec.isRTL, isFalse,
              reason: '${spec.code} must stay LTR');
        }
      }
    });

    test('every spec has catalogue metadata + asset path', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(spec.nativeName, isNotEmpty);
        expect(spec.scriptName, isNotEmpty);
        expect(spec.iso639_2, isNotEmpty);
        expect(spec.curriculumAssetPath,
            'assets/curriculum/learn/${spec.code}.json');
      }
    });
  });

  group('M9 per-language support matrix (§74)', () {
    for (final spec in kLearnLanguageCatalogue) {
      final code = spec.code;

      test('$code: curriculum knowledge data ships (5 chapters, 20 lessons)',
          () {
        final file = File('assets/curriculum/learn/$code.json');
        expect(file.existsSync(), isTrue,
            reason: '$code curriculum asset missing');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(json['schemaVersion'], 1);

        final lang = json['language'] as Map<String, dynamic>;
        expect(lang['enum'], spec.language.name);
        expect(lang['iso639_1'], code);
        expect(lang['direction'], spec.isRTL ? 'rtl' : 'ltr');

        final chapters =
            (json['chapters'] as List).cast<Map<String, dynamic>>();
        expect(chapters.length, 5,
            reason: '$code must ship the 5-chapter ladder so ordinal '
                'milestone criteria resolve for every language');

        var lessonCount = 0;
        for (final ch in chapters) {
          expect(ch['id'], isNotNull);
          for (final l
              in (ch['lessons'] as List).cast<Map<String, dynamic>>()) {
            lessonCount++;
            expect(l['id'], startsWith('${code}_'),
                reason: '$code lesson ids must be language-prefixed');
            expect((l['content'] as String).length, greaterThan(800),
                reason: '${l['id']} content must be substantive');
            expect(l['difficulty'], isIn(['beginner', 'intermediate', 'advanced']));
          }
        }
        expect(lessonCount, 20, reason: '$code must ship 20 lessons');
      });

      test('$code: every lesson has authored exercises (§74 exercise support)',
          () {
        final file = File('assets/curriculum/learn/$code.json');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final bank = _banks[code]!;
        for (final ch in (json['chapters'] as List)) {
          for (final l in (ch as Map<String, dynamic>)['lessons'] as List) {
            final id = (l as Map<String, dynamic>)['id'] as String;
            final exercises = bank[id];
            expect(exercises, isNotNull,
                reason: '$id has no exercises in the $code bank');
            // Parts A–G ship 2–4 per lesson; Parts H–J (M9) guarantee 3+.
            final minimum = const {'kn', 'ml', 'or'}.contains(code) ? 3 : 2;
            expect(exercises!.length, greaterThanOrEqualTo(minimum),
                reason: '$id ships only ${exercises.length} exercises '
                    '(floor: $minimum)');
            for (final ex in exercises) {
              expect(ex.lessonId, id,
                  reason: 'exercise ${ex.id} must anchor to $id');
            }
          }
        }
      });

      test('$code: native script is correct + no mojibake (§77)', () {
        final file = File('assets/curriculum/learn/$code.json');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final ch in (json['chapters'] as List)) {
          for (final l in (ch as Map<String, dynamic>)['lessons'] as List) {
            final lesson = l as Map<String, dynamic>;
            final title = lesson['title'] as String;
            final content = lesson['content'] as String;
            expect(_touchesScriptBlock(title, spec.scriptCode), isTrue,
                reason: '${lesson['id']} title must use ${spec.scriptCode}');
            expect(_touchesScriptBlock(content, spec.scriptCode), isTrue,
                reason: '${lesson['id']} content must use ${spec.scriptCode}');
            // §77 mojibake guard — a hard M9 guarantee for the new
            // languages. Parts A–G legitimately quote other scripts
            // inside cross-language comparisons (e.g. Urdu lessons
            // noting shared Hindi vocabulary), so the negative check
            // is scoped to the M9 set only.
            if (const {'kn', 'ml', 'or'}.contains(code)) {
              expect(_touchesForeignIndicBlock(content, spec.scriptCode),
                  isFalse,
                  reason: '${lesson['id']} content contains characters from '
                      'a foreign Indic/Arabic block (mojibake guard §77)');
            }
          }
        }
      });

      test('$code: milestone + planner + mastery support derivable (§74)',
          () {
        final file = File('assets/curriculum/learn/$code.json');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final chapters =
            (json['chapters'] as List).cast<Map<String, dynamic>>();
        // Milestones reference chapter ORDINALS 1..5 — each shipped
        // curriculum must expose five ordered chapters so the SAME
        // criteria resolve for every language.
        final orders = chapters.map((c) => c['order'] as int).toList()
          ..sort();
        expect(orders, [0, 1, 2, 3, 4]);
        // Planner graph + diagnostic banks derive from (chapter,
        // lesson) structure — non-empty curriculum is the support gate.
        expect(chapters.any((c) => (c['lessons'] as List).isNotEmpty),
            isTrue);
      });
    }
  });

  group('M9 Exam Mode isolation (§84 regression guard)', () {
    test('Learn curricula never leak into the Sanskrit Exam Mode path', () {
      for (final code in _banks.keys) {
        final file = File('assets/curriculum/learn/$code.json');
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final ch in (json['chapters'] as List)) {
          for (final l in (ch as Map<String, dynamic>)['lessons'] as List) {
            final id = (l as Map<String, dynamic>)['id'] as String;
            expect(id.startsWith('ls_'), isFalse,
                reason: '$id must never use the Sanskrit Exam Mode `ls_` '
                    'prefix (§84 Exam Mode protection)');
          }
        }
      }
    });

    test('all 10 language banks stay disjoint (one bank per lesson id)',
        () {
      final seen = <String, String>{};
      _banks.forEach((code, bank) {
        for (final lessonId in bank.keys) {
          final owner = seen[lessonId];
          expect(owner, isNull,
              reason: 'lesson id $lessonId claimed by both '
                  '$owner and $code banks');
          seen[lessonId] = code;
        }
      });
    });
  });
}
