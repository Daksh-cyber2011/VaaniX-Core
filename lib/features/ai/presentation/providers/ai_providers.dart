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
/// Registers the [OfflineModelAdapter] always, and the [GeminiModelAdapter]
/// when [AppEnvironment.isGeminiConfigured] is true. The Gemini adapter
/// is constructed with the rate limiter, response cache, and usage tracker
/// for quota optimization.
final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIServiceImpl(
    safetyFilter: ref.watch(safetyFilterProvider),
    rateLimiter: ref.watch(aiRateLimiterProvider),
    responseCache: ref.watch(responseCacheProvider),
    usageTracker: ref.watch(tokenUsageTrackerProvider),
  );
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

/// The default [AiConfig] — picks Gemini when configured, falls back to
/// offline otherwise. UI can override this per-request if needed.
final defaultAiConfigProvider = Provider<AiConfig>((ref) {
  return AiConfig(
    provider: AppEnvironment.isGeminiConfigured
        ? AiProviderId.gemini
        : AiProviderId.offline,
    model: AppEnvironment.isGeminiConfigured ? AppEnvironment.geminiModel : '',
    temperature: 0.7,
    maxTokens: 1024,
    enableStreaming: true,
  );
});
