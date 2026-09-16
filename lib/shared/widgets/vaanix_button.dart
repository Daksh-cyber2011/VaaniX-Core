/// VaaniX V1 Design System — Standardized Buttons
///
/// Variants:
/// - [VaaniXButton.primary]: Rich Violet/Indigo CTA for Learn Mode
/// - [VaaniXButton.cyan]: High-contrast Cyan CTA for Exam Cockpit
/// - [VaaniXButton.secondary]: Soft tinted container
/// - [VaaniXButton.outline]: Hairline border button
/// - [VaaniXButton.danger]: Red warning button for high visual gravity zones
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';

enum VaaniXButtonVariant {
  primary,
  cyan,
  secondary,
  outline,
  danger,
}

class VaaniXButton extends StatelessWidget {
  const VaaniXButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = VaaniXButtonVariant.primary,
    this.icon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
    this.borderRadius = VaaniXRadius.lg,
  });

  const VaaniXButton.cyan({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
    this.borderRadius = VaaniXRadius.lg,
  }) : variant = VaaniXButtonVariant.cyan;

  const VaaniXButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
    this.borderRadius = VaaniXRadius.lg,
  }) : variant = VaaniXButtonVariant.secondary;

  const VaaniXButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
    this.borderRadius = VaaniXRadius.lg,
  }) : variant = VaaniXButtonVariant.outline;

  const VaaniXButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48.0,
    this.borderRadius = VaaniXRadius.lg,
  }) : variant = VaaniXButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final VaaniXButtonVariant variant;
  final Widget? icon;
  final Widget? suffixIcon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case VaaniXButtonVariant.cyan:
        bg = isEnabled
            ? VaaniXColors.examCyanAccent
            : VaaniXColors.examCyanAccent.withValues(alpha: 0.4);
        fg = const Color(0xFF090D16);
        break;
      case VaaniXButtonVariant.secondary:
        bg = isDark
            ? VaaniXColors.examSurfaceElevated
            : VaaniXColors.learnSurfaceElevated;
        fg = isDark
            ? VaaniXColors.textPrimaryDark
            : VaaniXColors.learnPrimaryViolet;
        border = BorderSide(
          color: isDark ? VaaniXColors.examBorder : VaaniXColors.learnBorder,
          width: 1,
        );
        break;
      case VaaniXButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark
            ? VaaniXColors.examCyanAccent
            : VaaniXColors.learnPrimaryViolet;
        border = BorderSide(
          color: isDark
              ? VaaniXColors.examCyanAccent
              : VaaniXColors.learnPrimaryViolet,
          width: 1.5,
        );
        break;
      case VaaniXButtonVariant.danger:
        bg = VaaniXColors.telemetryRose;
        fg = Colors.white;
        break;
      case VaaniXButtonVariant.primary:
        bg = isEnabled
            ? VaaniXColors.learnPrimaryViolet
            : VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.4);
        fg = Colors.white;
        break;
    }

    final buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: fg,
            letterSpacing: 0.3,
          ),
        ),
        if (!isLoading && suffixIcon != null) ...[
          const SizedBox(width: 8),
          suffixIcon!,
        ],
      ],
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border,
        ),
        child: InkWell(
          onTap: isEnabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
