/// VaaniX V1 Design System — VAN Companion Bubble
///
/// Docked contextual companion card rendering:
/// - VAN avatar (using official expression artwork / vector renderer)
/// - Contextual speech bubble / pedagogical prompt
/// - Role & Emotion badge (Tactical Intel, Mentor, Focus, Celebration)
/// - Optional quick voice trigger / action chip
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

enum VanBadgeRole {
  mentor,
  tacticalIntel,
  celebration,
  warning,
}

class VanCompanionBubble extends StatelessWidget {
  const VanCompanionBubble({
    super.key,
    required this.message,
    this.title,
    this.vanState = VanState.idle,
    this.badgeRole = VanBadgeRole.mentor,
    this.badgeLabel,
    this.onVoiceTap,
    this.actionLabel,
    this.onActionTap,
    this.isTactical = false,
  });

  final String message;
  final String? title;
  final VanState vanState;
  final VanBadgeRole badgeRole;
  final String? badgeLabel;
  final VoidCallback? onVoiceTap;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool isTactical;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark || isTactical;

    final bgColor =
        isDark ? VaaniXColors.examSurfaceCard : VaaniXColors.learnSurfaceCard;
    final borderColor =
        isDark ? VaaniXColors.examBorder : VaaniXColors.learnBorder;
    final primaryAccent =
        isDark ? VaaniXColors.examCyanAccent : VaaniXColors.learnPrimaryViolet;

    final resolvedBadgeLabel = badgeLabel ??
        switch (badgeRole) {
          VanBadgeRole.mentor => 'VAN • MENTOR',
          VanBadgeRole.tacticalIntel => 'VAN • TACTICAL INTEL',
          VanBadgeRole.celebration => 'VAN • CELEBRATING',
          VanBadgeRole.warning => 'VAN • ALERT',
        };

    final badgeBgColor = switch (badgeRole) {
      VanBadgeRole.tacticalIntel =>
        VaaniXColors.examCyanAccent.withValues(alpha: 0.15),
      VanBadgeRole.warning => VaaniXColors.telemetryRoseBg,
      VanBadgeRole.celebration => VaaniXColors.telemetryEmeraldBg,
      VanBadgeRole.mentor => primaryAccent.withValues(alpha: 0.12),
    };

    final badgeTextColor = switch (badgeRole) {
      VanBadgeRole.tacticalIntel => VaaniXColors.examCyanAccent,
      VanBadgeRole.warning => VaaniXColors.telemetryRose,
      VanBadgeRole.celebration => VaaniXColors.telemetryEmerald,
      VanBadgeRole.mentor => primaryAccent,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: VaaniXRadius.borderLg,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VAN Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark
                  ? VaaniXColors.examSurfaceElevated
                  : VaaniXColors.learnSoftPurple,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? VaaniXColors.examCyanAccent.withValues(alpha: 0.4)
                    : VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: ClipOval(
                child: VanWidget(
                  state: vanState,
                  size: 46,
                  showSpeechBubble: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Message & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: VaaniXRadius.borderPill,
                      ),
                      child: Text(
                        resolvedBadgeLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (onVoiceTap != null)
                      GestureDetector(
                        onTap: onVoiceTap,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            size: 16,
                            color: primaryAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                if (title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? VaaniXColors.textPrimaryDark
                          : VaaniXColors.textPrimaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark
                        ? VaaniXColors.textSecondaryDark
                        : VaaniXColors.textSecondaryLight,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onActionTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: primaryAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
