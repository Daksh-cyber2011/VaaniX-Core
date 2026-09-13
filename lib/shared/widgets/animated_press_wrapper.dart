/// VaaniX Animated Press Wrapper
///
/// A lightweight [GestureDetector] wrapper that adds a subtle scale-down
/// animation on press — the standard premium micro-interaction used across
/// iOS and Android apps for tappable elements (cards, chips, avatar tiles).
///
/// Usage:
///   ```dart
///   AnimatedPressWrapper(
///     onTap: () { /* … */ },
///     child: MyCard(),
///   );
///   ```
///
/// The animation respects [MediaQuery.disableAnimationsOf] (reduced-motion).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';

class AnimatedPressWrapper extends StatefulWidget {
  const AnimatedPressWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.97,
    this.haptic = true,
    this.semanticLabel,
    this.semanticButton = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The scale to reach at full press depth. Default 0.97 (3% shrink).
  final double scaleFactor;

  /// Whether to trigger a light haptic on tap. Defaults to true.
  final bool haptic;

  final String? semanticLabel;
  final bool semanticButton;

  @override
  State<AnimatedPressWrapper> createState() => _AnimatedPressWrapperState();
}

class _AnimatedPressWrapperState extends State<AnimatedPressWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();

  void _onTapUp(_) {
    _ctrl.reverse();
    if (widget.haptic && widget.onTap != null) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onTap != null || widget.onLongPress != null;

    Widget child = widget.child;
    if (!reduceMotion && enabled) {
      child = AnimatedBuilder(
        animation: _scale,
        builder: (_, c) => Transform.scale(scale: _scale.value, child: c),
        child: child,
      );
    }

    return Semantics(
      button: widget.semanticButton || widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? _onTapDown : null,
        onTapUp: enabled ? _onTapUp : null,
        onTapCancel: enabled ? _onTapCancel : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
