/// VaaniX App Error Handler
///
/// Centralizes handling of otherwise-uncaught Flutter and Dart errors.
///
/// In production this is the integration point for crash reporting
/// (Sentry / Crashlytics / Firebase). In development it forwards to
/// [AppLogger.error] so errors are visible without polluting production logs.
///
/// Wire this up inside [runZonedGuarded] from the bootstrap layer.

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// Sink for uncaught errors across the framework and isolate zones.
///
/// Treat this as the single entry point for crash reporting. Concrete
/// integrations override the body once, here, instead of scattering
/// error handling across the app.
void reportError(Object error, StackTrace stack, {String? context}) {
  AppLogger.error(
    context != null ? 'Uncaught error ($context)' : 'Uncaught error',
    tag: 'AppErrorHandler',
    error: error,
    stackTrace: stack,
  );
  // TODO(integrations): forward to Sentry.captureException() when configured.
}

/// Sink for framework-level errors passed to [FlutterError.onError].
void handleFlutterError(FlutterErrorDetails details) {
  reportError(
    details.exception,
    details.stack ?? StackTrace.empty,
    context: 'flutter',
  );
}

/// Sink for errors caught by [PlatformDispatcher.instance.onError] and
/// isolate zone error handlers. Returns true to suppress the default print.
bool handleZoneError(Object error, StackTrace stack) {
  reportError(error, stack, context: 'zone');
  return true;
}
