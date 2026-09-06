/// VaaniX Application Entry Point
///
/// Responsibilities:
///   - Initialize Flutter bindings.
///   - Initialize Sentry (crash reporting) BEFORE runApp so the zone guard
///     can forward uncaught errors to the Sentry dashboard.
///   - Run the app inside a guarded zone so all errors funnel through
///     [reportError] (crash-reporting integration point).
///   - Execute the startup sequence via [bootstrap].
///   - Launch [VaaniXApp] wrapped in a Riverpod [ProviderScope], injecting
///     the async [SharedPreferences] dependency.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:vaanix_app/app/app.dart';
import 'package:vaanix_app/app/bootstrap/app_bootstrap.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/app_error_handler.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/providers/session_manager.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  // The environment must be available BEFORE Sentry init: the DSN itself is
  // environment configuration (SENTRY_DSN in the bundled .env, with a
  // --dart-define fallback — see [AppEnvironment.sentryDsn]). This also
  // means bootstrap() must not load the environment a second time.
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnvironment();

  await SentryFlutter.init(
    (options) {
      // No-op when unconfigured — empty/placeholder DSNs disable sending.
      options.dsn = AppEnvironment.sentryDsn;
      // Send traces in debug too so devs can verify the pipeline.
      options.tracesSampleRate = 1.0;
      // Report all framework errors, not just uncaught ones.
      options.reportSilentFlutterErrors = true;
    },
    appRunner: () async {
      await runZonedGuarded<Future<void>>(
        () async {
          // Route framework errors through the central handler.
          FlutterError.onError = handleFlutterError;

          final result = await bootstrap();

          runApp(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(
                  result.sharedPreferences,
                ),
                // Wire the core session manager dependency to the feature's
                // auth repository (dependency inversion seam).
                coreAuthRepositoryProvider
                    .overrideWith((ref) => ref.read(authRepositoryProvider)),
              ],
              child: const VaaniXApp(),
            ),
          );
        },
        handleZoneError,
      );
    },
  );
}
