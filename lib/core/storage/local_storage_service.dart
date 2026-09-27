/// VaaniX Local Storage Service Implementation
///
/// Typed wrapper around [SharedPreferences] implementing [ILocalStorageService].
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

class LocalStorageService implements ILocalStorageService {
  LocalStorageService(this._prefs, {String? keyNamespace})
      : _keyNamespace = keyNamespace;

  final SharedPreferences _prefs;

  /// Optional key namespace. When set, every key this service reads or
  /// writes is prefixed with `'$_keyNamespace:'`.
  ///
  /// This is the seam used for **per-user account isolation**: the
  /// `ScopedLocalStorage` wrapper delegates to a namespaced instance of
  /// this class, so two accounts signing in and out on the same device
  /// cannot see each other's local state. Every accessor below routes
  /// its key through [_k] — nothing bypasses the namespace.
  final String? _keyNamespace;

  String? _keyNamespaceRef;

  /// Rebind the namespace. Keys written under the previous namespace
  /// remain on disk but are invisible to this instance.
  void rebindNamespace(String? namespace) {
    _keyNamespaceRef = namespace;
  }

  /// Apply the active namespace to [key].
  String _k(String key) {
    final ns = _keyNamespaceRef ?? _keyNamespace;
    if (ns == null || ns.isEmpty) return key;
    return '$ns:$key';
  }

  // ─── Onboarding ────────────────────────────────────────────────────────────

