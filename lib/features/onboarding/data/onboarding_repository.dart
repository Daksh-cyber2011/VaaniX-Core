/// Onboarding Repository — Data Layer
///
/// Persists user onboarding choices via [ILocalStorageService].
library;

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/onboarding/domain/onboarding_state.dart';

class OnboardingRepository {
  const OnboardingRepository(this._storage);

  final ILocalStorageService _storage;

  // ─── SAVE ──────────────────────────────────────────────────────────────────

  Future<void> saveCompanionName(String name) =>
      _storage.setCompanionName(name);

  Future<void> savePersonalityMode(PersonalityMode mode) =>
      _storage.setPersonalityMode(mode.name);

  Future<void> saveSelectedClass(CbseClass cbseClass) =>
      _storage.setSelectedClass(cbseClass.value);

  Future<void> saveDailyGoal(int minutes) =>
      _storage.setDailyGoalMinutes(minutes);

  Future<void> markOnboardingComplete() => _storage.setOnboardingComplete(true);

  /// Persists the page the learner is on so a mid-onboarding app restart
  /// resumes instead of restarting from page 0 (Phase 5).
  Future<void> saveCurrentPage(int page) =>
      _storage.setOnboardingPage(page);

  /// Removes the stored page index. Called when onboarding completes so
  /// no stale index survives for a future (re-)run of the flow.
  Future<void> clearCurrentPage() =>
      _storage.remove(AppConstants.keyOnboardingPage);

  // ─── READ ──────────────────────────────────────────────────────────────────

  bool isOnboardingComplete() => _storage.isOnboardingComplete;

  /// Last persisted page index, or null when none was saved. Values are
  /// returned raw — clamping against the page count is the notifier's
  /// job (it owns the page-count constant).
  int? getCurrentPage() => _storage.onboardingPage;

  String getCompanionName() => _storage.companionName;

  PersonalityMode? getPersonalityMode() {
    final raw = _storage.personalityMode;
    if (raw == null) return null;
    return PersonalityMode.values.asNameMap()[raw];
  }

  CbseClass? getSelectedClass() {
    final raw = _storage.selectedClass;
    if (raw == null) return null;
    return CbseClass.fromValue(raw);
  }

  int getDailyGoal() => _storage.dailyGoalMinutes;
}
