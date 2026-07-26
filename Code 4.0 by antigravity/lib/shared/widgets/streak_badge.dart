/// Streak Badge — shows the user's current streak count
/// Used in the Home screen top bar (PRD Section 8.2)

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.streakCount,
    this.compact = false,
  });

  final int streakCount;

  /// If true, shows only the fire emoji + count without label
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.streak.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.streak.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            streakCount.toString(),
            style: AppTextStyles.labelLarge(color: AppColors.streak),
          ),
          if (!compact) ...[
            const SizedBox(width: 2),
            Text(
              'day${streakCount == 1 ? '' : 's'}',
              style: AppTextStyles.labelSmall(color: AppColors.streak),
            ),
          ],
        ],
      ),
    );
  }
}
