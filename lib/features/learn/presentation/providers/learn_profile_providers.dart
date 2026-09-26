/// VaaniX Learn Mode — Learner Profile Providers (M2)
///
/// Riverpod wiring for the per-language learning profile:
/// - [learnProfileRepositoryProvider] — persistence accessor
/// - [learnerProfileProvider] — family by language; loads the persisted
///   profile (or safe defaults) and persists-then-updates on every change
/// - [learnerProfileConfiguredProvider] — has the learner explicitly
///   saved a profile for this language (drives the Learn screen prompt)
/// - [activeLearnerProfileProvider] — profile of the SELECTED language
///   (null when no Learn language is chosen)
///
/// Contract notes:
/// - Persist FIRST, then update state (the same lesson the progress
///   module learned the hard way — a failed write must not leave the
///   session state lying).
/// - No language selected → no active profile; every consumer must cope
///   with null (the planner falls back to defaults).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/curriculum_compatibility_providers.dart';

/// The M2 profile persistence accessor.
final learnProfileRepositoryProvider = Provider<LearnProfileRepository>(
  (ref) => LearnProfileRepository(ref.watch(localStorageServiceProvider)),
);

/// Per-language profile state: persisted profile, or safe defaults for a
/// brand-new learner. All mutations go through [LearnerProfileNotifier.update],
/// which persists before publishing the new state.
final learnerProfileProvider = StateNotifierProvider.family<
    LearnerProfileNotifier, LearnerProfile, LearnLanguage>(
  (ref, language) {
    ref.watch(curriculumCompatibilityProvider(language));
    return LearnerProfileNotifier(
      ref.watch(learnProfileRepositoryProvider),
      language,
    );
  },
);

class LearnerProfileNotifier extends StateNotifier<LearnerProfile> {
  LearnerProfileNotifier(this._repo, this._language)
      : super(_repo.getProfile(_language) ?? LearnerProfile.initial(_language));

  final LearnProfileRepository _repo;
  final LearnLanguage _language;

  /// Applies [transform], persists the result, then publishes it.
  /// No-op when the transform produces an equal profile (idempotent
  /// saves — no storage churn).
  Future<void> update(LearnerProfile Function(LearnerProfile) transform) async {
    final next = transform(state);
    if (next == state) return;
    await _repo.saveProfile(next);
    if (!mounted) return;
    state = next;
  }

  Future<void> setGoal(LearningGoal goal) =>
      update((p) => p.copyWith(goal: goal));

  Future<void> setDesiredLevel(DesiredLevel level) =>
      update((p) => p.copyWith(desiredLevel: level));

  Future<void> setPace(LearningPace pace) =>
      update((p) => p.copyWith(pace: pace));

  Future<void> setPracticeStyle(PracticeStyle style) =>
      update((p) => p.copyWith(practiceStyle: style));

  Future<void> setSelfReport(SelfReport report) =>
      update((p) => p.copyWith(selfReport: report));

  Future<void> setDailyGoalMinutes(int minutes) =>
      update((p) => p.copyWith(dailyGoalMinutes: minutes));

  /// Clears the persisted profile and resets to defaults (the profile
  /// screen's reset action). No-op when nothing was ever saved.
  Future<void> resetToDefaults() async {
    if (!_repo.hasProfile(_language)) return;
    await _repo.clearLanguage(_language);
    if (!mounted) return;
    state = LearnerProfile.initial(_language);
  }
}

/// True when the learner has EXPLICITLY saved a profile for [language]
/// (as opposed to running on implicit defaults). Rebuilds whenever the
/// profile notifier changes so a save flips it immediately.
final learnerProfileConfiguredProvider =
    Provider.family<bool, LearnLanguage>((ref, language) {
  ref.watch(learnerProfileProvider(language));
  return ref.watch(learnProfileRepositoryProvider).hasProfile(language);
});

/// The profile of the CURRENTLY SELECTED Learn language — `null` when no
/// language is chosen (legacy Sanskrit path). Consumers (planner context,
/// AI grounding) must treat null as "use defaults".
final activeLearnerProfileProvider = Provider<LearnerProfile?>((ref) {
  final selected = ref.watch(selectedLearnLanguageProvider);
  if (selected == null) return null;
  return ref.watch(learnerProfileProvider(selected));
});
