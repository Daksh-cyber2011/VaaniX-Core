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

/// Executes the full startup sequence and returns a [BootstrapResult].
///
/// Note: Sentry must be initialized BEFORE runApp via
/// [SentryFlutter.init] in main.dart so it can wrap the zone guard.
/// This method only configures Sentry scope post-init.
Future<BootstrapResult> bootstrap() async {
  await _loadEnvironment();
  _configureSentryScope();
  await _initializeSupabase();

  final prefs = await _acquireSharedPreferences();
  return BootstrapResult(sharedPreferences: prefs);
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: AppConstants.envFilePath);
  } catch (e, st) {
    reportError(e, st, context: 'dotenv.load');
    // The bundled app currently ships assets/env/ WITHOUT a .env file
    // (only .gitkeep), so this path is the PRODUCTION norm, not an
    // edge case. Initialize an EMPTY environment so every later
    // dotenv.env[key] access is safe: flavor defaults to development,
    // Supabase/Gemini report unconfigured, and the app boots fully
    // offline instead of crashing with NotInitializedError before the
    // first frame.
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

Future<void> _initializeSupabase() async {
  if (!AppEnvironment.isSupabaseConfigured) {
    debugPrint('ℹ️ Supabase not configured — running without backend auth.');
    return;
  }

  try {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabaseAnonKey,
    );
  } catch (e, st) {
    reportError(e, st, context: 'Supabase.initialize');
  }
}

Future<SharedPreferences> _acquireSharedPreferences() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e, st) {
    reportError(e, st, context: 'SharedPreferences.getInstance');
    rethrow;
  }
}
