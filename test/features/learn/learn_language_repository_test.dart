/// Learn Mode Language Selection — persistence + provider tests (Part 0).
///
/// Verifies the repository round-trips a selection through SharedPreferences,
/// treats corrupt/unknown stored values as "no selection" rather than
/// crashing, and that the StateNotifier exposes the persisted value
/// reactively.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/learn_language_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final prefsInstance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefsInstance)],
  );
}

void main() {
  group('LearnLanguageRepository', () {
    test('selected is null when nothing has been persisted', () async {
      final prefs = await _freshPrefs();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      expect(repo.selected, isNull);
    });

    test('setSelected persists and selected reads it back', () async {
      final prefs = await _freshPrefs();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      await repo.setSelected(LearnLanguage.hindi);
      expect(repo.selected, LearnLanguage.hindi);

      await repo.setSelected(LearnLanguage.urdu);
      expect(repo.selected, LearnLanguage.urdu);
    });

    test('clearSelected removes the value', () async {
      final prefs = await _freshPrefs();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      await repo.setSelected(LearnLanguage.tamil);
      expect(repo.selected, LearnLanguage.tamil);

      await repo.clearSelected();
      expect(repo.selected, isNull);
    });

    test('a corrupt stored value is treated as no selection', () async {
      // Simulate a value left over from a future catalogue revision
      // (e.g., a language that was renamed or removed). The repository
      // must not crash; it must fall back to null so the Learn screen
      // shows the unselected state.
      SharedPreferences.setMockInitialValues({
        'learn_language': 'klingon',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      expect(repo.selected, isNull,
          reason: 'Unknown stored language names must not crash the repo.');
    });

    test('an empty stored string is treated as no selection', () async {
      SharedPreferences.setMockInitialValues({
        'learn_language': '',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      expect(repo.selected, isNull);
    });

    test('selection survives every catalogue language', () async {
      final prefs = await _freshPrefs();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      for (final language in LearnLanguage.values) {
        await repo.setSelected(language);
        expect(repo.selected, language, reason: '$language should round-trip');
      }
    });

    test('uses the dedicated keyLearnLanguage key (not keyLanguage)', () async {
      // Confirms Learn-language doesn't collide with the UI-language key
      // (an early audit caught them sharing a name in some sketches).
      final prefs = await _freshPrefs();
      final repo = LearnLanguageRepository(LocalStorageService(prefs));
      await repo.setSelected(LearnLanguage.bengali);
      expect(prefs.getString('learn_language'), 'bengali');
      expect(prefs.getString('app_language'), isNull,
          reason: 'UI language key must stay untouched');
    });
  });

  group('selectedLearnLanguageProvider', () {
    test('initial value is null when nothing persisted', () async {
      final container = await _container();
      addTearDown(container.dispose);
      expect(container.read(selectedLearnLanguageProvider), isNull);
    });

    test('initial value reflects a persisted selection', () async {
      final container = await _container(prefs: {
        'learn_language': 'bengali',
      });
      addTearDown(container.dispose);
      expect(
        container.read(selectedLearnLanguageProvider),
        LearnLanguage.bengali,
      );
    });

    test('select() persists and updates state', () async {
      final container = await _container();
      addTearDown(container.dispose);
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.kannada);
      expect(container.read(selectedLearnLanguageProvider),
          LearnLanguage.kannada);

      // Re-read from a fresh container to confirm it was persisted.
      final container2 = await _container();
      addTearDown(container2.dispose);
      expect(container2.read(selectedLearnLanguageProvider),
          LearnLanguage.kannada,
          reason: 'selection must survive provider disposal');
    });

    test('selecting the same language is a no-op', () async {
      final container = await _container(prefs: {
        'learn_language': 'odia',
      });
      addTearDown(container.dispose);
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.odia);
      expect(container.read(selectedLearnLanguageProvider),
          LearnLanguage.odia);
    });

    test('clear() removes the selection', () async {
      final container = await _container(prefs: {
        'learn_language': 'marathi',
      });
      addTearDown(container.dispose);
      await container.read(selectedLearnLanguageProvider.notifier).clear();
      expect(container.read(selectedLearnLanguageProvider), isNull);

      // Persisted too.
      final container2 = await _container();
      addTearDown(container2.dispose);
      expect(container2.read(selectedLearnLanguageProvider), isNull);
    });
  });

  group('selectedLearnLanguageSpecProvider', () {
    test('null when no language is selected', () async {
      final container = await _container();
      addTearDown(container.dispose);
      expect(container.read(selectedLearnLanguageSpecProvider), isNull);
    });

    test('returns the spec for the selected language', () async {
      final container = await _container(prefs: {
        'learn_language': 'urdu',
      });
      addTearDown(container.dispose);
      final spec = container.read(selectedLearnLanguageSpecProvider);
      expect(spec, isNotNull);
      expect(spec!.language, LearnLanguage.urdu);
      expect(spec.englishName, 'Urdu');
      expect(spec.isRTL, isTrue,
          reason:
              'Urdu must be flagged RTL for the picker and curriculum renderer');
    });
  });

  group('learnLanguageCatalogueProvider', () {
    test('exposes the locked 10-language list', () async {
      final container = await _container();
      addTearDown(container.dispose);
      final catalogue = container.read(learnLanguageCatalogueProvider);
      expect(catalogue, hasLength(10));
    });
  });
}
