/// VaaniX Environment Configuration
///
/// Single source of truth for all environment-derived runtime configuration.
///
/// Centralizes access to values loaded from `assets/env/.env` (via
/// flutter_dotenv) and exposes them as strongly-typed, named getters.
/// Feature and networking code should NEVER read `dotenv.env[...]` directly —
/// always go through [AppEnvironment].
///
/// Resolution order for a value:
///   1. Explicit override (e.g. `Flavor`) when supported.
///   2. Value from the loaded .env file.
///   3. Safe, non-null fallback.
///
/// This keeps the rest of the codebase testable, environment-agnostic, and
/// free of scattered `dotenv.env['KEY'] ?? 'fallback'` patterns.

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/app_constants.dart';

/// High-level deployment flavor.
///
/// Drives behavior switches such as verbose logging, analytics enablement,
/// and which backend base URL is used.
enum Flavor {
  development,
  staging,
  production;

  /// Parses the APP_ENV string from the environment file.
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

/// Read-only runtime configuration facade.
///
/// All getters are backed by the loaded [dotenv] instance. Callers are
/// expected to have awaited [dotenv.load] before reading any value
/// (handled by the bootstrap layer in main.dart).
@immutable
class AppEnvironment {
  const AppEnvironment._();

  /// Current deployment flavor.
  static Flavor get flavor =>
      Flavor.fromString(dotenv.env[AppConstants.appEnvKey]);

  /// True when running in development flavor or debug build.
  static bool get isDevelopment => flavor == Flavor.development || kDebugMode;

  static bool get isProduction => flavor == Flavor.production;

  /// Supabase project URL. Empty string means "not configured" — the auth
  /// layer treats this as a no-op backend so the app remains usable for
  /// onboarding / local-only flows during early development.
  static String get supabaseUrl =>
      dotenv.env[AppConstants.supabaseUrlKey]?.trim() ?? '';

  static String get supabaseAnonKey =>
      dotenv.env[AppConstants.supabaseAnonKeyKey]?.trim() ?? '';

  /// True when both Supabase credentials are present and non-placeholder.
  static bool get isSupabaseConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('your-project-id') &&
        !key.contains('your-supabase-anon-key');
  }

  /// Base URL for the optional FastAPI backend.
  static String get apiBaseUrl {
    final url = dotenv.env[AppConstants.apiBaseUrlKey]?.trim();
    if (url != null && url.isNotEmpty) return url;
    return 'http://localhost:8000/api/v1';
  }
}
