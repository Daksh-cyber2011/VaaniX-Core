/// VaaniX AI — Prompt Pipeline Contract
///
/// Transforms raw learner context into the final prompt shape handed to a
/// [ModelAdapter]. Keeping this as a discrete, pluggable step means prompt
/// engineering (persona, safety, few-shot examples, RAG context) can evolve
/// independently of model adapters and UI.
///
/// A default implementation ([DefaultPromptPipeline]) assembles the persona
/// prompt from the learner's personality mode + learner context. Future steps
/// (retrieval, safety filters, translation) chain in here.
library;

import 'package:vaanix_app/features/ai/domain/conversation_context.dart';

/// Builds the persona/instruction prompt for a given conversation context.
///
/// Implementations are pure functions of [ConversationContext] — they must not
/// perform IO or hold mutable state, so they remain trivially testable and
/// order-independent.
abstract class PromptPipeline {
  /// Resolve the system/persona prompt for [context].
  ///
  /// Returns the prompt string (possibly empty). When non-empty, this value
  /// overrides [AiConfig.systemPrompt] for the outgoing request.
  String buildPersonaPrompt(ConversationContext context);
}
