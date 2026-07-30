/// VaaniX Standardized Bottom Sheet Wrapper
///
/// Rounded top sheet container with pull drag handle.

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class VaaniXBottomSheet extends StatelessWidget {
  const VaaniXBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.subtextDark : AppColors.subtextLight)
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            Text(
              title!,
              style: AppTextStyles.titleLarge(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
