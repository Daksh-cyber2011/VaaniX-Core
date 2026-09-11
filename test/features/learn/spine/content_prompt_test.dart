/// Content Generation Prompts — M5 tests.
///
/// Pins the §62 prompt discipline and the §16 grounding rules: the three
/// user-prompt sections, the trusted excerpt as the ONLY knowledge
/// source, the honest "none" escape hatch, kind-specific task lines, and
/// the schema honesty (only generatable exercise types advertised).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/content_prompt.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';

void main() {
  const excerpt = TrustedKnowledgeExcerpt(
    languageCode: 'hi',
    conceptId: 'hi_ls_greetings',
    lessonId: 'hi_ls_greetings',
    vocabulary: ['नमस्ते', 'दोस्त'],
    exampleSentences: ['नमस्ते दोस्त'],
    referenceText: 'नमस्ते दोस्त — hello friend.',
    isRTL: false,
    scriptCode: 'Deva',
  );
  const digest = <String, Object?>{
    'language': 'hi',
    'desiredLevel': 'conversational',
  };

  group('system prompt', () {
    test('declares exactly the requested kind and the JSON contract', () {
      final system = buildContentSystemPrompt(
        kind: GeneratedContentKind.explanation,
      );
      expect(system, contains('"kind": "explanation"'));
      expect(system, contains('Return ONLY a single JSON object'));
      // The honest escape hatch (§16).
      expect(system, contains('{"kind":"none"}'));
      // Grounding rules (§16).
      expect(system, contains('TRUSTED LANGUAGE KNOWLEDGE'));
      expect(system, contains('Never invent new words'));
      expect(system, contains("OWN script and reading direction"));
      // Tone rules (§44).
      expect(system, contains('never say "prerequisite"'));
    });

    test('practice kind advertises ONLY the generatable types', () {
      final system = buildContentSystemPrompt(
        kind: GeneratedContentKind.practice,
      );
      expect(system, contains('"mcq"'));
      expect(system, contains('"fillBlank"'));
      expect(system, contains('"translation"'));
      expect(system, isNot(contains('"ordering"')));
      expect(system, isNot(contains('"matching"')));
    });
  });

  group('user prompt', () {
    test('has the three §62 sections', () {
      final user = buildContentUserPrompt(
        languageName: 'Hindi',
        languageCode: 'hi',
        isRTL: false,
        scriptName: 'Devanagari',
        conceptId: 'hi_ls_greetings',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: excerpt,
        learnerDigest: digest,
        kind: GeneratedContentKind.explanation,
        difficultyKnob: 2,
      );
      expect(user, contains('=== LANGUAGE KNOWLEDGE ==='));
      expect(user, contains('=== LEARNER STATE ==='));
      expect(user, contains('=== TASK ==='));
    });

    test('the trusted excerpt is the only knowledge source (§16)', () {
      final user = buildContentUserPrompt(
        languageName: 'Hindi',
        languageCode: 'hi',
        isRTL: false,
        scriptName: 'Devanagari',
        conceptId: 'hi_ls_greetings',
        conceptTitle: 'Greetings',
        conceptSubtitle: 'Saying hello',
        excerpt: excerpt,
        learnerDigest: digest,
        kind: GeneratedContentKind.example,
        difficultyKnob: 2,
      );
      expect(user, contains('TRUSTED VOCABULARY'));
      expect(user, contains('नमस्ते'));
      expect(user, contains('TRUSTED EXAMPLES'));
      expect(user, contains('नमस्ते दोस्त'));
      expect(user, contains('REFERENCE MATERIAL'));
      expect(user, contains('नमस्ते दोस्त — hello friend.'));
      expect(user, contains('CONCEPT: hi_ls_greetings — Greetings'));
      // The learner digest flows through verbatim.
      expect(user, contains('"desiredLevel": "conversational"'));
    });

    test('task line is kind-specific and carries the difficulty knob', () {
      final user = buildContentUserPrompt(
        languageName: 'Hindi',
        languageCode: 'hi',
        isRTL: false,
        scriptName: 'Devanagari',
        conceptId: 'hi_ls_greetings',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: excerpt,
        learnerDigest: digest,
        kind: GeneratedContentKind.practice,
        difficultyKnob: 4,
      );
      expect(user, contains('"kind": "practice"'));
      expect(user, contains('difficulty 4'));
      expect(user, contains('acceptedAnswers'));
    });

    test('RTL languages state their direction (§48)', () {
      final user = buildContentUserPrompt(
        languageName: 'Urdu',
        languageCode: 'ur',
        isRTL: true,
        scriptName: 'Nastaliq (Arabic)',
        conceptId: 'ur_ls_greetings',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: excerpt,
        learnerDigest: digest,
        kind: GeneratedContentKind.example,
        difficultyKnob: 2,
      );
      expect(user, contains('right-to-left'));
    });

    test('an empty excerpt tells the model to decline (§16)', () {
      const empty = TrustedKnowledgeExcerpt(
        languageCode: 'hi',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        vocabulary: [],
        exampleSentences: [],
        referenceText: '',
        isRTL: false,
        scriptCode: 'Deva',
      );
      final user = buildContentUserPrompt(
        languageName: 'Hindi',
        languageCode: 'hi',
        isRTL: false,
        scriptName: 'Devanagari',
        conceptId: 'hi_ls_greetings',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: empty,
        learnerDigest: digest,
        kind: GeneratedContentKind.explanation,
        difficultyKnob: 2,
      );
      expect(user, contains('TRUSTED VOCABULARY: (none available'));
      expect(user, contains('you must decline'));
    });
  });

  group('prompt → parser round shape', () {
    test('the schema pairs with the shared JSON extractor', () {
      final system = buildContentSystemPrompt(
        kind: GeneratedContentKind.explanation,
      );
      // The extractor tolerates fenced output of exactly this shape.
      final raw = '''
Sure! Here is the material:
```json
{"kind":"explanation","language":"hi","title":"t","body":"नमस्ते friend"}
```
''';
      final json = extractPlanJson(raw);
      expect(json, isNotNull);
      expect(json!['kind'], 'explanation');
      // The system prompt demanded the object-only contract; the parser
      // tolerates the violation without trusting it.
      expect(system, contains('No markdown, no code fences'));
    });
  });
}
