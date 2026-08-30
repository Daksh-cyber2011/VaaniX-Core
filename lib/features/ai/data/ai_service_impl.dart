/// VaaniX AI — AIService Implementation
///
/// Adapter registry + facade. Registers the [OfflineModelAdapter] always,
/// and the [GeminiModelAdapter] when [AppEnvironment.isGeminiConfigured]
/// is true. Routes requests to the adapter named by [AiConfig.provider],
/// falling back to offline when the chosen adapter is unavailable.
///
/// Segment 7.5: The GeminiModelAdapter is now constructed with an
/// [AiRateLimiter], [ResponseCache], and [TokenUsageTracker] for quota
/// optimization. These are injected from the Riverpod providers.

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/ai/data/gemini_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/offline_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/response_cache.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/ai_service.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

class AIServiceImpl implements AIService {
  AIServiceImpl({
    SafetyFilter? safetyFilter,
    AiRateLimiter? rateLimiter,
    ResponseCache? responseCache,
    TokenUsageTracker? usageTracker,
  }) {
    // Always register the offline adapter as the fallback.
    _adapters[AiProviderId.offline] = OfflineModelAdapter();

    // Register Gemini when configured, with quota optimization components.
    if (AppEnvironment.isGeminiConfigured) {
      _adapters[AiProviderId.gemini] = GeminiModelAdapter(
        safetyFilter: safetyFilter,
        rateLimiter: rateLimiter,
        responseCache: responseCache,
        usageTracker: usageTracker,
      );
    }
  }

  final Map<AiProviderId, ModelAdapter> _adapters = {};

  @override
  Map<AiProviderId, ModelAdapter> get adapters => Map.unmodifiable(_adapters);

  @override
  ModelAdapter adapterFor(AiConfig config) {
    // Try the requested provider first.
    final requested = _adapters[config.provider];
    if (requested != null && requested.isAvailable) {
      return requested;
    }

    // Fall back to offline — it's always available.
    return _adapters[AiProviderId.offline]!;
  }

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return adapterFor(config).complete(context: context, config: config);
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return adapterFor(config).stream(context: context, config: config);
  }

  @override
  void dispose() {
    for (final adapter in _adapters.values) {
      adapter.dispose();
    }
    _adapters.clear();
  }
}
