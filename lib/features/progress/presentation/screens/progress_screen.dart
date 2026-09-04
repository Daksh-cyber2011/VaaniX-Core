/// Progress Screen - XP, Streak & Chapter Overview
///
/// Reads from [userProfileProvider], [xpTotalProvider], and the curriculum to
/// show the learner's overall progress: total XP, current streak, completed
/// lesson count, and per-chapter completion bars.
///
/// Hierarchy (top to bottom):
///   1. NEXT FOCUS - the adaptive engine's recommendation is always the
///      first thing a learner sees.
///   2. Fresh-learner VAN welcome (only before the first lesson).
///   3. Stat tiles (XP / streak / lessons / quizzes).
///   4. Level + mastery meters.
///   5. Weak areas (real persisted mastery).
///   6. Chapters with exam performance.
///   7. Achievements entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/progress_meter.dart';
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
    final nextAction = ref.watch(adaptiveNextActionProvider);
    final weakLessons = ref.watch(weakLessonsProvider);
    final chapterBest = ref.watch(chapterBestFractionProvider);

    // Extract curriculum data (or empty list while loading/error).
    final curriculum = curriculumAsync.valueOrNull ?? [];
    final totalLessons =
        curriculum.fold<int>(0, (s, c) => s + c.lessons.length);
    final completedCount = completed.length;
    final quizCount = completedQuizIds.length;
    final isFreshLearner = xp == 0 && completedCount == 0;

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
          // ---- 1. Adaptive next focus (always first) ------------------
          _FocusCard(
            action: nextAction,
            onTap: _routeForAction(nextAction) == null
                ? null
                : () => context.go(_routeForAction(nextAction)!),
          ),
          if (isFreshLearner) ...[
            const SizedBox(height: 8),
            const VanWidget(
              state: VanState.happy,
              size: 120,
              showSpeechBubble: true,
              dialogueText: 'Your journey starts now!',
            ),
          ],

          const SizedBox(height: 20),
          // ---- 2. Stat tiles -------------------------------------------
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bolt_rounded,
                  label: 'Total XP',
                  value: '$xp',
                  color: AppColors.xp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Day Streak',
                  value: '${profile.currentStreak}',
                  color: AppColors.streak,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Lessons Done',
                  value: '$completedCount',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.quiz_rounded,
                  label: 'Quizzes Done',
                  value: '$quizCount',
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          // ---- 3. Level + mastery meters -------------------------------
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

          if (weakLessons.isNotEmpty) ...[
            const SizedBox(height: 20),
            _WeakAreasCard(
              lessons: weakLessons,
              masteredOf: (lesson) =>
                  ref.watch(masteredExercisesProvider(lesson.id)).length,
              totalOf: (lesson) => exercisesByLesson[lesson.id]?.length ?? 0,
            ),
          ],

          // ---- 4. Chapters with exam performance -----------------------
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'CHAPTERS',
                style: AppTextStyles.labelSmall(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.subtextDark
                      : AppColors.subtextLight,
                ),
              ),
              const Spacer(),
              if (totalLessons > 0)
                Text(
                  '${(completedCount / totalLessons * 100).round()}% complete',
                  style: AppTextStyles.labelSmall(
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          ...curriculum.map((chapter) {
            final done =
                chapter.lessons.where((l) => completed.contains(l.id)).length;
            final pct =
                chapter.lessons.isEmpty ? 0.0 : done / chapter.lessons.length;
            final best = chapterBest[chapter.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VaaniXCard(
                onTap: () => context.go(RouteNames.learn),
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
                    ProgressMeter(
                      value: pct,
                      height: 8,
                      semanticLabel:
                          '$done of ${chapter.lessons.length} lessons in ${chapter.title}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            best != null
                                ? 'Exam best: ${(best * 100).round()}%'
                                : (done == chapter.lessons.length &&
                                        chapter.lessons.isNotEmpty
                                    ? 'Lessons done - take the exam to lock in'
                                    : 'Exam not attempted'),
                            style: AppTextStyles.bodySmall(
                              color: best != null
                                  ? AppColors.success
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.subtextDark
                                      : AppColors.subtextLight),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.subtextLight, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          // ---- 5. Achievements entry ------------------------------------
          const SizedBox(height: 20),
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.subtextDark
                              : AppColors.subtextLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.subtextLight),
              ],
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
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
                style: AppTextStyles.bodySmall(color: subtext),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressMeter(
            value: levelProgress.clamp(0.0, 1.0),
            height: 8,
            semanticLabel: 'Progress to level ${level + 1}',
          ),
          const SizedBox(height: 6),
          Text(
            '${(levelProgress * 100).round()}% to Level ${level + 1}',
            style: AppTextStyles.bodySmall(color: subtext),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final pct = total == 0 ? 0.0 : mastered / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
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
                style: AppTextStyles.bodySmall(color: subtext),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressMeter(
            value: pct,
            height: 8,
            color: AppColors.success,
            semanticLabel: 'Practice mastery',
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'No practice exercises yet'
                : '${(pct * 100).round()}% of practice content mastered',
            style: AppTextStyles.bodySmall(color: subtext),
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

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelSmall(color: subtext)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineMedium(color: color)),
        ],
      ),
    );
  }
}

/// Route target for a next action (mirrors Home's mapping; kept local to
/// avoid cross-feature coupling for a few lines of UI glue).
String? _routeForAction(NextAction action) {
  switch (action.action) {
    case AdaptiveAction.startJourney:
    case AdaptiveAction.continueLesson:
      final id = action.lessonId;
      return id == null
          ? RouteNames.learn
          : RouteNames.lessonContent.replaceFirst(':lessonId', id);
    case AdaptiveAction.practiceWeakTopic:
      final id = action.lessonId;
      return id == null
          ? RouteNames.learn
          : RouteNames.lessonPractice.replaceFirst(':lessonId', id);
    case AdaptiveAction.takeChapterExam:
      return RouteNames.exam;
    case AdaptiveAction.allDone:
      return RouteNames.chat;
  }
}

/// The adaptive recommendation, rendered as the learner's next focus.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.action, this.onTap});

  final NextAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final IconData icon = switch (action.action) {
      AdaptiveAction.startJourney ||
      AdaptiveAction.continueLesson =>
        Icons.menu_book_rounded,
      AdaptiveAction.practiceWeakTopic => Icons.fitness_center_rounded,
      AdaptiveAction.takeChapterExam => Icons.quiz_rounded,
      AdaptiveAction.allDone => Icons.celebration_rounded,
    };
    return VaaniXCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT FOCUS',
                    style: AppTextStyles.labelSmall(color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(action.title, style: AppTextStyles.titleMedium()),
                const SizedBox(height: 2),
                Text(action.subtitle,
                    style: AppTextStyles.bodySmall(color: subtext)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.subtextLight),
        ],
      ),
    );
  }
}

