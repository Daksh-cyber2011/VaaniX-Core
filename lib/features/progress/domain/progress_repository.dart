/// Progress Repository — Domain Contract
///
/// Tracks which lessons/quizzes the learner has completed and how much XP
/// they have earned. Local-first; synced to Supabase when configured.

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

abstract class ProgressRepository {
  /// IDs of lessons the learner has completed.
  Result<List<String>> getCompletedLessonIds();

  /// IDs of quizzes the learner has completed (at least once).
  Result<List<String>> getCompletedQuizIds();

  /// Mark [lessonId] as completed and award its XP.
  Future<Result<int>> completeLesson(Lesson lesson);

  /// Record a quiz attempt and award XP proportional to the score.
  Future<Result<QuizResult>> completeQuiz({
    required String quizId,
    required int score,
    required int total,
  });

  /// Total XP earned.
  Result<int> getXp();

  /// Reset all progress (used by Settings → reset account).
  Future<Result<void>> reset();
}
