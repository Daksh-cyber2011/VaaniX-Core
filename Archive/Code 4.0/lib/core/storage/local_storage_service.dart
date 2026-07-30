/// VaaniX Local Storage Service
///
/// Thin, typed wrapper around [SharedPreferences] that centralizes all
/// local-persistence access for the app.
///
/// Why this exists (instead of features reading SharedPreferences directly):
///   - One place to evolve storage (e.g. migrating to Hive/Isar later).
///   - One place to enforce key naming, defaults, and null-safety.
///   - Decouples repositories from the storage mechanism.
///
/// Keys live in [AppConstants] under the "STORAGE KEYS" section.

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  // ──────────────────────────────────────────────────────────────────
  // Onboarding
  // ──────────────────────────────────────────────────────────────────

  bool get isOnboardingComplete =>
      _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(AppConstants.keyOnboardingComplete, value);

  // ──────────────────────────────────────────────────────────────────
  // Companion / personality
  // ──────────────────────────────────────────────────────────────────

  String get companionName =>
      _prefs.getString(AppConstants.keyUserCompanionName) ??
      AppConstants.companionDefaultName;
  Future<void> setCompanionName(String name) =>
      _prefs.setString(AppConstants.keyUserCompanionName, name);

  String? get personalityMode =>
      _prefs.getString(AppConstants.keyPersonalityMode);
  Future<void> setPersonalityMode(String mode) =>
      _prefs.setString(AppConstants.keyPersonalityMode, mode);

  // ──────────────────────────────────────────────────────────────────
  // Learning profile
  // ──────────────────────────────────────────────────────────────────

  int? get selectedClass => _prefs.getInt(AppConstants.keySelectedClass);
  Future<void> setSelectedClass(int cbseClass) =>
      _prefs.setInt(AppConstants.keySelectedClass, cbseClass);

  int get dailyGoalMinutes =>
      _prefs.getInt(AppConstants.keyDailyGoalMinutes) ??
      AppConstants.defaultDailyGoalMinutes;
  Future<void> setDailyGoalMinutes(int minutes) =>
      _prefs.setInt(AppConstants.keyDailyGoalMinutes, minutes);

  // ──────────────────────────────────────────────────────────────────
  // Streaks / activity
  // ──────────────────────────────────────────────────────────────────

  int get currentStreak =>
      _prefs.getInt(AppConstants.keyCurrentStreak) ?? 0;
  Future<void> setCurrentStreak(int streak) =>
      _prefs.setInt(AppConstants.keyCurrentStreak, streak);

  String? get lastActiveDate =>
      _prefs.getString(AppConstants.keyLastActiveDate);
  Future<void> setLastActiveDate(String isoDate) =>
      _prefs.setString(AppConstants.keyLastActiveDate, isoDate);

  // ──────────────────────────────────────────────────────────────────
  // Preferences
  // ──────────────────────────────────────────────────────────────────

  String? get themeMode => _prefs.getString(AppConstants.keyThemeMode);
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(AppConstants.keyThemeMode, mode);

  String? get language => _prefs.getString(AppConstants.keyLanguage);
  Future<void> setLanguage(String language) =>
      _prefs.setString(AppConstants.keyLanguage, language);

  // ──────────────────────────────────────────────────────────────────
  // Raw pass-through (for edge cases & migrations)
  // ──────────────────────────────────────────────────────────────────

  bool containsKey(String key) => _prefs.containsKey(key);
  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
}
