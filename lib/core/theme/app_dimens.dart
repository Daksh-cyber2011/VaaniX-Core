/// VaaniX Layout & Motion Tokens
///
/// Single source of truth for spacing, radii, touch targets, durations and
/// motion curves. Screens should never hard-code magic numbers when a token
/// exists here.
///
/// Tokens are additive and theme-independent; color tokens live in
/// [AppColors], typography in [AppTextStyles], elevation in [AppShadows].
library;

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Spacing, radii and sizing scale used across the app.
abstract final class AppDimens {
  // ============================================================
  // SPACING SCALE (4pt base grid)
  // ============================================================

  /// 4 - hairline gaps, icon-to-label inside a chip.
  static const double space1 = 4;

  /// 8 - tight internal padding, badge gaps.
  static const double space2 = 8;

  /// 12 - related element separation.
  static const double space3 = 12;

  /// 16 - default intra-card padding.
  static const double space4 = 16;

  /// 20 - card padding, screen horizontal inset.
  static const double space5 = 20;

  /// 24 - section separation.
  static const double space6 = 24;

  /// 32 - large section separation.
  static const double space7 = 32;

  /// 40 - hero block separation.
  static const double space8 = 40;

  /// 48 - pre-footer / bottom-bar clearance.
  static const double space9 = 48;

  // ============================================================
  // RADII (one soft-radius system; pill for chips/badges)
  // ============================================================

  /// Small elements: chips, small buttons, inline tags.
  static const double radiusSm = 10;

  /// Inputs, secondary buttons, tooltips.
  static const double radiusMd = 14;

  /// Cards, sheets, dialogs.
  static const double radiusLg = 20;

  /// Hero cards, the Nest container, modal sheets.
  static const double radiusXl = 28;

  /// Badges, pills, status dots.
  static const double radiusPill = 999;

  // ============================================================
  // TOUCH TARGETS (accessibility floor)
  // ============================================================

  /// Minimum interactive target per Material guidance.
  static const double minTouchTarget = 48;

  /// Comfortable primary-action height.
  static const double primaryActionHeight = 56;

  /// Compact action height (secondary rows, dialog buttons).
  static const double compactActionHeight = 48;

  // ============================================================
  // COMPONENT SIZING
  // ============================================================

  /// VAN sizes used across surfaces - keep proportional rhythm.
  static const double vanSizeHero = 160;
  static const double vanSizeStrip = 44;
  static const double vanSizeBubble = 64;

  /// Standard icon sizes.
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
}

/// Motion durations and curves. One coherent feel: quick exits, gentle
/// settles, no bounce unless celebration.
abstract final class AppMotion {
  /// Feedback ticks: ripples, checkbox, chip selection.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard element transitions: cards, sheets, fades.
  static const Duration base = Duration(milliseconds: 250);

  /// Larger choreography: hero transitions, VAN state changes.
  static const Duration slow = Duration(milliseconds: 400);

  /// Celebration / achievement moments.
  static const Duration celebrate = Duration(milliseconds: 600);

  /// Default emphasized curve - smooth settle without overshoot.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Entering elements (slide up + fade).
  static const Curve enter = Curves.easeOut;

  /// Celebration overshoot.
  static const Curve playful = Curves.easeOutBack;
}
