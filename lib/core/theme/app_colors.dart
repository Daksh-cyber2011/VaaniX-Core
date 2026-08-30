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
  // VAN SIGNATURE COLORS (Constitutional â€” never change)
  // Source: PRD Section 6.2 & VAN Design Bible Chapter 2
  // ============================================================

  /// Van's body color â€” warm yellow
  static const Color vanYellow = Color(0xFFF4C74A);

  /// Van's beak and feet â€” warm orange
  static const Color vanOrange = Color(0xFFF07A33);

  // ============================================================
  // PRIMARY BRAND PALETTE
  // ============================================================

  /// Primary â€” deep indigo-blue (trustworthy, calm, scholarly)
  static const Color primary = Color(0xFF3B4CCA);

  /// Primary light variant
  static const Color primaryLight = Color(0xFF6B7CF7);

  /// Primary dark variant
  static const Color primaryDark = Color(0xFF2A369E);

  /// Accent â€” Van Yellow (used for highlights, streaks, CTAs)
  static const Color accent = vanYellow;

  /// Secondary accent â€” Van Orange (used for badges, warm moments)
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

  /// Warm dark â€” NOT pure black; warm tinted to match Van's world
  static const Color backgroundDark = Color(0xFF121218);
  static const Color surfaceDark = Color(0xFF1E1E28);
  static const Color surfaceVariantDark = Color(0xFF2A2A36);
  static const Color onBackgroundDark = Color(0xFFF0EDE6);
  static const Color onSurfaceDark = Color(0xFFE8E4DC);
  static const Color subtextDark = Color(0xFF9090A0);
  static const Color borderDark = Color(0xFF2E2E3C);

  // ============================================================
  // NEST BACKGROUND COLORS
  // The Nest is Van's cozy learning space â€” warm and inviting
  // ============================================================

  static const Color nestWarmLight = Color(0xFFFFF8E7);
  static const Color nestWarmDark = Color(0xFF1C1812);

  // ============================================================
  // TRANSPARENT & OVERLAYS
  // ============================================================

  static const Color transparent = Colors.transparent;
  static const Color overlay = Color(0x80000000);
  static const Color shimmer = Color(0xFFE8E4DC);
  // ============================================================
  // EXTENDED TOKENS (2026-08 design takeover - additive)
  // ============================================================

  /// Tinted primary container - selected states, soft fills, focus washes.
  static const Color primaryContainerLight = Color(0xFFEAEDFB);
  static const Color primaryContainerDark = Color(0xFF2B3266);

  /// Success container - correct-answer fills, mastery chips.
  static const Color successContainerLight = Color(0xFFE3F3EA);
  static const Color successContainerDark = Color(0xFF1E3B2D);

  /// Error container - incorrect-answer fills, destructive confirmations.
  static const Color errorContainerLight = Color(0xFFFCE7E6);
  static const Color errorContainerDark = Color(0xFF43201F);

  /// Warning container - streak risk, offline hints, retake nudges.
  static const Color warningContainerLight = Color(0xFFFFF3E0);
  static const Color warningContainerDark = Color(0xFF41331C);

  /// Info accent - AI explanations, tips, hints.
  static const Color info = Color(0xFF4A90D9);
  static const Color infoContainerLight = Color(0xFFE7F1FB);
  static const Color infoContainerDark = Color(0xFF1C3248);

  /// Focus ring for keyboard navigation and switch access.
  static const Color focusRingLight = Color(0xFF3B4CCA);
  static const Color focusRingDark = Color(0xFF9BA6F5);

  /// Dark-theme shimmer base (the original [shimmer] is light-only).
  static const Color shimmerDark = Color(0xFF2A2A36);
}
