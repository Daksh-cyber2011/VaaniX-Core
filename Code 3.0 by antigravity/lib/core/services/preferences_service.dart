/// VaaniX Preferences Service
///
/// Typed wrapper over [SharedPreferences] for non-sensitive app settings
/// (theme, language, onboarding flags, daily goal, etc.).
///
/// Sensitive values (tokens) belong in [SecureStorageService], not here.
///
/// SharedPreferences is initialized in main.dart and injected via
/// [sharedPreferencesProvider]; this service takes the instance directly
/// so it can be unit-tested without Riverpod.

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // ── Onboarding ──────────────────────────────────────────────
  bool isOnboardingComplete() =>
      _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(AppConstants.keyOnboardingComplete, value);

  // ── Companion name ──────────────────────────────────────────
  String getCompanionName() =>
      _prefs.getString(AppConstants.keyUserCompanionName) ??
      AppConstants.companionDefaultName;

  Future<void> setCompanionName(String name) =>
      _prefs.setString(AppConstants.keyUserCompanionName, name);

  // ── Theme mode (string name of ThemeMode enum) ──────────────
  String getThemeMode() =>
      _prefs.getString(AppConstants.keyThemeMode) ?? 'system';

  Future<void> setThemeMode(String modeName) =>
      _prefs.setString(AppConstants.keyThemeMode, modeName);

  // ── Language ────────────────────────────────────────────────
  String getLanguage() => _prefs.getString(AppConstants.keyLanguage) ?? 'en';

  Future<void> setLanguage(String code) =>
      _prefs.setString(AppConstants.keyLanguage, code);

  // ── Daily goal ──────────────────────────────────────────────
  int getDailyGoalMinutes() =>
      _prefs.getInt(AppConstants.keyDailyGoalMinutes) ??
      AppConstants.defaultDailyGoalMinutes;

  Future<void> setDailyGoalMinutes(int minutes) =>
      _prefs.setInt(AppConstants.keyDailyGoalMinutes, minutes);

  // ── Personality mode ────────────────────────────────────────
  String? getPersonalityMode() =>
      _prefs.getString(AppConstants.keyPersonalityMode);

  Future<void> setPersonalityMode(String mode) =>
      _prefs.setString(AppConstants.keyPersonalityMode, mode);

  // ── Selected class ──────────────────────────────────────────
  int? getSelectedClass() => _prefs.getInt(AppConstants.keySelectedClass);

  Future<void> setSelectedClass(int value) =>
      _prefs.setInt(AppConstants.keySelectedClass, value);

  // ── Streak ──────────────────────────────────────────────────
  int getCurrentStreak() => _prefs.getInt(AppConstants.keyCurrentStreak) ?? 0;

  Future<void> setCurrentStreak(int value) =>
      _prefs.setInt(AppConstants.keyCurrentStreak, value);

  String? getLastActiveDate() => _prefs.getString(AppConstants.keyLastActiveDate);

  Future<void> setLastActiveDate(String isoDate) =>
      _prefs.setString(AppConstants.keyLastActiveDate, isoDate);

  // ── Generic pass-through (rare use; prefer typed accessors) ─
  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearAll() async {
    // Onboarding + companion identity survive a "clear settings" action.
    final keep = {
      AppConstants.keyOnboardingComplete,
      AppConstants.keyUserCompanionName,
    };
    final keys = _prefs.getKeys().where((k) => !keep.contains(k));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
