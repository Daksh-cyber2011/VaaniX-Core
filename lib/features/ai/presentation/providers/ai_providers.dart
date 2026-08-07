/// VaaniX AI — Riverpod Providers
///
/// Wires the AI module into the Riverpod dependency graph. This is the
/// single entry point the rest of the app uses to access AI functionality.
///
/// Providers exposed:
/// - [safetyFilterProvider] — DefaultSafetyFilter
/// - [promptPipelineProvider] — DefaultPromptPipeline
/// - [conversationMemoryProvider] — LocalConversationMemory
/// - [aiServiceProvider] — AIServiceImpl (registers Gemini if configured)
/// - [conversationPipelineProvider] — ConversationPipelineImpl
/// - [defaultAiConfigProvider] — picks Gemini when configured, else offline

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/ai/data/ai_service_impl.dart';
import 'package:vaanix_app/features/ai/data/conversation_pipeline_impl.dart';
import 'package:vaanix_app/features/ai/data/default_prompt_pipeline.dart';
import 'package:vaanix_app/features/ai/data/local_conversation_memory.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
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

/// The top-level [AIService] facade.
///
/// Registers the [OfflineModelAdapter] always, and the [GeminiModelAdapter]
/// when [AppEnvironment.isGeminiConfigured] is true. Disposes all adapters
/// when the provider is disposed.
final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIServiceImpl();
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
    model: AppEnvironment.isGeminiConfigured ? 'gemini-1.5-flash' : '',
    temperature: 0.7,
    maxTokens: 1024,
    enableStreaming: true,
  );
});
