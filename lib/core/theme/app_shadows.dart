/// VaaniX Elevation Tokens
///
/// Shadows are tinted to the brand background hue (never pure black) so
/// surfaces feel warm and printed rather than floating on glass. Use these
/// instead of ad-hoc BoxShadow values.
library;


import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';

/// Elevation levels for the light and dark themes.
abstract final class AppShadows {
  // ============================================================
  // LIGHT THEME (warm paper world)
  // ============================================================

  /// Level 1 - resting cards, chips, badges.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x143B4CCA), // primary-tinted, 8%
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Level 2 - raised interactive elements, hovered cards, the continue card.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1E3B4CCA), // primary-tinted, 12%
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Level 3 - floating overlays: dialogs, VAN speech bubble, FABs.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x293B4CCA), // primary-tinted, 16%
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  // ============================================================
  // DARK THEME (shadows deepen; borders carry separation instead)
  // ============================================================

  /// Level 1 dark - resting cards.
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x66000000), // 40% black
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Level 2 dark - raised elements.
  static const List<BoxShadow> raisedDark = [
    BoxShadow(
      color: Color(0x80000000), // 50% black
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Level 3 dark - floating overlays.
  static const List<BoxShadow> floatingDark = [
    BoxShadow(
      color: Color(0x99000000), // 60% black
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  /// Theme-aware resolver.
  static List<BoxShadow> resolve(Brightness brightness) =>
      brightness == Brightness.dark ? raisedDark : raised;

  /// Card-level shadow for the given brightness.
  static List<BoxShadow> forCard(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : card;

  /// Floating-level shadow for the given brightness.
  static List<BoxShadow> forFloating(Brightness brightness) =>
      brightness == Brightness.dark ? floatingDark : floating;

  /// Kept for surface-tint experiments; do not use directly in widgets.
  static Color overlayScrim(Brightness brightness) =>
      brightness == Brightness.dark
          ? AppColors.overlay
          : AppColors.onBackgroundLight.withValues(alpha: 0.45);
}
