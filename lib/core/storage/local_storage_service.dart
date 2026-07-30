/// VaaniX Local Storage Service Implementation
///
/// Typed wrapper around [SharedPreferences] implementing [ILocalStorageService].

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

class LocalStorageService implements ILocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  // ─── Onboarding ────────────────────────────────────────────────────────────

  @override
  bool get isOnboardingComplete =>
      _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(AppConstants.keyOnboardingComplete, value);

  // ─── Companion / Personality ───────────────────────────────────────────────

  @override
  String get companionName =>
      _prefs.getString(AppConstants.keyUserCompanionName) ??
      AppConstants.companionDefaultName;

  @override
  Future<void> setCompanionName(String name) =>
      _prefs.setString(AppConstants.keyUserCompanionName, name);

  @override
  String? get personalityMode =>
      _prefs.getString(AppConstants.keyPersonalityMode);

  @override
  Future<void> setPersonalityMode(String mode) =>
      _prefs.setString(AppConstants.keyPersonalityMode, mode);

  // ─── Learning Profile ──────────────────────────────────────────────────────

  @override
  int? get selectedClass => _prefs.getInt(AppConstants.keySelectedClass);

  @override
  Future<void> setSelectedClass(int cbseClass) =>
      _prefs.setInt(AppConstants.keySelectedClass, cbseClass);

  @override
  int get dailyGoalMinutes =>
      _prefs.getInt(AppConstants.keyDailyGoalMinutes) ??
      AppConstants.defaultDailyGoalMinutes;

  @override
  Future<void> setDailyGoalMinutes(int minutes) =>
      _prefs.setInt(AppConstants.keyDailyGoalMinutes, minutes);

  // ─── Streaks / Activity ─────────────────────────────────────────────────────

  @override
  int get currentStreak =>
      _prefs.getInt(AppConstants.keyCurrentStreak) ?? 0;

  @override
  Future<void> setCurrentStreak(int streak) =>
      _prefs.setInt(AppConstants.keyCurrentStreak, streak);

  @override
  String? get lastActiveDate =>
      _prefs.getString(AppConstants.keyLastActiveDate);

  @override
  Future<void> setLastActiveDate(String isoDate) =>
      _prefs.setString(AppConstants.keyLastActiveDate, isoDate);

  // ─── XP & Progress ────────────────────────────────────────────────────────

  @override
  int get xpTotal => _prefs.getInt(AppConstants.keyXpTotal) ?? 0;

  @override
  Future<void> setXpTotal(int xp) =>
      _prefs.setInt(AppConstants.keyXpTotal, xp);

  @override
  List<String> get completedLessonIds =>
      _prefs.getStringList(AppConstants.keyCompletedLessonIds) ?? const [];

  @override
  Future<void> setCompletedLessonIds(List<String> ids) =>
      _prefs.setStringList(AppConstants.keyCompletedLessonIds, ids);

  @override
  List<String> get completedQuizIds =>
      _prefs.getStringList(AppConstants.keyCompletedQuizIds) ?? const [];

  @override
  Future<void> setCompletedQuizIds(List<String> ids) =>
      _prefs.setStringList(AppConstants.keyCompletedQuizIds, ids);

  // ─── Preferences ───────────────────────────────────────────────────────────

  @override
  String? get themeMode => _prefs.getString(AppConstants.keyThemeMode);

  @override
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(AppConstants.keyThemeMode, mode);

  @override
  String? get language => _prefs.getString(AppConstants.keyLanguage);

  @override
  Future<void> setLanguage(String language) =>
      _prefs.setString(AppConstants.keyLanguage, language);

  // ─── Utilities ─────────────────────────────────────────────────────────────

  @override
  bool containsKey(String key) => _prefs.containsKey(key);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);

  @override
  Future<bool> clear() => _prefs.clear();
}
