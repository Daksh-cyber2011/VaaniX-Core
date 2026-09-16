/// VaaniX V1 Design System — Color Tokens
///
/// Derived from the Stitch Design Canvas for VaaniX.
/// Establishes the visual identity for both:
/// 1. EXAM MODE ("Tactical Cockpit") — Dark slate, high-contrast cyan, cobalt
/// 2. LEARN MODE ("The Sanctuary") — Editorial ivory/slate, violet, soft iris
///
/// Preserves constitutional Van signature colors.
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';

abstract final class VaaniXColors {
  // ============================================================
  // VAN SIGNATURE COLORS (Constitutional)
  // ============================================================
  static const Color vanYellow = AppColors.vanYellow;
  static const Color vanOrange = AppColors.vanOrange;

  // ============================================================
  // EXAM MODE — TACTICAL COCKPIT (Dark Dominant)
  // ============================================================
  static const Color examCanvasBg = Color(0xFF090D16);
  static const Color examSurfaceCard = Color(0xFF131B2E);
  static const Color examSurfaceElevated = Color(0xFF1C263F);
  static const Color examBorder = Color(0xFF1E293B);
  static const Color examCyanAccent = Color(0xFF00E5FF);
  static const Color examCyanSoft = Color(0x1A00E5FF);
  static const Color examIndigoAccent = Color(0xFF4F46E5);
  static const Color examPrimary = Color(0xFF4338CA);
  static const Color examSecondary = Color(0xFF6366F1);
  static const Color examSurface = Color(0xFFEEF2FF);

  // ============================================================
  // LEARN MODE — THE SANCTUARY (Light Editorial)
  // ============================================================
  static const Color learnCanvasBg = Color(0xFFF8FAFC);
  static const Color learnSurfaceCard = Color(0xFFFFFFFF);
  static const Color learnSurfaceElevated = Color(0xFFF1F5F9);
  static const Color learnBorder = Color(0xFFE2E8F0);
  static const Color learnPrimaryViolet = Color(0xFF4338CA);
  static const Color learnAccentIris = Color(0xFF6366F1);
  static const Color learnSoftPurple = Color(0xFFEEF2FF);

  // ============================================================
  // NEUTRAL FOUNDATIONS (Light & Dark)
  // ============================================================
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color bgDark = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF131B2E);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ============================================================
  // TELEMETRY & SEMANTIC SIGNALS
  // ============================================================
  static const Color telemetryEmerald = Color(0xFF10B981);
  static const Color telemetryEmeraldBg = Color(0xFFECFDF5);
  static const Color telemetryAmber = Color(0xFFF59E0B);
  static const Color telemetryAmberBg = Color(0xFFFFFBEB);
  static const Color telemetryRose = Color(0xFFEF4444);
  static const Color telemetryRoseBg = Color(0xFFFEF2F2);
  static const Color telemetryCyan = Color(0xFF00E5FF);
  static const Color telemetryCyanBg = Color(0xFFE0F7FA);
  static const Color telemetryBlue = Color(0xFF3B82F6);
  static const Color telemetryBlueBg = Color(0xFFEFF6FF);

  // Focus & Overlays
  static const Color overlay = Color(0x80000000);
  static const Color shimmerLight = Color(0xFFE2E8F0);
  static const Color shimmerDark = Color(0xFF1E293B);
}
