/// Active Curriculum Provider — Part A dispatch tests.
///
/// Verifies that [activeCurriculumProvider] correctly dispatches between
/// the legacy Sanskrit curriculum and the per-language Learn Mode
/// curriculum based on the selected language. Specifically:
///   - no selection → Sanskrit (4 chapters, 13 lessons)
///   - Hindi selected → Hindi curriculum (5 chapters, 20 lessons)
///   - Bengali selected → empty (Part B hasn't shipped yet)
///   - switching languages re-fetches the curriculum
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';

Future<ProviderContainer> _container(
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final prefsInstance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefsInstance)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('activeCurriculumProvider — no selection (legacy Sanskrit)', () {
    test('returns Sanskrit curriculum when no language is selected', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Sanskrit Exam Mode curriculum: 4 chapters, 13 lessons total
      expect(chapters, hasLength(4),
          reason: 'Legacy Sanskrit curriculum has 4 chapters');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_alphabet',
        'ch_words',
        'ch_sentences',
        'ch_grammar',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 13,
          reason: 'Legacy Sanskrit curriculum has 13 lessons');
    });
  });

  group('activeCurriculumProvider — Hindi selected (Part A)', () {
    test('returns Hindi curriculum when Hindi is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'hindi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Part A: Hindi ships 5 chapters, 20 lessons
      expect(chapters, hasLength(5),
          reason: 'Hindi curriculum has 5 chapters (Levels 0-4)');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_hi_script',
        'ch_hi_greet',
        'ch_hi_daily',
        'ch_hi_grammar',
        'ch_hi_reading',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 20, reason: 'Hindi curriculum has 20 lessons');
    });

    test('Hindi lessons use hi_ prefix (no collision with Sanskrit)', () async {
      final container = await _container(prefs: {
        'learn_language': 'hindi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('hi_'), isTrue,
              reason: 'Hindi lesson ${lesson.id} must use hi_ prefix');
          expect(lesson.id.startsWith('ls_'), isFalse,
              reason: 'Hindi lesson ${lesson.id} collides with Sanskrit');
        }
      }
    });

    test('every Hindi lesson has content (not empty)', () async {
      final container = await _container(prefs: {
        'learn_language': 'hindi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull,
              reason: 'Hindi lesson ${lesson.id} has null content');
          expect(lesson.content!.isNotEmpty, isTrue,
              reason: 'Hindi lesson ${lesson.id} has empty content');
        }
      }
    });
  });

  group('activeCurriculumProvider — Bengali selected (Part B)', () {
    test('returns Bengali curriculum when Bengali is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'bengali',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Part B: Bengali ships 5 chapters, 20 lessons
      expect(chapters, hasLength(5),
          reason: 'Bengali curriculum has 5 chapters (Levels 0-4)');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_bn_script',
        'ch_bn_greet',
        'ch_bn_daily',
        'ch_bn_grammar',
        'ch_bn_reading',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 20, reason: 'Bengali curriculum has 20 lessons');
    });

    test('Bengali lessons use bn_ prefix (no collision with Hindi or Sanskrit)',
        () async {
      final container = await _container(prefs: {
        'learn_language': 'bengali',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('bn_'), isTrue,
              reason: 'Bengali lesson ${lesson.id} must use bn_ prefix');
          expect(lesson.id.startsWith('hi_'), isFalse,
              reason: 'Bengali lesson ${lesson.id} collides with Hindi');
          expect(lesson.id.startsWith('ls_'), isFalse,
              reason: 'Bengali lesson ${lesson.id} collides with Sanskrit');
        }
      }
    });

    test('every Bengali lesson has content (not empty)', () async {
      final container = await _container(prefs: {
        'learn_language': 'bengali',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull,
              reason: 'Bengali lesson ${lesson.id} has null content');
          expect(lesson.content!.isNotEmpty, isTrue,
              reason: 'Bengali lesson ${lesson.id} has empty content');
        }
      }
    });
  });

  group('activeCurriculumProvider — Marathi selected (Part C)', () {
    test('returns Marathi curriculum when Marathi is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'marathi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Part C: Marathi ships 5 chapters, 20 lessons
      expect(chapters, hasLength(5),
          reason: 'Marathi curriculum has 5 chapters (Levels 0-4)');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_mr_script',
        'ch_mr_greet',
        'ch_mr_daily',
        'ch_mr_grammar',
        'ch_mr_reading',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 20, reason: 'Marathi curriculum has 20 lessons');
    });

    test('Marathi lessons use mr_ prefix (no collision with other languages)',
        () async {
      final container = await _container(prefs: {
        'learn_language': 'marathi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('mr_'), isTrue,
              reason: 'Marathi lesson ${lesson.id} must use mr_ prefix');
          expect(lesson.id.startsWith('hi_'), isFalse,
              reason: 'Marathi lesson ${lesson.id} collides with Hindi');
          expect(lesson.id.startsWith('bn_'), isFalse,
              reason: 'Marathi lesson ${lesson.id} collides with Bengali');
          expect(lesson.id.startsWith('ls_'), isFalse,
              reason: 'Marathi lesson ${lesson.id} collides with Sanskrit');
        }
      }
    });

    test('every Marathi lesson has content (not empty)', () async {
      final container = await _container(prefs: {
        'learn_language': 'marathi',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull,
              reason: 'Marathi lesson ${lesson.id} has null content');
          expect(lesson.content!.isNotEmpty, isTrue,
              reason: 'Marathi lesson ${lesson.id} has empty content');
        }
      }
    });
  });

  group('activeCurriculumProvider — Telugu selected (Part D)', () {
    test('returns Telugu curriculum when Telugu is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'telugu',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Part D: Telugu ships 5 chapters, 20 lessons
      expect(chapters, hasLength(5),
          reason: 'Telugu curriculum has 5 chapters (Levels 0-4)');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_te_script',
        'ch_te_greet',
        'ch_te_daily',
        'ch_te_grammar',
        'ch_te_reading',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 20, reason: 'Telugu curriculum has 20 lessons');
    });

    test('Telugu lessons use te_ prefix (no collision with other languages)',
        () async {
      final container = await _container(prefs: {
        'learn_language': 'telugu',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('te_'), isTrue,
              reason: 'Telugu lesson ${lesson.id} must use te_ prefix');
          expect(lesson.id.startsWith('hi_'), isFalse);
          expect(lesson.id.startsWith('bn_'), isFalse);
          expect(lesson.id.startsWith('mr_'), isFalse);
          expect(lesson.id.startsWith('ls_'), isFalse);
        }
      }
    });

    test('every Telugu lesson has content (not empty)', () async {
      final container = await _container(prefs: {
        'learn_language': 'telugu',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull,
              reason: 'Telugu lesson ${lesson.id} has null content');
          expect(lesson.content!.isNotEmpty, isTrue,
              reason: 'Telugu lesson ${lesson.id} has empty content');
        }
      }
    });
  });

  group('activeCurriculumProvider — Tamil selected (Part E)', () {
    test('returns Tamil curriculum when Tamil is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'tamil',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);

      // Part E: Tamil ships 5 chapters, 20 lessons
      expect(chapters, hasLength(5),
          reason: 'Tamil curriculum has 5 chapters (Levels 0-4)');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_ta_script',
        'ch_ta_greet',
        'ch_ta_daily',
        'ch_ta_grammar',
        'ch_ta_reading',
      ]);
      final lessonCount =
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
      expect(lessonCount, 20, reason: 'Tamil curriculum has 20 lessons');
    });

    test('Tamil lessons use ta_ prefix (no collision)', () async {
      final container = await _container(prefs: {
        'learn_language': 'tamil',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('ta_'), isTrue);
          expect(lesson.id.startsWith('hi_'), isFalse);
          expect(lesson.id.startsWith('bn_'), isFalse);
          expect(lesson.id.startsWith('mr_'), isFalse);
          expect(lesson.id.startsWith('te_'), isFalse);
          expect(lesson.id.startsWith('ls_'), isFalse);
        }
      }
    });

    test('every Tamil lesson has content (not empty)', () async {
      final container = await _container(prefs: {
        'learn_language': 'tamil',
      });
      addTearDown(container.dispose);

      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull);
          expect(lesson.content!.isNotEmpty, isTrue);
        }
      }
    });
  });

  group('activeCurriculumProvider — Gujarati selected (Part F)', () {
    test('returns Gujarati curriculum when Gujarati is selected', () async {
      final container = await _container(prefs: {
        'learn_language': 'gujarati',
      });
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'Gujarati curriculum has 5 chapters');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_gu_script',
        'ch_gu_greet',
        'ch_gu_daily',
        'ch_gu_grammar',
        'ch_gu_reading',
      ]);
    });

    test('Gujarati lessons use gu_ prefix', () async {
      final container = await _container(prefs: {'learn_language': 'gujarati'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('gu_'), isTrue);
        }
      }
    });

    test('every Gujarati lesson has content', () async {
      final container = await _container(prefs: {'learn_language': 'gujarati'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull);
          expect(lesson.content!.isNotEmpty, isTrue);
        }
      }
    });
  });

  group('activeCurriculumProvider — Urdu selected (Part G)', () {
    test('returns Urdu curriculum when Urdu is selected', () async {
      final container = await _container(prefs: {'learn_language': 'urdu'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5), reason: 'Urdu curriculum has 5 chapters');
      expect(chapters.map((c) => c.id).toList(), [
        'ch_ur_script',
        'ch_ur_greet',
        'ch_ur_daily',
        'ch_ur_grammar',
        'ch_ur_reading',
      ]);
    });

    test('Urdu lessons use ur_ prefix', () async {
      final container = await _container(prefs: {'learn_language': 'urdu'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.id.startsWith('ur_'), isTrue);
        }
      }
    });

    test('every Urdu lesson has content', () async {
      final container = await _container(prefs: {'learn_language': 'urdu'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      for (final ch in chapters) {
        for (final lesson in ch.lessons) {
          expect(lesson.content, isNotNull);
          expect(lesson.content!.isNotEmpty, isTrue);
        }
      }
    });
  });

  group('activeCurriculumProvider — additional shipped languages', () {
    test('returns Kannada curriculum when Kannada is selected', () async {
      final container = await _container(prefs: {'learn_language': 'kannada'});
      addTearDown(container.dispose);
      final chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'Kannada has a complete five-chapter curriculum');
    });
  });

  group('activeCurriculumProvider — reactivity', () {
    test('switching languages re-fetches the curriculum', () async {
      final container = await _container();
      addTearDown(container.dispose);

      // Start with no selection → Sanskrit
      var chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(4), reason: 'Initial: Sanskrit 4 chapters');

      // Select Hindi → should switch to Hindi curriculum
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.hindi);

      // Re-read (the FutureProvider should have re-fetched)
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Hindi: 5 chapters');

      // Switch to Bengali → should switch to Bengali curriculum (Part B)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.bengali);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Bengali: 5 chapters (Part B shipped)');

      // Switch to Marathi → should switch to Marathi curriculum (Part C)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.marathi);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Marathi: 5 chapters (Part C shipped)');

      // Switch to Telugu → should switch to Telugu curriculum (Part D)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.telugu);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Telugu: 5 chapters (Part D shipped)');

      // Switch to Tamil → should switch to Tamil curriculum (Part E)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.tamil);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Tamil: 5 chapters (Part E shipped)');

      // Switch to Gujarati → should switch to Gujarati curriculum (Part F)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.gujarati);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Gujarati: 5 chapters (Part F shipped)');

      // Switch to Urdu → should switch to Urdu curriculum (Part G shipped)
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.urdu);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Urdu: 5 chapters (Part G shipped)');

      // Switch to Kannada → should load its complete curriculum.
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.kannada);
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(5),
          reason: 'After selecting Kannada: 5 chapters');

      // Clear selection → back to Sanskrit
      await container.read(selectedLearnLanguageProvider.notifier).clear();
      chapters = await container.read(activeCurriculumProvider.future);
      expect(chapters, hasLength(4),
          reason: 'After clearing selection: back to Sanskrit 4 chapters');
    });
  });
}
