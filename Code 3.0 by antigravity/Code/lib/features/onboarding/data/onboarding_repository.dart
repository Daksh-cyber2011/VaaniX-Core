/// Onboarding Repository — Data Layer
///
/// Persists user onboarding choices to SharedPreferences.
/// Called by [OnboardingNotifier] after each screen is completed.
///
/// Keys come from [AppConstants] — never hardcode strings here.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/onboarding_state.dart';

class OnboardingRepository {
  const OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  // ──────────────────────────────────────────────────────────────
  // SAVE
  // ──────────────────────────────────────────────────────────────

  /// Persist the companion name the user chose.
  Future<void> saveCompanionName(String name) async {
    await _prefs.setString(AppConstants.keyUserCompanionName, name);
  }

  /// Persist the selected personality mode.
  Future<void> savePersonalityMode(PersonalityMode mode) async {
    await _prefs.setString(AppConstants.keyPersonalityMode, mode.name);
  }

  /// Persist the selected CBSE class.
  Future<void> saveSelectedClass(CbseClass cbseClass) async {
    await _prefs.setInt(AppConstants.keySelectedClass, cbseClass.value);
  }

  /// Persist the daily goal in minutes.
  Future<void> saveDailyGoal(int minutes) async {
    await _prefs.setInt(AppConstants.keyDailyGoalMinutes, minutes);
  }

  /// Mark onboarding as fully complete.
  Future<void> markOnboardingComplete() async {
    await _prefs.setBool(AppConstants.keyOnboardingComplete, true);
  }

  // ──────────────────────────────────────────────────────────────
  // READ
  // ──────────────────────────────────────────────────────────────

  /// Returns true if the user has completed onboarding before.
  bool isOnboardingComplete() =>
      _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

  /// Returns the stored companion name, or 'Van' if not set.
  String getCompanionName() =>
      _prefs.getString(AppConstants.keyUserCompanionName) ??
      AppConstants.companionDefaultName;

  /// Returns the stored personality mode, or null if not set.
  PersonalityMode? getPersonalityMode() {
    final raw = _prefs.getString(AppConstants.keyPersonalityMode);
    if (raw == null) return null;
    return PersonalityMode.values.asNameMap()[raw];
  }

  /// Returns the stored CBSE class, or null if not set.
  CbseClass? getSelectedClass() {
    final raw = _prefs.getInt(AppConstants.keySelectedClass);
    if (raw == null) return null;
    return CbseClass.fromValue(raw);
  }

  /// Returns the stored daily goal, or the default.
  int getDailyGoal() =>
      _prefs.getInt(AppConstants.keyDailyGoalMinutes) ??
      AppConstants.defaultDailyGoalMinutes;
}
