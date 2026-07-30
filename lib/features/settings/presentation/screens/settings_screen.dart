/// Settings Screen
///
/// Controls app themes (Light/Dark/System), companion info, learning goals,
/// and account preferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/core/theme/theme_notifier.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final storage = ref.watch(localStorageServiceProvider);

    final companionName = storage.companionName;
    final dailyGoal = storage.dailyGoalMinutes;
    final selectedClass = storage.selectedClass;

    return VaaniXScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Text(
            'APPEARANCE',
            style: AppTextStyles.labelSmall(color: AppColors.subtextLight),
          ),
          const SizedBox(height: 8),
          VaaniXCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.brightness_6_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme Mode', style: AppTextStyles.titleMedium()),
                      Text(
                        themeMode == ThemeMode.system
                            ? 'System Default'
                            : themeMode == ThemeMode.dark
                                ? 'Dark Mode'
                                : 'Light Mode',
                        style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selected) {
                    ref.read(themeNotifierProvider.notifier).setThemeMode(selected.first);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'LEARNING PROFILE',
            style: AppTextStyles.labelSmall(color: AppColors.subtextLight),
          ),
          const SizedBox(height: 8),

          VaaniXCard(
            onTap: () {},
            child: Row(
              children: [
                const Icon(Icons.emoji_nature_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Companion Name', style: AppTextStyles.titleMedium()),
                      Text(
                        companionName,
                        style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtextLight),
              ],
            ),
          ),
          const SizedBox(height: 10),

          VaaniXCard(
            onTap: () {},
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
                        style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtextLight),
              ],
            ),
          ),
          const SizedBox(height: 10),

          VaaniXCard(
            onTap: () {},
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
                        selectedClass != null ? 'Class $selectedClass th' : 'Not set',
                        style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtextLight),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
