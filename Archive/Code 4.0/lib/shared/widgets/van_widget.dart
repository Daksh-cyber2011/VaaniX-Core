/// Van Widget — AI Companion Display
///
/// Placeholder widget for Van the duck companion.
/// When Lottie animations are ready, this widget will switch to
/// playing the appropriate .json animation based on [state].
///
/// Used on: Home (The Nest), Onboarding, Lesson screens, Celebration screen.

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// The emotional state Van should display.
/// Maps to the 8 primary emotion families from PRD Section 6.3.
enum VanState {
  idle,        // Normal breathing, idle animations
  happy,       // Correct answer, login, streak
  thinking,    // Processing, waiting, explaining
  focus,       // During quizzes
  caring,      // User struggling
  surprised,   // Achievements
  sad,         // Mild only — never depressing
  funny,       // Humor moments
  achievement, // Streaks, milestones
}

class VanWidget extends StatefulWidget {
  const VanWidget({
    super.key,
    this.state = VanState.idle,
    this.size = 160.0,
    this.onTap,
    this.onLongPress,
    this.showSpeechBubble = false,
    this.dialogueText,
  });

  final VanState state;

  /// Width/Height of the Van widget (it's always square)
  final double size;

  /// Tap → random reaction from pool of 20+ responses (PRD Section 8.2)
  final VoidCallback? onTap;

  /// Long press → rare special reactions (PRD Section 8.2)
  final VoidCallback? onLongPress;

  /// Whether to show a speech bubble above Van
  final bool showSpeechBubble;

  /// Van's dialogue text shown in the speech bubble
  final String? dialogueText;

  @override
  State<VanWidget> createState() => _VanWidgetState();
}

class _VanWidgetState extends State<VanWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    // Idle breathing animation — 3–4s cycle (PRD Section 6.4)
    _idleController = AnimationController(
      duration: Duration(milliseconds: AppConstants.vanIdleCycleDurationMs),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speech bubble (shown above Van)
          if (widget.showSpeechBubble && widget.dialogueText != null)
            _SpeechBubble(text: widget.dialogueText!),
          if (widget.showSpeechBubble && widget.dialogueText != null)
            const SizedBox(height: 8),

          // Van character
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.state == VanState.idle
                    ? _breatheAnimation.value
                    : 1.0,
                child: child,
              );
            },
            child: _VanBody(
              size: widget.size,
              state: widget.state,
            ),
          ),
        ],
      ),
    );
  }
}

/// Van's visual body — placeholder until Lottie assets are ready.
/// Colors and proportions match the VAN Design Bible (Chapter 2 & 4).
class _VanBody extends StatelessWidget {
  const _VanBody({required this.size, required this.state});

  final double size;
  final VanState state;

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with Lottie.asset(animationPath) when assets are ready
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Body (≈35% of height per design bible)
          Positioned(
            bottom: size * 0.15,
            child: Container(
              width: size * 0.55,
              height: size * 0.40,
              decoration: BoxDecoration(
                color: AppColors.vanYellow,
                borderRadius: BorderRadius.circular(size * 0.2),
              ),
            ),
          ),
          // Head (≈45% of height per design bible — circular)
          Positioned(
            top: size * 0.05,
            child: Container(
              width: size * 0.60,
              height: size * 0.55,
              decoration: BoxDecoration(
                color: AppColors.vanYellow,
                borderRadius: BorderRadius.circular(size * 0.30),
              ),
              child: Stack(
                children: [
                  // Eyes
                  Positioned(
                    top: size * 0.14,
                    left: size * 0.10,
                    child: _VanEye(size: size * 0.08, state: state),
                  ),
                  Positioned(
                    top: size * 0.14,
                    right: size * 0.10,
                    child: _VanEye(size: size * 0.08, state: state),
                  ),
                  // Beak
                  Positioned(
                    bottom: size * 0.08,
                    left: size * 0.18,
                    right: size * 0.18,
                    child: Container(
                      height: size * 0.10,
                      decoration: BoxDecoration(
                        color: AppColors.vanOrange,
                        borderRadius: BorderRadius.circular(size * 0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Feet (orange, visible below body)
          Positioned(
            bottom: size * 0.02,
            left: size * 0.18,
            child: _VanFoot(size: size * 0.12),
          ),
          Positioned(
            bottom: size * 0.02,
            right: size * 0.18,
            child: _VanFoot(size: size * 0.12),
          ),
        ],
      ),
    );
  }
}

class _VanEye extends StatelessWidget {
  const _VanEye({required this.size, required this.state});

  final double size;
  final VanState state;

  @override
  Widget build(BuildContext context) {
    final isHappy = state == VanState.happy || state == VanState.achievement;
    return Container(
      width: size,
      height: isHappy ? size * 0.6 : size,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(size),
      ),
      child: isHappy
          ? null
          : Align(
              alignment: const Alignment(0.3, -0.3),
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
    );
  }
}

class _VanFoot extends StatelessWidget {
  const _VanFoot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.5,
      decoration: BoxDecoration(
        color: AppColors.vanOrange,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
    );
  }
}

/// Speech bubble for Van's dialogue
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
