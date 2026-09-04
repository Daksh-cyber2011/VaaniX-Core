/// VaaniX Extension Methods
///
/// Utility extensions on built-in types used throughout the app.
library;

import 'package:flutter/material.dart';

// ============================================================
// STRING EXTENSIONS
// ============================================================

extension StringX on String {
  /// Capitalize first letter of each word
  String toTitleCase() => split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Returns true if string is null or empty after trimming
  bool get isNullOrEmpty => trim().isEmpty;

  /// Truncate with ellipsis
  String truncate(int maxLength) =>
      length <= maxLength ? this : '${substring(0, maxLength)}…';
}

// ============================================================
// DATETIME EXTENSIONS
// ============================================================

extension DateTimeX on DateTime {
  /// Returns true if this date is the same calendar day as [other]
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Returns true if this date is today
  bool get isToday => isSameDay(DateTime.now());

  /// Returns true if this date is yesterday
  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));
}

// ============================================================
// CONTEXT EXTENSIONS
// ============================================================

extension BuildContextX on BuildContext {
  /// Current [ThemeData]
  ThemeData get theme => Theme.of(this);

  /// Current [ColorScheme]
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Current [TextTheme]
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Screen width
  double get screenWidth => screenSize.width;

  /// Screen height
  double get screenHeight => screenSize.height;

  /// Whether dark mode is active
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Safe area padding
  EdgeInsets get safeArea => MediaQuery.paddingOf(this);

  /// Show a styled SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(this).colorScheme.error : null,
      ),
    );
  }
}

// ============================================================
// INT EXTENSIONS
// ============================================================

extension IntX on int {
  /// Convert seconds to mm:ss display string
  String toTimeDisplay() {
    final minutes = this ~/ 60;
    final seconds = this % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Convert XP to a readable format (e.g. 1200 → "1.2K")
  String toXpDisplay() {
    if (this < 1000) return toString();
    return '${(this / 1000).toStringAsFixed(1)}K';
  }
}
