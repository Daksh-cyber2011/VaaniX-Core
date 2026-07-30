/// XP Badge — shows the user's current XP total

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/extensions/extensions.dart';

class XpBadge extends StatelessWidget {
  const XpBadge({
    super.key,
    required this.xpTotal,
    this.compact = false,
  });

  final int xpTotal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.xp.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.xp.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            xpTotal.toXpDisplay(),
            style: AppTextStyles.labelLarge(color: AppColors.xp),
          ),
          if (!compact) ...[
            const SizedBox(width: 2),
            Text(
              'XP',
              style: AppTextStyles.labelSmall(color: AppColors.xp),
            ),
          ],
        ],
      ),
    );
  }
}
