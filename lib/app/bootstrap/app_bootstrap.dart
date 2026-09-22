/// VaaniX Application Bootstrap
///
/// Centralizes all startup work that must complete before the UI runs:
///   1. Load environment variables from the bundled .env file.
///   2. Initialize Sentry (crash reporting) if a DSN is configured.
///   3. Initialize Supabase (skipped safely if not configured).
///   4. Acquire the [SharedPreferences] singleton (injected into Riverpod).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/errors/app_error_handler.dart';

/// Result of a successful bootstrap.
class BootstrapResult {
  const BootstrapResult({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;
}

/// Injectable only so bootstrap failure behavior can be tested without a
/// networked Supabase project. Production always uses [Supabase.initialize].
typedef SupabaseInitializer = Future<void> Function({
  required String url,
  required String anonKey,
});

/// Executes the full startup sequence and returns a [BootstrapResult].
///
/// Note: Sentry must be initialized BEFORE runApp via
/// [SentryFlutter.init] in main.dart so it can wrap the zone guard.
/// This method only configures Sentry scope post-init.
Future<BootstrapResult> bootstrap({
  SupabaseInitializer? supabaseInitializer,
}) async {
  // main() already loads the environment BEFORE Sentry init (the Sentry DSN
  // itself is environment config); only load it here when it is not done.
  if (!dotenv.isInitialized) {
    await loadEnvironment();
  }
  _configureSentryScope();
  await _initializeSupabase(supabaseInitializer);

  final prefs = await _acquireSharedPreferences();
  return BootstrapResult(sharedPreferences: prefs);
}

/// Loads the bundled .env asset (if present) and always leaves dotenv in a
/// usable state.
///
/// The bundled app currently ships assets/env/ WITHOUT a .env file (only
/// .gitkeep), so the catch path is the PRODUCTION norm, not an edge case.
/// An EMPTY environment is initialized so every later dotenv.env[key]
/// access is safe: flavor defaults to development, Supabase/Gemini report
/// unconfigured, and the app boots fully offline instead of crashing with
/// NotInitializedError before the first frame.
Future<void> loadEnvironment() async {
  try {
    await dotenv.load(fileName: AppConstants.envFilePath);
  } catch (e, st) {
    reportError(e, st, context: 'dotenv.load');
    if (!dotenv.isInitialized) {
      dotenv.testLoad();
    }
  }
}

/// Tags the Sentry scope with environment metadata so crashes can be
/// filtered by flavor / release in the dashboard.
void _configureSentryScope() {
  Sentry.configureScope((scope) {
    scope.setTag('flavor', AppEnvironment.flavor.name);
    scope.setTag('release', AppConstants.appVersion);
    // Structured context (tag) instead of the deprecated setExtra API.
    scope.setTag(
        'supabase_configured', AppEnvironment.isSupabaseConfigured.toString());
  });
}

/// Guards against a second `Supabase.initialize` call, which throws when the
/// SDK is already initialized. Reachable now that bootstrap can be retried
/// after a later step (preferences) failed.
bool _supabaseInitialized = false;

Future<void> _initializeSupabase(SupabaseInitializer? initializer) async {
  if (_supabaseInitialized) return;
  if (!AppEnvironment.isSupabaseConfigured) {
    // Guarded so release builds never emit the message.
    if (kDebugMode) {
      debugPrint('ℹ️ Supabase not configured — running without backend auth.');
    }
    return;
  }

  // A configured backend that cannot initialize is not equivalent to an
  // intentionally unconfigured offline install. Allow a failure to reach
  // _startApp's retryable bootstrap failure screen; continuing here selected
  // SupabaseAuthRepository later, which then accessed an uninitialized client.
  if (initializer == null) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabaseAnonKey,
    );
  } else {
    await initializer(
      url: AppEnvironment.supabaseUrl,
      anonKey: AppEnvironment.supabaseAnonKey,
    );
  }
  _supabaseInitialized = true;
}

/// Acquires the [SharedPreferences] singleton.
///
/// Intentionally does NOT catch: the app cannot run without preferences, so
/// the failure must reach the caller, which renders the bootstrap-failure
/// screen and offers a retry. Reporting is done there (one Sentry event per
/// failed start-up attempt) rather than here, which would double-report.
Future<SharedPreferences> _acquireSharedPreferences() {
  return SharedPreferences.getInstance();
}
