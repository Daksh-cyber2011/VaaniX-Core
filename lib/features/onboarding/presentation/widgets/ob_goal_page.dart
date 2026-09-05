/// Onboarding Page 4 — Daily Goal
///
/// User selects their daily learning goal: 5/10/15/20 minutes.
/// Van reacts to each choice. Per PRD Section 8.1 Screen 5.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ObGoalPage extends ConsumerWidget {
  const ObGoalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selected = state.dailyGoalMinutes;
    final companionName = state.resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: VanWidget(
              key: ValueKey(selected),
              state: _vanStateForGoal(selected),
              size: 140,
              showSpeechBubble: true,
              dialogueText: _vanReaction(selected, companionName),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Set your daily goal',
            style: AppTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Even 5 minutes a day builds a habit.',
            style: AppTextStyles.bodyMedium(
                color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...AppConstants.dailyGoalOptions.map((minutes) {
            final isSelected = minutes == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalTile(
                minutes: minutes,
                isSelected: isSelected,
                onTap: () => notifier.selectDailyGoal(minutes),
              ),
            );
          }),
          const Spacer(),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => notifier.confirmDailyGoal(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  VanState _vanStateForGoal(int minutes) {
    if (minutes >= 20) return VanState.achievement;
    if (minutes >= 15) return VanState.happy;
    if (minutes >= 10) return VanState.happy;
    return VanState.caring;
  }

  String _vanReaction(int minutes, String name) {
    switch (minutes) {
      case 5:
        return "5 minutes? I'll take it! Every day counts.";
      case 10:
        return "10 minutes! That's my favourite streak size! ";
      case 15:
        return "15 minutes — you mean business! Let's go! ";
      case 20:
        return "20 MINUTES?! $name, you're a legend! ";
      default:
        return 'How much time do you want to study each day?';
    }
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => '$minutes min / day';

  String get _badge {
    switch (minutes) {
      case 5:
        return 'Starter';
      case 10:
        return 'Recommended';
      case 15:
        return 'Dedicated';
      case 20:
        return 'Champion';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceVariantLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$minutes',
                    style: AppTextStyles.titleLarge(
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label, style: AppTextStyles.titleMedium()),
                  Text(
                    _badge,
                    style: AppTextStyles.labelSmall(
                      color: isSelected
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.subtextDark
                              : AppColors.subtextLight),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
