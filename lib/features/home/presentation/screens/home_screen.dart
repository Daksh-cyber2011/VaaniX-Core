/// Home Screen - The Nest (command center)
///
/// Van's cozy learning space. Shows the animated Van companion, the daily
/// greeting, streak / XP / level badges, and the learner's REAL state:
/// the next unfinished lesson (continue card), lesson progress, and
/// quick routes to Exam, Progress, Achievements and Chat.
///
/// All values come from live providers (profile, XP, completed lessons,
/// curriculum) - nothing here is static.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
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

  void _openNextLesson(String lessonId) {
    context.go(RouteNames.lessonContent.replaceFirst(':lessonId', lessonId));
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
    final completedSet = completedIds.toSet();
    final Lesson? nextLesson = curriculumAsync.maybeWhen(
      data: (chapters) => nextLessonInCurriculum(chapters, completedSet),
      orElse: () => null,
    );
    final totalLessons = curriculumAsync.maybeWhen(
      data: (chapters) =>
          chapters.fold<int>(0, (sum, c) => sum + c.lessons.length),
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Top bar: streak + XP + level + chat + avatar ----------
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
                      color: colorScheme.primary.withValues(alpha: 0.10),
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
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ---- The Nest: Van + greeting + continue card --------------
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.nestWarmDark
                      : AppColors.nestWarmLight,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        '$greeting!',
                        style: AppTextStyles.headlineSmall(
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    VanWidget(
                      size: 160,
                      useController: true,
                      showSpeechBubble: true,
                      dialogueText:
                          "Ready to learn with $companionName? I'll help you "
                          'every step of the way!',
                    ),
                    const Spacer(),
                    _ContinueCard(
                      nextLesson: nextLesson,
                      completedCount: completedSet.length,
                      totalLessons: totalLessons,
                      onOpen: nextLesson == null
                          ? null
                          : () => _openNextLesson(nextLesson.id),
                      onAllDone: () => context.go(RouteNames.exam),
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
                onPressed: nextLesson == null
                    ? () => context.go(RouteNames.learn)
                    : () => _openNextLesson(nextLesson.id),
                icon: Icon(
                  nextLesson == null
                      ? Icons.celebration_rounded
                      : Icons.menu_book_rounded,
                  color: Colors.white,
                ),
                label: nextLesson == null
                    ? "Start Today's Lesson"
                    : 'Continue: ${nextLesson.title}',
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
    return Material(
      color: colorScheme.primary.withValues(alpha: 0.06),
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

/// Live "continue learning" card: next unfinished lesson + progress.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.nextLesson,
    required this.completedCount,
    required this.totalLessons,
    required this.onOpen,
    required this.onAllDone,
  });

  final Lesson? nextLesson;
  final int completedCount;
  final int totalLessons;
  final VoidCallback? onOpen;
  final VoidCallback onAllDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = nextLesson == null && totalLessons > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
            color: colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  done ? 'All lessons complete!' : 'Continue learning',
                  style: AppTextStyles.labelMedium(color: colorScheme.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Take an exam to keep the streak alive'
                      : nextLesson?.title ?? 'Loading...',
                  style: AppTextStyles.titleSmall(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (totalLessons > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$completedCount of $totalLessons lessons done',
                    style: AppTextStyles.bodySmall(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          done
              ? IconButton(
                  onPressed: onAllDone,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  color: colorScheme.primary,
                  tooltip: 'Take an exam',
                )
              : TextButton(
                  onPressed: onOpen,
                  child: const Text('Go'),
                ),
        ],
      ),
    );
  }
}
