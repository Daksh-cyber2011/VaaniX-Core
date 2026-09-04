/// Streak Badge - shows the user's current streak count.
///
/// Uses the brand fire-orange accent with a Material glyph (never emoji) so
/// it renders identically on every device and in both themes.
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.streakCount,
    this.compact = false,
  });

  final int streakCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Warm up the fire accent for dark surfaces so it stays vivid.
    final accent = isDark ? const Color(0xFFFF8C52) : AppColors.streak;

    return Semantics(
      label: '$streakCount day streak',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              streakCount.toString(),
              style: AppTextStyles.labelLarge(color: accent),
            ),
            if (!compact) ...[
              const SizedBox(width: 2),
              Text(
                'day${streakCount == 1 ? '' : 's'}',
                style: AppTextStyles.labelSmall(color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
