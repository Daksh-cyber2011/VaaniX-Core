/// VaaniX App Error Handler
///
/// Centralizes handling of otherwise-uncaught Flutter and Dart errors.

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/logging/logger.dart';

void reportError(Object error, StackTrace stack, {String? context}) {
  AppLogger.error(
    context != null ? 'Uncaught error ($context)' : 'Uncaught error',
    tag: 'AppErrorHandler',
    error: error,
    stackTrace: stack,
  );
}

void handleFlutterError(FlutterErrorDetails details) {
  reportError(
    details.exception,
    details.stack ?? StackTrace.empty,
    context: 'flutter',
  );
}

bool handleZoneError(Object error, StackTrace stack) {
  reportError(error, stack, context: 'zone');
  return true;
}
