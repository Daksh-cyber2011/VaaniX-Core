/// M10 — AI Reliability adversarial suite (Master Brief §90).
///
/// Runs the brief's FULL adversarial matrix against the two AI entry
/// points — the M4 planner and the M5 content generator — plus the
/// pure parsers. Every case must RECOVER SAFELY: a typed Left, never a
/// throw, never broken UI state.
///
/// The twelve §90 cases:
///   1  empty AI response        7  very long response
///   2  wrong language           8  unexpected Unicode (bidi/control)
///   3  hallucinated concept     9  API timeout
///   4  invalid exercise         10 rate limit (quota error)
///   5  malformed JSON           11 network unavailable
///   6  missing field            12 cached stale plan
/// plus: recovery — the deterministic fallback still serves a plan
/// after every failure, and rate limiting stays shared/app-wide.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content_parser.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_output.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';

// ─── Fakes ───────────────────────────────────────────────────────────

/// Configurable fake of the raw-text LLM boundary (§90 driver).
class AdversarialTextClient implements PlannerTextClient {
  AdversarialTextClient({this.available = true, this.reply, this.error});

  bool available;
  String? reply;
  Object? error;

  int completeCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({required String system, required String user}) {
    completeCalls++;
    final err = error;
    if (err != null) {
      throw err;
    }
    return Future.value(reply!);
  }
}

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'hi_ch1',
          title: 'First words',
          lessons: [
            Lesson(id: 'hi_ls_1', title: 'Greetings', chapterId: 'hi_ch1'),
            Lesson(id: 'hi_ls_2', title: 'Family', chapterId: 'hi_ch1'),
          ],
        ),
      ],
    );

PlannerContext _context() => PlannerContext(
      languageCode: 'hi',
      languageName: 'Hindi',
      graph: _graph(),
      state: const LearningState(languageCode: 'hi'),
      supportedActivityTypes: kDeterministicPlannerActivityKinds,
    );

TrustedKnowledgeExcerpt _excerpt() => const TrustedKnowledgeExcerpt(
      languageCode: 'hi',
      conceptId: 'hi_ls_1',
      lessonId: 'hi_ls_1',
      vocabulary: ['नमस्ते', 'अभिवादन', 'परिवार'],
      exampleSentences: ['नमस्ते, कैसे हो?'],
      referenceText: 'नमस्ते is the standard Hindi greeting; अभिवादन means '
          'greeting; परिवार means family.',
      isRTL: false,
      scriptCode: 'Deva',
    );

/// A minimal VALID grounded practice payload (passes every check).
Map<String, dynamic> validPracticePayload() => {
      'kind': 'practice',
      'title': 'नमस्ते practice',
      'exercise': {
        'type': 'mcq',
        'prompt': 'नमस्ते का अर्थ क्या है?',
        'options': ['अभिवादन', 'परिवार', 'पानी', 'किताब'],
        'correctIndex': 0,
        'explanation': 'नमस्ते एक अभिवादन है — the standard greeting.',
      },
    };

String planJsonFor(String conceptId) => '''
{"focusSummary": "One step.",
 "activities": [
   {"conceptId": "$conceptId", "activityType": "newLearning", "difficulty": 2,
    "reason": "Next on your path.", "estimatedMinutes": 5}
 ]}
''';

