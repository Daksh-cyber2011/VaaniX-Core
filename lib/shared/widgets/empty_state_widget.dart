/// VaaniX Empty State Widget
///
/// Reusable placeholder UI displayed when a list or view has no data.
/// Fully theme-aware; the icon container carries a soft tint of the accent.
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onActionPressed,
    this.iconColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = iconColor ?? theme.colorScheme.primary;
    final subtext = theme.textTheme.bodyMedium?.color?.withOpacity(0.72);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                minimumSize: const Size(200, 48),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
