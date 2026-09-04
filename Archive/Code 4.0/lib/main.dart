/// VaaniX Application Entry Point
///
/// Responsibilities:
///   - Initialize Flutter bindings.
///   - Run the app inside a guarded zone so all errors funnel through
///     [reportError] (crash-reporting integration point).
///   - Execute the startup sequence via [bootstrap].
///   - Launch [VaaniXApp] wrapped in a Riverpod [ProviderScope], injecting
///     the async [SharedPreferences] dependency.
///
/// All startup logic lives in [bootstrap]; this file only orchestrates.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/errors/app_error_handler.dart';
import 'core/providers/app_providers.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Route framework errors through the central handler.
      FlutterError.onError = handleFlutterError;

      final result = await bootstrap();

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              result.sharedPreferences,
            ),
          ],
          child: const VaaniXApp(),
        ),
      );
    },
    handleZoneError,
  );
}
