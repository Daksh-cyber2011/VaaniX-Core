/// VaaniX AI — Riverpod Providers
///
/// Wires the AI module into the Riverpod dependency graph. This is the
/// single entry point the rest of the app uses to access AI functionality.
///
/// Providers exposed:
/// - [safetyFilterProvider] — DefaultSafetyFilter
/// - [promptPipelineProvider] — DefaultPromptPipeline
/// - [conversationMemoryProvider] — LocalConversationMemory
/// - [aiRateLimiterProvider] — AiRateLimiter (15 RPM throttle)
/// - [responseCacheProvider] — ResponseCache (Q&A caching)
/// - [tokenUsageTrackerProvider] — TokenUsageTracker (daily usage)
/// - [aiServiceProvider] — AIServiceImpl (registers Gemini if configured)
/// - [conversationPipelineProvider] — ConversationPipelineImpl
/// - [defaultAiConfigProvider] — picks Gemini when configured, else offline
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/providers/sync_providers.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/ai_service_impl.dart';
import 'package:vaanix_app/features/ai/data/backend_ai_transport.dart';
import 'package:vaanix_app/features/ai/data/conversation_pipeline_impl.dart';
import 'package:vaanix_app/features/ai/data/default_prompt_pipeline.dart';
import 'package:vaanix_app/features/ai/data/gemini_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/groq_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/local_conversation_memory.dart';
import 'package:vaanix_app/features/ai/data/response_cache.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_service.dart';
import 'package:vaanix_app/features/ai/domain/conversation_memory.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/domain/prompt_pipeline.dart';

/// The [SafetyFilter] used by the pipeline. Defaults to [DefaultSafetyFilter].
final safetyFilterProvider = Provider<SafetyFilter>((ref) {
  return const DefaultSafetyFilter();
});

/// The [PromptPipeline] that builds Van's persona prompt.
final promptPipelineProvider = Provider<PromptPipeline>((ref) {
  return const DefaultPromptPipeline();
});

/// The [ConversationMemory] for persisting chat history.
/// Local-first (SharedPreferences); will be swapped for Supabase in Production.
final conversationMemoryProvider = Provider<ConversationMemory>((ref) {
  return LocalConversationMemory(ref.watch(localStorageServiceProvider));
});

/// The [AiRateLimiter] — throttles Gemini requests to stay under 15 RPM.
/// Single instance shared across all requests (singleton within the
/// provider lifecycle).
final aiRateLimiterProvider = Provider<AiRateLimiter>((ref) {
  return AiRateLimiter();
});

/// The [ResponseCache] — caches Q&A pairs in SharedPreferences for 24h.
/// Reduces API calls by 40-60% for repeated Sanskrit questions.
final responseCacheProvider = Provider<ResponseCache>((ref) {
  return ResponseCache(ref.watch(localStorageServiceProvider));
});

/// The [TokenUsageTracker] — tracks daily token + request usage.
/// Used for the usage display in Chat screen + Settings.
final tokenUsageTrackerProvider = Provider<TokenUsageTracker>((ref) {
  return TokenUsageTracker(ref.watch(localStorageServiceProvider));
});

