/// Local Progress Repository — Data Layer
///
/// Offline-first [ProgressRepository] backed by [ILocalStorageService].
/// XP is written through to the local store so the Home XP badge and the
/// Progress screen read a consistent value.

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
      // (Score / total are still returned for display, but xpEarned is 0 on
      // repeat completions.)
      final alreadyCompleted = _storage.completedQuizIds.contains(quizId);
      final xpEarned = alreadyCompleted ? 0 : _quizXp(score, total);
      final ids = {..._storage.completedQuizIds, quizId}.toList();
      await Future.wait([
        _storage.setCompletedQuizIds(ids),
        if (!alreadyCompleted) _setXp(_storage.xpTotal + xpEarned),
      ]);
      return QuizResult(
        quizId: quizId,
        score: score,
        total: total,
        xpEarned: xpEarned,
        completedAt: DateTime.now(),
      );
    });
  }

  @override
  Result<int> getXp() => ok(_storage.xpTotal);

  @override
  Future<Result<void>> reset() {
    return guardAsync(() async {
      await Future.wait([
        _storage.setCompletedLessonIds(const []),
        _storage.setCompletedQuizIds(const []),
        _storage.setXpTotal(0),
      ]);
    });
  }

  Future<void> _setXp(int value) => _storage.setXpTotal(value);

  /// Award 10 XP per correct answer.
  int _quizXp(int score, int total) => score * 10;
}
