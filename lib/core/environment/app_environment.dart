/// VaaniX Environment Configuration
///
/// Single source of truth for all environment-derived runtime configuration.

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';

enum Flavor {
  development,
  staging,
  production;

  static Flavor fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'production':
        return Flavor.production;
      case 'staging':
        return Flavor.staging;
      default:
        return Flavor.development;
    }
  }
}

@immutable
class AppEnvironment {
  const AppEnvironment._();

  static Flavor get flavor =>
      Flavor.fromString(dotenv.env[AppConstants.appEnvKey]);

  static bool get isDevelopment => flavor == Flavor.development || kDebugMode;

  static bool get isProduction => flavor == Flavor.production;

  static String get supabaseUrl =>
      dotenv.env[AppConstants.supabaseUrlKey]?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.env[AppConstants.supabaseAnonKeyKey]?.trim() ?? '';

  static bool get isSupabaseConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('your-project-id') &&
        !key.contains('your-supabase-anon-key');
  }

  static String get apiBaseUrl {
    final url = dotenv.env[AppConstants.apiBaseUrlKey]?.trim();
    if (url != null && url.isNotEmpty) return url;
    return 'http://localhost:8000/api/v1';
  }

  /// Google Gemini API key. Empty when not configured — the AI module
  /// falls back to [OfflineModelAdapter] in that case.
  static String get geminiApiKey =>
      dotenv.env[AppConstants.geminiApiKey]?.trim() ?? '';

  /// True when a Gemini API key is present and non-empty.
  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;
}
