/// Local Progress Repository — Data Layer
///
/// Offline-first [ProgressRepository] backed by [ILocalStorageService].
/// XP is written through to the local store so the Home XP badge and the
/// Progress screen read a consistent value.
///
/// Quiz attempt history is persisted as JSON strings under per-quizId keys
/// (`quiz_attempts_<quizId>`), enabling best-score tracking and per-quiz
/// analytics without requiring a database.

import 'dart:convert';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._storage);

  final ILocalStorageService _storage;

  @override
  Result<List<String>> getCompletedLessonIds() =>
      ok(_storage.completedLessonIds);

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
  Future<Result<void>> reset() {
    return guardAsync(() async {
      // Collect all quiz_attempt_* keys to clear.
      // SharedPreferences doesn't expose a prefix-search, so we rely on
      // the known quizIds from the curriculum. For V1 there's only one
      // quiz ('v1_practice_quiz'); clearing it is sufficient. Segment 8
      // will generalize this when per-chapter quizzes land.
      final quizIds = _storage.completedQuizIds;
      await Future.wait([
        _storage.setCompletedLessonIds(const []),
        _storage.setCompletedQuizIds(const []),
        _storage.setXpTotal(0),
        for (final id in quizIds) _storage.setQuizAttempts(id, '[]'),
      ]);
    });
  }

  Future<void> _setXp(int value) => _storage.setXpTotal(value);

  /// Append [result] to the persisted attempt history for [quizId].
  Future<void> _appendAttempt(String quizId, QuizResult result) async {
    final current = getQuizAttempts(quizId).fold((_) => <QuizResult>[], (v) => v);
    final next = [...current, result];
    _storage.setQuizAttempts(quizId, jsonEncode(next.map((r) => r.toJson()).toList()));
  }

  /// Award [AppConstants.xpPerCorrectAnswer] XP per correct answer.
  /// Uses the centralized constant to prevent drift across modules.
  int _quizXp(int score, int total) =>
      score * AppConstants.xpPerCorrectAnswer;
}
