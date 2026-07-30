/// VaaniX Application Bootstrap
///
/// Centralizes all startup work that must complete before the UI runs:
///   1. Load environment variables from the bundled .env file.
///   2. Initialize Supabase (skipped safely if not configured).
///   3. Acquire the [SharedPreferences] singleton (injected into Riverpod).

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    reportError(e, st, context: 'dotenv.load');
  }
}

Future<void> _initializeSupabase() async {
  if (!AppEnvironment.isSupabaseConfigured) {
    debugPrint('ℹ️ Supabase not configured — running without backend auth.');
    return;
  }

  try {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      anonKey: AppEnvironment.supabaseAnonKey,
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
