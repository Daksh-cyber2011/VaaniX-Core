/// Onboarding Page 3 — Subject Setup
///
/// User selects their CBSE class (6–10).
/// Board is fixed to CBSE in V1 (per PRD Section 8.1 Screen 4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/onboarding/domain/onboarding_state.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ObSubjectPage extends ConsumerWidget {
  const ObSubjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selectedClass = state.selectedClass;
    final companionName = state.resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Center(
            child: VanWidget(
              state: VanState.thinking,
              size: 130,
              showSpeechBubble: true,
              dialogueText: selectedClass == null
                  ? 'Which class are you in? '
                  : 'Perfect! ${selectedClass.label} it is!',
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Tell $companionName your class',
            style: AppTextStyles.headlineMedium(),
          ),
          const SizedBox(height: 6),
          Text(
            'Board: CBSE \u00b7 Subject: Sanskrit',
            style: AppTextStyles.bodyMedium(
                color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight)),
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: CbseClass.values.length,
            itemBuilder: (context, i) {
              final cbseClass = CbseClass.values[i];
              final isSelected = selectedClass == cbseClass;
              return _ClassChip(
                cbseClass: cbseClass,
                isSelected: isSelected,
                onTap: () => notifier.selectClass(cbseClass),
              );
            },
          ),
          if (selectedClass != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Text('', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedClass.label} \u00b7 CBSE Sanskrit',
                        style:
                            AppTextStyles.titleSmall(color: AppColors.primary),
                      ),
                      Text(
                        'Curriculum-aligned lessons ready for you!',
                        style: AppTextStyles.bodySmall(
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.subtextDark
                                    : AppColors.subtextLight)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          PrimaryButton(
            label: 'Continue',
            onPressed: selectedClass != null
                ? () => notifier.confirmSubjectSetup()
                : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.cbseClass,
    required this.isSelected,
    required this.onTap,
  });

  final CbseClass cbseClass;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color:
            isSelected ? AppColors.primary : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cbseClass.value}',
                style: AppTextStyles.titleLarge(
                  color: isSelected ? Colors.white : null,
                ),
              ),
              Text(
                'th',
                style: AppTextStyles.labelSmall(
                  color: isSelected
                      ? Colors.white70
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