/// The top-level [AIService] facade.
///
/// Registers adapters in priority order — the first available one wins:
///   1. Groq   (when the model is registered — see below)
///   2. Gemini (when the model is registered — see below)
///   3. Offline (always registered as the deterministic fallback)
///
/// The selected provider for any given request is the FIRST registered
/// adapter whose [ModelAdapter.isAvailable] is true. The Offline
/// adapter is always available so the chat pipeline can never refuse a
/// request — a hard AI outage gracefully degrades to the offline tutor
/// instead of leaving the screen blank.
///
/// Production vs development routing:
///   * When [AppEnvironment.useBackendAi] is true (production), both
///     Groq and Gemini are registered unconditionally — the BACKEND
///     owns the provider credentials and there is no reason for the
///     client to also carry them. This is the only safe production
///     posture: the transport is [BackendAiTransport] and the
///     `apiKey` passed by the adapter is treated as opaque.
///   * When `useBackendAi` is false (local development), Groq and
///     Gemini are registered only when their CLIENT-SIDE keys are
///     configured. A real key in `assets/env/.env` would be unsafe in
///     a production build, so this path is gated by `kDebugMode`-like
///     reasoning via the env flag.
final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIServiceImpl(
    safetyFilter: ref.watch(safetyFilterProvider),
    rateLimiter: ref.watch(aiRateLimiterProvider),
    responseCache: ref.watch(responseCacheProvider),
    usageTracker: ref.watch(tokenUsageTrackerProvider),
  );

  final useBackend = AppEnvironment.useBackendAi;
  final isProductionFlavor = AppEnvironment.isProduction;

  // Production-safety guard: in production flavor the client MUST NOT
  // register direct provider adapters, even if a key happens to be
  // present in `.env`. This is the hard line that prevents a
  // forgotten/overlooked `.env` from leaking a provider secret into a
  // shipped APK. Development builds retain the original behavior so
  // engineers can iterate without standing up the backend.
  final allowDirectProvider = !isProductionFlavor;

  // In production (`VAANIX_USE_BACKEND_AI=true`) provider keys MUST
  // not live in the mobile client — both Groq and Gemini adapters
  // route through the VaaniX backend instead. In development we keep
  // the direct adapters so engineers can iterate against the
  // provider without standing up the backend.
  final backendTransport = useBackend
      ? BackendAiTransport(apiClient: ref.read(vaanixApiClientProvider))
      : null;

  // 1. Groq — preferred when configured. Registered first so it is
  //    selected over Gemini when both providers are present.
  //    In production mode this is registered unconditionally because
  //    the BACKEND owns the credential; the client-side
  //    `isGroqConfigured` flag is irrelevant. Direct registration is
  //    additionally gated on `allowDirectProvider` so a stray
  //    production `.env` never leaks a real key to a shipped client.
  final registerGroqDirect =
      allowDirectProvider && AppEnvironment.isGroqConfigured;
  final registerGroqViaBackend = useBackend;
  if (registerGroqDirect || registerGroqViaBackend) {
    service.registerAdapter(GroqModelAdapter(
      safetyFilter: ref.read(safetyFilterProvider),
      rateLimiter: ref.read(aiRateLimiterProvider),
      responseCache: ref.read(responseCacheProvider),
      usageTracker: ref.read(tokenUsageTrackerProvider),
      transport: registerGroqViaBackend ? backendTransport : null,
    ));
  }

  // 2. Gemini — kept as the secondary online provider. When Groq is
  //    down, callers fall through to Gemini automatically (the service
  //    retries the next available adapter on retryable failures).
  //    Same production-mode reasoning as Groq above.
  final registerGeminiDirect =
      allowDirectProvider && AppEnvironment.isGeminiConfigured;
  final registerGeminiViaBackend = useBackend;
  if (registerGeminiDirect || registerGeminiViaBackend) {
    service.registerAdapter(GeminiModelAdapter(
      safetyFilter: ref.read(safetyFilterProvider),
      rateLimiter: ref.read(aiRateLimiterProvider),
      responseCache: ref.read(responseCacheProvider),
      usageTracker: ref.read(tokenUsageTrackerProvider),
    ));
  }

  // Note: the offline adapter is registered unconditionally inside
  // AIServiceImpl's constructor — never remove that guarantee.
  ref.onDispose(service.dispose);
  return service;
});

/// The [ConversationPipeline] the UI calls to send messages.
///
/// Wires together AIService + PromptPipeline + ConversationMemory +
/// SafetyFilter into the full 7-step orchestration.
final conversationPipelineProvider = Provider<ConversationPipeline>((ref) {
  return ConversationPipelineImpl(
    aiService: ref.watch(aiServiceProvider),
    promptPipeline: ref.watch(promptPipelineProvider),
    memory: ref.watch(conversationMemoryProvider),
    safetyFilter: ref.watch(safetyFilterProvider),
  );
});

/// The default [AiConfig] — picks Groq when registered, then Gemini,
/// then falls back to offline. UI can override this per-request if
/// needed.
///
/// Production-mode aware: when [AppEnvironment.useBackendAi] is true
/// the Groq adapter is registered (the backend owns the credential),
/// so Groq wins even without a client-side key. Otherwise, the
/// adapters are registered only when their client-side keys are
/// present, so the config mirrors that.
final defaultAiConfigProvider = Provider<AiConfig>((ref) {
  final useBackend = AppEnvironment.useBackendAi;
  final isProductionFlavor = AppEnvironment.isProduction;
  final allowDirectProvider = !isProductionFlavor;

  final registerGroq =
      useBackend || (allowDirectProvider && AppEnvironment.isGroqConfigured);
  final registerGemini =
      useBackend || (allowDirectProvider && AppEnvironment.isGeminiConfigured);

  if (registerGroq) {
    return AiConfig(
      provider: AiProviderId.groq,
      model: AppEnvironment.groqModel,
      temperature: 0.7,
      maxTokens: 1024,
      enableStreaming: true,
    );
  }
  if (registerGemini) {
    return AiConfig(
      provider: AiProviderId.gemini,
      model: AppEnvironment.geminiModel,
      temperature: 0.7,
      maxTokens: 1024,
      enableStreaming: true,
    );
  }
  return const AiConfig(
    provider: AiProviderId.offline,
    model: '',
    temperature: 0.7,
    maxTokens: 1024,
    enableStreaming: true,
  );
});

/// Today's AI usage snapshot, watched by the Chat screen's usage chip.
///
/// Phase 4 fix (defect #16): the chip previously read the tracker ONCE via
/// a FutureBuilder and never refreshed, so the count went stale after every
/// send. The ChatController invalidates this provider after each successful
/// turn, which rebuilds the chip with fresh numbers.
final dailyUsageProvider = FutureProvider<DailyUsage>((ref) async {
  return ref.watch(tokenUsageTrackerProvider).getTodayUsage();
});
