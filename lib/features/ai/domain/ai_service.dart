/// VaaniX AI — Service Contract (Top-level Facade)
///
/// The single, provider-agnostic entry point for generating AI responses.
/// The service owns the registry of [ModelAdapter]s and routes a request to
/// the adapter named by [AiConfig.provider] (falling back to the offline
/// adapter when the chosen one is unavailable).
///
/// Why a separate service on top of adapters?
///   - Centralizes availability/fallback logic in one tested place.
///   - Keeps the [ConversationPipeline] from knowing about adapter selection.
///   - Gives a stable API the rest of the app imports (`aiServiceProvider`).
///
/// Domain layer only: this file defines the contract. The implementation
/// lives in `features/ai/data/`.
library;

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

abstract class AIService {
  /// All registered adapters, keyed by their provider id.
  Map<AiProviderId, ModelAdapter> get adapters;

  /// The adapter selected by [config], or the offline fallback.
  ModelAdapter adapterFor(AiConfig config);

  /// Generate a complete response for [context].
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  });

  /// Stream response deltas for [context].
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  });

  /// Release all adapter resources.
  void dispose();
}
