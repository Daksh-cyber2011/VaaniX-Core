/// Daily Activity Providers — Riverpod Wiring (Milestone 7)
///
/// The daily-goal loop and the daily review challenge:
///
/// - [todayXpProvider] — XP earned today through real learning events
/// - [dailyGoalStateProvider] — [DailyGoalState] (today XP vs. the
///   learner's profile goal)
/// - [recordDailyXpProvider] — the single hook screens call after an XP
///   -bearing learning event; detects the goal-reached crossing
/// - [dailyReviewChallengeProvider] — today's weak-lesson review pick
/// - [claimReviewChallengeProvider] — pays the once-per-day review bonus
///   when the challenge lesson is fully mastered in a finished session
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';

import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/data/daily_activity_repository.dart';
import 'package:vaanix_app/features/progress/domain/daily_goal.dart';
import 'package:vaanix_app/features/progress/domain/review_challenge.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// The repository instance.
final dailyActivityRepositoryProvider =
    Provider<DailyActivityRepository>((ref) {
  return DailyActivityRepository(ref.watch(localStorageServiceProvider));
});

/// Today's local date key. Read at provider build time; screens rebuild on
/// every learning event, so a long-lived midnight session refreshes on the
/// next event at the latest.
final todayDateKeyProvider = Provider<String>((ref) {
  return dailyGoalDateKey(DateTime.now());
});

/// Reactive XP-earned-today counter.
final todayXpProvider = StateNotifierProvider<_TodayXpNotifier, int>((ref) {
  return _TodayXpNotifier(
    ref.watch(dailyActivityRepositoryProvider),
    ref.watch(todayDateKeyProvider),
  );
});

class _TodayXpNotifier extends StateNotifier<int> {
  _TodayXpNotifier(this._repo, this._dateKey) : super(0) {
    state = _repo.xpOn(_dateKey);
  }

  final DailyActivityRepository _repo;
  final String _dateKey;

  /// Re-syncs the reactive counter after a repository write.
  void setTotal(int newTotal) => state = newTotal;
}

/// The result of one daily-XP recording.
class DailyXpRecord {
  const DailyXpRecord({
    required this.xpToday,
    required this.goalXpTarget,
    required this.goalReachedNow,
  });

  /// XP earned today AFTER this event was recorded.
  final int xpToday;

  /// Today's XP target (derived from the profile's goal minutes).
  final int goalXpTarget;

  /// True when THIS event crossed the goal (fires once per day).
  final bool goalReachedNow;

  bool get goalMet => goalXpTarget <= 0 || xpToday >= goalXpTarget;
}

/// Records XP earned through a REAL learning event (lesson completion,
/// exam scoring) into today's counter and returns the resulting state.
///
/// Callers pass the XP actually awarded by the progress repository (the
/// same idempotency guards apply upstream — a repeat lesson completion
/// awards 0 and callers skip recording zeros).
final recordDailyXpProvider =
    Provider<Future<DailyXpRecord> Function(int amount)>((ref) {
  final repo = ref.watch(dailyActivityRepositoryProvider);
  final dateKey = ref.watch(todayDateKeyProvider);
  final goalMinutes = ref.watch(userProfileProvider).dailyGoalMinutes;

  return (amount) async {
    final before = repo.xpOn(dateKey);
    final target = dailyGoalXpTarget(goalMinutes);
    final result = await repo.addXp(dateKey, amount);
    final xpToday = result.fold((_) => before, (v) => v);

    // Update the reactive counter (the repository is the source of truth;
    // the notifier just mirrors it for the UI).
    ref.read(todayXpProvider.notifier).setTotal(xpToday);

    final goalReachedNow = target > 0 && before < target && xpToday >= target;
    if (goalReachedNow) {
      ref.log(const AnalyticsEvent(AnalyticsEventName.dailyGoalReached));
    }
    return DailyXpRecord(
      xpToday: xpToday,
      goalXpTarget: target,
      goalReachedNow: goalReachedNow,
    );
  };
});

/// Today's daily-goal snapshot for the UI.
final dailyGoalStateProvider = Provider<DailyGoalState>((ref) {
  final xpToday = ref.watch(todayXpProvider);
  final goalMinutes = ref.watch(userProfileProvider).dailyGoalMinutes;
  return DailyGoalState(
    dateKey: ref.watch(todayDateKeyProvider),
    xpEarnedToday: xpToday,
    goalMinutes: goalMinutes,
  );
});

// ─── Daily Review Challenge ────────────────────────────────────────────────

/// Today's review challenge: the first weak lesson (adaptive order) with
/// authored exercises, or null when everything practised is mastered.
final dailyReviewChallengeProvider = Provider<ReviewChallenge?>((ref) {
  final weakLessons = ref.watch(weakLessonsProvider);
  return pickDailyReviewChallenge(
    weakLessons,
    (lesson) => ref.watch(masteredExercisesProvider(lesson.id)).length,
    (lesson) => ref.watch(exercisesForLessonProvider(lesson.id)).length,
  );
});

/// True when today's review bonus has already been claimed.
final isReviewClaimedProvider = Provider<bool>((ref) {
  final repo = ref.watch(dailyActivityRepositoryProvider);
  return repo.isReviewClaimed(ref.watch(todayDateKeyProvider));
});

/// Attempts to claim today's review reward after a finished practice
/// session on [lessonId]. Returns the bonus amount when the claim PAID
/// (0 when there was no challenge, the lesson doesn't match, mastery is
/// incomplete, or the day's bonus was already claimed).
///
/// Payment path: the progress repository's idempotent bonus-XP ledger
/// (`review_<dateKey>`) — once per day, never double-paid even if two
/// sessions race the same claim.
final claimReviewChallengeProvider =
    Provider<Future<int> Function(String lessonId)>((ref) {
  final repo = ref.watch(dailyActivityRepositoryProvider);
  final progressRepo = ref.watch(progressRepositoryProvider);
  final dateKey = ref.watch(todayDateKeyProvider);

  return (lessonId) async {
    final challenge = ref.read(dailyReviewChallengeProvider);
    final mastered = ref.read(masteredExercisesProvider(lessonId)).length;
    final total = ref.read(exercisesForLessonProvider(lessonId)).length;

    final completes = completesReviewChallenge(
      challenge: challenge,
      lessonId: lessonId,
      masteredAfterSession: mastered,
      totalAuthored: total,
    );
    if (!completes) return 0;

    final claimed = await repo.claimReview(dateKey);
    var claimedNow = false;
    claimed.fold((_) {}, (v) => claimedNow = v);
    if (!claimedNow) return 0;

    final xp = await progressRepo.awardBonusXp(
      sourceId: reviewChallengeSourceId(dateKey),
      amount: kReviewChallengeBonusXp,
    );
    var paid = 0;
    xp.fold((_) {}, (totalXp) => paid = kReviewChallengeBonusXp);
    if (paid > 0) {
      ref.log(const AnalyticsEvent(
        AnalyticsEventName.reviewChallengeCompleted,
      ));
      ref.invalidate(xpTotalProvider);
      ref.invalidate(isReviewClaimedProvider);
    }
    return paid;
  };
});
