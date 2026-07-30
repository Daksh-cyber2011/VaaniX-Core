/// Onboarding Page 6 — The Nest Reveal
///
/// First view of The Nest — Van's cozy learning space.
/// Per PRD Section 8.1 Screen 7.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class ObNestRevealPage extends ConsumerStatefulWidget {
  const ObNestRevealPage({super.key});

  @override
  ConsumerState<ObNestRevealPage> createState() => _ObNestRevealPageState();
}

class _ObNestRevealPageState extends ConsumerState<ObNestRevealPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _nestController;
  late final Animation<double> _fade;
  late final Animation<double> _nestScale;
  late final Animation<Offset> _vanSlide;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _nestController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _vanSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));
    _nestScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _nestController, curve: Curves.easeOutBack),
    );

    _nestController.forward().then((_) => _entryController.forward());
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nestController.dispose();
    super.dispose();
  }

  Future<void> _onStart() async {
    setState(() => _isLoading = true);
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.goNamed(RouteNames.homeName);
  }

  @override
  Widget build(BuildContext context) {
    final companionName = ref.watch(onboardingProvider).resolvedName;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: FadeTransition(
            opacity: _fade,
            child: Row(
              children: [
                const StreakBadge(streakCount: 1, compact: true),
                const SizedBox(width: 8),
                const XpBadge(xpTotal: 0, compact: true),
                const Spacer(),
                Text(
                  '✨ The Nest',
                  style: AppTextStyles.titleSmall(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ScaleTransition(
              scale: _nestScale,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.nestWarmLight,
                      AppColors.vanYellow.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      left: 20,
                      child: _NestDecor(emoji: '📚', size: 28),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: _NestDecor(emoji: '🌱', size: 26),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 24,
                      child: _NestDecor(emoji: '📝', size: 22),
                    ),
                    Positioned(
                      bottom: 30,
                      right: 24,
                      child: _NestDecor(emoji: '🗺️', size: 22),
                    ),
                    Positioned(
                      top: 60,
                      right: 28,
                      child: _NestDecor(emoji: '☕', size: 20),
                    ),

                    Center(
                      child: SlideTransition(
                        position: _vanSlide,
                        child: FadeTransition(
                          opacity: _fade,
                          child: VanWidget(
                            state: VanState.happy,
                            size: 180,
                            showSpeechBubble: true,
                            dialogueText:
                                'This is where we\'ll study together, $companionName! 🦆',
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                Text(
                  "Welcome home, $companionName!",
                  style: AppTextStyles.headlineSmall(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your learning adventure begins now.',
                  style: AppTextStyles.bodyMedium(
                      color: AppColors.subtextLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: "Let's Start! 🎉",
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _onStart,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NestDecor extends StatefulWidget {
  const _NestDecor({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  State<_NestDecor> createState() => _NestDecorState();
}

class _NestDecorState extends State<_NestDecor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -3, end: 3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _float.value),
        child: Text(widget.emoji,
            style: TextStyle(fontSize: widget.size.toDouble())),
      ),
    );
  }
}
