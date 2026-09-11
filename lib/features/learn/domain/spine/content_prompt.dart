/// Learn Mode 2.0 — Content Generation Prompts (M5, Master Brief
/// §16/§44/§45/§62)
///
/// The same §62 prompt discipline the M4 planner uses, applied to
/// PERSONALIZED MATERIAL generation:
///
///   SYSTEM / PEDAGOGY RULES   → [buildContentSystemPrompt]
///   LANGUAGE KNOWLEDGE        → user prompt section 1 (the trusted
///                               excerpt: vocabulary, examples, reference)
///   LEARNER STATE             → user prompt section 2 (structured digest)
///   TASK                      → user prompt section 3 (ONE item, one kind)
///   OUTPUT SCHEMA             → system prompt (the JSON contract)
///
/// The grounding rules are the point (Master Brief §16): the model may
/// personalize ONLY the trusted material it is shown — it may not invent
/// vocabulary, grammar, or facts. The schema includes an honest escape
/// hatch ({"kind":"none"}) so a model that cannot stay grounded declines
/// instead of fabricating; the caller then falls back to trusted content
/// (§34 priority ladder, §46).
///
/// Pure Dart; no Flutter imports.
library;

import 'dart:convert';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';

/// Human word for each generated-material kind (prompt + UI vocabulary).
const Map<GeneratedContentKind, String> kGeneratedContentKindDescriptions =
    <GeneratedContentKind, String>{
  GeneratedContentKind.explanation:
      'a short, friendly explanation of the concept',
  GeneratedContentKind.example:
      'a few personalized example sentences or a mini dialogue',
  GeneratedContentKind.practice: 'one practice question with an answer key',
};

/// Builds the SYSTEM prompt: pedagogy + grounding rules + the strict JSON
/// schema for ONE generated item (Master Brief §62 + §16).
String buildContentSystemPrompt({
  required GeneratedContentKind kind,
  Set<ExerciseType>? generatableExerciseTypes,
}) {
  final kinds = generatableExerciseTypes ?? kGeneratableExerciseTypes;
  final exerciseTypes =
      kinds.map((t) => '"${t.name}"').join(' | ');
  final kindWord = kGeneratedContentKindDescriptions[kind] ?? kind.name;

  return '''
You are the material maker inside VaaniX, a language-learning app.
Your ONLY job is to create ONE small piece of personalized learning
material for ONE learner. You never chat and never do anything except
return ONE JSON object.

OUTPUT FORMAT (strict):
Return ONLY a single JSON object. No markdown, no code fences, no
commentary. Shape (fields you do not need are omitted):

{
  "kind": "${kind.name}",           // exactly this kind
  "language": "<the language code from the task>",
  "title": "short friendly label, max 80 characters",
  "body": "the explanation text",   // ONLY for kind "explanation"
  "lines": [                        // ONLY for kind "example"
    {"text": "sentence in the target language",
     "translation": "English translation"}
  ],
  "exercise": {                     // ONLY for kind "practice"
    "type": "<$exerciseTypes>",
    "prompt": "the question",
    "options": ["choice A", "choice B", "choice C"],
    "correctIndex": 0,
    "acceptedAnswers": ["answer 1"],
    "explanation": "why the answer is right"
  }
}

For kind "${kind.name}" you are making $kindWord.

GROUNDING RULES (violating any of these makes the material invalid):
1. Use ONLY the vocabulary, sentences and grammar patterns shown in the
   TRUSTED LANGUAGE KNOWLEDGE section. Never invent new words, never
   borrow grammar from another language, never guess spellings.
2. Every sentence you write in the target language must be written in
   the target language's OWN script and reading direction.
3. Never mix another language into the target-language text. English is
   allowed ONLY in "translation" fields and in explanations addressed to
   the learner.
4. If you cannot stay inside the trusted material, return exactly
   {"kind":"none"} — declining is always better than guessing.
5. Keep every field short and useful. No filler, no lectures.

TONE RULES (the learner reads this material):
- Personal and encouraging, plain words, no linguistic jargon
  (never say "prerequisite", "schema", "CEFR", "difficulty curve").
- Speak to one learner ("you"), never about "users".
- Educational material only. Nothing harmful, unsafe, or off-topic.''';
}

