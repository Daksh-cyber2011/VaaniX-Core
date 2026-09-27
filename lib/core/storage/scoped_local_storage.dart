/// Per-user local storage — account isolation seam.
///
/// ## Why this exists
///
/// SharedPreferences is a single flat namespace. Storing `xp_total`,
/// `learn_profile_*`, AI conversation history and the like under fixed
/// keys means that when User A signs out and User B signs in on the same
/// device, User B sees User A's local progress. That is a data leak
/// between accounts, not a cosmetic bug.
///
/// ## How it works
///
/// [ScopedLocalStorage] wraps a [LocalStorageService] and re-binds that
/// service's **key namespace** whenever the active user changes. Every
/// key the underlying service reads or writes is routed through its
/// `_k()` helper, so switching users is a prefix swap rather than a
/// data migration — nothing is copied, nothing is lost, and the
/// previous user's rows simply become unreachable.
///
/// Keys on disk look like:
///
/// ```text
/// user:<uuidA>:xp_total
/// user:<uuidA>:learn_profile_hi_course
/// guest:xp_total
/// ```
///
/// ## Relationship to the plain service
///
/// This wrapper deliberately implements [ILocalStorageService] by
/// delegating every member, so feature repositories need no changes.
/// With no active user the scope is `guest`, which keeps the signed-out
/// experience working exactly as before.
library;

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';

/// Wraps a [LocalStorageService] so every key is prefixed with the
/// current user's id (`user:<id>:*`), or `guest:*` when nobody is
/// signed in.
class ScopedLocalStorage implements ILocalStorageService {
  ScopedLocalStorage(this._inner, {String? currentUserId}) {
    rebind(currentUserId);
  }

  static const String guestScope = 'guest';
  static const String _userScopePrefix = 'user';

  final LocalStorageService _inner;

  String? _userId;

  /// The scope prefix currently in effect.
  String get _scopePrefix {
    final id = _userId;
    if (id == null || id.isEmpty) return guestScope;
    return '$_userScopePrefix:$id';
  }

  /// The active user id, or `null` for guest.
  String? get currentUserId => _userId;

  /// Switch the active scope.
  ///
  /// Returns the previously-active user id so the caller can decide
  /// whether to wipe that user's rows (e.g. on an explicit
  /// "sign out and forget" action). Nothing is deleted here: a user
  /// who signs back in finds their progress intact.
  String? rebind(String? newUserId) {
    final previous = _userId;
    _userId = (newUserId != null && newUserId.isEmpty) ? null : newUserId;
    _inner.rebindNamespace(_scopePrefix);
    return previous;
  }

  /// Delete every key owned by [userId], regardless of who is
  /// currently signed in. Used by an explicit "sign out and erase"
  /// flow and by tests that verify isolation.
  Future<void> wipeUser(String userId) async {
    final prefix = '$_userScopePrefix:$userId:';
    final raw = _inner.rawKeys;
    final doomed = raw.where((k) => k.startsWith(prefix)).toList();
    for (final key in doomed) {
      await _inner.removeRaw(key);
    }
  }

  // ─── ILocalStorageService — pure delegation ───────────────────────────
  // The namespacing happens inside [_inner] via its key namespace, so
  // these members must NOT re-prefix: that would double the prefix.

  @override
  bool get isOnboardingComplete => _inner.isOnboardingComplete;

  @override
  Future<void> setOnboardingComplete(bool value) =>
      _inner.setOnboardingComplete(value);

  @override
  int? get onboardingPage => _inner.onboardingPage;

  @override
  Future<void> setOnboardingPage(int page) => _inner.setOnboardingPage(page);

  @override
  String get companionName => _inner.companionName;

  @override
  Future<void> setCompanionName(String name) => _inner.setCompanionName(name);

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
  Future<void> setCurrentStreak(int streak) => _inner.setCurrentStreak(streak);

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
  Future<void> setActiveAppMode(String mode) => _inner.setActiveAppMode(mode);

  @override
  String get learnerName => _inner.learnerName;

  @override
  Future<void> setLearnerName(String name) => _inner.setLearnerName(name);

  @override
  String? getAiConversation(String conversationId) =>
      _inner.getAiConversation(conversationId);

  @override
  Future<void> setAiConversation(
    String conversationId,
    String jsonMessages,
  ) =>
      _inner.setAiConversation(conversationId, jsonMessages);

  @override
  Future<void> clearAiConversations() => _inner.clearAiConversations();

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _inner.setString(key, value);

  @override
  bool containsKey(String key) => _inner.containsKey(key);

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  Future<bool> clear() => _inner.clear();

  @override
  Set<String> get keys => _inner.keys;
}
