/// VaaniX Application Entry Point
///
/// Responsibilities:
/// - Load environment variables from assets/env/.env
/// - Initialize Supabase client
/// - Initialize SharedPreferences (injected into ProviderScope for onboarding)
/// - Launch app wrapped in Riverpod [ProviderScope]

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables
  await dotenv.load(fileName: AppConstants.envFilePath);

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    // TODO: Add deep link configuration when auth flows are implemented
  );

  // 3. Initialize SharedPreferences (needed by onboarding + future features)
  final prefs = await SharedPreferences.getInstance();

  // 4. Run app — inject SharedPreferences via ProviderScope override
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VaaniXApp(),
    ),
  );
}
