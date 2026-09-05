/// VaaniX Card
///
/// Standardized card component with custom surface colors, rounded borders,
/// optional glassmorphism/gradient highlights, padding, and tap callbacks.
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';

class VaaniXCard extends StatelessWidget {
  const VaaniXCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 20.0,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;

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

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: cardChild,
              )
            : cardChild,
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardChild,
      );
    }

    return cardChild;
  }
}
