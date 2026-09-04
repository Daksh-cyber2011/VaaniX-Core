/// VaaniX Achievements — Screen
///
/// Displays all 10 achievements in a 2-column grid. Each card shows the
/// achievement icon, title, description, and a progress bar (current/threshold).
/// Locked achievements are greyed out; unlocked ones show a checkmark + date.
///
/// Entry points: Progress screen ("Achievements" card) and Settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/domain/achievement.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(allAchievementsProgressProvider);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;

    return VaaniXScaffold(
      title: 'Achievements',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // â”€â”€â”€ Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount / $totalCount Unlocked',
                        style: AppTextStyles.titleLarge(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep learning to unlock more!',
                        style: AppTextStyles.bodySmall(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.subtextDark
                                    : AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // â”€â”€â”€ Achievement Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          ..._sorted(achievements)
              .map((progress) => _AchievementCard(progress: progress)),
        ],
      ),
    );
  }

  /// Unlocked awards first, then locked ones ordered by how close the
  /// learner is to unlocking - the next win is always visible near the top.
  static List<AchievementProgress> _sorted(List<AchievementProgress> all) {
    final unlocked = all.where((a) => a.isUnlocked).toList()
      ..sort((a, b) =>
          (b.unlockedAt ?? DateTime(0)).compareTo(a.unlockedAt ?? DateTime(0)));
    final locked = all.where((a) => !a.isUnlocked).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    return [...unlocked, ...locked];
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final ach = progress.achievement;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlocked = progress.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppColors.success.withOpacity(0.06)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? AppColors.success.withOpacity(0.3)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.subtextLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForName(ach.iconName),
              color: isUnlocked ? AppColors.success : AppColors.subtextLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title + Description + Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ach.title,
                        style: AppTextStyles.titleSmall(
                          color: isUnlocked ? AppColors.success : null,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 18),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ach.description,
                  style: AppTextStyles.bodySmall(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight),
                ),
                const SizedBox(height: 8),
                if (isUnlocked) ...[
                  if (progress.unlockedAt != null)
                    Text(
                      'Unlocked ${_formatDate(progress.unlockedAt!)}',
                      style: AppTextStyles.labelSmall(color: AppColors.success),
                    ),
                ] else ...[
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 6,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.current} / ${ach.threshold}',
                    style: AppTextStyles.labelSmall(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight),
                  ),
                ],
              ],
            ),
          ),

          // XP reward badge
          if (ach.xpReward > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.xp.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${ach.xpReward} XP',
                style: AppTextStyles.labelSmall(color: AppColors.xp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForName(String name) {
    return switch (name) {
      'school' => Icons.school_rounded,
      'menu_book' => Icons.menu_book_rounded,
      'auto_stories' => Icons.auto_stories_rounded,
      'quiz' => Icons.quiz_rounded,
      'star' => Icons.star_rounded,
      'local_fire_department' => Icons.local_fire_department_rounded,
      'whatshot' => Icons.whatshot_rounded,
      'stars' => Icons.stars_rounded,
      'emoji_events' => Icons.emoji_events_rounded,
      'pets' => Icons.pets_rounded,
      _ => Icons.emoji_events_rounded,
    };
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }
}
