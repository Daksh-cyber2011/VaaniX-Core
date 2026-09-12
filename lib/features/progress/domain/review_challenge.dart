/// Review Challenge — Domain Layer (Milestone 7)
///
/// The daily "review reward" loop: spaced revisit of the learner's weakest
/// practised content, with a once-per-day bonus for finishing it.
///
/// A challenge EXISTS only when the adaptive weak-area engine found
/// completed lessons with unmastered exercises — the challenge is always
/// real review of real gaps, never busywork. The candidate list is the
/// adaptive engine's [listWeakLessons] output (curriculum order), and the
/// daily pick is the FIRST candidate, so the challenge is deterministic
/// and traceable to persisted mastery data.
///
/// The reward is claimed at most once per local day (date-keyed), and only
/// when the challenge lesson's practice set is fully mastered in the same
/// session that saves it. Claims flow through the progress repository's
/// idempotent bonus-XP ledger (`review_<dateKey>`), so even a double
/// dispatch can never double-pay.
library;

import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Bonus XP for completing today's review challenge.
const int kReviewChallengeBonusXp = 15;

/// The source id used in the bonus-XP ledger for a claimed daily review.
/// Date-keyed so the SAME challenge completed on a NEW day pays again —
/// review is worth rewarding every day, exactly once.
String reviewChallengeSourceId(String dateKey) => 'review_$dateKey';

/// Today's review challenge, or null when there is nothing worth
/// reviewing (all completed lessons fully mastered).
class ReviewChallenge {
  const ReviewChallenge({
    required this.lesson,
    required this.masteredCount,
    required this.totalCount,
  });

  /// The lesson to review (first weak lesson in curriculum order).
  final Lesson lesson;

  /// Already-mastered exercise ids for the lesson (persisted).
  final int masteredCount;

  /// Authored exercises for the lesson.
  final int totalCount;

  /// Exercises still to master today.
  int get remaining => (totalCount - masteredCount).clamp(0, totalCount);
}

/// Pure daily challenge picker: the first weak lesson with at least one
/// authored exercise. Deterministic over the adaptive engine's output.
ReviewChallenge? pickDailyReviewChallenge(
  List<Lesson> weakLessonsInOrder,
  int Function(Lesson) masteredOf,
  int Function(Lesson) totalOf,
) {
  for (final lesson in weakLessonsInOrder) {
    final total = totalOf(lesson);
    if (total <= 0) continue;
    return ReviewChallenge(
      lesson: lesson,
      masteredCount: masteredOf(lesson),
      totalCount: total,
    );
  }
  return null;
}

/// True when finishing a practice session for [lessonId] completes TODAY's
/// challenge: the session's lesson is the challenge lesson AND the lesson
/// is now fully mastered. Pure so the claim gate is unit-testable.
bool completesReviewChallenge({
  required ReviewChallenge? challenge,
  required String lessonId,
  required int masteredAfterSession,
  required int totalAuthored,
}) {
  if (challenge == null) return false;
  if (challenge.lesson.id != lessonId) return false;
  if (totalAuthored <= 0) return false;
  return masteredAfterSession >= totalAuthored;
}
