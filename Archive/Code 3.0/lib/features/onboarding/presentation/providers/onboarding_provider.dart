/// Onboarding Providers — Riverpod State Management
///
/// [onboardingRepositoryProvider]: provides OnboardingRepository.
/// [onboardingProvider]: the main StateNotifier for onboarding flow.
///
/// Uses manual Riverpod providers (no code generation) to match
/// the existing pattern in the project (no generated files yet).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_state.dart';

// ──────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDER
// ──────────────────────────────────────────────────────────────────

/// Provides [OnboardingRepository] backed by SharedPreferences.
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingRepository(prefs);
});

// ──────────────────────────────────────────────────────────────────
// ONBOARDING STATE NOTIFIER
// ──────────────────────────────────────────────────────────────────

/// Manages the full onboarding flow state.
/// Exposed via [onboardingProvider].
///
/// On construction, hydrates persisted choices from SharedPreferences
/// so mid-onboarding restarts and returning users see correct defaults.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._repo) : super(_hydrate(_repo));

  final OnboardingRepository _repo;

  /// Reads persisted state from SharedPreferences on first load.
  /// - `isComplete` is always hydrated so splash/router can guard correctly.
  /// - User choices (goal, class, personality) are restored if previously saved.
  /// - `companionName` starts blank so the name page text field is always empty.
  /// - `currentPage` starts at 0 (no partial-onboarding recovery yet).
  static OnboardingState _hydrate(OnboardingRepository repo) {
    return OnboardingState(
      isComplete: repo.isOnboardingComplete(),
      dailyGoalMinutes: repo.getDailyGoal(),
      personalityMode: repo.getPersonalityMode(),
      selectedClass: repo.getSelectedClass(),
      // companionName intentionally NOT hydrated — text field starts blank.
    );
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE NAVIGATION
  // ──────────────────────────────────────────────────────────────

  void goToPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void nextPage() {
    state = state.copyWith(currentPage: state.currentPage + 1);
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 1 — Name Van
  // ──────────────────────────────────────────────────────────────

  void setCompanionName(String name) {
    state = state.copyWith(companionName: name);
  }

  Future<void> confirmCompanionName() async {
    await _repo.saveCompanionName(state.resolvedName);
    nextPage();
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 2 — Personality Mode
  // ──────────────────────────────────────────────────────────────

  void selectPersonalityMode(PersonalityMode mode) {
    state = state.copyWith(personalityMode: mode);
  }

  Future<void> confirmPersonalityMode() async {
    if (state.personalityMode == null) return;
    await _repo.savePersonalityMode(state.personalityMode!);
    nextPage();
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 3 — Subject Setup
  // ──────────────────────────────────────────────────────────────

  void selectClass(CbseClass cbseClass) {
    state = state.copyWith(selectedClass: cbseClass);
  }

  Future<void> confirmSubjectSetup() async {
    if (state.selectedClass == null) return;
    await _repo.saveSelectedClass(state.selectedClass!);
    nextPage();
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 4 — Daily Goal
  // ──────────────────────────────────────────────────────────────

  void selectDailyGoal(int minutes) {
    state = state.copyWith(dailyGoalMinutes: minutes);
  }

  Future<void> confirmDailyGoal() async {
    await _repo.saveDailyGoal(state.dailyGoalMinutes);
    nextPage();
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 5 — Auth (skipped — real auth is a future milestone)
  // ──────────────────────────────────────────────────────────────

  void skipAuth() {
    nextPage();
  }

  // ──────────────────────────────────────────────────────────────
  // PAGE 6 — Nest Reveal (complete onboarding)
  // ──────────────────────────────────────────────────────────────

  Future<void> completeOnboarding() async {
    await _repo.markOnboardingComplete();
    state = state.copyWith(isComplete: true);
  }
}

/// The main onboarding provider.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return OnboardingNotifier(repo);
});
