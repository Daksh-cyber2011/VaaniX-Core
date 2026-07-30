/// VaaniX Color Palette
///
/// Derived directly from the VAN Design Bible (02 - VAN / 02 - Visual Design.md)
/// and the PRD color specifications.
///
/// DO NOT change Van's signature colors without founder approval.
/// They are constitutional to the brand identity.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ============================================================
  // VAN SIGNATURE COLORS (Constitutional — never change)
  // Source: PRD Section 6.2 & VAN Design Bible Chapter 2
  // ============================================================

  /// Van's body color — warm yellow
  static const Color vanYellow = Color(0xFFF4C74A);

  /// Van's beak and feet — warm orange
  static const Color vanOrange = Color(0xFFF07A33);

  // ============================================================
  // PRIMARY BRAND PALETTE
  // ============================================================

  /// Primary — deep indigo-blue (trustworthy, calm, scholarly)
  static const Color primary = Color(0xFF3B4CCA);

  /// Primary light variant
  static const Color primaryLight = Color(0xFF6B7CF7);

  /// Primary dark variant
  static const Color primaryDark = Color(0xFF2A369E);

  /// Accent — Van Yellow (used for highlights, streaks, CTAs)
  static const Color accent = vanYellow;

  /// Secondary accent — Van Orange (used for badges, warm moments)
  static const Color accentOrange = vanOrange;

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  /// Success / correct answer
  static const Color success = Color(0xFF4CAF7D);

  /// Error / wrong answer
  static const Color error = Color(0xFFE53935);

  /// Warning
  static const Color warning = Color(0xFFFFA726);

  /// XP / achievements
  static const Color xp = Color(0xFFFFD700);

  /// Streak fire
  static const Color streak = Color(0xFFFF6B35);

  // ============================================================
  // LIGHT THEME SURFACES
  // ============================================================

  static const Color backgroundLight = Color(0xFFFAF8F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF0EDE6);
  static const Color onBackgroundLight = Color(0xFF1C1C2E);
  static const Color onSurfaceLight = Color(0xFF2D2D3A);
  static const Color subtextLight = Color(0xFF6B6B80);
  static const Color borderLight = Color(0xFFE0DDD6);

  // ============================================================
  // DARK THEME SURFACES
  // ============================================================

  /// Warm dark — NOT pure black; warm tinted to match Van's world
  static const Color backgroundDark = Color(0xFF121218);
  static const Color surfaceDark = Color(0xFF1E1E28);
  static const Color surfaceVariantDark = Color(0xFF2A2A36);
  static const Color onBackgroundDark = Color(0xFFF0EDE6);
  static const Color onSurfaceDark = Color(0xFFE8E4DC);
  static const Color subtextDark = Color(0xFF9090A0);
  static const Color borderDark = Color(0xFF2E2E3C);

  // ============================================================
  // NEST BACKGROUND COLORS
  // The Nest is Van's cozy learning space — warm and inviting
  // ============================================================

  static const Color nestWarmLight = Color(0xFFFFF8E7);
  static const Color nestWarmDark = Color(0xFF1C1812);

  // ============================================================
  // TRANSPARENT & OVERLAYS
  // ============================================================

  static const Color transparent = Colors.transparent;
  static const Color overlay = Color(0x80000000);
  static const Color shimmer = Color(0xFFE8E4DC);
}
