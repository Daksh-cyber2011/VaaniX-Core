/// VaaniX Learn Mode — Language Selection Providers (Part 0 Foundation)
///
/// Riverpod wiring for the Learn Mode language catalogue:
/// - [learnLanguageRepositoryProvider] — persistence accessor
/// - [selectedLearnLanguageProvider] — reactive current selection
/// - [learnLanguageCatalogueProvider] — the locked 10-language list
///
/// Curriculum dispatch providers ([learnCurriculumProvider],
/// [learnExercisesByLessonProvider]) live in `curriculum_loader.dart`
/// and `exercise_providers.dart` respectively, co-located with the
/// Exam Mode curriculum providers they extend.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/learn_language_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';

/// Provides the [LearnLanguageRepository] backed by shared preferences.
///
/// Single source of truth for the persisted Learn Mode language —
/// screens that need to read or change the selection depend on this,
/// not on a direct [SharedPreferences] lookup.
final learnLanguageRepositoryProvider = Provider<LearnLanguageRepository>(
  (ref) => LearnLanguageRepository(ref.watch(localStorageServiceProvider)),
);

/// Reactive state of the user's currently selected Learn Mode language.
///
/// `null` means no Learn language is selected — the Learn screen then
/// shows the legacy Sanskrit curriculum (Exam Mode content) plus a
/// "Choose your Learn language" call-to-action. Selecting a language
/// through [SelectedLearnLanguageNotifier.select] persists the choice
/// and triggers a rebuild of any widget watching this provider.
final selectedLearnLanguageProvider =
    StateNotifierProvider<SelectedLearnLanguageNotifier, LearnLanguage?>(
  (ref) => SelectedLearnLanguageNotifier(
    ref.watch(learnLanguageRepositoryProvider),
  ),
);

class SelectedLearnLanguageNotifier extends StateNotifier<LearnLanguage?> {
  SelectedLearnLanguageNotifier(this._repo) : super(_repo.selected);

  final LearnLanguageRepository _repo;

  /// Persists [language] as the current selection and updates listeners.
  ///
  /// Idempotent: selecting the same language again is a no-op (no
  /// analytics spam, no rebuild storm).
  Future<void> select(LearnLanguage language) async {
    if (state == language) return;
    await _repo.setSelected(language);
    state = language;
  }

  /// Clears the persisted selection (back to "no Learn language chosen").
  Future<void> clear() async {
    if (state == null) return;
    await _repo.clearSelected();
    state = null;
  }
}

/// The locked 10-language catalogue, exposed as a provider so widgets
/// (the picker, the Learn screen header) and tests can read it without
/// importing the constant directly.
final learnLanguageCatalogueProvider =
    Provider<List<LearnLanguageSpec>>((ref) => kLearnLanguageCatalogue);

/// Convenience provider: the spec for the currently selected language,
/// or `null` when no language is selected. Saves a watcher from having
/// to do the catalogue lookup itself.
final selectedLearnLanguageSpecProvider = Provider<LearnLanguageSpec?>((ref) {
  final selected = ref.watch(selectedLearnLanguageProvider);
  if (selected == null) return null;
  return learnLanguageSpec(selected);
});
