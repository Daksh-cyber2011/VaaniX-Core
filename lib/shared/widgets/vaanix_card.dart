/// VaaniX Card
///
/// Standardized card component with custom surface colors, rounded borders,
/// optional glassmorphism/gradient highlights, padding, and tap callbacks.
///
/// Tappable cards automatically get a scale micro-interaction (via
/// [AnimatedPressWrapper]) and a semantic button annotation. The press
/// animation respects [MediaQuery.disableAnimationsOf].
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/shared/widgets/animated_press_wrapper.dart';

class VaaniXCard extends StatelessWidget {
  const VaaniXCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.space5),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppDimens.radiusLg,
    this.elevation = 0,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;

  /// Accessible label for screen readers. If null and [onTap] is set, the
  /// card announces as a generic "button"; provide a label for clarity.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = backgroundColor ??
        (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final effectiveBorder =
        borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);

    final cardChild = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation * 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    final tappable = onTap != null || onLongPress != null;

    final Widget result = tappable
        ? AnimatedPressWrapper(
            onTap: onTap,
            onLongPress: onLongPress,
            semanticLabel: semanticLabel,
            semanticButton: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: cardChild,
            ),
          )
        : cardChild;

    if (margin != null) {
      return Padding(padding: margin!, child: result);
    }
    return result;
  }
}
