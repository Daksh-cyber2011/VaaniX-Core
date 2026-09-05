/// Onboarding Repository — Data Layer
///
/// Persists user onboarding choices via the app-wide [LocalStorageService].
/// Called by [OnboardingNotifier] after each screen is completed.
///
/// Storage keys are owned by [LocalStorageService] (backed by
/// [AppConstants]); this repository deals only in domain types
/// ([PersonalityMode], [CbseClass]) and never touches SharedPreferences
/// directly, keeping it trivially testable with a fake storage service.

import '../../../core/storage/local_storage_service.dart';
import '../domain/onboarding_state.dart';

class OnboardingRepository {
  const OnboardingRepository(this._storage);

  final LocalStorageService _storage;

  // ──────────────────────────────────────────────────────────────
  // SAVE
  // ──────────────────────────────────────────────────────────────

  /// Persist the companion name the user chose.
  Future<void> saveCompanionName(String name) =>
      _storage.setCompanionName(name);

  /// Persist the selected personality mode.
  Future<void> savePersonalityMode(PersonalityMode mode) =>
      _storage.setPersonalityMode(mode.name);

  /// Persist the selected CBSE class.
  Future<void> saveSelectedClass(CbseClass cbseClass) =>
      _storage.setSelectedClass(cbseClass.value);

  /// Persist the daily goal in minutes.
  Future<void> saveDailyGoal(int minutes) =>
      _storage.setDailyGoalMinutes(minutes);

  /// Mark onboarding as fully complete.
  Future<void> markOnboardingComplete() =>
      _storage.setOnboardingComplete(true);

  // ──────────────────────────────────────────────────────────────
  // READ
  // ──────────────────────────────────────────────────────────────

  /// Returns true if the user has completed onboarding before.
  bool isOnboardingComplete() => _storage.isOnboardingComplete;

  /// Returns the stored companion name, or 'Van' if not set.
  String getCompanionName() => _storage.companionName;

  /// Returns the stored personality mode, or null if not set / invalid.
  PersonalityMode? getPersonalityMode() {
    final raw = _storage.personalityMode;
    if (raw == null) return null;
    return PersonalityMode.values.asNameMap()[raw];
  }

  /// Returns the stored CBSE class, or null if not set.
  CbseClass? getSelectedClass() {
    final raw = _storage.selectedClass;
    if (raw == null) return null;
    return CbseClass.fromValue(raw);
  }

  /// Returns the stored daily goal, or the default.
  int getDailyGoal() => _storage.dailyGoalMinutes;
}
