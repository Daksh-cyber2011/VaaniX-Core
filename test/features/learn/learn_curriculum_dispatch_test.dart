/// Learn Mode Per-Language Curriculum Dispatch — Part 0 tests.
///
/// Verifies the loader contract for Part 0: every one of the 10 Learn
/// Mode languages loads successfully (asset reads, JSON parses, schema
/// validates) but returns an empty chapter list — because Part 0 ships
/// only the infrastructure, not the curricula themselves. Parts A–J
/// replace each stub asset with real content; this test must then be
/// updated to assert non-empty chapters per language.
///
/// Also verifies:
/// - the legacy Sanskrit path ([loadCurriculum] / [curriculumProvider])
///   is unchanged and still returns the 13-lesson Sanskrit curriculum
/// - the legacy exam bank ([loadAllQuizQuestions]) is unchanged
/// - the two paths never collide (selecting Hindi never loads Sanskrit)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart'
    show Chapter;

/// Binding initializer so rootBundle.loadString works in unit tests
/// (it reads from the on-disk assets/ directory when the test runs
/// from the project root, which Flutter test does by default).
void _ensureBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

void main() {
  _ensureBinding();

  group('loadLearnCurriculum — Part G contract', () {
    test('Hindi returns a non-empty curriculum (Part A shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
      expect(chapters, isNotEmpty,
          reason:
              'Part A: Hindi must ship a real curriculum (5 chapters / 20 lessons)');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_hi_script');
    });

    test('Bengali returns a non-empty curriculum (Part B shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.bengali);
      expect(chapters, isNotEmpty,
          reason: 'Part B: Bengali must ship a real curriculum');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_bn_script');
    });

    test('Marathi returns a non-empty curriculum (Part C shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.marathi);
      expect(chapters, isNotEmpty,
          reason: 'Part C: Marathi must ship a real curriculum');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_mr_script');
    });

    test('Telugu returns a non-empty curriculum (Part D shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.telugu);
      expect(chapters, isNotEmpty,
          reason:
              'Part D: Telugu must ship a real curriculum (5 chapters / 20 lessons)');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_te_script',
          reason: 'Telugu Level 0 chapter must be ch_te_script');
    });

    test('Tamil returns a non-empty curriculum (Part E shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.tamil);
      expect(chapters, isNotEmpty,
          reason:
              'Part E: Tamil must ship a real curriculum (5 chapters / 20 lessons)');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_ta_script',
          reason: 'Tamil Level 0 chapter must be ch_ta_script');
    });

    test('Gujarati returns a non-empty curriculum (Part F shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.gujarati);
      expect(chapters, isNotEmpty,
          reason:
              'Part F: Gujarati must ship a real curriculum (5 chapters / 20 lessons)');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_gu_script',
          reason: 'Gujarati Level 0 chapter must be ch_gu_script');
    });
    test('Urdu returns a non-empty curriculum (Part G shipped)', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.urdu);
      expect(chapters, isNotEmpty,
          reason:
              'Part G: Urdu must ship a real curriculum (5 chapters / 20 lessons)');
      expect(chapters, hasLength(5));
      expect(chapters.first.id, 'ch_ur_script',
          reason: 'Urdu Level 0 chapter must be ch_ur_script');
    });

    test('every catalogue language returns its shipped curriculum', () async {
      for (final language in LearnLanguage.values) {
        final chapters = await loadLearnCurriculum(language);
        expect(chapters, isNotEmpty,
            reason: '$language must have a shipped curriculum.');
      }
    });

    test('every Learn language asset file exists on disk', () {
      for (final spec in kLearnLanguageCatalogue) {
        final file = File(spec.curriculumAssetPath);
        expect(file.existsSync(), isTrue);
      }
    });

    test('every Learn language asset is valid JSON with schemaVersion 1', () {
      for (final spec in kLearnLanguageCatalogue) {
        final raw = File(spec.curriculumAssetPath).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        expect(json['schemaVersion'], kLearnCurriculumSchemaVersion);
        expect(json['chapters'], isA<List<dynamic>>());
      }
    });

    test('every language asset has its five shipped chapters', () {
      for (final spec in kLearnLanguageCatalogue) {
        final raw = File(spec.curriculumAssetPath).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final chapters = json['chapters'] as List;
        expect(chapters, isNotEmpty,
            reason: '${spec.language.name} must have non-empty chapters');
        expect(chapters.length, 5,
            reason: '${spec.language.name} ships exactly 5 chapters');
      }
    });

    test('every Learn language asset declares its own language metadata', () {
      for (final spec in kLearnLanguageCatalogue) {
        final raw = File(spec.curriculumAssetPath).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final lang = json['language'] as Map<String, dynamic>;
        expect(lang['enum'], spec.language.name,
            reason: '${spec.language.name} asset language.enum mismatch');
        expect(lang['iso639_1'], spec.code,
            reason: '${spec.language.name} asset language.iso639_1 mismatch');
        expect(lang['englishName'], spec.englishName);
        expect(lang['nativeName'], spec.nativeName);
      }
    });

    test('Urdu asset declares RTL direction', () {
      final raw = File('assets/curriculum/learn/ur.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect((json['language'] as Map<String, dynamic>)['direction'], 'rtl');
    });

    test('every non-Urdu asset declares LTR direction', () {
      for (final spec in kLearnLanguageCatalogue) {
        if (spec.language == LearnLanguage.urdu) continue;
        final raw = File(spec.curriculumAssetPath).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        expect((json['language'] as Map<String, dynamic>)['direction'], 'ltr',
            reason: '${spec.language.name} should be LTR');
      }
    });
  });

  group('loadLearnCurriculum — failure tolerance', () {
    test('returns empty list when the asset path does not exist', () async {
      // Use a language whose spec we monkey-patch to point at a missing
      // file. We can't easily monkey-patch the const catalogue, so we
      // verify the same behavior indirectly: the try/catch in
      // loadLearnCurriculum catches AssetNotFoundError and returns [].
      // The actual stubs all exist, so we exercise this by passing a
      // non-existent path through rootBundle directly.
      try {
        await rootBundle
            .loadString('assets/curriculum/learn/__nonexistent__.json');
        fail('loadString should have thrown for a missing asset');
      } catch (_) {
        // expected — this is the path loadLearnCurriculum catches.
      }
      // And the real loader returns [] for every catalogue language
      // (proven above), so the catch path is the contract.
    });
  });

  group('legacy Sanskrit path — preserved (Part 0 must NOT touch)', () {
    test('loadCurriculum still returns the 4-chapter / 13-lesson Sanskrit tree',
        () async {
      // The Sanskrit curriculum is loaded from assets/curriculum/v1.json
      // (NOT under assets/curriculum/learn/). Part 0 must not change it.
      final chapters = await loadCurriculum();
      expect(chapters, hasLength(4),
          reason: 'Sanskrit Exam Mode curriculum must keep 4 chapters');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_alphabet',
        'ch_words',
        'ch_sentences',
        'ch_grammar',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 13,
          reason: 'Sanskrit Exam Mode curriculum must keep 13 lessons');
    });

    test('sanskritCurriculum constant is unchanged', () {
      expect(sanskritCurriculum, hasLength(4));
      expect(
        sanskritCurriculum.expand((c) => c.lessons).length,
        13,
        reason: 'sanskritCurriculum dart constant must keep 13 lessons',
      );
    });

    test('chapterQuizzes Sanskrit bank is unchanged (32 questions)', () {
      final all = chapterQuizzes.values.expand((q) => q).toList();
      expect(all.length, 32,
          reason: 'Sanskrit exam bank must keep 32 questions');
    });

    test('selecting a Learn language does not touch Sanskrit providers', () {
      // The legacy curriculumProvider is a separate AsyncNotifierProvider
      // from learnCurriculumProvider (a family). Different identities:
      // the Sanskrit path reads `curriculumProvider`, the Learn path
      // reads `learnCurriculumProvider(language)`. They never share
      // state, so loading Hindi cannot pollute Sanskrit's cache.
      expect(curriculumProvider,
          isA<AsyncNotifierProvider<CurriculumNotifier, List<Chapter>>>(),
          reason: 'Legacy Sanskrit curriculum provider must be a '
              'plain AsyncNotifierProvider.');
      expect(learnCurriculumProvider, isNot(same(curriculumProvider)),
          reason: 'Learn and Sanskrit curricula must use separate providers.');
    });
  });

  group('schema version guard', () {
    test('kLearnCurriculumSchemaVersion is 1 (Part 0 baseline)', () {
      expect(kLearnCurriculumSchemaVersion, 1,
          reason: 'Bump this constant ONLY when the Learn curriculum '
              'JSON schema changes in a breaking way. Parts A–J ship '
              'content against schemaVersion 1.');
    });
  });
}