/// Builds the USER prompt with the three §62 sections, grounded in the
/// concept's [TrustedKnowledgeExcerpt] (Master Brief §16 "trusted
/// language metadata / vocabulary / grammar / examples").
String buildContentUserPrompt({
  required String languageName,
  required String languageCode,
  required bool isRTL,
  required String scriptName,
  required String conceptId,
  required String conceptTitle,
  required String? conceptSubtitle,
  required TrustedKnowledgeExcerpt excerpt,
  required Map<String, Object?> learnerDigest,
  required GeneratedContentKind kind,
  required int difficultyKnob,
}) {
  final buffer = StringBuffer();

  // ── Section 1: LANGUAGE KNOWLEDGE (trusted excerpt only) ─────────────
  buffer.writeln('=== LANGUAGE KNOWLEDGE ===');
  buffer.writeln(
      'Language: $languageName (code: $languageCode, script: $scriptName, '
      'written ${isRTL ? 'right-to-left' : 'left-to-right'}).');
  buffer.writeln('CONCEPT: $conceptId — $conceptTitle'
      '${conceptSubtitle == null || conceptSubtitle.isEmpty ? '' : ' ($conceptSubtitle)'}');
  buffer.writeln();
  if (excerpt.vocabulary.isNotEmpty) {
    buffer.writeln('TRUSTED VOCABULARY (the only words you may rely on):');
    buffer.writeln(excerpt.vocabulary.take(60).join(', '));
    buffer.writeln();
  } else {
    buffer.writeln(
        'TRUSTED VOCABULARY: (none available — you must decline.)');
    buffer.writeln();
  }
  if (excerpt.exampleSentences.isNotEmpty) {
    buffer.writeln('TRUSTED EXAMPLES (copy these patterns, never contradict them):');
    for (final sentence in excerpt.exampleSentences) {
      buffer.writeln('- $sentence');
    }
    buffer.writeln();
  }
  if (excerpt.referenceText.isNotEmpty) {
    buffer.writeln('REFERENCE MATERIAL (from the learner\'s lesson):');
    buffer.writeln(excerpt.referenceText);
    buffer.writeln();
  }

  // ── Section 2: LEARNER STATE ─────────────────────────────────────────
  buffer.writeln('=== LEARNER STATE ===');
  buffer.writeln(
      const JsonEncoder.withIndent('  ').convert(learnerDigest));

  // ── Section 3: TASK ──────────────────────────────────────────────────
  buffer.writeln();
  buffer.writeln('=== TASK ===');
  buffer.writeln(
      'Make ONE item of kind "${kind.name}" for the concept above, at '
      'difficulty $difficultyKnob (1 = brand new, 5 = very hard), '
      'personalized to the learner state.');
  switch (kind) {
    case GeneratedContentKind.explanation:
      buffer.writeln(
          'Explain it differently from the lesson, in a few short '
          'sentences, using only the trusted vocabulary and patterns.');
    case GeneratedContentKind.example:
      buffer.writeln(
          'Give 2 to 5 example sentences (or a tiny dialogue) that reuse '
          'the trusted vocabulary. Each line needs an English '
          '"translation" field.');
    case GeneratedContentKind.practice:
      buffer.writeln(
          'Write ONE practice question: "mcq" or "fillBlank" with 3 '
          'options and "correctIndex", or "translation" with '
          '"acceptedAnswers". Always include an "explanation" for the '
          'answer.');
  }
  buffer.writeln('If you cannot do this with the trusted material only, '
      'return {"kind":"none"}.');
  buffer.writeln('Respond with the JSON object only.');

  return buffer.toString();
}
