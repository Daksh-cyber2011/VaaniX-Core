/// Progress Screen — XP, Streak & Chapter Overview
///
/// Reads from [userProfileProvider], [xpTotalProvider], and the curriculum to
/// show the learner's overall progress: total XP, current streak, completed
/// lesson count, and per-chapter completion bars.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
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
    final curriculum = ref.watch(curriculumProvider);

    final totalLessons = curriculum.fold<int>(0, (s, c) => s + c.lessons.length);
    final completedCount = completed.length;

    return VaaniXScaffold(
      title: 'Progress',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Hero stats
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: '⭐',
                label: 'Total XP',
                value: '$xp',
                color: AppColors.xp,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
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
              Expanded(child: _StatCard(
                icon: '📚',
                label: 'Lessons Done',
                value: '$completedCount',
                color: AppColors.primary,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: '🎯',
                label: 'Accuracy',
                value: totalLessons == 0
                    ? '—'
                    : '${((completedCount / totalLessons) * 100).round()}%',
                color: AppColors.success,
              )),
            ],
          ),

          const SizedBox(height: 24),
          Text('CHAPTERS',
              style:
                  AppTextStyles.labelSmall(color: AppColors.subtextLight)),
          const SizedBox(height: 8),

          ...curriculum.map((chapter) {
            final done = chapter.lessons
                .where((l) => completed.contains(l.id))
                .length;
            final pct = chapter.lessons.isEmpty
                ? 0.0
                : done / chapter.lessons.length;
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
