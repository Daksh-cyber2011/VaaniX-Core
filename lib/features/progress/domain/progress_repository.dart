/// Progress Repository — Domain Contract
///
/// Tracks which lessons/quizzes the learner has completed and how much XP
/// they have earned. Local-first; synced to Supabase when configured.
library;

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

abstract class ProgressRepository {
  /// IDs of lessons the learner has completed.
  Result<List<String>> getCompletedLessonIds();

  /// IDs of quizzes the learner has completed (at least once).
  Result<List<String>> getCompletedQuizIds();

  /// All attempt history for [quizId], newest last. Empty if never
  /// attempted. Used for best-score tracking and per-quiz analytics.
  Result<List<QuizResult>> getQuizAttempts(String quizId);

  /// Mark [lessonId] as completed and award its XP.
  Future<Result<int>> completeLesson(Lesson lesson);

  /// Record a quiz attempt and award XP proportional to the score.
  /// Also appends to the attempt history for [quizId].
  Future<Result<QuizResult>> completeQuiz({
    required String quizId,
    required int score,
    required int total,
  });

  /// Total XP earned.
  Result<int> getXp();

  /// Award a one-time bonus XP grant tagged with [sourceId] (for example
  /// `ach_<achievementId>`). Idempotent per source: repeating the same
  /// source never double-awards. Bonus XP is tracked in its own ledger and
  /// never pollutes the completed-lesson / completed-quiz records, so
  /// lesson counts and journey progress stay truthful.
  Future<Result<int>> awardBonusXp({
    required String sourceId,
    required int amount,
  });

  /// Exercise ids the learner has mastered (answered correctly at least
  /// once) for [lessonId]. Empty when never practised. Corrupt data is
  /// treated as empty rather than crashing.
  Result<List<String>> getMasteredExercises(String lessonId);

  /// Record exercise mastery for [lessonId] as an idempotent union of
  /// [ids]. Awarding no XP (lesson XP is the only XP gate), repeat
  /// records simply merge, so practice sessions can safely re-run.
  Future<Result<void>> recordMasteredExercises(
    String lessonId,
    List<String> ids,
  );

  /// Reset all progress (used by Settings → reset account).
  Future<Result<void>> reset();
}
