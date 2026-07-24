/// Onboarding Page 2 — Personality Mode
///
/// User selects how they want Van to behave: Cheerleader / Calm / Fun.
/// Van visually reacts to each selection via VanState change.
/// Per PRD Section 8.1 Screen 3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../../../shared/widgets/van_widget.dart';
import '../../domain/onboarding_state.dart';
import '../providers/onboarding_provider.dart';

/// Describes a selectable personality mode card.
class _ModeOption {
  const _ModeOption({
    required this.mode,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.vanState,
    required this.color,
  });

  final PersonalityMode mode;
  final String emoji;
  final String title;
  final String subtitle;
  final VanState vanState;
  final Color color;
}

const _modes = [
  _ModeOption(
    mode: PersonalityMode.cheerleader,
    emoji: '🎉',
    title: 'Cheerleader',
    subtitle: 'Energetic hype. Celebrates every win.',
    vanState: VanState.achievement,
    color: AppColors.accentOrange,
  ),
  _ModeOption(
    mode: PersonalityMode.calm,
    emoji: '🌿',
    title: 'Calm',
    subtitle: 'Patient and steady. Great for focus.',
    vanState: VanState.caring,
    color: AppColors.success,
  ),
  _ModeOption(
    mode: PersonalityMode.fun,
    emoji: '🦆',
    title: 'Fun',
    subtitle: 'Silly duck puns. Keeps it light.',
    vanState: VanState.funny,
    color: AppColors.primary,
  ),
];

class ObPersonalityPage extends ConsumerWidget {
  const ObPersonalityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selected = state.personalityMode;

    // Determine Van's display state based on selection
    final vanState = selected != null
        ? _modes.firstWhere((m) => m.mode == selected).vanState
        : VanState.idle;

    final companionName = state.resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // ── Van reacts to selection ─────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            child: VanWidget(
              key: ValueKey(vanState),
              state: vanState,
              size: 140,
              showSpeechBubble: true,
              dialogueText: selected == null
                  ? 'How do you want me to study with you?'
                  : _modeReaction(selected, companionName),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'How should $companionName act?',
            style: AppTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can change this anytime in settings.',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
          ),

          const SizedBox(height: 28),

          // ── Mode Cards ─────────────────────────────────────────
          ...List.generate(_modes.length, (i) {
            final option = _modes[i];
            final isSelected = selected == option.mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModeCard(
                option: option,
                isSelected: isSelected,
                onTap: () => notifier.selectPersonalityMode(option.mode),
              ),
            );
          }),

          const Spacer(),

          PrimaryButton(
            label: 'Continue',
            onPressed: selected != null
                ? () => notifier.confirmPersonalityMode()
                : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _modeReaction(PersonalityMode mode, String name) {
    switch (mode) {
      case PersonalityMode.cheerleader:
        return "LET'S GO $name! 🎉 I'll be your biggest fan!";
      case PersonalityMode.calm:
        return "Perfect. We'll take it step by step, together. 🌿";
      case PersonalityMode.fun:
        return "Quack! This is gonna be a great time 🦆";
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ModeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? option.color.withOpacity(0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? option.color : AppColors.borderLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: option.color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: option.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(option.emoji,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: AppTextStyles.titleMedium()),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: AppTextStyles.bodySmall(
                          color: AppColors.subtextLight),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: option.color,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
