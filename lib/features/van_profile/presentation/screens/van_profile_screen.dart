/// Van Profile Screen
///
/// Shows Van with his current personality mode and lets the learner change
/// it inline. Tapping Van plays a reaction. Reads/writes via
/// [userProfileProvider].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class VanProfileScreen extends ConsumerStatefulWidget {
  const VanProfileScreen({super.key});

  @override
  ConsumerState<VanProfileScreen> createState() => _VanProfileScreenState();
}

class _VanProfileScreenState extends ConsumerState<VanProfileScreen> {
  VanState _tapState = VanState.idle;

  void _onTapVan() {
    setState(() => _tapState = VanState.happy);
    Future.delayed(const Duration(milliseconds: 800),
        () => mounted ? setState(() => _tapState = VanState.idle) : null);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final companionName = profile.resolvedCompanionName;
    final mode = profile.personalityMode;

    return VaaniXScaffold(
      title: companionName,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Center(
            child: VanWidget(
              state: _tapState == VanState.happy ? VanState.happy : VanState.idle,
              size: 180,
              showSpeechBubble: true,
              dialogueText: mode == null
                  ? "Hi, I'm $companionName! Tap me! 🦆"
                  : _reaction(mode, companionName),
              onTap: _onTapVan,
            ),
          ),
          const SizedBox(height: 32),
          Text('PERSONALITY',
              style:
                  AppTextStyles.labelSmall(color: AppColors.subtextLight)),
          const SizedBox(height: 8),
          ...PersonalityMode.values.map((m) {
            final selected = mode == m;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => ref
                    .read(userProfileProvider.notifier)
                    .updatePersonalityMode(m),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.borderLight,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(m.label, style: AppTextStyles.titleMedium()),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (mode != null) ...[
            const SizedBox(height: 24),
            PrimaryButton.text(
              label: 'Reset to default',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => ref
                  .read(userProfileProvider.notifier)
                  .updatePersonalityMode(PersonalityMode.cheerleader),
            ),
          ],
        ],
      ),
    );
  }

  String _reaction(PersonalityMode mode, String name) {
    switch (mode) {
      case PersonalityMode.cheerleader:
        return "LET'S GO! I'm $name, your hype duck! 🎉";
      case PersonalityMode.calm:
        return "Hi, I'm $name. We'll go step by step. 🌿";
      case PersonalityMode.fun:
        return "Quack! $name here, ready to learn! 🦆";
    }
  }
}
