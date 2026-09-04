/// VaaniX Primary Button
///
/// The main call-to-action button used throughout the app.
/// Matches the elevated button theme defined in [AppTheme].
///
/// Supports loading state, disabled state, and secondary/text variants.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum _ButtonVariant { primary, secondary, text }

class PrimaryButton extends StatelessWidget {
  /// Primary (filled) variant — the default CTA button.
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.minimumSize,
  }) : _variant = _ButtonVariant.primary;

  /// Secondary (outlined) variant.
  const PrimaryButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.minimumSize,
  }) : _variant = _ButtonVariant.secondary;

  /// Text (flat) variant.
  const PrimaryButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.minimumSize,
  }) : _variant = _ButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final Size? minimumSize;

  // `final` is required because this class uses const constructors.
  final _ButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.onBackgroundDark,
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(width: 8),
                  Text(label, style: AppTextStyles.labelLarge()),
                ],
              )
            : Text(label, style: AppTextStyles.labelLarge());

    switch (_variant) {
      case _ButtonVariant.primary:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: minimumSize != null
              ? ElevatedButton.styleFrom(minimumSize: minimumSize)
              : null,
          child: child,
        );
      case _ButtonVariant.secondary:
        return OutlinedButton(
          onPressed: effectiveOnPressed,
          style: minimumSize != null
              ? OutlinedButton.styleFrom(minimumSize: minimumSize)
              : null,
          child: child,
        );
      case _ButtonVariant.text:
        return TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        );
    }
  }
}
