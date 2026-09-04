/// Home Screen - The Nest (command center)
///
/// Van's cozy learning space. Shows the animated Van companion, the daily
/// greeting, streak / XP / level badges, and the learner's REAL state:
/// the next unfinished lesson (continue card), lesson progress, and
/// quick routes to Exam, Progress, Achievements and Chat.
///
/// All values come from live providers (profile, XP, completed lessons,
/// curriculum) - nothing here is static.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_shadows.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/progress_meter.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/offline_banner.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Record today's activity so the streak stays current whenever the Nest
    // is opened. Fire-and-forget; the provider handles persistence.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).recordDailyActivity();
      ref.read(vanControllerProvider.notifier).dispatch(
            const VanEvent(
              VanEventType.appOpened,
              message: 'Welcome back! Ready to learn together?',
            ),
          );
    });
  }

  void _openAction(NextAction action) {
    ref.log(AnalyticsEvent(
      AnalyticsEventName.nextActionSelected,
      {'action': action.action.name},
    ));
    final route = _actionRoute(action);
    if (route != null) context.go(route);
  }

  String? _actionRoute(NextAction action) {
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

  IconData _actionIcon(AdaptiveAction action) {
    switch (action) {
      case AdaptiveAction.startJourney:
      case AdaptiveAction.continueLesson:
        return Icons.menu_book_rounded;
      case AdaptiveAction.practiceWeakTopic:
        return Icons.fitness_center_rounded;
      case AdaptiveAction.takeChapterExam:
        return Icons.quiz_rounded;
      case AdaptiveAction.allDone:
        return Icons.celebration_rounded;
    }
  }

  Lesson? _lessonById(List<Chapter> chapters, String lessonId) {
    for (final chapter in chapters) {
      for (final lesson in chapter.lessons) {
        if (lesson.id == lessonId) return lesson;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider);
    final xp = ref.watch(xpTotalProvider);
    final completedIds = ref.watch(completedLessonIdsProvider);
    final curriculumAsync = ref.watch(curriculumProvider);

    final companionName = profile.resolvedCompanionName;
    final streak = profile.currentStreak;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924\u092E\u094D' // suprabhatam
        : (hour < 17
            ? '\u0936\u0941\u092D \u0938\u093E\u092F\u092E\u094D' // shubha sayam
            : '\u0936\u0941\u092D\u0930\u093E\u0924\u094D\u0930\u093F\u0903'); // shubharatrih

    // Real learning state from live providers.
    final nextAction = ref.watch(adaptiveNextActionProvider);
    final Lesson? nextLesson = nextAction.lessonId == null
        ? null
        : curriculumAsync.maybeWhen(
            data: (chapters) => _lessonById(chapters, nextAction.lessonId!),
            orElse: () => null,
          );
    final completedSet = completedIds.toSet();
    final totalLessons = curriculumAsync.maybeWhen(
      data: (chapters) =>
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length),
      orElse: () => 0,
    );

    // Practice mastery for the highlighted lesson (real persisted state).
    final practiceLessonId = nextAction.lessonId;
    final masteredIds = practiceLessonId == null
        ? const <String>[]
        : ref.watch(masteredExercisesProvider(practiceLessonId));
    final lessonExercises = practiceLessonId == null
        ? const <Exercise>[]
        : ref.watch(exercisesForLessonProvider(practiceLessonId));

    final showJourneyProgress = totalLessons > 0;
    final journeyProgress =
        showJourneyProgress ? completedSet.length / totalLessons : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greetingColor =
        isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Top bar: streak + XP + level + chat + settings ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (streak > 0) ...[
                    StreakBadge(streakCount: streak),
                    const SizedBox(width: 10),
                  ],
                  XpBadge(xpTotal: xp),
                  const SizedBox(width: 10),
                  // Level pill derived from XP (deterministic curve).
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Lv ${levelFromXp(xp)}',
                      style:
                          AppTextStyles.labelMedium(color: colorScheme.primary),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.go(RouteNames.chat),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    tooltip: 'Chat with $companionName',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => context.go(RouteNames.settings),
                    icon: const Icon(Icons.person_outline_rounded),
                    tooltip: 'Profile and settings',
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

            // ---- Offline status (appears only when offline) -------------
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: OfflineBanner(),
            ),

            // ---- The Nest: Van + greeting + continue card --------------
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.nestWarmDark
                      : AppColors.nestWarmLight,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Sanskrit greeting stays as the brand's warm eyebrow;
                    // the actionable line lives in Van's speech bubble.
                    Text(
                      greeting,
                      style: AppTextStyles.titleSmall(
                        color: greetingColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    VanWidget(
                      size: AppDimens.vanSizeHero,
                      useController: true,
                      showSpeechBubble: true,
                      dialogueText: nextAction.vanMessage,
                    ),
                    const Spacer(),
                    _ContinueCard(
                      action: nextAction,
                      nextLesson: nextLesson,
                      completedCount: completedSet.length,
                      totalLessons: totalLessons,
                      journeyProgress: journeyProgress,
                      masteredCount: masteredIds.length,
                      totalExercises: lessonExercises.length,
                      onTap: () => _openAction(nextAction),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ---- CTAs: continue + exam + progress ----------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: PrimaryButton(
                onPressed: () => _openAction(nextAction),
                icon: Icon(_actionIcon(nextAction.action), color: Colors.white),
                label: nextAction.label,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SecondaryCta(
                      icon: Icons.quiz_outlined,
                      label: 'Exam',
                      onTap: () => context.go(RouteNames.exam),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryCta(
                      icon: Icons.insights_rounded,
                      label: 'Progress',
                      onTap: () => context.go(RouteNames.progress),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryCta(
                      icon: Icons.emoji_events_outlined,
                      label: 'Awards',
                      onTap: () => context.go(RouteNames.achievements),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact secondary action tile used under the primary CTA.
class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? AppColors.surfaceDark
          : colorScheme.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.labelMedium(color: colorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live next-action hero card inside the Nest. Driven entirely by the
/// adaptive engine - the title, subtitle and icon change with the
/// recommended action. The whole card is the tap target; there is no
/// duplicate "Go" affordance.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.action,
    required this.nextLesson,
    required this.completedCount,
    required this.totalLessons,
    required this.journeyProgress,
    required this.masteredCount,
    required this.totalExercises,
    required this.onTap,
  });

  final NextAction action;
  final Lesson? nextLesson;
  final int completedCount;
  final int totalLessons;
  final double journeyProgress;
  final int masteredCount;
  final int totalExercises;
  final VoidCallback onTap;

  IconData get _icon {
    switch (action.action) {
      case AdaptiveAction.startJourney:
      case AdaptiveAction.continueLesson:
        return Icons.menu_book_rounded;
      case AdaptiveAction.practiceWeakTopic:
        return Icons.fitness_center_rounded;
      case AdaptiveAction.takeChapterExam:
        return Icons.quiz_rounded;
      case AdaptiveAction.allDone:
        return Icons.celebration_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subtext = colorScheme.onSurface.withOpacity(0.62);
    final showProgress = action.action == AdaptiveAction.continueLesson ||
        action.action == AdaptiveAction.startJourney;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: AppShadows.raised,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.title,
                        style: AppTextStyles.labelMedium(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        style: AppTextStyles.titleSmall(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showProgress &&
                          totalExercises > 0 &&
                          nextLesson != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          masteredCount >= totalExercises
                              ? 'Practice complete - $masteredCount/$totalExercises'
                              : 'Practice: $masteredCount of $totalExercises mastered',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                      if (showProgress && totalLessons > 0) ...[
                        const SizedBox(height: 8),
                        ProgressMeter(
                          value: journeyProgress,
                          height: 6,
                          semanticLabel:
                              '$completedCount of $totalLessons lessons completed',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount of $totalLessons lessons done',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
