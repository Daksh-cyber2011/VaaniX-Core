/// VaaniX Global Theme
///
/// Provides both light and dark [ThemeData] instances for [MaterialApp].
/// All color decisions are documented with their design rationale.
///
/// Design source: VAN Design Bible + PRD Section 6.2 + docs/Product/Design-System.md
///
/// Component-level styling lives here so screens never re-style Material
/// widgets locally. Tokens: [AppColors], [AppTextStyles], [AppDimens],
/// [AppShadows].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

abstract final class AppTheme {
  // ============================================================
  // SHARED WIDGET-LEVEL FRAGMENTS
  // ============================================================

  static SwitchThemeData _switch(Color primary, Color surface) =>
      SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : primary.withValues(alpha: 0.18),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : primary.withValues(alpha: 0.32),
        ),
      );

  static ProgressIndicatorThemeData _progress(Color primary) =>
      ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: 0.12),
        circularTrackColor: primary.withValues(alpha: 0.15),
        refreshBackgroundColor: primary.withValues(alpha: 0.15),
      );

  static TooltipThemeData _tooltip(Color onBackground) => TooltipThemeData(
        decoration: BoxDecoration(
          color: onBackground.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        textStyle: AppTextStyles.labelSmall(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 500),
      );

  static ListTileThemeData _listTile(
    Color primary,
    Color subtext,
    Brightness brightness,
  ) =>
      ListTileThemeData(
        iconColor: subtext,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minLeadingWidth: 24,
        titleTextStyle: AppTextStyles.bodyLarge(),
        subtitleTextStyle: AppTextStyles.bodySmall(color: subtext),
      );

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        splashFactory: InkRipple.splashFactory,
        visualDensity: VisualDensity.standard,
        focusColor: AppColors.focusRingLight,
        highlightColor: AppColors.primary.withValues(alpha: 0.06),

        // Seed color drives Material 3 color scheme generation
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryContainerLight,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.vanYellow,
          onSecondary: AppColors.onBackgroundLight,
          tertiary: AppColors.vanOrange,
          error: AppColors.error,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
        ),

        scaffoldBackgroundColor: AppColors.backgroundLight,
        textTheme: AppTextStyles.buildTextTheme(),

        // --- AppBar ---
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.onBackgroundLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: AppTextStyles.titleLarge(
            color: AppColors.onBackgroundLight,
          ),
        ),

        // --- Elevated Button - Primary CTA ---
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, AppDimens.primaryActionHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge(),
            elevation: 0,
          ).copyWith(
            // Pressed state: subtle scale of the fill, no elevation jump.
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),

        // --- Text Button ---
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTextStyles.labelLarge(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(0, AppDimens.compactActionHeight),
          ),
        ),

        // --- Outlined Button ---
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize:
                const Size(double.infinity, AppDimens.primaryActionHeight),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge(),
          ),
        ),

        // --- Icon Buttons (48dp touch floor) ---
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppDimens.minTouchTarget),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        // --- Input Fields ---
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariantLight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          hintStyle: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
          labelStyle: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
        ),

        // --- Cards ---
        cardTheme: CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderLight),
          ),
        ),

        // --- Dialogs ---
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle:
              AppTextStyles.titleLarge(color: AppColors.onSurfaceLight),
          contentTextStyle:
              AppTextStyles.bodyMedium(color: AppColors.onSurfaceLight),
        ),

        // --- Bottom Sheets ---
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          modalBackgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: false,
        ),

        // --- Progress indicators ---
        progressIndicatorTheme: _progress(AppColors.primary),

        // --- Tooltips ---
        tooltipTheme: _tooltip(AppColors.onBackgroundLight),

        // --- List tiles (settings rows) ---
        listTileTheme:
            _listTile(AppColors.primary, AppColors.subtextLight, Brightness.light),

        // --- Switches ---
        switchTheme: _switch(AppColors.primary, AppColors.subtextLight),

        // --- Bottom Navigation ---
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.subtextLight,
          selectedLabelStyle: AppTextStyles.labelSmall(),
          unselectedLabelStyle: AppTextStyles.labelSmall(),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // --- Navigation Bar (Material 3) ---
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          height: 68,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary);
            }
            return const IconThemeData(color: AppColors.subtextLight);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.labelSmall(color: AppColors.primary);
            }
            return AppTextStyles.labelSmall(color: AppColors.subtextLight);
          }),
        ),

        // --- Chip ---
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariantLight,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          labelStyle: AppTextStyles.labelMedium(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        // --- Snack Bar ---
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.onBackgroundLight,
          contentTextStyle: AppTextStyles.bodyMedium(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // --- Divider ---
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
          space: 1,
        ),
      );

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        splashFactory: InkRipple.splashFactory,
        visualDensity: VisualDensity.standard,
        focusColor: AppColors.focusRingDark,
        highlightColor: AppColors.primaryLight.withValues(alpha: 0.08),

        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryContainerDark,
          onPrimaryContainer: AppColors.primaryContainerLight,
          secondary: AppColors.vanYellow,
          onSecondary: AppColors.onBackgroundDark,
          tertiary: AppColors.vanOrange,
          error: const Color(0xFFFF6B6B),
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
        ),

        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: AppTextStyles.buildTextTheme(dark: true),

        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.onBackgroundDark,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: AppTextStyles.titleLarge(
            color: AppColors.onBackgroundDark,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            minimumSize:
                const Size(double.infinity, AppDimens.primaryActionHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge(),
            elevation: 0,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            textStyle: AppTextStyles.labelLarge(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(0, AppDimens.compactActionHeight),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            minimumSize:
                const Size(double.infinity, AppDimens.primaryActionHeight),
            side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: AppTextStyles.labelLarge(),
          ),
        ),

        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppDimens.minTouchTarget),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariantDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFFF6B6B),
              width: 1.5,
            ),
          ),
          hintStyle: AppTextStyles.bodyMedium(color: AppColors.subtextDark),
          labelStyle: AppTextStyles.bodyMedium(color: AppColors.subtextDark),
        ),

        cardTheme: CardThemeData(
          color: AppColors.surfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderDark),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle:
              AppTextStyles.titleLarge(color: AppColors.onSurfaceDark),
          contentTextStyle:
              AppTextStyles.bodyMedium(color: AppColors.onSurfaceDark),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          modalBackgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: false,
        ),

        progressIndicatorTheme: _progress(AppColors.primaryLight),

        tooltipTheme: _tooltip(AppColors.onBackgroundDark),

        listTileTheme:
            _listTile(AppColors.primaryLight, AppColors.subtextDark, Brightness.dark),

        switchTheme: _switch(AppColors.primaryLight, AppColors.subtextDark),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.subtextDark,
          selectedLabelStyle: AppTextStyles.labelSmall(),
          unselectedLabelStyle: AppTextStyles.labelSmall(),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          indicatorColor: AppColors.primaryLight.withValues(alpha: 0.15),
          height: 68,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primaryLight);
            }
            return const IconThemeData(color: AppColors.subtextDark);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.labelSmall(color: AppColors.primaryLight);
            }
            return AppTextStyles.labelSmall(color: AppColors.subtextDark);
          }),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariantDark,
          selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
          labelStyle: AppTextStyles.labelMedium(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceVariantDark,
          contentTextStyle: AppTextStyles.bodyMedium(
            color: AppColors.onSurfaceDark,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.borderDark,
          thickness: 1,
          space: 1,
        ),
      );
}
