/// VaaniX Application Entry Point
///
/// Responsibilities:
/// - Load environment variables from assets/env/.env
/// - Initialize Supabase client
/// - Launch app wrapped in Riverpod [ProviderScope]

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';

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

  // 3. Run app
  runApp(
    const ProviderScope(
      child: VaaniXApp(),
    ),
  );
}
