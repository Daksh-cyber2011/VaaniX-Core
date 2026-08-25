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

  // XP & progress
  int get xpTotal;
  Future<void> setXpTotal(int xp);

  List<String> get completedLessonIds;
  Future<void> setCompletedLessonIds(List<String> ids);

  List<String> get completedQuizIds;
  Future<void> setCompletedQuizIds(List<String> ids);

  /// Quiz attempt history — a JSON-encoded list of [QuizResult] maps for
  /// the given quizId. Empty string or null means no attempts yet.
  String? getQuizAttempts(String quizId);
  Future<void> setQuizAttempts(String quizId, String jsonAttempts);

  // Preferences
  String? get themeMode;
  Future<void> setThemeMode(String mode);

  String? get language;
  Future<void> setLanguage(String language);

  // AI Conversations — JSON-encoded lists of AiMessage maps.
  // Keyed by conversationId. Used by LocalConversationMemory.
  String? getAiConversation(String conversationId);
  Future<void> setAiConversation(String conversationId, String jsonMessages);
  Future<void> clearAiConversations();

  // Generic string storage — used by ResponseCache and TokenUsageTracker
  // for arbitrary JSON blobs that don't fit the typed accessors above.
  String? getString(String key);
  Future<void> setString(String key, String value);

  // Utilities
  bool containsKey(String key);
  Future<bool> remove(String key);
  Future<bool> clear();

  /// All keys currently present in storage (for prefix-scoped cleanup).
  Set<String> get keys;
}
