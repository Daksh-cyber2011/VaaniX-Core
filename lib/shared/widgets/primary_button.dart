/// VaaniX Primary Button
///
/// The main call-to-action button used throughout the app.
/// Matches the elevated button theme defined in [AppTheme].
///
/// Supports loading state, disabled state, and secondary/text variants.
/// The loading spinner color adapts to the variant so it is always visible.
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

enum _ButtonVariant { primary, secondary, text }

class PrimaryButton extends StatelessWidget {
  /// Primary (filled) variant - the default CTA button.
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

  final _ButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    // Spinner must contrast with the variant surface:
    // - filled: light spinner on brand fill
    // - outlined/text: brand-colored spinner on transparent surface
    final spinnerColor = switch (_variant) {
      _ButtonVariant.primary => Colors.white,
      // Outlined/text variants sit on the surface; brand color stays visible.
      _ => theme.colorScheme.primary,
    };

    final labelWidget = Text(label, style: AppTextStyles.labelLarge());

    final child = isLoading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon!,
                  const SizedBox(width: 8),
                  labelWidget,
                ],
              )
            : labelWidget;

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
