/// Learn Mode Language Catalogue — Part 0 invariants.
///
/// Guards the locked 10-language catalogue against drift. The master
/// brief locks the list at exactly these 10 languages in this order;
/// any change here must be an explicit, deliberate catalogue revision
/// (not a silent edit). Tests fail loudly if:
///   - the list shrinks, grows, or reorders
///   - a language's metadata is malformed
///   - two languages share a code / asset path / enum name
///   - Urdu is not the only RTL language
///   - a curriculum asset path doesn't follow the `learn/<code>.json` convention
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';

void main() {
  group('catalogue — locked 10-language list', () {
    test('exposes exactly the 10 VaaniX Learn Mode languages in order', () {
      expect(
        kLearnLanguageCatalogue.map((s) => s.language).toList(),
        [
          LearnLanguage.hindi,
          LearnLanguage.bengali,
          LearnLanguage.marathi,
          LearnLanguage.telugu,
          LearnLanguage.tamil,
          LearnLanguage.gujarati,
          LearnLanguage.urdu,
          LearnLanguage.kannada,
          LearnLanguage.malayalam,
          LearnLanguage.odia,
        ],
        reason: 'The 10-language list is LOCKED by the master brief. '
            'Do not add, remove, or reorder without an explicit Part '
            'directive.',
      );
    });

    test('catalogue length is exactly 10', () {
      expect(kLearnLanguageCatalogue, hasLength(10),
          reason: 'VaaniX Learn Mode ships 10 languages, no more, no less.');
    });
  });

  group('catalogue — per-language metadata integrity', () {
    test('every spec has a non-empty code, english name, native name, script', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(spec.code, isNotEmpty, reason: '${spec.language} code');
        expect(spec.englishName, isNotEmpty, reason: '${spec.language} englishName');
        expect(spec.nativeName, isNotEmpty, reason: '${spec.language} nativeName');
        expect(spec.scriptName, isNotEmpty, reason: '${spec.language} scriptName');
        expect(spec.scriptCode, isNotEmpty, reason: '${spec.language} scriptCode');
        expect(spec.iso639_1, isNotEmpty, reason: '${spec.language} iso639_1');
        expect(spec.iso639_2, isNotEmpty, reason: '${spec.language} iso639_2');
        expect(spec.curriculumAssetPath, isNotEmpty,
            reason: '${spec.language} curriculumAssetPath');
      }
    });

    test('every code is a 2-letter lower-case ISO 639-1 string', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(RegExp(r'^[a-z]{2}$').hasMatch(spec.code), isTrue,
            reason: '${spec.language} code "${spec.code}" must be 2 lowercase letters');
      }
    });

    test('every curriculum asset path is assets/curriculum/learn/<code>.json', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(
          spec.curriculumAssetPath,
          'assets/curriculum/learn/${spec.code}.json',
          reason: '${spec.language} asset path must follow the convention',
        );
      }
    });

    test('iso639_1 matches code for every language', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(spec.iso639_1, spec.code,
            reason: '${spec.language} iso639_1 must match code');
      }
    });

    test('every iso639_2 is a 3-letter lower-case string', () {
      for (final spec in kLearnLanguageCatalogue) {
        expect(RegExp(r'^[a-z]{3}$').hasMatch(spec.iso639_2), isTrue,
            reason: '${spec.language} iso639_2 "${spec.iso639_2}"');
      }
    });
  });

  group('catalogue — uniqueness', () {
    test('every language enum value is unique', () {
      final enums = kLearnLanguageCatalogue.map((s) => s.language).toSet();
      expect(enums.length, kLearnLanguageCatalogue.length,
          reason: 'duplicate LearnLanguage enum values');
    });

    test('every code is unique', () {
      final codes = kLearnLanguageCatalogue.map((s) => s.code).toSet();
      expect(codes.length, kLearnLanguageCatalogue.length,
          reason: 'duplicate ISO 639-1 codes');
    });

    test('every curriculum asset path is unique', () {
      final paths =
          kLearnLanguageCatalogue.map((s) => s.curriculumAssetPath).toSet();
      expect(paths.length, kLearnLanguageCatalogue.length,
          reason: 'duplicate curriculumAssetPath');
    });

    test('every native name is unique', () {
      final names =
          kLearnLanguageCatalogue.map((s) => s.nativeName).toSet();
      expect(names.length, kLearnLanguageCatalogue.length,
          reason: 'duplicate nativeName');
    });

    test('every english name is unique', () {
      final names =
          kLearnLanguageCatalogue.map((s) => s.englishName).toSet();
      expect(names.length, kLearnLanguageCatalogue.length,
          reason: 'duplicate englishName');
    });
  });

  group('catalogue — RTL contract', () {
    test('Urdu is the only RTL language', () {
      final rtl = kLearnLanguageCatalogue.where((s) => s.isRTL).toList();
      expect(rtl, hasLength(1));
      expect(rtl.single.language, LearnLanguage.urdu,
          reason: 'Urdu (Nastaliq) is the only RTL script in the catalogue. '
              'If another RTL language is added, update this test explicitly.');
    });

    test('every other language is LTR', () {
      final ltr = kLearnLanguageCatalogue
          .where((s) => s.scriptDirection == ScriptDirection.ltr)
          .toSet();
      expect(ltr.length, 9,
          reason: '9 of the 10 Learn languages are LTR');
    });
  });

  group('catalogue — lookup helpers', () {
    test('learnLanguageSpec returns the spec for every enum value', () {
      for (final language in LearnLanguage.values) {
        final spec = learnLanguageSpec(language);
        expect(spec.language, language);
      }
    });

    test('learnLanguageSpecByCode resolves every catalogue code', () {
      for (final expected in kLearnLanguageCatalogue) {
        final resolved = learnLanguageSpecByCode(expected.code);
        expect(resolved, isNotNull,
            reason: '${expected.code} should resolve');
        expect(resolved!.language, expected.language);
      }
    });

    test('learnLanguageSpecByCode is case-insensitive', () {
      expect(learnLanguageSpecByCode('HI')?.language, LearnLanguage.hindi);
      expect(learnLanguageSpecByCode('Ur')?.language, LearnLanguage.urdu);
    });

    test('learnLanguageSpecByCode returns null for unknown codes', () {
      expect(learnLanguageSpecByCode('xx'), isNull);
      expect(learnLanguageSpecByCode(''), isNull);
      expect(learnLanguageSpecByCode('english'), isNull);
    });

    test('learnLanguageSpecByName resolves every enum name', () {
      for (final expected in kLearnLanguageCatalogue) {
        final resolved = learnLanguageSpecByName(expected.language.name);
        expect(resolved, isNotNull,
            reason: '${expected.language.name} should resolve');
        expect(resolved!.language, expected.language);
      }
    });

    test('learnLanguageSpecByName returns null for unknown names', () {
      expect(learnLanguageSpecByName('sanskrit'), isNull,
          reason: 'Sanskrit is NOT in the Learn Mode catalogue — it lives '
              'in Exam Mode (assets/curriculum/v1.json).');
      expect(learnLanguageSpecByName(''), isNull);
      expect(learnLanguageSpecByName('not-a-language'), isNull);
    });
  });
}
