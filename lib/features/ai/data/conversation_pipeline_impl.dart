/// VaaniX AI — Conversation Pipeline Implementation
///
/// Orchestrates a single assistant turn end-to-end:
///   1. Resolve the persona prompt via [PromptPipeline].
///   2. Load prior memory via [ConversationMemory].
///   3. Truncate to the context window.
///   4. Sanitize input via [SafetyFilter].
///   5. Delegate generation to [AIService].
///   6. Moderate output via [SafetyFilter].
///   7. Persist the new exchange to memory.
///
/// On failure (generation error OR output moderation failure), memory is
/// left untouched — the user message is not persisted if Van can't reply.
library;

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/ai_service.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_memory.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/domain/prompt_pipeline.dart';

class ConversationPipelineImpl implements ConversationPipeline {
  ConversationPipelineImpl({
    required AIService aiService,
    required PromptPipeline promptPipeline,
    required ConversationMemory memory,
    required SafetyFilter safetyFilter,
  })  : _aiService = aiService,
        _promptPipeline = promptPipeline,
        _memory = memory,
        _safetyFilter = safetyFilter;

  final AIService _aiService;
  final PromptPipeline _promptPipeline;
  final ConversationMemory _memory;
  final SafetyFilter _safetyFilter;

  @override
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async {
    // 1. Resolve persona prompt.
    final personaPrompt = _promptPipeline.buildPersonaPrompt(context);

    // 2. Load prior memory.
    final memoryResult = await _memory.load(context.conversationId);
    final priorMessages = memoryResult.fold(
      (_) => <AiMessage>[],
      (v) => v,
    );

    // 3. Build the full context: prior messages + new user message,
    //    with persona prompt attached. The learning context rides along so
    //    adapters that re-derive prompts from the context keep seeing it.
    var fullContext = ConversationContext(
      conversationId: context.conversationId,
      learner: context.learner,
      messages: [...priorMessages, userMessage],
      personaPrompt: personaPrompt,
      learningContext: context.learningContext,
    );

    // 4. Truncate to context window (keep last 20 messages).
    fullContext = fullContext.truncated(keep: 20);

    // 5. Delegate to AI service for generation.
    final result = await _aiService.complete(
      context: fullContext,
      config: config,
    );

    // 6. Handle failure — return early without persisting.
    if (result.isLeft()) {
      final failure = result.swap().getOrElse(
            () => const UnknownFailure('AI generation failed'),
          );
      return Left(failure);
    }

    // 7. Extract the assistant message.
    final assistantMessage = result.getOrElse(
      () => AiMessage.assistant(id: 'error', content: ''),
    );

    // 8. Moderate the output.
    if (!_safetyFilter.isOutputSafe(assistantMessage.content)) {
      return const Left(AiContentFilterFailure());
    }

    // 9. Persist the new exchange to memory.
    await _memory.append(
      conversationId: context.conversationId,
      message: userMessage,
    );
    await _memory.append(
      conversationId: context.conversationId,
      message: assistantMessage,
    );

    // 10. Return the updated context with the assistant's reply appended.
    return Right(fullContext.append(assistantMessage));
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async* {
    // 1. Resolve persona prompt.
    final personaPrompt = _promptPipeline.buildPersonaPrompt(context);

    // 2. Load prior memory.
    final memoryResult = await _memory.load(context.conversationId);
    final priorMessages = memoryResult.fold(
      (_) => <AiMessage>[],
      (v) => v,
    );

    // 3. Build full context.
    var fullContext = ConversationContext(
      conversationId: context.conversationId,
      learner: context.learner,
      messages: [...priorMessages, userMessage],
      personaPrompt: personaPrompt,
      learningContext: context.learningContext,
    );
    fullContext = fullContext.truncated(keep: 20);

    // 4. Stream from the AI service.
    final stream = _aiService.stream(context: fullContext, config: config);

    final buffer = StringBuffer();
    var hadError = false;

    await for (final delta in stream) {
      yield delta;
      delta.fold(
        (_) => hadError = true,
        (d) {
          buffer.write(d.content);
        },
      );
    }

    // 5. On successful completion, moderate + persist.
    if (!hadError) {
      final fullText = buffer.toString();
      if (fullText.isNotEmpty && _safetyFilter.isOutputSafe(fullText)) {
        final assistantMessage = AiMessage.assistant(
          id: 'stream_${DateTime.now().millisecondsSinceEpoch}',
          content: fullText,
          createdAt: DateTime.now().toUtc(),
        );

        await _memory.append(
          conversationId: context.conversationId,
          message: userMessage,
        );
        await _memory.append(
          conversationId: context.conversationId,
          message: assistantMessage,
        );
      }
    }
  }
}
