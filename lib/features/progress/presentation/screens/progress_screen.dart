/// Progress Screen — XP, Streak & Chapter Overview
///
/// Reads from [userProfileProvider], [xpTotalProvider], and the curriculum to
/// show the learner's overall progress: total XP, current streak, completed
/// lesson count, and per-chapter completion bars.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final xp = ref.watch(xpTotalProvider);
    final completed = ref.watch(completedLessonIdsProvider);
    final completedQuizIds = ref.watch(completedQuizIdsProvider);
    final curriculumAsync = ref.watch(curriculumProvider);

    // Extract curriculum data (or empty list while loading/error).
    final curriculum = curriculumAsync.valueOrNull ?? [];
    final totalLessons =
        curriculum.fold<int>(0, (s, c) => s + c.lessons.length);
    final completedCount = completed.length;
    final quizCount = completedQuizIds.length;

    // Gamification state (pure helpers, tested in gamification_test).
    final level = levelFromXp(xp);
    final progressPct = levelProgress(xp);
    final xpInto = xpIntoLevel(xp);
    final xpNext = xpForNextLevel(level);

    // Real persisted mastery summed across all curriculum lessons.
    var totalMastered = 0;
    var totalExercises = 0;
    for (final chapter in curriculum) {
      for (final lesson in chapter.lessons) {
        totalMastered += ref.watch(masteredExercisesProvider(lesson.id)).length;
        totalExercises += exercisesByLesson[lesson.id]?.length ?? 0;
      }
    }

    return VaaniXScaffold(
      title: 'Progress',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Hero stats
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                icon: '⭐',
                label: 'Total XP',
                value: '$xp',
                color: AppColors.xp,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                icon: '🔥',
                label: 'Day Streak',
                value: '${profile.currentStreak}',
                color: AppColors.streak,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                icon: '📚',
                label: 'Lessons Done',
                value: '$completedCount',
                color: AppColors.primary,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                icon: '🎯',
                label: 'Quizzes Done',
                value: '$quizCount',
                color: AppColors.success,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                icon: '📊',
                label: 'Completion',
                value: totalLessons == 0
                    ? '—'
                    : '${((completedCount / totalLessons) * 100).round()}%',
                color: AppColors.vanOrange,
              )),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // spacer for layout balance
            ],
          ),

          const SizedBox(height: 24),
          _LevelCard(
            level: level,
            levelProgress: progressPct,
            xpInto: xpInto,
            xpNext: xpNext,
          ),
          const SizedBox(height: 12),
          _MasteredCard(
            mastered: totalMastered,
            total: totalExercises,
          ),
          const SizedBox(height: 24),
          Text('CHAPTERS',
              style: AppTextStyles.labelSmall(color: AppColors.subtextLight)),
          const SizedBox(height: 8),

          ...curriculum.map((chapter) {
            final done =
                chapter.lessons.where((l) => completed.contains(l.id)).length;
            final pct =
                chapter.lessons.isEmpty ? 0.0 : done / chapter.lessons.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VaaniXCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(chapter.title,
                              style: AppTextStyles.titleMedium()),
                        ),
                        Text('$done/${chapter.lessons.length}',
                            style: AppTextStyles.labelMedium(
                                color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // ─── Achievements Entry Point ────────────────────────────
          const SizedBox(height: 24),
          VaaniXCard(
            onTap: () => context.go(RouteNames.achievements),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Achievements', style: AppTextStyles.titleMedium()),
                      Text(
                        'Tap to see your milestones',
                        style: AppTextStyles.bodySmall(
                            color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.subtextLight),
              ],
            ),
          ),

          if (xp == 0 && completedCount == 0) ...[
            const SizedBox(height: 16),
            const VanWidget(
              state: VanState.happy,
              size: 120,
              showSpeechBubble: true,
              dialogueText: 'Your journey starts now! ⭐',
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.levelProgress,
    required this.xpInto,
    required this.xpNext,
  });

  final int level;
  final double levelProgress;
  final int xpInto;
  final int xpNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Level $level',
                style: AppTextStyles.titleMedium(color: AppColors.primary),
              ),
              const Spacer(),
              Text(
                '$xpInto / $xpNext XP',
                style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(levelProgress * 100).round()}% to Level ${level + 1}',
            style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
          ),
        ],
      ),
    );
  }
}

class _MasteredCard extends StatelessWidget {
  const _MasteredCard({required this.mastered, required this.total});

  final int mastered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : mastered / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Exercises mastered',
                style: AppTextStyles.titleMedium(color: AppColors.success),
              ),
              const Spacer(),
              Text(
                total == 0 ? '-' : '$mastered / $total',
                style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.success.withValues(alpha: 0.1),
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'No practice exercises yet'
                : '${(pct * 100).round()}% of practice content mastered',
            style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(label,
                  style:
                      AppTextStyles.labelSmall(color: AppColors.subtextLight)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineMedium(color: color)),
        ],
      ),
    );
  }
}
