/// VaaniX V1 Design System — Dual-Engine Global Theme
///
/// Implements:
/// 1. LEARN SANCTUARY (Light Mode) — Editorial ivory/slate, violet, clean white cards
/// 2. EXAM COCKPIT (Dark Mode) — Tactical dark canvas, cyan accents, cobalt elevations
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';

abstract final class VaaniXTheme {
  // ============================================================
  // LEARN SANCTUARY (LIGHT MODE)
  // ============================================================
  static ThemeData get learnSanctuaryTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: VaaniXColors.learnPrimaryViolet,
      brightness: Brightness.light,
      primary: VaaniXColors.learnPrimaryViolet,
      onPrimary: Colors.white,
      primaryContainer: VaaniXColors.learnSoftPurple,
      onPrimaryContainer: VaaniXColors.learnPrimaryViolet,
      secondary: VaaniXColors.learnAccentIris,
      onSecondary: Colors.white,
      surface: VaaniXColors.learnSurfaceCard,
      onSurface: VaaniXColors.textPrimaryLight,
      outline: VaaniXColors.learnBorder,
      outlineVariant: VaaniXColors.borderLight,
      error: VaaniXColors.telemetryRose,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VaaniXColors.learnCanvasBg,
      fontFamily: 'Poppins',
      cardTheme: CardTheme(
        color: VaaniXColors.learnSurfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VaaniXRadius.borderLg,
          side: const BorderSide(color: VaaniXColors.learnBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VaaniXColors.learnCanvasBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: VaaniXColors.textPrimaryLight,
        ),
        iconTheme: IconThemeData(color: VaaniXColors.textPrimaryLight),
      ),
      dividerTheme: const DividerThemeData(
        color: VaaniXColors.learnBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ============================================================
  // EXAM COCKPIT (TACTICAL DARK MODE)
  // ============================================================
  static ThemeData get examCockpitTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: VaaniXColors.examIndigoAccent,
      brightness: Brightness.dark,
      primary: VaaniXColors.examCyanAccent,
      onPrimary: const Color(0xFF090D16),
      primaryContainer: VaaniXColors.examSurfaceElevated,
      onPrimaryContainer: VaaniXColors.examCyanAccent,
      secondary: VaaniXColors.examIndigoAccent,
      onSecondary: Colors.white,
      surface: VaaniXColors.examSurfaceCard,
      onSurface: VaaniXColors.textPrimaryDark,
      outline: VaaniXColors.examBorder,
      outlineVariant: VaaniXColors.examBorder,
      error: VaaniXColors.telemetryRose,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VaaniXColors.examCanvasBg,
      fontFamily: 'Poppins',
      cardTheme: CardTheme(
        color: VaaniXColors.examSurfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VaaniXRadius.borderLg,
          side: const BorderSide(color: VaaniXColors.examBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VaaniXColors.examCanvasBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: VaaniXColors.textPrimaryDark,
        ),
        iconTheme: IconThemeData(color: VaaniXColors.textPrimaryDark),
      ),
      dividerTheme: const DividerThemeData(
        color: VaaniXColors.examBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
