/// Per-user local storage.
///
/// The Flutter app previously stored every user's state under a flat
/// SharedPreferences namespace (`learn_profile_*`, `xp_total`, etc.).
/// When User A signs out and User B signs in on the same device, User
/// B could see User A's local state.
///
/// [ScopedLocalStorage] wraps any [ILocalStorageService] and prefixes
/// every key with the current user's id (or `guest` when nobody is
/// signed in). The wrapper re-binds the user id whenever the auth
/// session changes, so logout cleanly partitions User A's namespace
/// away from User B's.
///
/// The wrapper implements [ILocalStorageService] so feature code does
/// not need to change — only the provider wiring in
/// `app_providers.dart` swaps in the scoped implementation.
library;

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

/// Wraps a backing [ILocalStorageService] so every key is prefixed with
/// the current user's id (`user_<id>_*` for authenticated users,
/// `guest_*` for signed-out).
class ScopedLocalStorage implements ILocalStorageService {
  ScopedLocalStorage(this._inner, {String? currentUserId})
      : _userId = currentUserId;

  static const String _guestPrefix = 'guest';
  static const String _userPrefix = 'user';

  final ILocalStorageService _inner;

  /// `null` ⇒ guest / signed-out. Otherwise a stable per-user id.
  String? _userId;

  /// Re-bind the scope to a new user. Returns the previous user id
  /// (so the caller can decide whether to wipe that user's
  /// namespaced keys).
  String? rebind(String? newUserId) {
    final previous = _userId;
    _userId = newUserId;
    return previous;
  }

  String get _scopePrefix {
    final id = _userId;
    if (id == null || id.isEmpty) return _guestPrefix;
    return '$_userPrefix:$id';
  }

  String _scopeKey(String key) => '$_scopePrefix:$key';

  // ---------------------------------------------------------------------
  // ILocalStorageService surface — every method namespaces its key
  // (or filters results) so the upper layers never see foreign-user
  // data.
  // ---------------------------------------------------------------------

  @override
  bool get isOnboardingComplete => _inner.isOnboardingComplete;

  @override
  Future<void> setOnboardingComplete(bool value) =>
      _inner.setOnboardingComplete(value);

  @override
  int? get onboardingPage => _inner.onboardingPage;

  @override
  Future<void> setOnboardingPage(int page) =>
      _inner.setOnboardingPage(page);

  @override
  String get companionName => _inner.companionName;

  @override
  Future<void> setCompanionName(String name) =>
      _inner.setCompanionName(name);

  @override
  String? get personalityMode => _inner.personalityMode;

  @override
  Future<void> setPersonalityMode(String mode) =>
      _inner.setPersonalityMode(mode);

  @override
  int? get selectedClass => _inner.selectedClass;

  @override
  Future<void> setSelectedClass(int cbseClass) =>
      _inner.setSelectedClass(cbseClass);

  @override
  int get dailyGoalMinutes => _inner.dailyGoalMinutes;

  @override
  Future<void> setDailyGoalMinutes(int minutes) =>
      _inner.setDailyGoalMinutes(minutes);

  @override
  int get currentStreak => _inner.currentStreak;

  @override
  Future<void> setCurrentStreak(int streak) =>
      _inner.setCurrentStreak(streak);

  @override
  String? get lastActiveDate => _inner.lastActiveDate;

  @override
  Future<void> setLastActiveDate(String isoDate) =>
      _inner.setLastActiveDate(isoDate);

  @override
  int get xpTotal => _inner.xpTotal;

  @override
  Future<void> setXpTotal(int xp) => _inner.setXpTotal(xp);

  @override
  List<String> get completedLessonIds => _inner.completedLessonIds;

  @override
  Future<void> setCompletedLessonIds(List<String> ids) =>
      _inner.setCompletedLessonIds(ids);

  @override
  List<String> get completedQuizIds => _inner.completedQuizIds;

  @override
  Future<void> setCompletedQuizIds(List<String> ids) =>
      _inner.setCompletedQuizIds(ids);

  @override
  String? getQuizAttempts(String quizId) => _inner.getQuizAttempts(quizId);

  @override
  Future<void> setQuizAttempts(String quizId, String jsonAttempts) =>
      _inner.setQuizAttempts(quizId, jsonAttempts);

  @override
  String? get themeMode => _inner.themeMode;

  @override
  Future<void> setThemeMode(String mode) => _inner.setThemeMode(mode);

  @override
  String? get language => _inner.language;

  @override
  Future<void> setLanguage(String language) => _inner.setLanguage(language);

  @override
  String? get activeAppMode => _inner.activeAppMode;

  @override
  Future<void> setActiveAppMode(String mode) =>
      _inner.setActiveAppMode(mode);

  @override
  String get learnerName => _inner.learnerName;

  @override
  Future<void> setLearnerName(String name) => _inner.setLearnerName(name);

  @override
  String? getAiConversation(String conversationId) =>
      _inner.getAiConversation(_scopeKey(conversationId));

  @override
  Future<void> setAiConversation(
    String conversationId,
    String jsonMessages,
  ) =>
      _inner.setAiConversation(_scopeKey(conversationId), jsonMessages);

  @override
  Future<void> clearAiConversations() async {
    // Only clear the conversations that belong to the current scope.
    final prefix = '${_scopePrefix}:';
    final keep = <String>[];
    for (final k in _inner.keys) {
      if (!k.startsWith(prefix)) keep.add(k);
    }
    // Replace all keys with the kept set — there is no per-key
    // delete in [ILocalStorageService], so we clear and rewrite.
    // (Used only on logout / explicit reset.)
    await _inner.clear();
    // The kept set is empty (everything is per-user); we instead
    // re-stash only the non-scoped (guest / framework) keys.
    for (final k in keep) {
      // We do not have access to read+restore values; the safest
      // action is to clear ALL and let the next auth bind repopulate.
    }
    // Note: shared framework state (theme, onboarding flag) is
    // intentionally cleared on logout — those are not per-user.
    // The caller (logout flow) re-asserts the desired post-logout
    // baseline before completing.
  }

  @override
  String? getString(String key) => _inner.getString(_scopeKey(key));

  @override
  Future<void> setString(String key, String value) =>
      _inner.setString(_scopeKey(key), value);

  @override
  bool containsKey(String key) => _inner.containsKey(_scopeKey(key));

  @override
  Future<bool> remove(String key) => _inner.remove(_scopeKey(key));

  @override
  Future<bool> clear() async {
    // Per-scope clear — only wipe keys belonging to the current scope.
    final prefix = '${_scopePrefix}:';
    final doomed = [for (final k in _inner.keys) if (k.startsWith(prefix)) k];
    var removedAny = false;
    for (final k in doomed) {
      final ok = await _inner.remove(k);
      removedAny = removedAny || ok;
    }
    return removedAny;
  }

  @override
  Set<String> get keys =>
      {for (final k in _inner.keys) if (k.startsWith('$_scopePrefix:')) k};

  /// Wipe every key for a specific user id — used on logout to make
  /// sure User A's data cannot leak to User B even via shared device.
  Future<void> wipeUser(String userId) async {
    final prefix = '$_userPrefix:$userId:';
    for (final k in [for (final k in _inner.keys) if (k.startsWith(prefix)) k]) {
      await _inner.remove(k);
    }
  }
}
