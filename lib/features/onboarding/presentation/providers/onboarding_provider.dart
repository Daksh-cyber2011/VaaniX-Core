/// Onboarding Providers — Riverpod State Management
///
/// [onboardingRepositoryProvider]: provides OnboardingRepository.
/// [onboardingProvider]: the main StateNotifier for onboarding flow.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/onboarding/data/onboarding_repository.dart';
import 'package:vaanix_app/features/onboarding/domain/onboarding_state.dart';

/// Total number of onboarding pages (indices 0..5).
/// [nextPage] will not advance past this.
const int _kOnboardingPageCount = 6;

/// Provides [OnboardingRepository] backed by [LocalStorageService].
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return OnboardingRepository(storage);
});

/// Manages the full onboarding flow state.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._repo, this._analytics)
      : super(_hydrate(_repo));

  final OnboardingRepository _repo;
  final AnalyticsClient _analytics;

  static OnboardingState _hydrate(OnboardingRepository repo) {
    return OnboardingState(
      isComplete: repo.isOnboardingComplete(),
      // Hydrate companionName so a mid-onboarding app restart restores
      // the saved name. Previously this was omitted, causing the name to
      // silently revert to the default "Van" on re-entry.
      companionName: repo.getCompanionName(),
      dailyGoalMinutes: repo.getDailyGoal(),
      personalityMode: repo.getPersonalityMode(),
      selectedClass: repo.getSelectedClass(),
    );
  }

  void goToPage(int page) {
    final clamped = page.clamp(0, _kOnboardingPageCount - 1);
    state = state.copyWith(currentPage: clamped);
  }

  void nextPage() {
    if (state.currentPage >= _kOnboardingPageCount - 1) return;
    state = state.copyWith(currentPage: state.currentPage + 1);
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void setCompanionName(String name) {
    state = state.copyWith(companionName: name);
  }

  Future<void> confirmCompanionName() async {
    await _repo.saveCompanionName(state.resolvedName);
    nextPage();
  }

  void selectPersonalityMode(PersonalityMode mode) {
    state = state.copyWith(personalityMode: mode);
  }

  Future<void> confirmPersonalityMode() async {
    if (state.personalityMode == null) return;
    await _repo.savePersonalityMode(state.personalityMode!);
    nextPage();
  }

  void selectClass(CbseClass cbseClass) {
    state = state.copyWith(selectedClass: cbseClass);
  }

  Future<void> confirmSubjectSetup() async {
    if (state.selectedClass == null) return;
    await _repo.saveSelectedClass(state.selectedClass!);
    nextPage();
  }

  void selectDailyGoal(int minutes) {
    state = state.copyWith(dailyGoalMinutes: minutes);
  }

  Future<void> confirmDailyGoal() async {
    await _repo.saveDailyGoal(state.dailyGoalMinutes);
    nextPage();
  }

  void skipAuth() {
    nextPage();
  }

  Future<void> completeOnboarding() async {
    await _repo.markOnboardingComplete();
    _analytics.log(const AnalyticsEvent(AnalyticsEventName.onboardingCompleted));
    state = state.copyWith(isComplete: true);
  }
}

/// The main onboarding provider.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final repo = ref.watch(onboardingRepositoryProvider);
  return OnboardingNotifier(repo, ref.watch(analyticsClientProvider));
});
