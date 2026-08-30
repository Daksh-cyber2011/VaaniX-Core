/// VaaniX Error State Widget
///
/// Standardized error view with retry button for failed network/data calls.
/// Fully theme-aware and reduced-motion friendly.
import 'package:flutter/material.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final subtext = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: errorColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: retryLabel,
                onPressed: onRetry,
                minimumSize: const Size(180, 48),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
