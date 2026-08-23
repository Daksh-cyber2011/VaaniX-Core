/// Van Widget — AI Companion Display
///
/// Widget for Van the duck companion.
/// Renders emotional states, breathing animation, speech bubble, and taps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_controller.dart';
import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';

export 'package:vaanix_app/features/van/domain/van_state.dart';

class VanWidget extends ConsumerStatefulWidget {
  const VanWidget({
    super.key,
    this.state = VanState.idle,
    this.size = 160.0,
    this.onTap,
    this.onLongPress,
    this.showSpeechBubble = false,
    this.dialogueText,
    this.isLoading = false,
    this.useController = false,
    this.assetCatalog = VanAssetCatalog.placeholder,
    this.semanticLabel,
  });

  final VanState state;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showSpeechBubble;
  final String? dialogueText;
  final bool isLoading;

  /// When true, render the global event-driven [VanController] state instead
  /// of the supplied [state]. Existing call sites remain presentation-only.
  final bool useController;
  final VanAssetCatalog assetCatalog;
  final String? semanticLabel;

  @override
  ConsumerState<VanWidget> createState() => _VanWidgetState();
}

class _VanWidgetState extends ConsumerState<VanWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
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
    final presentation = widget.useController ? ref.watch(vanControllerProvider) : null;
    final state = presentation?.current ?? widget.state;
    final dialogueText = presentation?.message ?? widget.dialogueText;
    final isLoading = presentation?.isLoading ?? widget.isLoading;
    final asset = widget.assetCatalog.assetFor(state);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final defaultTap = widget.useController && state.definition.allowsUserInteraction
        ? () => ref.read(vanControllerProvider.notifier).dispatch(
              const VanEvent(VanEventType.companionTapped),
            )
        : null;
    final tilt = switch (state) {
      VanState.thinking => -0.04,
      VanState.caring || VanState.sad => 0.03,
      VanState.funny => -0.08,
      VanState.surprised => 0.05,
      VanState.achievement => 0.02,
      _ => 0.0,
    };

    return Semantics(
      button: widget.onTap != null || widget.onLongPress != null || defaultTap != null,
      label: widget.semanticLabel ?? 'Van is ${state.definition.meaning}',
      child: GestureDetector(
      onTap: widget.onTap ?? defaultTap,
      onLongPress: widget.onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speech bubble (shown above Van)
          if (widget.showSpeechBubble && (dialogueText != null || isLoading))
            _SpeechBubble(text: dialogueText, isLoading: isLoading),
          if (widget.showSpeechBubble && (dialogueText != null || isLoading))
            const SizedBox(height: 8),

          // Van character
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: !reducedMotion && state == VanState.idle
                    ? _breatheAnimation.value
                    : 1.0,
                child: Transform.rotate(angle: reducedMotion ? 0 : tilt, child: child),
              );
            },
            child: _VanBody(
              size: widget.size,
              state: state,
              assetId: asset.id,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _VanBody extends StatelessWidget {
  const _VanBody({required this.size, required this.state, required this.assetId});

  final double size;
  final VanState state;
  final String assetId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Signature feather tuft: a stable silhouette cue from the Bible.
          Positioned(
            top: size * 0.005,
            child: Semantics(
              label: assetId,
              excludeSemantics: true,
              child: Container(
                width: size * 0.13,
                height: size * 0.10,
                decoration: BoxDecoration(
                  color: AppColors.vanYellow,
                  borderRadius: BorderRadius.circular(size * 0.08),
                ),
              ),
            ),
          ),
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
          // Default blue hoodie. Final vector/Lottie art can replace this
          // fallback through VanAssetCatalog without changing this API.
          Positioned(
            bottom: size * 0.19,
            child: Container(
              width: size * 0.58,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(size * 0.13),
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

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.isLoading});

  final String? text;
  final bool isLoading;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text ?? 'Thinking…',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
