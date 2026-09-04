/// XP Badge - shows the user's current XP total.
///
/// Uses the brand XP-gold accent with a Material glyph (never emoji) so it
/// renders identically on every device and in both themes.
library;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Deepen the gold slightly on dark surfaces for contrast.
    final accent = isDark ? const Color(0xFFFFD65C) : AppColors.xp;

    return Semantics(
      label: '${xpTotal.toXpDisplay()} experience points',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              xpTotal.toXpDisplay(),
              style: AppTextStyles.labelLarge(color: accent),
            ),
            if (!compact) ...[
              const SizedBox(width: 2),
              Text(
                'XP',
                style: AppTextStyles.labelSmall(color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
