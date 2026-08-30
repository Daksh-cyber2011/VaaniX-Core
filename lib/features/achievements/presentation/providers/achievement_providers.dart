/// VaaniX Achievements — Riverpod Providers
///
/// Wires the [AchievementRepository] and exposes reactive providers for
/// the UI:
///
/// - [achievementRepositoryProvider] — the repository instance
/// - [unlockedAchievementsProvider] — async map of unlocked achievement IDs
/// - [allAchievementsProgressProvider] — list of [AchievementProgress] with
///   current values computed from live progress data + isUnlocked from the repo
/// - [achievementCheckerProvider] — [AchievementChecker] that watches progress
///   data and auto-unlocks achievements when thresholds are met

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/data/achievement_repository.dart';
import 'package:vaanix_app/features/achievements/domain/achievement.dart';
import 'package:vaanix_app/features/achievements/domain/achievement_definitions.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// The repository instance.
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  return AchievementRepository(ref.watch(localStorageServiceProvider));
});

/// Async map of unlocked achievement IDs → unlock timestamps.
/// Re-fetches when [achievementCheckerProvider] invalidates it.
final unlockedAchievementsProvider =
    FutureProvider<Map<String, DateTime>>((ref) async {
  final repo = ref.watch(achievementRepositoryProvider);
  final result = await repo.getUnlocked();
  return result.fold((_) => <String, DateTime>{}, (v) => v);
});

/// Computes [AchievementProgress] for every achievement in the definitions,
/// using live progress data (completed lessons, quizzes, XP, streak) and
/// the persisted unlock map.
final allAchievementsProgressProvider =
    Provider<List<AchievementProgress>>((ref) {
  // Watch live progress data so this re-computes on any change.
  final completedLessons = ref.watch(completedLessonIdsProvider);
  final completedQuizzes = ref.watch(completedQuizIdsProvider);
  final xp = ref.watch(xpTotalProvider);
  final profile = ref.watch(userProfileProvider);
  final streak = profile.currentStreak;

  // Watch unlocked map (async — read valueOrNull for sync access).
  final unlockedAsync = ref.watch(unlockedAchievementsProvider);
  final unlocked = unlockedAsync.valueOrNull ?? {};

  return AchievementDefinitions.all.map((ach) {
    final current = _computeCurrent(
      ach,
      completedLessons: completedLessons.length,
      completedQuizzes: completedQuizzes.length,
      xp: xp,
      streak: streak,
    );

    final isUnlocked = unlocked.containsKey(ach.id);
    final unlockedAt = unlocked[ach.id];

    return AchievementProgress(
      achievement: ach,
      current: current,
      isUnlocked: isUnlocked,
      unlockedAt: unlockedAt,
    );
  }).toList();
});

/// Computes the current progress value for an achievement based on its
/// category.
int _computeCurrent(
  Achievement ach, {
  required int completedLessons,
  required int completedQuizzes,
  required int xp,
  required int streak,
}) {
  return switch (ach.category) {
    AchievementCategory.lessons => completedLessons,
    AchievementCategory.quizzes => completedQuizzes,
    AchievementCategory.streak => streak,
    AchievementCategory.xp => xp,
    AchievementCategory.special =>
      0, // special achievements are unlocked manually
  };
}

/// Provider that exposes the count of unlocked achievements (for the
/// Progress screen badge).
final unlockedCountProvider = Provider<int>((ref) {
  final all = ref.watch(allAchievementsProgressProvider);
  return all.where((a) => a.isUnlocked).length;
});

/// Provider that exposes the total count of achievements.
final totalAchievementsCountProvider = Provider<int>((ref) {
  return AchievementDefinitions.all.length;
});
