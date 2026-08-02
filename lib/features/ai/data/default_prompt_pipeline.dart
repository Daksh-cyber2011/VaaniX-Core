/// VaaniX AI — Default Prompt Pipeline
///
/// Assembles Van's persona/instruction prompt from the learner's personality
/// mode and learner context. This is the only place persona wording lives,
/// so tone changes are localized and testable.
///
/// Future prompt-engineering concerns (safety filters, RAG context injection,
/// few-shot examples, localization) chain in by composing this implementation
/// or replacing it via DI — the [PromptPipeline] contract stays unchanged.

import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/prompt_pipeline.dart';

class DefaultPromptPipeline implements PromptPipeline {
  const DefaultPromptPipeline();

  @override
  String buildPersonaPrompt(ConversationContext context) {
    final learner = context.learner;
    final companion =
        learner.companionName.trim().isEmpty ? 'Van' : learner.companionName.trim();

    final base = StringBuffer()
      ..writeln('You are $companion, an emotionally intelligent AI duck '
          'companion that teaches Sanskrit to Indian students (CBSE).')
      ..writeln('Always be warm, encouraging, and age-appropriate.')
      ..writeln('Prefer Sanskrit (Devanagari) with transliteration and a short '
          'English gloss for new words.')
      ..writeln('Celebrate effort, normalize mistakes, and keep replies concise.');

    if (learner.displayName.trim().isNotEmpty) {
      base.writeln('The learner\'s name is ${learner.displayName.trim()}; '
          'address them by name occasionally.');
    }
    if (learner.cbseClassLabel != null) {
      base.writeln('Target level: ${learner.cbseClassLabel}.');
    }
    if (learner.topic.trim().isNotEmpty) {
      base.writeln('Current topic: ${learner.topic.trim()}.');
    }

    // Personality steering.
    switch (learner.personalityMode.toLowerCase()) {
      case 'cheerleader':
        base.writeln('Tone: energetic, celebratory, lots of encouragement.');
      case 'calm':
        base.writeln('Tone: patient, soft, steady; great for anxious learners.');
      case 'fun':
        base.writeln('Tone: playful, light duck puns, casual.');
    }

    return base.toString().trim();
  }
}
