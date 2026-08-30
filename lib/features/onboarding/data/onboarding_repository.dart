/// Onboarding Repository — Data Layer
///
/// Persists user onboarding choices via [ILocalStorageService].

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

  // ─── READ ──────────────────────────────────────────────────────────────────

  bool isOnboardingComplete() => _storage.isOnboardingComplete;

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
