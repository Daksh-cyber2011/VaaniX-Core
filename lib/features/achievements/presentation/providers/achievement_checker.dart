/// VaaniX Achievements — Achievement Checker
///
/// Watches live progress data (completed lessons, quizzes, XP, streak)
/// and automatically unlocks achievements when thresholds are met.
///
/// On unlock:
///   1. Calls [AchievementRepository.unlock] to persist the unlock.
///   2. Awards bonus XP through the progress repository's bonus-XP ledger
///      (idempotent per achievement, and never pollutes the completed
///      lesson records).
///   3. Returns the list of newly-unlocked [Achievement]s so the UI can
///      show a celebration overlay.
///
/// The checker is called after every lesson completion, quiz completion,
/// and streak update. It's also called when the user chats with Van for
/// the first time (for the 'van_friend' achievement).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';

import 'package:vaanix_app/features/achievements/data/achievement_repository.dart';
import 'package:vaanix_app/features/achievements/domain/achievement.dart';

import 'package:vaanix_app/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

class AchievementChecker {
  AchievementChecker(this._ref);

  final Ref _ref;

  /// Check all achievements against current progress and unlock any that
  /// are newly earned. Returns the list of newly-unlocked achievements
  /// (empty if none were newly unlocked).
  ///
  /// Call this after:
  ///   - Lesson completion (Learn screen / LessonContentScreen)
  ///   - Quiz completion (Exam screen)
  ///   - Streak update (Home screen recordDailyActivity)
  ///   - First chat message (ChatController)
  Future<List<Achievement>> checkAchievements({
    int? quizScorePercentage,
    bool didChatWithVan = false,
  }) async {
    final repo = _ref.read(achievementRepositoryProvider);
    // Authoritative persisted unlock map, awaited: the async provider may
    // still be pending right after app start, and reading its cached empty
    // map would re-report already-unlocked achievements.
    final persistedUnlocked =
        await _ref.read(unlockedAchievementsProvider.future);
    final progressList = _ref.read(allAchievementsProgressProvider);
    final newlyUnlocked = <Achievement>[];

    for (final progress in progressList) {
      if (progress.isUnlocked) continue; // already unlocked (UI cache)
      if (persistedUnlocked.containsKey(progress.achievement.id)) {
        continue; // already unlocked (authoritative persistence)
      }

      final ach = progress.achievement;
      bool shouldUnlock = false;

      // Standard threshold-based achievements.
      if (progress.current >= ach.threshold) {
        shouldUnlock = true;
      }

      // Special: perfect quiz score (threshold is 100, meaning 100%).
      if (ach.id == 'perfect_quiz' && quizScorePercentage != null) {
        if (quizScorePercentage >= ach.threshold) {
          shouldUnlock = true;
        }
      }

      // Special: chat with Van (threshold is 1, meaning do it once).
      if (ach.id == 'van_friend' && didChatWithVan) {
        shouldUnlock = true;
      }

      if (shouldUnlock) {
        final result = await repo.unlock(ach.id);
        var unlockedNow = false;
        result.fold(
          (_) {}, // persistence failure: skip XP + celebration for safety
          (_) => unlockedNow = true,
        );
        if (!unlockedNow) continue;

        newlyUnlocked.add(ach);
        _ref.log(AnalyticsEvent(
          AnalyticsEventName.achievementUnlocked,
          {'achievementId': ach.id},
        ));

        // Award bonus XP through the dedicated ledger (Phase 1 repair).
        // The old path routed this through completeLesson() with a
        // synthetic `ach_*` lesson id, which corrupted lesson counts and
        // journey progress everywhere. The ledger is idempotent per
        // achievement and never touches completed-lesson records.
        if (ach.xpReward > 0) {
          final xpResult = await _ref
              .read(progressRepositoryProvider)
              .awardBonusXp(
                sourceId: 'ach_${ach.id}',
                amount: ach.xpReward,
              );
          xpResult.fold(
            (_) {},
            (_) => _ref.invalidate(xpTotalProvider),
          );
        }
      }
    }

    // Invalidate the progress providers so the UI updates.
    if (newlyUnlocked.isNotEmpty) {
      _ref.invalidate(unlockedAchievementsProvider);
      _ref.invalidate(allAchievementsProgressProvider);
    }

    return newlyUnlocked;
  }
}

/// Provider for the [AchievementChecker].
final achievementCheckerProvider = Provider<AchievementChecker>((ref) {
  return AchievementChecker(ref);
});
