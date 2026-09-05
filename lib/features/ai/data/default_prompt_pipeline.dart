/// VaaniX AI — Default Prompt Pipeline
///
/// Assembles Van's persona/instruction prompt from the learner's personality
/// mode and learner context. This is the only place persona wording lives,
/// so tone changes are localized and testable.
///
/// Phase 4: the persona is intentionally STABLE across turns. The per-turn
/// learning-context snapshot is delivered separately — see
/// [ConversationContext.learningContextMessage] — so adapters can keep the
/// system instruction (and the model client built from it) unchanged between
/// requests.
///
/// Segment 6: Now uses the [PersonalityMode] enum directly instead of
/// fragile lowercase string matching. The personality mode is passed as
/// a string in [LearnerContext.personalityMode] — we map it to the enum
/// and use exhaustive switch.
///
/// Future prompt-engineering concerns (RAG context injection, few-shot
/// examples, localization) chain in by composing this implementation
/// or replacing it via DI — the [PromptPipeline] contract stays unchanged.
library;

import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/prompt_pipeline.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';

class DefaultPromptPipeline implements PromptPipeline {
  const DefaultPromptPipeline();

  @override
  String buildPersonaPrompt(ConversationContext context) {
    final learner = context.learner;
    final companion = learner.companionName.trim().isEmpty
        ? 'Van'
        : learner.companionName.trim();

    final base = StringBuffer()
      ..writeln('You are $companion, an emotionally intelligent AI duck '
          'companion that teaches Sanskrit to Indian students (CBSE).')
      ..writeln('Always be warm, encouraging, and age-appropriate.')
      ..writeln('Prefer Sanskrit (Devanagari) with transliteration and a short '
          'English gloss for new words.')
      ..writeln(
          'Celebrate effort, normalize mistakes, and keep replies concise.');

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

    // Personality steering — use the enum directly instead of string matching.
    // Resolve the enum from the string; null/unknown falls through to default.
    final mode = PersonalityMode.values.asNameMap()[learner.personalityMode];
    if (mode != null) {
      switch (mode) {
        case PersonalityMode.cheerleader:
          base.writeln('Tone: energetic, celebratory, lots of encouragement.');
        case PersonalityMode.calm:
          base.writeln(
              'Tone: patient, soft, steady; great for anxious learners.');
        case PersonalityMode.fun:
          base.writeln('Tone: playful, light duck puns, casual.');
      }
    }

    // Learning-context injection (V1 §4, re-shaped in Phase 4): the bounded,
    // real progress snapshot assembled by learningContextProvider is NO
    // LONGER appended here. The persona must stay STABLE across turns — it
    // is the Gemini system instruction, and per-turn churn (streak, XP,
    // progress) forced a client rebuild on every request, defeating model
    // reuse. The snapshot now travels as framed message content via
    // [ConversationContext.learningContextMessage]; adapters append it to
    // the outgoing user turn. The persona still carries the slow-changing
    // personalization (names, class, topic, tone).
    return base.toString().trim();
  }
}