  @override
  bool get isOnboardingComplete =>
      _readBool(AppConstants.keyOnboardingComplete) ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_k(AppConstants.keyOnboardingComplete), value);

  @override
  int? get onboardingPage => _readInt(AppConstants.keyOnboardingPage);

  @override
  Future<void> setOnboardingPage(int page) =>
      _prefs.setInt(_k(AppConstants.keyOnboardingPage), page);

  // ─── Companion / Personality ───────────────────────────────────────────────

  @override
  String get companionName =>
      _readString(AppConstants.keyUserCompanionName) ??
      AppConstants.companionDefaultName;

  @override
  Future<void> setCompanionName(String name) =>
      _prefs.setString(_k(AppConstants.keyUserCompanionName), name);

  @override
  String? get personalityMode => _readString(AppConstants.keyPersonalityMode);

  @override
  Future<void> setPersonalityMode(String mode) =>
      _prefs.setString(_k(AppConstants.keyPersonalityMode), mode);

  // ─── Learning Profile ──────────────────────────────────────────────────────

  @override
  int? get selectedClass => _readInt(AppConstants.keySelectedClass);

  @override
  Future<void> setSelectedClass(int cbseClass) =>
      _prefs.setInt(_k(AppConstants.keySelectedClass), cbseClass);

  @override
  int get dailyGoalMinutes =>
      _readInt(AppConstants.keyDailyGoalMinutes) ??
      AppConstants.defaultDailyGoalMinutes;

  @override
  Future<void> setDailyGoalMinutes(int minutes) =>
      _prefs.setInt(_k(AppConstants.keyDailyGoalMinutes), minutes);

  // ─── Streaks / Activity ─────────────────────────────────────────────────────

  @override
  int get currentStreak => _readInt(AppConstants.keyCurrentStreak) ?? 0;

  @override
  Future<void> setCurrentStreak(int streak) =>
      _prefs.setInt(_k(AppConstants.keyCurrentStreak), streak);

  @override
  String? get lastActiveDate => _readString(AppConstants.keyLastActiveDate);

  @override
  Future<void> setLastActiveDate(String isoDate) =>
      _prefs.setString(_k(AppConstants.keyLastActiveDate), isoDate);

  // ─── XP & Progress ────────────────────────────────────────────────────────

  @override
  int get xpTotal => _readInt(AppConstants.keyXpTotal) ?? 0;

  @override
  Future<void> setXpTotal(int xp) => _prefs.setInt(_k(AppConstants.keyXpTotal), xp);

  @override
  List<String> get completedLessonIds =>
      _readStringList(AppConstants.keyCompletedLessonIds) ?? const [];

  @override
  Future<void> setCompletedLessonIds(List<String> ids) =>
      _prefs.setStringList(_k(AppConstants.keyCompletedLessonIds), ids);

  @override
  List<String> get completedQuizIds =>
      _readStringList(AppConstants.keyCompletedQuizIds) ?? const [];

  @override
  Future<void> setCompletedQuizIds(List<String> ids) =>
      _prefs.setStringList(_k(AppConstants.keyCompletedQuizIds), ids);

  /// Quiz attempt history is stored as a JSON-encoded string under
  /// key `quiz_attempts_<quizId>`. This keeps SharedPreferences (which
  /// only supports primitive types) happy while allowing structured
  /// attempt data via [QuizResult.fromJson]/[toJson].
  @override
  String? getQuizAttempts(String quizId) =>
      _readString('quiz_attempts_$quizId');

  @override
  Future<void> setQuizAttempts(String quizId, String jsonAttempts) =>
      _prefs.setString('quiz_attempts_$quizId', jsonAttempts);

  // ─── Preferences ───────────────────────────────────────────────────────────

  @override
  String? get themeMode => _readString(AppConstants.keyThemeMode);

  @override
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_k(AppConstants.keyThemeMode), mode);

  @override
  String? get language => _readString(AppConstants.keyLanguage);

  @override
  Future<void> setLanguage(String language) =>
      _prefs.setString(_k(AppConstants.keyLanguage), language);

  @override
  String? get activeAppMode => _readString('vaanix_active_app_mode');

  @override
  Future<void> setActiveAppMode(String mode) =>
      _prefs.setString(_k('vaanix_active_app_mode'), mode);

  // ─── Learner Identity ──────────────────────────────────────────────────

  @override
  String get learnerName => _readString(AppConstants.keyLearnerName) ?? '';

  @override
  Future<void> setLearnerName(String name) =>
      _prefs.setString(_k(AppConstants.keyLearnerName), name);

  // ─── AI Conversations ──────────────────────────────────────────────────────

  /// AI conversation history stored as JSON strings under
  /// `ai_conversation_<conversationId>` (prefix constant shared with the
  /// conversation-memory retention pruning).
  @override
  String? getAiConversation(String conversationId) =>
      _readString('${AppConstants.aiConversationKeyPrefix}$conversationId');

  @override
  Future<void> setAiConversation(String conversationId, String jsonMessages) =>
      _prefs.setString(
          _k('${AppConstants.aiConversationKeyPrefix}$conversationId'),
          jsonMessages);

  @override
  Future<void> clearAiConversations() async {
    // Remove all keys starting with the shared AI conversation prefix,
    // scoped to the active namespace.
    final prefix = _k(AppConstants.aiConversationKeyPrefix);
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // ─── Generic String Storage ────────────────────────────────────────────────

  @override
  String? getString(String key) => _readString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(_k(key), value);

  // ─── Utilities ─────────────────────────────────────────────────────────────

  @override
  bool containsKey(String key) => _prefs.containsKey(_k(key));

  @override
  Future<bool> remove(String key) => _prefs.remove(_k(key));

  /// Clears only the keys inside the active namespace. With no
  /// namespace set, this falls back to a full `prefs.clear()` so the
  /// pre-namespacing behavior (a hard reset) is preserved.
  @override
  Future<bool> clear() async {
    final ns = _keyNamespaceRef ?? _keyNamespace;
    if (ns == null || ns.isEmpty) return _prefs.clear();
    final prefix = '$ns:';
    final doomed = _prefs.getKeys().where((k) => k.startsWith(prefix));
    var removedAny = false;
    for (final key in doomed.toList()) {
      removedAny = await _prefs.remove(key) || removedAny;
    }
    return removedAny;
  }

  /// All keys inside the active namespace, with the namespace prefix
  /// stripped. With no namespace set, this is the full key set.
  @override
  Set<String> get keys {
    final ns = _keyNamespaceRef ?? _keyNamespace;
    final all = _prefs.getKeys();
    if (ns == null || ns.isEmpty) return all;
    final prefix = '$ns:';
    return {
      for (final k in all)
        if (k.startsWith(prefix)) k.substring(prefix.length),
    };
  }

  /// The un-namespaced key set, i.e. every key physically present in
  /// SharedPreferences. Used by account-isolation helpers that need to
  /// address another user's namespace directly.
  Set<String> get rawKeys => _prefs.getKeys();

  /// Remove a key by its physical (namespaced) name, bypassing the
  /// active namespace. Pairs with [rawKeys].
  Future<bool> removeRaw(String rawKey) => _prefs.remove(rawKey);

  // SharedPreferences getters cast values and throw when an older build or a
  // damaged preferences file contains the wrong type. Treat such values as
  // absent so provider hydration can use its existing safe defaults.
  //
  // Every read routes its key through [_k] so the active namespace applies
  // uniformly. Callers pass the *logical* key; the physical key on disk is
  // namespaced.
  bool? _readBool(String key) {
    try {
      return _prefs.getBool(_k(key));
    } catch (_) {
      return null;
    }
  }

  int? _readInt(String key) {
    try {
      return _prefs.getInt(_k(key));
    } catch (_) {
      return null;
    }
  }

  String? _readString(String key) {
    try {
      return _prefs.getString(_k(key));
    } catch (_) {
      return null;
    }
  }

  List<String>? _readStringList(String key) {
    try {
      return _prefs.getStringList(_k(key));
    } catch (_) {
      return null;
    }
  }
}
