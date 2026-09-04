/// VaaniX Standardized Modal Dialog
///
/// Clean, branded alert and confirmation dialogs matching design guidelines.
/// The confirm action adapts to dark mode and uses the semantic danger color
/// for destructive confirmations.
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';

class VaaniXDialog extends StatelessWidget {
  const VaaniXDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'OK',
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.isDangerous = false,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDangerous;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withOpacity(0.72),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (cancelLabel != null) ...[
                  Expanded(
                    child: PrimaryButton.secondary(
                      label: cancelLabel!,
                      onPressed:
                          onCancel ?? () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDangerous
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        onConfirm ?? () => Navigator.of(context).pop(true),
                    child:
                        Text(confirmLabel, style: AppTextStyles.labelLarge()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
