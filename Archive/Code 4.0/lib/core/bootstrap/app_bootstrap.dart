/// VaaniX Application Bootstrap
///
/// Centralizes all startup work that must complete before the UI runs:
///
///   1. Load environment variables from the bundled .env file.
///   2. Initialize Supabase (skipped safely if not configured).
///   3. Acquire the [SharedPreferences] singleton (injected into Riverpod).
///
/// Running everything through here means [main.dart] stays tiny and the
/// startup sequence is unit-testable in isolation.
///
/// All heavy work runs inside [runZonedGuarded] (see main.dart) so that
/// errors are funneled through [reportError] and never crash the app
/// silently.

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_environment.dart';
import '../constants/app_constants.dart';

/// Result of a successful bootstrap. Holds the single async dependency
/// ([SharedPreferences]) that needs to be injected into Riverpod at start.
class BootstrapResult {
  const BootstrapResult({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;
}

/// Executes the full startup sequence and returns a [BootstrapResult].
///
/// Never throws: any failure is reported and produces safe fallbacks so the
/// app still boots (degraded mode is better than a black screen).
Future<BootstrapResult> bootstrap() async {
  await _loadEnvironment();
  await _initializeSupabase();

  final prefs = await _acquireSharedPreferences();
  return BootstrapResult(sharedPreferences: prefs);
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: AppConstants.envFilePath);
  } catch (e, st) {
    // Missing .env is non-fatal — defaults keep the app runnable.
    reportError(e, st, context: 'dotenv.load');
  }
}

Future<void> _initializeSupabase() async {
  // Skip when credentials are absent or still placeholders so the app stays
  // usable for local-only / onboarding-driven development.
  if (!AppEnvironment.isSupabaseConfigured) {
    debugPrint('ℹ️ Supabase not configured — running without backend auth.');
    return;
  }

  try {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      anonKey: AppEnvironment.supabaseAnonKey,
      // TODO(auth): wire deep links for OAuth / magic-link redirect.
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
    // This is genuinely fatal — rethrow so the caller can surface it rather
    // than running with a null storage layer everywhere.
    rethrow;
  }
}
