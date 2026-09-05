/// Local Progress Repository — Data Layer
///
/// Offline-first [ProgressRepository] backed by [ILocalStorageService].
/// XP is written through to the local store so the Home XP badge and the
/// Progress screen read a consistent value.
///
/// Quiz attempt history is persisted as JSON strings under per-quizId keys
/// (`quiz_attempts_<quizId>`), enabling best-score tracking and per-quiz
/// analytics without requiring a database.
library;

import 'dart:convert';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._storage) {
    // Phase 1 repair: older builds awarded achievement bonus XP through
    // completeLesson() with synthetic `ach_*` lesson ids, polluting the
    // completed-lesson list (inflating journey %, lesson stats and the
    // adaptive subtitle). Strip any such ids once at construction.
    _sanitizeLegacyAchievementLessonIds();
  }

  final ILocalStorageService _storage;

  /// Prefix used by the legacy synthetic-achievement lesson ids.
  static const String _achievementLessonPrefix = 'ach_';

  /// Storage key of the bonus-XP ledger (JSON list of awarded source ids).
  static const String _bonusXpKey = 'bonus_xp_awarded';

  void _sanitizeLegacyAchievementLessonIds() {
    final ids = _storage.completedLessonIds;
    final polluted = ids.any((id) => id.startsWith(_achievementLessonPrefix));
    if (!polluted) return;
    _storage.setCompletedLessonIds(
      ids.where((id) => !id.startsWith(_achievementLessonPrefix)).toList(),
    );
  }

  @override
  Result<List<String>> getCompletedLessonIds() => ok(
        // Defensive filter: reads stay clean even if the constructor's
        // write-through sanitize is still in flight.
        _storage.completedLessonIds
            .where((id) => !id.startsWith(_achievementLessonPrefix))
            .toList(),
      );

  @override
  Result<List<String>> getCompletedQuizIds() => ok(_storage.completedQuizIds);

  @override
  Result<List<QuizResult>> getQuizAttempts(String quizId) {
    final raw = _storage.getQuizAttempts(quizId);
    if (raw == null || raw.isEmpty) return ok(const <QuizResult>[]);
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return ok(list
          .map((e) => QuizResult.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      // Corrupt JSON — treat as no history rather than crashing.
      return ok(const <QuizResult>[]);
    }
  }

  @override
  Future<Result<int>> completeLesson(Lesson lesson) {
    return guardAsync(() async {
      // Idempotency guard: only award XP the first time a lesson is completed.
      // Prevents XP farming if a caller bypasses the notifier-level guard.
      final alreadyCompleted = _storage.completedLessonIds.contains(lesson.id);
      if (alreadyCompleted) {
        return _storage.xpTotal;
      }
      final ids = {..._storage.completedLessonIds, lesson.id}.toList();
      await Future.wait([
        _storage.setCompletedLessonIds(ids),
        _setXp(_storage.xpTotal + lesson.xpReward),
      ]);
      return _storage.xpTotal;
    });
  }

  @override
  Future<Result<QuizResult>> completeQuiz({
    required String quizId,
    required int score,
    required int total,
  }) {
    return guardAsync(() async {
      // Idempotency guard: only award XP the first time a quizId is completed.
      // Prevents the Retry → Save Progress → infinite XP farm exploit.
      // (Score / total are still returned for display + persisted to history,
      // but xpEarned is 0 on repeat completions.)
      final alreadyCompleted = _storage.completedQuizIds.contains(quizId);
      final xpEarned = alreadyCompleted ? 0 : _quizXp(score, total);
      final result = QuizResult(
        quizId: quizId,
        score: score,
        total: total,
        xpEarned: xpEarned,
        completedAt: DateTime.now(),
      );

      // Persist the attempt to history (always, even on repeats —
      // the history is for analytics, the XP is what's idempotent).
      await _appendAttempt(quizId, result);

      final ids = {..._storage.completedQuizIds, quizId}.toList();
      await Future.wait([
        _storage.setCompletedQuizIds(ids),
        if (!alreadyCompleted) _setXp(_storage.xpTotal + xpEarned),
      ]);

      return result;
    });
  }

  @override
  Result<int> getXp() => ok(_storage.xpTotal);

  @override
  Future<Result<int>> awardBonusXp({
    required String sourceId,
    required int amount,
  }) {
    return guardAsync(() async {
      // Zero-value grants need no ledger entry and no XP write.
      if (amount <= 0) return _storage.xpTotal;

      final awarded = _bonusXpSources();
      // Idempotency guard: a source (achievement, milestone, ...) can only
      // ever contribute its bonus once.
      if (awarded.contains(sourceId)) return _storage.xpTotal;

      awarded.add(sourceId);
      await Future.wait([
        _storage.setString(_bonusXpKey, jsonEncode(awarded)),
        _setXp(_storage.xpTotal + amount),
      ]);
      return _storage.xpTotal;
    });
  }

  /// Reads the persisted bonus-XP ledger. Corrupt JSON is treated as an
  /// empty ledger rather than crashing (same policy as attempt history).
  List<String> _bonusXpSources() {
    final raw = _storage.getString(_bonusXpKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }

  static const String _masteredPrefix = 'mastered_exercises_';

  @override
  Result<List<String>> getMasteredExercises(String lessonId) {
    final raw = _storage.getString('$_masteredPrefix$lessonId');
    if (raw == null || raw.isEmpty) return ok(const <String>[]);
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return ok(list.whereType<String>().toList());
    } catch (_) {
      // Corrupt mastery JSON - treat as no mastery rather than crashing.
      return ok(const <String>[]);
    }
  }

  @override
  Future<Result<void>> recordMasteredExercises(
    String lessonId,
    List<String> ids,
  ) {
    return guardAsync(() async {
      final existing = getMasteredExercises(lessonId)
          .fold((_) => const <String>[], (v) => v);
      final merged = {...existing, ...ids}.toList()..sort();
      await _storage.setString(
        '$_masteredPrefix$lessonId',
        jsonEncode(merged),
      );
    });
  }

  /// Storage-key prefix of per-quiz attempt history (kept in sync with
  /// LocalStorageService.get/setQuizAttempts).
  static const String _attemptsPrefix = 'quiz_attempts_';

  @override
  Future<Result<void>> reset() {
    return guardAsync(() async {
      // Purge by KEY PREFIX, not by the ids currently listed in
      // completedQuizIds: any orphaned/stale attempt history (schema
      // evolution, future per-chapter quizzes) must not survive a reset.
      await Future.wait([
        _storage.setCompletedLessonIds(const []),
        _storage.setCompletedQuizIds(const []),
        _storage.setXpTotal(0),
        // Bonus-XP ledger must reset with everything else so achievements
        // cleared in the same reset can re-award their XP when re-earned.
        _storage.setString(_bonusXpKey, jsonEncode(<String>[])),
        // Attempt history under ANY quiz id.
        for (final key in _storage.keys)
          if (key.startsWith(_attemptsPrefix)) _storage.remove(key),
        // Exercise mastery is per-lesson; purge every mastered_* key.
        for (final key in _storage.keys)
          if (key.startsWith(_masteredPrefix)) _storage.remove(key),
      ]);
    });
  }

  Future<void> _setXp(int value) => _storage.setXpTotal(value);

  /// Append [result] to the persisted attempt history for [quizId].
  Future<void> _appendAttempt(String quizId, QuizResult result) async {
    final current =
        getQuizAttempts(quizId).fold((_) => <QuizResult>[], (v) => v);
    final next = [...current, result];
    _storage.setQuizAttempts(
        quizId, jsonEncode(next.map((r) => r.toJson()).toList()));
  }

  /// Award [AppConstants.xpPerCorrectAnswer] XP per correct answer.
  /// Uses the centralized constant to prevent drift across modules.
  int _quizXp(int score, int total) => score * AppConstants.xpPerCorrectAnswer;
}
