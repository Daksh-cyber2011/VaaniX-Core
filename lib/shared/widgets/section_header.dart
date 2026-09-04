/// VaaniX Section Header
///
/// A consistent section title with an optional trailing action ("See all").
/// Use at the top of content groups on Home, Learn, Progress and Settings so
/// every screen shares one scannable rhythm.
library;
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.padding = const EdgeInsets.fromLTRB(0, 24, 0, 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 40),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
