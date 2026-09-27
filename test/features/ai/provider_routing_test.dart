/// Provider-routing tests for the AI gateway.
///
/// Pins the routing rules:
///   * Offline adapter is ALWAYS registered (so the chat pipeline can
///     never refuse a request — a hard AI outage gracefully degrades).
///   * Groq is registered when `GROQ_API_KEY` is configured (and not a
///     placeholder), and is preferred over Gemini when both are set.
///   * Gemini is registered only when its key is configured.
///   * [defaultAiConfigProvider] picks Groq → Gemini → Offline in that
///     exact order, mirroring the registration order.
///
/// The test builds a fresh [ProviderContainer] per scenario so the
/// routing logic runs against the real env configuration without any
/// other test polluting it.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/ai/data/gemini_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/groq_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/offline_model_adapter.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';

Future<void> _setEnv({
  String? geminiKey,
  String? groqKey,
}) async {
  dotenv.testLoad(mergeWith: {
    if (geminiKey != null) AppConstants.geminiApiKey: geminiKey,
    if (groqKey != null) AppConstants.groqApiKey: groqKey,
  });
}

Future<ProviderContainer> _newContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    dotenv.testLoad(mergeWith: const {});
  });

  group('aiServiceProvider routing', () {
    test('registers the Offline adapter unconditionally', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv();
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, contains(AiProviderId.offline));
    });

    test('registers Groq ONLY when GROQ_API_KEY is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(groqKey: 'gsk_real_1234567890abcdef');
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, contains(AiProviderId.groq));
      expect(
        service.adapters[AiProviderId.groq],
        isA<GroqModelAdapter>(),
      );
    });

    test('registers Gemini ONLY when GEMINI_API_KEY is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(geminiKey: 'AIzaSy_real_key_value');
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, contains(AiProviderId.gemini));
      expect(
        service.adapters[AiProviderId.gemini],
        isA<GeminiModelAdapter>(),
      );
    });

    test('rejects placeholder Groq keys', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(groqKey: 'your-groq-placeholder');
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, isNot(contains(AiProviderId.groq)),
          reason: 'a starter .env placeholder MUST NOT enable Groq — the '
              'chat pipeline should fall through to Gemini/offline');
    });

    test('does not register Groq when neither key is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv();
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, [AiProviderId.offline]);
    });

    test('registers Groq AND Gemini when both are configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(
        geminiKey: 'AIzaSy_real_key_value',
        groqKey: 'gsk_real_1234567890abcdef',
      );
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys,
          containsAll([AiProviderId.groq, AiProviderId.gemini, AiProviderId.offline]));
      // Groq is preferred when both are configured — adapterFor with
      // AiProviderId.groq must resolve to the real Groq adapter, not
      // fall through to offline.
      final groqConfig = const AiConfig(
        provider: AiProviderId.groq,
        model: '',
        temperature: 0.7,
        maxTokens: 1024,
        enableStreaming: true,
      );
      expect(service.adapterFor(groqConfig), isA<GroqModelAdapter>());
    });

    test('registerAdapter disposes the previous instance under the same id',
        () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv();
      final service = container.read(aiServiceProvider);
      // The Offline adapter is always registered. Replace it with a
      // fake, then verify the swap took effect and the previous
      // instance was disposed.
      final original = service.adapters[AiProviderId.offline]!;
      var disposed = 0;
      final fake = _DisposingOfflineFake(onDispose: () => disposed += 1);
      service.registerAdapter(fake);
      expect(service.adapters[AiProviderId.offline], same(fake));
      service.registerAdapter(original);
      // The fake was displaced — its dispose() must have been called.
      expect(disposed, 1,
          reason: 'the service must dispose the adapter it displaced to '
              'avoid leaking resources');
    });
  });

  group('defaultAiConfigProvider routing', () {
    test('picks Groq when its key is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(groqKey: 'gsk_real_1234567890abcdef');
      final config = container.read(defaultAiConfigProvider);
      expect(config.provider, AiProviderId.groq);
      expect(config.model, isNotEmpty,
          reason: 'the model id MUST come from the env configuration — '
              'never an empty string');
    });

    test('picks Gemini when only its key is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(geminiKey: 'AIzaSy_real_key_value');
      final config = container.read(defaultAiConfigProvider);
      expect(config.provider, AiProviderId.gemini);
    });

    test('prefers Groq over Gemini when both are configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv(
        geminiKey: 'AIzaSy_real_key_value',
        groqKey: 'gsk_real_1234567890abcdef',
      );
      final config = container.read(defaultAiConfigProvider);
      expect(config.provider, AiProviderId.groq,
          reason: 'Groq is the preferred online provider in the routing '
              'chain (Groq → Gemini → Offline)');
    });

    test('falls back to Offline when neither key is configured', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv();
      final config = container.read(defaultAiConfigProvider);
      expect(config.provider, AiProviderId.offline);
      expect(config.model, '');
    });
  });

  group('adapter resolution (adapterFor)', () {
    test('falls through to offline when the requested provider is absent',
        () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setEnv();
      final service = container.read(aiServiceProvider);
      final result = service.adapterFor(const AiConfig(
        provider: AiProviderId.groq,
        model: '',
        temperature: 0.7,
        maxTokens: 1024,
        enableStreaming: false,
      ));
      expect(result, isA<OfflineModelAdapter>(),
          reason: 'a missing provider MUST fall through to offline — never '
              'throw, never fabricate an AI response');
    });
  });

  group('production routing', () {
    /// Helper that turns on the production-mode env flag for a single
    /// test scenario. `VAANIX_USE_BACKEND_AI=true` is what triggers
    /// backend-bound routing.
    Future<void> _setProductionEnv({
      String? groqKey,
      String? geminiKey,
    }) async {
      dotenv.testLoad(mergeWith: {
        AppConstants.useBackendAiKey: 'true',
        if (groqKey != null) AppConstants.groqApiKey: groqKey,
        if (geminiKey != null) AppConstants.geminiApiKey: geminiKey,
      });
    }

    test(
        'VAANIX_USE_BACKEND_AI=true registers Groq even WITHOUT a '
        'client-side Groq key (backend owns the credential)', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setProductionEnv();
      // Critically: no client-side Groq or Gemini key is set.
      final service = container.read(aiServiceProvider);
      expect(service.adapters.keys, contains(AiProviderId.groq),
          reason: 'in production mode the backend owns the provider '
              'credential, so the Groq adapter MUST be registered even '
              'when the client has no GROQ_API_KEY set');
      expect(service.adapters.keys, contains(AiProviderId.gemini),
          reason: 'same reasoning applies to the Gemini adapter');
    });

    test(
        'VAANIX_USE_BACKEND_AI=true picks Groq in defaultAiConfigProvider '
        'even without client-side keys', () async {
      final container = await _newContainer();
      addTearDown(container.dispose);
      await _setProductionEnv();
      final config = container.read(defaultAiConfigProvider);
      expect(config.provider, AiProviderId.groq,
          reason: 'production routing picks Groq (the first registered '
              'adapter) regardless of whether the client holds a key');
    });

    test(
        'production flavor + direct keys → direct adapters are NOT '
        'registered (safety guard)', () async {
      // This test runs ONLY in debug mode (where AppEnvironment.isProduction
      // is true only when VAANIX_ENV=production is explicitly set). The
      // harness sets VAANIX_ENV via dotenv.testLoad, then asserts the
      // production guard kicks in.
      dotenv.testLoad(mergeWith: const {
        AppConstants.appEnvKey: 'production',
        AppConstants.groqApiKey: 'gsk_real_production_key_value',
      });
      final container = await _newContainer();
      addTearDown(container.dispose);
      final service = container.read(aiServiceProvider);
      // Direct providers must NOT be registered in production flavor
      // even when keys are present — the client must not be able to
      // talk to Groq/Gemini directly from a shipped APK.
      expect(service.adapters.keys, isNot(contains(AiProviderId.groq)),
          reason: 'production flavor MUST NOT register a Groq adapter that '
              'would call the provider directly from the client');
      expect(service.adapters.keys, isNot(contains(AiProviderId.gemini)),
          reason: 'production flavor MUST NOT register a Gemini adapter '
              'that would call the provider directly from the client');
      // Offline is always available so the app still functions.
      expect(service.adapters.keys, contains(AiProviderId.offline));
    });
  });
}

/// Tiny offline adapter that counts disposes so the test can verify the
/// service disposed the previous instance when [registerAdapter]
/// displaced it. Inherits [OfflineModelAdapter] so we do not have to
/// reimplement [ModelAdapter.complete] / [ModelAdapter.stream].
class _DisposingOfflineFake extends OfflineModelAdapter {
  _DisposingOfflineFake({required this.onDispose});

  final void Function() onDispose;

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }
}