/// Real weak-area list derived from persisted mastery (up to five, plus a
/// remainder hint). Every count comes from the progress repository.
class _WeakAreasCard extends StatelessWidget {
  const _WeakAreasCard({
    required this.lessons,
    required this.masteredOf,
    required this.totalOf,
  });

  final List<Lesson> lessons;
  final int Function(Lesson) masteredOf;
  final int Function(Lesson) totalOf;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final visible = lessons.take(5).toList();
    return VaaniXCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text('Weak areas', style: AppTextStyles.titleMedium()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lessons you completed - finish their exercises to lock them in.',
            style: AppTextStyles.bodySmall(color: subtext),
          ),
          const SizedBox(height: 8),
          for (final lesson in visible)
            _WeakLessonTile(
              lesson: lesson,
              mastered: masteredOf(lesson),
              total: totalOf(lesson),
            ),
          if (lessons.length > visible.length) ...[
            const SizedBox(height: 4),
            Text(
              '+${lessons.length - visible.length} more',
              style: AppTextStyles.labelSmall(color: subtext),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeakLessonTile extends StatelessWidget {
  const _WeakLessonTile({
    required this.lesson,
    required this.mastered,
    required this.total,
  });

  final Lesson lesson;
  final int mastered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    // Transparent Material so ListTile ink splashes paint on a Material
    // ancestor instead of being hidden by the card's DecoratedBox.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.repeat_rounded, color: AppColors.accent),
        title: Text(lesson.title, style: AppTextStyles.bodyLarge()),
        subtitle: Text(
          '$mastered of $total exercises mastered',
          style: AppTextStyles.bodySmall(color: subtext),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.subtextLight),
        onTap: () => context
            .go(RouteNames.lessonPractice.replaceFirst(':lessonId', lesson.id)),
      ),
    );
  }
}
