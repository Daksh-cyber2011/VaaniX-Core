/// VaaniX AI — Conversation Pipeline Contract
///
/// Orchestrates a single assistant turn end-to-end:
///   1. Resolve the persona prompt ([PromptPipeline]).
///   2. Load prior memory into the context ([ConversationMemory]).
///   3. Truncate to the context window.
///   4. Delegate generation to the [AIService] (which selects a [ModelAdapter]).
///   5. Persist the new exchange back to memory.
///
/// This is the seam the UI calls. It hides the adapter/pipeline/memory wiring
/// behind one high-level, failure-first API so screens stay thin.

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';

abstract class ConversationPipeline {
  /// Send [userMessage] within [context] and return Van's complete reply.
  ///
  /// The pipeline appends both messages to memory and returns the updated
  /// context. On failure the memory is left untouched.
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  });

  /// Stream Van's reply deltas for [userMessage] within [context].
  ///
  /// Memory is persisted once the stream completes (on the final `done` delta).
  /// Emits [Result]s so transport errors surface the same way as [send].
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  });
}
