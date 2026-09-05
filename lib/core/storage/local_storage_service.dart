/// VaaniX Local Storage Service Implementation
///
/// Typed wrapper around [SharedPreferences] implementing [ILocalStorageService].
library;

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
  int get currentStreak => _prefs.getInt(AppConstants.keyCurrentStreak) ?? 0;

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
  Future<void> setXpTotal(int xp) => _prefs.setInt(AppConstants.keyXpTotal, xp);

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

  /// Quiz attempt history is stored as a JSON-encoded string under
  /// key `quiz_attempts_<quizId>`. This keeps SharedPreferences (which
  /// only supports primitive types) happy while allowing structured
  /// attempt data via [QuizResult.fromJson]/[toJson].
  @override
  String? getQuizAttempts(String quizId) =>
      _prefs.getString('quiz_attempts_$quizId');

  @override
  Future<void> setQuizAttempts(String quizId, String jsonAttempts) =>
      _prefs.setString('quiz_attempts_$quizId', jsonAttempts);

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

  // ─── Learner Identity ──────────────────────────────────────────────────

  @override
  String get learnerName => _prefs.getString(AppConstants.keyLearnerName) ?? '';

  @override
  Future<void> setLearnerName(String name) =>
      _prefs.setString(AppConstants.keyLearnerName, name);

  // ─── AI Conversations ──────────────────────────────────────────────────────

  /// AI conversation history stored as JSON strings under
  /// `ai_conversation_<conversationId>` (prefix constant shared with the
  /// conversation-memory retention pruning).
  @override
  String? getAiConversation(String conversationId) =>
      _prefs.getString('${AppConstants.aiConversationKeyPrefix}$conversationId');

  @override
  Future<void> setAiConversation(String conversationId, String jsonMessages) =>
      _prefs.setString(
          '${AppConstants.aiConversationKeyPrefix}$conversationId', jsonMessages);

  @override
  Future<void> clearAiConversations() async {
    // Remove all keys starting with the shared AI conversation prefix.
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(AppConstants.aiConversationKeyPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // ─── Generic String Storage ────────────────────────────────────────────────

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ─── Utilities ─────────────────────────────────────────────────────────────

  @override
  bool containsKey(String key) => _prefs.containsKey(key);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);

  @override
  Future<bool> clear() => _prefs.clear();

  @override
  Set<String> get keys => _prefs.getKeys();
}
