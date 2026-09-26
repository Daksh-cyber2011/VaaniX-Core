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
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/ai_service_impl.dart';
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
///   1. Groq   (when `GROQ_API_KEY` is set and not a placeholder)
///   2. Gemini (when `GEMINI_API_KEY` is set and not a placeholder)
///   3. Offline (always registered as the deterministic fallback)
///
/// The selected provider for any given request is the FIRST registered
/// adapter whose [ModelAdapter.isAvailable] is true. The Offline
/// adapter is always available so the chat pipeline can never refuse a
/// request — a hard AI outage gracefully degrades to the offline tutor
/// instead of leaving the screen blank. The Gemini / Groq adapters are
/// constructed with the shared rate limiter, response cache, and usage
/// tracker so quota optimization is provider-agnostic.
final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIServiceImpl(
    safetyFilter: ref.watch(safetyFilterProvider),
    rateLimiter: ref.watch(aiRateLimiterProvider),
    responseCache: ref.watch(responseCacheProvider),
    usageTracker: ref.watch(tokenUsageTrackerProvider),
  );

  // 1. Groq — preferred when configured. Registered first so it is
  //    selected over Gemini when both providers are present.
  if (AppEnvironment.isGroqConfigured) {
    service.registerAdapter(GroqModelAdapter(
      safetyFilter: ref.read(safetyFilterProvider),
      rateLimiter: ref.read(aiRateLimiterProvider),
      responseCache: ref.read(responseCacheProvider),
      usageTracker: ref.read(tokenUsageTrackerProvider),
    ));
  }

  // 2. Gemini — kept as the secondary online provider. When Groq is
  //    down, callers fall through to Gemini automatically (the service
  //    retries the next available adapter on retryable failures).
  if (AppEnvironment.isGeminiConfigured) {
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

/// The default [AiConfig] — picks Groq when configured, then Gemini,
/// then falls back to offline. UI can override this per-request if
/// needed.
final defaultAiConfigProvider = Provider<AiConfig>((ref) {
  if (AppEnvironment.isGroqConfigured) {
    return AiConfig(
      provider: AiProviderId.groq,
      model: AppEnvironment.groqModel,
      temperature: 0.7,
      maxTokens: 1024,
      enableStreaming: true,
    );
  }
  if (AppEnvironment.isGeminiConfigured) {
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
