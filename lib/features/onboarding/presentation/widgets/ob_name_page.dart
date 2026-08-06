/// Onboarding Page 1 — Name Van
///
/// Van walks in with a dialogue bubble. User can type a name
/// or accept the default "Van". Per PRD Section 8.1 Screen 2.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ObNamePage extends ConsumerStatefulWidget {
  const ObNamePage({super.key});

  @override
  ConsumerState<ObNamePage> createState() => _ObNamePageState();
}

class _ObNamePageState extends ConsumerState<ObNamePage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _vanEntryController;
  late final Animation<Offset> _vanSlide;
  late final Animation<double> _vanFade;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _vanEntryController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _vanSlide = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _vanEntryController,
      curve: Curves.easeOutCubic,
    ));
    _vanFade = CurvedAnimation(
      parent: _vanEntryController,
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _vanEntryController.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _vanEntryController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final name = _controller.text.trim();
    ref.read(onboardingProvider.notifier).setCompanionName(name);
    ref.read(onboardingProvider.notifier).confirmCompanionName();
  }

  @override
  Widget build(BuildContext context) {
    final companionName = ref.watch(onboardingProvider).resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          SlideTransition(
            position: _vanSlide,
            child: FadeTransition(
              opacity: _vanFade,
              child: VanWidget(
                state: VanState.happy,
                size: 160,
                showSpeechBubble: true,
                dialogueText: "Hi! I'm Van 🦆 What would you like to call me?",
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            'Name Your Companion',
            style: AppTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can always rename later.',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
          ),

          const SizedBox(height: 32),

          TextField(
            controller: _controller,
            onChanged: (v) => setState(() {}),
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Van (default)',
              counterText: '',
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _controller.clear()),
                    )
                  : null,
            ),
            style: AppTextStyles.bodyLarge(),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              key: ValueKey(companionName),
              '"$companionName and I are going to study together!"',
              style: AppTextStyles.bodySmall(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(),

          PrimaryButton(
            label: 'Continue',
            onPressed: _onContinue,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
