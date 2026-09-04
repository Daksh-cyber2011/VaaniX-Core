/// Environment Configuration Tests
///
/// Verifies the configured-vs-unconfigured contract of [AppEnvironment]:
/// missing or placeholder Supabase credentials never enable the cloud path
/// (offline mode stays authoritative), flavors default safely, and the API
/// base falls back to a local value. No secrets are required or invented.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => dotenv.testLoad());

  group('AppEnvironment configured/unconfigured', () {
    test('isSupabaseConfigured is false without credentials', () {
      expect(AppEnvironment.isSupabaseConfigured, isFalse);
    });

    test('isSupabaseConfigured rejects template placeholders', () {
      dotenv.testLoad(mergeWith: {
        AppConstants.supabaseUrlKey: 'https://your-project-id.supabase.co',
        AppConstants.supabaseAnonKeyKey: 'your-supabase-anon-key',
      });
      expect(AppEnvironment.isSupabaseConfigured, isFalse);
    });

    test('isSupabaseConfigured is true with real-looking credentials', () {
      dotenv.testLoad(mergeWith: {
        AppConstants.supabaseUrlKey: 'https://real-project.supabase.co',
        AppConstants.supabaseAnonKeyKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sub',
      });
      expect(AppEnvironment.isSupabaseConfigured, isTrue);
    });

    test('flavor defaults to development and never to production', () {
      expect(AppEnvironment.flavor, Flavor.development);
      expect(AppEnvironment.isDevelopment, isTrue);
      expect(AppEnvironment.isProduction, isFalse);
    });

    test('apiBaseUrl falls back to localhost when unset', () {
      expect(AppEnvironment.apiBaseUrl, 'http://localhost:8000/api/v1');
    });

    test('production flavor is recognized from env', () {
      dotenv.testLoad(mergeWith: {AppConstants.appEnvKey: 'production'});
      expect(AppEnvironment.isProduction, isTrue);
      expect(AppEnvironment.flavor, Flavor.production);
    });

    test('geminiModel defaults to the current stable flash model', () {
      expect(AppEnvironment.geminiModel, 'gemini-2.5-flash');
    });

    test('geminiModel honors the GEMINI_MODEL env override', () {
      dotenv.testLoad(mergeWith: {
        AppConstants.geminiModelKey: 'gemini-2.5-flash-lite',
      });
      expect(AppEnvironment.geminiModel, 'gemini-2.5-flash-lite');
    });

    test('isGeminiConfigured is false without a key', () {
      expect(AppEnvironment.isGeminiConfigured, isFalse);
    });

    test('isGeminiConfigured rejects template placeholder keys', () {
      dotenv.testLoad(mergeWith: {
        AppConstants.geminiApiKey: 'your-gemini-api-key-here',
      });
      expect(AppEnvironment.isGeminiConfigured, isFalse,
          reason: 'a starter .env copy must never enable the online path');
    });

    test('isGeminiConfigured is true with a real-looking key', () {
      dotenv.testLoad(mergeWith: {
        AppConstants.geminiApiKey: 'AIzaSyDummyRealLookingKeyForTests',
      });
      expect(AppEnvironment.isGeminiConfigured, isTrue);
    });
  });
}
