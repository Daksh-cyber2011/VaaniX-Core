/// VaaniX Typography System
///
/// Font: Nunito (Google Fonts)
/// Rationale: Rounded letterforms feel warm and approachable —
/// matching Van's personality. Highly legible for young learners.
///
/// Scale follows Material 3 type system naming conventions.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // ============================================================
  // BASE FONT GETTER
  // ============================================================

  static TextStyle _nunito({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ============================================================
  // DISPLAY — Large hero text
  // ============================================================

  static TextStyle displayLarge({Color? color}) => _nunito(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.12,
        letterSpacing: -0.25,
      );

  static TextStyle displayMedium({Color? color}) => _nunito(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.16,
      );

  static TextStyle displaySmall({Color? color}) => _nunito(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.22,
      );

  // ============================================================
  // HEADLINE — Screen titles
  // ============================================================

  static TextStyle headlineLarge({Color? color}) => _nunito(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.25,
      );

  static TextStyle headlineMedium({Color? color}) => _nunito(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.29,
      );

  static TextStyle headlineSmall({Color? color}) => _nunito(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.33,
      );

  // ============================================================
  // TITLE — Section headers, card titles
  // ============================================================

  static TextStyle titleLarge({Color? color}) => _nunito(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.27,
      );

  static TextStyle titleMedium({Color? color}) => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.50,
        letterSpacing: 0.15,
      );

  static TextStyle titleSmall({Color? color}) => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.43,
        letterSpacing: 0.1,
      );

  // ============================================================
  // BODY — Reading content, lesson text
  // ============================================================

  static TextStyle bodyLarge({Color? color}) => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.50,
        letterSpacing: 0.5,
      );

  static TextStyle bodyMedium({Color? color}) => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.43,
        letterSpacing: 0.25,
      );

  static TextStyle bodySmall({Color? color}) => _nunito(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.33,
        letterSpacing: 0.4,
      );

  // ============================================================
  // LABEL — Buttons, badges, navigation
  // ============================================================

  static TextStyle labelLarge({Color? color}) => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.43,
        letterSpacing: 0.1,
      );

  static TextStyle labelMedium({Color? color}) => _nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.33,
        letterSpacing: 0.5,
      );

  static TextStyle labelSmall({Color? color}) => _nunito(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.45,
        letterSpacing: 0.5,
      );

  // ============================================================
  // SANSKRIT — Special styling for Sanskrit text
  // Uses serif-adjacent weight for readability
  // ============================================================

  static TextStyle sanskritBody({Color? color}) => _nunito(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.primary,
        height: 1.6,
        letterSpacing: 0.3,
      );

  static TextStyle sanskritLarge({Color? color}) => _nunito(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.primary,
        height: 1.5,
      );

  // ============================================================
  // VAN DIALOGUE — Van's speech bubble text
  // ============================================================

  static TextStyle vanDialogue({Color? color}) => _nunito(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.5,
        letterSpacing: 0.1,
      );

  // ============================================================
  // HELPER: Build a TextTheme from these styles
  // Used by AppTheme to wire into MaterialApp
  // ============================================================

  static TextTheme buildTextTheme({bool dark = false}) {
    final baseColor = dark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
    return TextTheme(
      displayLarge: displayLarge(color: baseColor),
      displayMedium: displayMedium(color: baseColor),
      displaySmall: displaySmall(color: baseColor),
      headlineLarge: headlineLarge(color: baseColor),
      headlineMedium: headlineMedium(color: baseColor),
      headlineSmall: headlineSmall(color: baseColor),
      titleLarge: titleLarge(color: baseColor),
      titleMedium: titleMedium(color: baseColor),
      titleSmall: titleSmall(color: baseColor),
      bodyLarge: bodyLarge(color: baseColor),
      bodyMedium: bodyMedium(color: baseColor),
      bodySmall: bodySmall(color: baseColor),
      labelLarge: labelLarge(color: baseColor),
      labelMedium: labelMedium(color: baseColor),
      labelSmall: labelSmall(color: baseColor),
    );
  }
}
