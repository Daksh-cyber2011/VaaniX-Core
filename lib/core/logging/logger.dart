/// VaaniX Central Logger
///
/// A single, structured logging facade for the entire app.
///
/// - In debug builds: colored, labeled output via [debugPrint].
/// - In production: integrates with crash-reporting (Sentry / Crashlytics)
///   via the [AppErrorHandler] reporting hook.
///
/// All app code should call through [AppLogger] instead of [debugPrint]
/// or [print] directly. This keeps log hygiene centralized and makes it
/// trivial to add structured logging or remote log aggregation later.
///
/// Usage:
/// ```dart
/// AppLogger.info('User signed in', tag: 'AuthRepository');
/// AppLogger.warn('Retrying after timeout', tag: 'DioClient');
/// AppLogger.error('Unexpected failure', error: e, stackTrace: st);
/// ```

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Log severity level.
enum _LogLevel {
  verbose,
  info,
  warn,
  error,
}

/// Application-wide structured logger.
abstract final class AppLogger {
  /// Verbose trace — disabled in profile/release builds.
  static void verbose(String message, {String? tag}) {
    if (kDebugMode) _log(_LogLevel.verbose, message, tag: tag);
  }

  /// Informational message.
  static void info(String message, {String? tag}) {
    if (kDebugMode) _log(_LogLevel.info, message, tag: tag);
  }

  /// Warning — something unexpected but recoverable.
  static void warn(String message, {String? tag, Object? error}) {
    if (kDebugMode) _log(_LogLevel.warn, message, tag: tag, error: error);
  }

  /// Error — should never happen in normal operation.
  ///
  /// In debug builds: prints to console.
  /// In release builds: forwards to Sentry via [Sentry.captureException]
  /// so production crashes are visible in the Sentry dashboard.
  /// If Sentry is not initialized, the call is a no-op (Sentry SDK
  /// gracefully handles un-initialized capture calls).
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _log(_LogLevel.error, message, tag: tag, error: error);
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    // Forward to Sentry in all modes — Sentry.no-op if not initialized.
    // Attach the message as a breadcrumb for context.
    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('log_tag', tag ?? 'unknown');
          scope.setLevel(SentryLevel.error);
          scope.setExtra('message', message);
        },
      );
    } else {
      // No exception object — capture as a message.
      Sentry.captureMessage(
        message,
        level: SentryLevel.error,
        withScope: (scope) {
          scope.setTag('log_tag', tag ?? 'unknown');
        },
      );
    }
  }

  // ─── Internals ────────────────────────────────────────────────────────────

  static void _log(
    _LogLevel level,
    String message, {
    String? tag,
    Object? error,
  }) {
    final prefix = switch (level) {
      _LogLevel.verbose => '🔍 VERBOSE',
      _LogLevel.info    => '✅ INFO   ',
      _LogLevel.warn    => '⚠️  WARN   ',
      _LogLevel.error   => '🚨 ERROR  ',
    };

    final label = tag != null ? '[$tag] ' : '';
    final suffix = error != null ? '\n  ↳ $error' : '';
    debugPrint('$prefix $label$message$suffix');
  }
}
