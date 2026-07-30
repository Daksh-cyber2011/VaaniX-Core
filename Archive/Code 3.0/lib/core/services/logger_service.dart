/// VaaniX Logger Service
///
/// Thin wrapper around the `logger` package providing a single shared
/// [AppLogger] instance. Honors the active environment — debug logs are
/// suppressed in release builds to avoid leaking internal details.
///
/// Usage:
///   AppLogger.i('User signed in', error: e, stackTrace: st);
///   AppLogger.d('Loaded ${lessons.length} lessons');

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Singleton logger used across the app.
///
/// Constructed once; callers reuse [AppLogger.instance].
class AppLogger {
  AppLogger._();

  static final Logger instance = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // Release builds log warnings and above only.
    level: kReleaseMode ? Level.warning : Level.trace,
    filter: _VaaniXLogFilter(),
  );

  // ── Convenience pass-throughs ────────────────────────────────
  static void t(dynamic message, [Object? error, StackTrace? st]) =>
      instance.t(message, error: error, stackTrace: st);

  static void d(dynamic message, [Object? error, StackTrace? st]) =>
      instance.d(message, error: error, stackTrace: st);

  static void i(dynamic message, [Object? error, StackTrace? st]) =>
      instance.i(message, error: error, stackTrace: st);

  static void w(dynamic message, [Object? error, StackTrace? st]) =>
      instance.w(message, error: error, stackTrace: st);

  static void e(dynamic message, [Object? error, StackTrace? st]) =>
      instance.e(message, error: error, stackTrace: st);

  static void f(dynamic message, [Object? error, StackTrace? st]) =>
      instance.f(message, error: error, stackTrace: st);
}

/// Custom filter so log level can also be overridden at runtime via
/// [AppLogger.instance.level] without fighting the default filter.
class _VaaniXLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return event.level.index >= level.index;
  }
}
