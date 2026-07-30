/// VaaniX Local Storage Interface
///
/// Contract defining all local storage capabilities.
/// Enables mockability for unit testing and decoupling from SharedPreferences.

abstract class ILocalStorageService {
  // Onboarding
  bool get isOnboardingComplete;
  Future<void> setOnboardingComplete(bool value);

  // Companion / personality
  String get companionName;
  Future<void> setCompanionName(String name);

  String? get personalityMode;
  Future<void> setPersonalityMode(String mode);

  // Learning profile
  int? get selectedClass;
  Future<void> setSelectedClass(int cbseClass);

  int get dailyGoalMinutes;
  Future<void> setDailyGoalMinutes(int minutes);

  // Streaks / activity
  int get currentStreak;
  Future<void> setCurrentStreak(int streak);

  String? get lastActiveDate;
  Future<void> setLastActiveDate(String isoDate);

  // Preferences
  String? get themeMode;
  Future<void> setThemeMode(String mode);

  String? get language;
  Future<void> setLanguage(String language);

  // Utilities
  bool containsKey(String key);
  Future<bool> remove(String key);
  Future<bool> clear();
}
