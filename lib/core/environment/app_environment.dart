/// VaaniX Environment Configuration
///
/// Single source of truth for all environment-derived runtime configuration.
library;

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

  /// True when the AI adapters MUST route through the VaaniX backend
  /// instead of calling provider APIs directly. Defaults to `false`
  /// so existing dev builds continue to work. Production should set
  /// `VAANIX_USE_BACKEND_AI=true` so provider keys never reach the
  /// mobile client.
  static bool get useBackendAi {
    final raw = dotenv.env[AppConstants.useBackendAiKey]?.trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  /// True when [useBackendAi] is on AND no direct provider keys are
  /// configured. This is the safest posture: the client does not
  /// carry any provider secret.
  static bool get productionSafe =>
      useBackendAi && !isGroqConfigured && !isGeminiConfigured;

  /// True when the client is configured to talk to providers directly.
  /// Carrying real provider keys in production is unsafe (they can be
  /// extracted from the APK). Callers that surface this in user-facing
  /// UI should pair it with a warning.
  static bool get hasDirectProviderKeys =>
      isGroqConfigured || isGeminiConfigured;

  /// Google Gemini API key. Empty when not configured — the AI module
  /// falls back to [OfflineModelAdapter] in that case.
  /// Google Gemini model name, defaulting to [AppConstants.defaultGeminiModel].
  /// Configurable via the GEMINI_MODEL env var so the app never hardcodes a
  /// model string in one place.
  static String get geminiModel {
    final configured = dotenv.env[AppConstants.geminiModelKey]?.trim() ?? '';
    return configured.isNotEmpty ? configured : AppConstants.defaultGeminiModel;
  }

  static String get geminiApiKey =>
      dotenv.env[AppConstants.geminiApiKey]?.trim() ?? '';

  /// Groq API key. Empty when not configured — the AI module falls back to
  /// the next-configured provider in the routing chain in that case.
  static String get groqApiKey =>
      dotenv.env[AppConstants.groqApiKey]?.trim() ?? '';

  /// Groq model name. Defaults to [AppConstants.defaultGroqModel] when the
  /// `GROQ_MODEL` env var is unset. Configurable centrally; never hardcode
  /// model strings throughout the AI feature tree.
  static String get groqModel {
    final configured = dotenv.env[AppConstants.groqModelKey]?.trim() ?? '';
    return configured.isNotEmpty ? configured : AppConstants.defaultGroqModel;
  }

  /// True when a real Groq API key is present. Template placeholders are
  /// rejected (mirror of the Gemini check) so a starter `.env` never
  /// enables the online path.
  static bool get isGroqConfigured {
    final key = groqApiKey;
    return key.isNotEmpty && !key.toLowerCase().contains('your-groq');
  }

  /// Sentry crash-reporting DSN. Empty when unconfigured — Sentry then runs
  /// in no-op mode and the app is unaffected.
  ///
  /// Single coherent mechanism (Phase 13 fix): the DSN is a RUNTIME dotenv
  /// variable (assets/env/.env, the file .env.example documents), so docs
  /// and code can no longer drift. A compile-time --dart-define
  /// (String.fromEnvironment) remains supported as a FALLBACK for CI setups
  /// that prefer not to ship the DSN in the bundled asset.
  static String get sentryDsn {
    final fromEnv = dotenv.env[AppConstants.sentryDsnKey]?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    return const String.fromEnvironment(AppConstants.sentryDsnKey);
  }

  /// True when a Gemini API key is present and non-empty.
  /// True when a real Gemini API key is present. Template placeholders are
  /// rejected exactly like Supabase's, so a starter `.env` copy never enables
  /// the online path (offline mode stays authoritative until real credentials
  /// exist).
  static bool get isGeminiConfigured {
    final key = geminiApiKey;
    return key.isNotEmpty && !key.toLowerCase().contains('your-gemini');
  }
}
