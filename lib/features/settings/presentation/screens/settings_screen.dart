/// Settings Screen
///
/// Controls app themes (Light/Dark/System), companion info, learning goals,
/// and account preferences. All preference cards are editable inline via
/// dialogs backed by [userProfileProvider].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/providers/session_manager.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:vaanix_app/core/theme/theme_notifier.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final profile = ref.watch(userProfileProvider);

    final companionName = profile.resolvedCompanionName;
    final personality = profile.personalityMode;
    final dailyGoal = profile.dailyGoalMinutes;
    final selectedClass = profile.cbseClass;

    return VaaniXScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Text(
            'APPEARANCE',
            style: AppTextStyles.labelSmall(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
          ),
          const SizedBox(height: 8),
          VaaniXCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme Mode',
                              style: AppTextStyles.titleMedium()),
                          Text(
                            themeMode == ThemeMode.system
                                ? 'System Default'
                                : themeMode == ThemeMode.dark
                                    ? 'Dark Mode'
                                    : 'Light Mode',
                            style: AppTextStyles.bodySmall(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.subtextDark
                                    : (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.settings_suggest_outlined, size: 18),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      ref
                          .read(themeNotifierProvider.notifier)
                          .setThemeMode(selected.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'LEARNING PROFILE',
            style: AppTextStyles.labelSmall(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
          ),
          const SizedBox(height: 8),

          VaaniXCard(
            onTap: () => _editCompanionName(context, ref, companionName),
            child: Row(
              children: [
                const Icon(Icons.emoji_nature_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Companion Name',
                          style: AppTextStyles.titleMedium()),
                      Text(
                        companionName,
                        style: AppTextStyles.bodySmall(
                            color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          VaaniXCard(
            onTap: () => _editPersonality(context, ref, personality),
            child: Row(
              children: [
                Icon(
                    personality?.emoji != null
                        ? Icons.emoji_emotions_outlined
                        : Icons.mood_bad_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Van's Personality",
                          style: AppTextStyles.titleMedium()),
                      Text(
                        personality == null
                            ? 'Not set'
                            : personality.label,
                        style: AppTextStyles.bodySmall(
                            color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          VaaniXCard(
            onTap: () => _editDailyGoal(context, ref, dailyGoal),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Goal', style: AppTextStyles.titleMedium()),
                      Text(
                        '$dailyGoal minutes / day',
                        style: AppTextStyles.bodySmall(
                            color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          VaaniXCard(
            onTap: () => _editClass(context, ref, selectedClass),
            child: Row(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CBSE Class', style: AppTextStyles.titleMedium()),
                      Text(
                        selectedClass != null ? selectedClass.label : 'Not set',
                        style: AppTextStyles.bodySmall(
                            color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'PROGRESS',
            style: AppTextStyles.labelSmall(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
          ),
          const SizedBox(height: 8),
          VaaniXCard(
            onTap: () => _confirmReset(context, ref),
            child: Row(
              children: [
                const Icon(Icons.restart_alt_rounded, color: AppColors.error),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reset Progress',
                          style: AppTextStyles.titleMedium(
                              color: AppColors.error)),
                      Text(
                        'Clears XP and completed lessons. Cannot be undone.',
                        style: AppTextStyles.bodySmall(
                            color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // â”€â”€â”€ ACCOUNT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (AppEnvironment.isSupabaseConfigured) ...[
            Text(
              'ACCOUNT',
              style: AppTextStyles.labelSmall(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
            ),
            const SizedBox(height: 8),
            VaaniXCard(
              onTap: () => _signOut(context, ref),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, color: AppColors.error),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign Out',
                            style: AppTextStyles.titleMedium(
                                color: AppColors.error)),
                        Text(
                          'End your session. Your local progress is kept.',
                          style: AppTextStyles.bodySmall(
                              color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: AppTextStyles.bodySmall(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.subtextDark : AppColors.subtextLight)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // â”€â”€â”€ Editors â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _editCompanionName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Van'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Van',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      await ref.read(userProfileProvider.notifier).updateCompanionName(result);
    }
  }

  Future<void> _editPersonality(
    BuildContext context,
    WidgetRef ref,
    PersonalityMode? current,
  ) async {
    final result = await showDialog<PersonalityMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Van's Personality"),
        children: PersonalityMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, mode),
            child: Row(
              children: [
                Icon(\n                  switch (mode) {\n                    PersonalityMode.cheerleader => Icons.celebration_rounded,\n                    PersonalityMode.calm => Icons.self_improvement_rounded,\n                    PersonalityMode.fun => Icons.mood_rounded,\n                  },\n                  size: 22,\n                  color: AppColors.primary,\n                ),
                const SizedBox(width: 12),
                Text(mode.label, style: AppTextStyles.titleMedium()),
                if (current == mode) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result != null) {
      await ref
          .read(userProfileProvider.notifier)
          .updatePersonalityMode(result);
    }
  }

  Future<void> _editDailyGoal(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Daily Goal'),
        children: AppConstants.dailyGoalOptions.map((minutes) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, minutes),
            child: Row(
              children: [
                Text('$minutes', style: AppTextStyles.titleLarge()),
                const SizedBox(width: 6),
                Text('min/day', style: AppTextStyles.bodySmall()),
                if (minutes == current) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result != null) {
      await ref.read(userProfileProvider.notifier).updateDailyGoal(result);
    }
  }

  Future<void> _editClass(
    BuildContext context,
    WidgetRef ref,
    CbseClass? current,
  ) async {
    final result = await showDialog<CbseClass>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('CBSE Class'),
        children: CbseClass.values.map((c) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: Row(
              children: [
                Text(c.label, style: AppTextStyles.titleMedium()),
                if (current == c) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result != null) {
      await ref.read(userProfileProvider.notifier).updateCbseClass(result);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'This clears your XP, completed lessons/quizzes, practice '
          'mastery, exam history, achievements and your day streak. '
          'Your onboarding profile (companion name, class, goals) is '
          'kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(progressRepositoryProvider).reset();
      await ref.read(achievementRepositoryProvider).clear();
      // The day streak measures learning behavior - it belongs to
      // progress, not to identity, so Reset clears it too.
      await ref.read(userProfileRepositoryProvider).resetLearningStreak();
      ref.invalidate(userProfileProvider);
      // Invalidate ALL progress-related providers so the UI updates
      // immediately. Previously only xpTotalProvider was invalidated,
      // leaving completedLessonIdsProvider and completedQuizIdsProvider
      // stale â€” the Learn and Progress screens kept showing completed
      // lessons until the providers were re-created (hot restart).
      ref.invalidate(xpTotalProvider);
      ref.invalidate(completedLessonIdsProvider);
      ref.invalidate(completedQuizIdsProvider);
      // Repository-level invalidation also rebuilds every per-lesson
      // mastered-exercises family instance (stale mastery fix) and the
      // achievements map.
      ref.invalidate(progressRepositoryProvider);
      ref.invalidate(achievementRepositoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress cleared. A fresh start!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your session will end, but your local progress (XP, streak, '
          'completed lessons) is kept on this device. You can sign back '
          'in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(sessionManagerProvider.notifier).signOut();
    if (!context.mounted) return;
    context.goNamed(RouteNames.authName);
  }
}