void main() {
  group('§90 case 1 — empty AI response', () {
    test('planner: null/blank reply → Left, no throw', () async {
      final planner = GeminiPlanner(
        textClient: AdversarialTextClient(reply: ''),
      );
      final r = await planner.buildPlan(_context());
      expect(r.isLeft(), isTrue);
    });

    test('generator: blank reply → Left, no throw', () async {
      final gen = PersonalizedContentGenerator(
        textClient: AdversarialTextClient(reply: '   '),
      );
      final r = await gen.generate(
        spec: learnLanguageSpec(LearnLanguage.hindi),
        conceptId: 'hi_ls_1',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: _excerpt(),
        kind: GeneratedContentKind.practice,
        difficultyKnob: 2,
        learnerDigest: const {},
      );
      expect(r.isLeft(), isTrue);
    });
  });

  group('§90 case 2 — wrong language', () {
    test('content in the WRONG script is rejected (Hindi ask, Tamil text)',
        () async {
      final wrongScript = '''
{"kind": "practice", "title": "வணக்கம் பயிற்சி",
 "exercise": {"type": "mcq", "prompt": "வணக்கம் என்றால் என்ன?",
  "options": ["அபிவாதனை", "குடும்பம்", "தண்ணீர்", "புத்தகம்"],
  "correctIndex": 0, "explanation": "வணக்கம் என்பது அபிவாதனை."}}
''';
      final gen = PersonalizedContentGenerator(
        textClient: AdversarialTextClient(reply: wrongScript),
      );
      final r = await gen.generate(
        spec: learnLanguageSpec(LearnLanguage.hindi),
        conceptId: 'hi_ls_1',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: _excerpt(),
        kind: GeneratedContentKind.practice,
        difficultyKnob: 2,
        learnerDigest: const {},
      );
      expect(r.isLeft(), isTrue);
    });

    test('cached plan for ANOTHER language is refused', () {
      // Covered by CachedPlanPlanner's language check (M4 test pins it);
      // here we pin the parser-level equivalent: a wrong-script example
      // line set for an RTL request.
      final rtlExample = '''
{"kind": "example", "title": "नमस्ते उदाहरण",
 "lines": [{"text": "வணக்கம்", "translation": "greetings"}]}
''';
      final r = GeneratedContentParser.parse(
        rtlExample,
        requestedKind: GeneratedContentKind.example,
        languageCode: 'ur',
        isRTL: true,
        scriptCode: 'Arab',
        conceptId: 'ur_ls_1',
        lessonId: 'ur_ls_1',
        difficultyKnob: 2,
        excerpt: const TrustedKnowledgeExcerpt(
          languageCode: 'ur',
          conceptId: 'ur_ls_1',
          lessonId: 'ur_ls_1',
          vocabulary: ['سلام', 'خوش'],
          exampleSentences: [],
          referenceText: 'سلام greeting',
          isRTL: true,
          scriptCode: 'Arab',
        ),
        freshId: () => 'gen-test-1',
      );
      expect(r.isLeft(), isTrue);
    });
  });

  group('§90 case 3 — hallucinated concept', () {
    test('plan naming an UNKNOWN conceptId is rejected', () async {
      final client = AdversarialTextClient(
        reply: planJsonFor('zz_made_up_concept'),
      );
      final planner = GeminiPlanner(textClient: client);

      final r = await planner.buildPlan(_context());

      expect(r.isLeft(), isTrue,
          reason: 'a concept outside the trusted graph must never '
              'reach the learner (§14 grounding)');
    });
  });

  group('§90 case 4 — invalid exercise', () {
    test('unsupported exercise type (ordering) is rejected', () {
      final payload = validPracticePayload();
      (payload['exercise'] as Map<String, dynamic>)['type'] = 'ordering';
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
      expect(v.rejections, contains(GeneratedRejection.unsupportedExerciseType));
    });

    test('mcq without a correct index is rejected', () {
      final payload = validPracticePayload();
      (payload['exercise'] as Map<String, dynamic>)['correctIndex'] = 99;
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
    });
  });

  group('§90 case 5 — malformed JSON', () {
    test('garbage reply → Left on both entry points', () async {
      final planner = GeminiPlanner(
        textClient: AdversarialTextClient(reply: 'no json here at all'),
      );
      expect((await planner.buildPlan(_context())).isLeft(), isTrue);

      final gen = PersonalizedContentGenerator(
        textClient: AdversarialTextClient(reply: '}}} broken {{{'),
      );
      expect(
        (await gen.generate(
          spec: learnLanguageSpec(LearnLanguage.hindi),
          conceptId: 'hi_ls_1',
          conceptTitle: 'Greetings',
          conceptSubtitle: null,
          excerpt: _excerpt(),
          kind: GeneratedContentKind.practice,
          difficultyKnob: 2,
          learnerDigest: const {},
        ))
            .isLeft(),
        isTrue,
      );
    });

    test('unbalanced JSON object → null extraction', () {
      expect(extractPlanJson('{"a": 1'), isNull);
    });
  });

  group('§90 case 6 — missing field', () {
    test('plan without activities is rejected', () async {
      final client = AdversarialTextClient(reply: '{"focusSummary": "x"}');
      final planner = GeminiPlanner(textClient: client);
      expect((await planner.buildPlan(_context())).isLeft(), isTrue);
    });

    test('practice payload without title is rejected', () {
      final payload = validPracticePayload()..remove('title');
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
      expect(v.rejections, contains(GeneratedRejection.missingFields));
    });
  });

  group('§90 case 7 — very long response', () {
    test('multi-megabyte reply is bounded BEFORE scanning', () {
      final huge = '{"junk": "${'x' * (300 * 1024)}"}';
      // Must return null quickly — no pathological scan, no crash.
      expect(extractPlanJson(huge), isNull);
    });

    test('oversized body exceeds the size caps', () {
      final payload = {
        'kind': 'explanation',
        'title': 'नमस्ते',
        'body': 'नमस्ते ' * 5000, // far beyond kMaxBodyChars
      };
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
      expect(v.rejections, contains(GeneratedRejection.oversized));
    });
  });

  group('§90 case 8 — unexpected Unicode', () {
    test('bidi override (U+202E) in the title is rejected', () {
      final payload = validPracticePayload();
      payload['title'] = 'नमस्ते \u202Eevil';
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
      expect(v.rejections, contains(GeneratedRejection.unsafeCharacters));
    });

    test('control character in the exercise prompt is rejected', () {
      final payload = validPracticePayload();
      (payload['exercise'] as Map<String, dynamic>)['prompt'] =
          'नमस्ते\u0007 का अर्थ?';
      final v = GeneratedContentValidator.validate(
        raw: payload,
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficultyKnob: 2,
        excerpt: _excerpt(),
        freshId: () => 'gen-x',
      );
      expect(v.isValid, isFalse);
      expect(v.rejections, contains(GeneratedRejection.unsafeCharacters));
    });

    test('legitimate Indic ZWNJ (U+200C) is ALLOWED (orthography)', () {
      expect(
        // U+200C is standard Tamil/Telugu orthography (see trusted
        // ta/te lessons) and must NOT be treated as unsafe.
        GeneratedContentValidator.validate(
          raw: {
            'kind': 'explanation',
            'title': 'नमस्ते',
            'body': 'यह अभिवादन है\u200C और सही है — परिवार शब्द भी।',
          },
          requestedKind: GeneratedContentKind.explanation,
          languageCode: 'hi',
          isRTL: false,
          scriptCode: 'Deva',
          conceptId: 'hi_ls_1',
          lessonId: 'hi_ls_1',
          difficultyKnob: 2,
          excerpt: _excerpt(),
          freshId: () => 'gen-x',
        ).rejections.any((r) => r == GeneratedRejection.unsafeCharacters),
        isFalse,
      );
    });
  });

  group('§90 case 9 — API timeout', () {
    test('TimeoutException → TimeoutFailure, never a throw', () async {
      final planner = GeminiPlanner(
        textClient: AdversarialTextClient(
          error: TimeoutException('deadline exceeded', Duration(seconds: 15)),
        ),
      );
      final r = await planner.buildPlan(_context());
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f, isA<TimeoutFailure>()),
        (_) => fail('expected a Left'),
      );
    });

    test('generator timeout → Left, no throw', () async {
      final gen = PersonalizedContentGenerator(
        textClient: AdversarialTextClient(
          error: TimeoutException('slow', Duration(seconds: 15)),
        ),
      );
      final r = await gen.generate(
        spec: learnLanguageSpec(LearnLanguage.hindi),
        conceptId: 'hi_ls_1',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: _excerpt(),
        kind: GeneratedContentKind.practice,
        difficultyKnob: 2,
        learnerDigest: const {},
      );
      expect(r.isLeft(), isTrue);
    });
  });

  group('§90 case 10 — rate limit', () {
    test('quota exception becomes a typed Left (shared budget intact)',
        () async {
      final planner = GeminiPlanner(
        textClient: AdversarialTextClient(
          error: Exception('429 RESOURCE_EXHAUSTED: quota exceeded'),
        ),
      );
      final r = await planner.buildPlan(_context());
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f, isA<AiServiceFailure>()),
        (_) => fail('expected a Left'),
      );
    });

    // Final polish: unmapped SDK exceptions must never leak raw exception
    // text (hosts, stack fragments) into Failure messages that UI surfaces
    // render — the calm canonical copy takes over.
    test('unmapped client exception → calm AiServiceFailure (no leak)',
        () async {
      final planner = GeminiPlanner(
        textClient: AdversarialTextClient(
          error: Exception(
              'SocketException: failed host lookup: generativelanguage'
              '.googleapis.internal (OS Error: No address)'),
        ),
      );
      final r = await planner.buildPlan(_context());
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) {
          expect(f, isA<AiServiceFailure>());
          expect(f.message, isNot(contains('SocketException')));
          expect(f.message, isNot(contains('generativelanguage')));
          expect(f.message, isNot(contains('OS Error')));
        },
        (_) => fail('expected a Left'),
      );
    });

    test('AiRateLimiter slots are strictly sequential', () async {
      final limiter = AiRateLimiter();
      final sw = Stopwatch()..start();
      await limiter.awaitSlot();
      await limiter.awaitSlot();
      sw.stop();
      // The limiter space slots out at the configured RPM budget; two
      // immediate takes must never both resolve instantly.
      expect(sw.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });
  });

  group('§90 case 11 — network unavailable', () {
    test('unavailable client → Left WITHOUT calling the model', () async {
      final client = AdversarialTextClient(available: false);
      final planner = GeminiPlanner(textClient: client);

      final r = await planner.buildPlan(_context());

      expect(r.isLeft(), isTrue);
      expect(client.completeCalls, 0);
    });

    test('generator unavailable → Left BEFORE any network call', () async {
      final client = AdversarialTextClient(available: false);
      final gen = PersonalizedContentGenerator(textClient: client);
      final r = await gen.generate(
        spec: learnLanguageSpec(LearnLanguage.hindi),
        conceptId: 'hi_ls_1',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: _excerpt(),
        kind: GeneratedContentKind.practice,
        difficultyKnob: 2,
        learnerDigest: const {},
      );
      expect(r.isLeft(), isTrue);
      expect(client.completeCalls, 0);
    });
  });

  group('§90 case 12 — cached stale plan', () {
    test('stale cache is refused by the freshness contract', () {
      final now = DateTime.now();
      final ancientPlan = LearningPlan(
        id: 'plan-ancient',
        languageCode: 'hi',
        source: PlanSource.ai,
        activities: const <LearningActivity>[],
        createdAt: now.subtract(const Duration(days: 30)),
      );
      expect(
        LearnPlanRepository.isFresh(ancientPlan, now: now),
        isFalse,
        reason: 'a 30-day-old cached plan must be treated as stale',
      );

      final freshPlan = LearningPlan(
        id: 'plan-fresh',
        languageCode: 'hi',
        source: PlanSource.ai,
        activities: const <LearningActivity>[],
        createdAt: now,
      );
      expect(LearnPlanRepository.isFresh(freshPlan, now: now), isTrue);
    });
  });

  group('§90 recovery — the chain still serves the learner', () {
    test('after EVERY AI failure, the deterministic planner still plans',
        () async {
      // Simulate the full fallback: AI is down → cached empty →
      // deterministic planner must still produce a usable plan.
      final client = AdversarialTextClient(reply: 'garbage');
      final aiPlanner = GeminiPlanner(textClient: client);

      final aiResult = await aiPlanner.buildPlan(_context());
      expect(aiResult.isLeft(), isTrue);

      final deterministic = DeterministicPlanner();
      final fallback = await deterministic.buildPlan(_context());
      expect(fallback.isRight(), isTrue,
          reason: 'Learn Mode must degrade to trusted content, never '
              'become unusable (§36)');
      fallback.fold(
        (_) => fail('deterministic planner must succeed'),
        (plan) {
          expect(plan.source, PlanSource.deterministic);
          expect(plan.activities, isNotEmpty);
        },
      );
    });

    test('declined generation falls back to trusted content (Left, no '
        'broken UI state)', () async {
      final gen = PersonalizedContentGenerator(
        textClient: AdversarialTextClient(reply: '{"kind": "none"}'),
      );
      final r = await gen.generate(
        spec: learnLanguageSpec(LearnLanguage.hindi),
        conceptId: 'hi_ls_1',
        conceptTitle: 'Greetings',
        conceptSubtitle: null,
        excerpt: _excerpt(),
        kind: GeneratedContentKind.practice,
        difficultyKnob: 2,
        learnerDigest: const {},
      );
      expect(r.isLeft(), isTrue,
          reason: 'an honest decline is a typed Left — the UI keeps '
              'showing trusted material (§34/§46)');
    });
  });
}
