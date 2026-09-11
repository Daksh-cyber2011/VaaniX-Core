/// Generated Content Model + Validator — M5 tests.
///
/// Pins the §45/§46/§47/§48 validation gate: every rejection reason is
/// reachable, invalid material is DISCARDED (never fixed, never thrown),
/// anchors and ids are forced from the trusted request, the §47/§48
/// wrong-script guard holds, grounding follows the trusted excerpt, and
/// persisted JSON round-trips.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';

const _hiExcerpt = TrustedKnowledgeExcerpt(
  languageCode: 'hi',
  conceptId: 'hi_ls_greetings',
  lessonId: 'hi_ls_greetings',
  vocabulary: ['नमस्ते', 'दोस्त', 'शुभ'],
  exampleSentences: ['नमस्ते दोस्त'],
  referenceText: 'नमस्ते दोस्त',
  isRTL: false,
  scriptCode: 'Deva',
);

var _idCounter = 0;
String _freshId() => 'gen-test-${_idCounter++}';

Map<String, dynamic> _explanation({
  String kind = 'explanation',
  String? language = 'hi',
  String title = 'नमस्ते — a warm hello',
  String body = 'नमस्ते is how friends greet each other in Hindi.',
}) =>
    {
      'kind': kind,
      if (language != null) 'language': language,
      'title': title,
      'body': body,
    };

Map<String, dynamic> _validMcqExercise() => {
      'type': 'mcq',
      'prompt': 'Which word means नमस्ते?',
      'options': ['नमस्ते', 'शुभ'],
      'correctIndex': 0,
      'explanation': 'नमस्ते is the greeting.',
    };

void main() {
  group('kind + language gates', () {
    test('non-map input is malformed, never a throw', () {
      final v = GeneratedContentValidator.validate(
        raw: 'nope',
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.isValid, isFalse);
      expect(
        v.rejections,
        contains(GeneratedRejection.malformedOutput),
      );
    });

    test('unknown kind is unsupported', () {
      final v = GeneratedContentValidator.validate(
        raw: {
          'kind': 'poem',
          'title': 'x',
        },
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.unsupportedKind),
      );
    });

    test('a different kind than requested is unsupported', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(kind: 'example'),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.unsupportedKind),
      );
    });

    test('claiming another language is a mismatch (§14/§47)', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(language: 'bn'),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.languageMismatch),
      );
    });

    test('out-of-range difficulty is invalid', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 9,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.invalidDifficulty),
      );
    });
  });

  group('explanation kind', () {
    test('a grounded explanation passes and keeps the forced anchors', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.isValid, isTrue);
      expect(v.content!.kind, GeneratedContentKind.explanation);
      expect(v.content!.conceptId, 'hi_ls_greetings');
      expect(v.content!.lessonId, 'hi_ls_greetings');
      expect(v.content!.languageCode, 'hi');
      expect(v.content!.difficultyKnob, 2);
      expect(v.content!.body, isNotNull);
    });

    test('missing body is missingFields; oversized body is oversized', () {
      final empty = GeneratedContentValidator.validate(
        raw: _explanation(body: ''),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        empty.rejections,
        contains(GeneratedRejection.missingFields),
      );

      final huge = GeneratedContentValidator.validate(
        raw: _explanation(body: 'नमस्ते ' * 400),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(huge.rejections, contains(GeneratedRejection.oversized));
    });

    test('ungrounded text (no trusted token) is rejected (§45)', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(
            body: 'Completely unrelated filler words appear here.'),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.ungroundedContent),
      );
    });

    test('an empty excerpt grounds NOTHING (§16 fail-closed)', () {
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
      final v = GeneratedContentValidator.validate(
        raw: _explanation(),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: empty,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.ungroundedContent),
      );
    });
  });

  group('example kind', () {
    Map<String, dynamic> example({
      Object? lines = const [
        {'text': 'नमस्ते दोस्त', 'translation': 'Hello friend'},
      ],
    }) =>
        {
          'kind': 'example',
          'language': 'hi',
          'title': 'Two ways to say hello',
          'lines': lines,
        };

    test('grounded lines pass', () {
      final v = GeneratedContentValidator.validate(
        raw: example(),
        requestedKind: GeneratedContentKind.example,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.isValid, isTrue);
      expect(v.content!.lines, hasLength(1));
      expect(v.content!.lines.first.translation, 'Hello friend');
    });

    test('wrong-script target text is rejected (§47/§48)', () {
      final v = GeneratedContentValidator.validate(
        raw: example(lines: [
          {'text': ' totally latin text', 'translation': 'bad'},
        ]),
        requestedKind: GeneratedContentKind.example,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.rejections, contains(GeneratedRejection.wrongScript));
    });

    test('too many lines are oversized (§45 structure)', () {
      final v = GeneratedContentValidator.validate(
        raw: example(lines: [
          for (var i = 0; i < 9; i++)
            {'text': 'नमस्ते $i', 'translation': 'hello $i'},
        ]),
        requestedKind: GeneratedContentKind.example,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.rejections, contains(GeneratedRejection.oversized));
    });
  });

  group('practice kind', () {
    Map<String, dynamic> practice(Map<String, dynamic> exercise) => {
          'kind': 'practice',
          'language': 'hi',
          'title': 'Quick check',
          'exercise': exercise,
        };

    test('a valid mcq passes with FORCED trusted anchors + fresh id', () {
      final v = GeneratedContentValidator.validate(
        raw: practice(_validMcqExercise()),
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 3,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.isValid, isTrue);
      final exercise = v.content!.exercise!;
      expect(exercise.lessonId, 'hi_ls_greetings');
      expect(exercise.id, startsWith('gen-test-'));
      expect(exercise.isValid, isTrue);
      expect(exercise.type, ExerciseType.mcq);
    });

    test('ordering is NOT generatable (§15 supported set)', () {
      final v = GeneratedContentValidator.validate(
        raw: practice({
          'type': 'ordering',
          'prompt': 'नमस्ते order',
          'items': ['नमस्ते', 'दोस्त'],
          'explanation': 'order',
        }),
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(
        v.rejections,
        contains(GeneratedRejection.unsupportedExerciseType),
      );
    });

    test('missing explanation is missingFields (§45)', () {
      final v = GeneratedContentValidator.validate(
        raw: practice({
          'type': 'mcq',
          'prompt': 'Which word means नमस्ते?',
          'options': ['नमस्ते', 'शुभ'],
          'correctIndex': 0,
        }),
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.rejections, contains(GeneratedRejection.missingFields));
    });

    test('a broken exercise (correctIndex out of range) is invalid', () {
      final v = GeneratedContentValidator.validate(
        raw: practice({
          'type': 'mcq',
          'prompt': 'Which word means नमस्ते?',
          'options': ['नमस्ते', 'शुभ'],
          'correctIndex': 5,
          'explanation': 'नमस्ते is the greeting.',
        }),
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.rejections, contains(GeneratedRejection.invalidExercise));
    });

    test('translation without accepted answers is missingFields (§45)', () {
      final v = GeneratedContentValidator.validate(
        raw: practice({
          'type': 'translation',
          'prompt': 'Translate: नमस्ते दोस्त',
          'acceptedAnswers': <String>[],
          'explanation': 'नमस्ते दोस्त means hello friend.',
        }),
        requestedKind: GeneratedContentKind.practice,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      expect(v.rejections, contains(GeneratedRejection.missingFields));
    });
  });

  group('JSON round-trip', () {
    test('GeneratedContent survives toJson → fromJson unchanged', () {
      final v = GeneratedContentValidator.validate(
        raw: _explanation(),
        requestedKind: GeneratedContentKind.explanation,
        languageCode: 'hi',
        isRTL: false,
        scriptCode: 'Deva',
        conceptId: 'hi_ls_greetings',
        lessonId: 'hi_ls_greetings',
        difficultyKnob: 2,
        excerpt: _hiExcerpt,
        freshId: _freshId,
      );
      final content = v.content!;
      final restored = GeneratedContent.fromJson(content.toJson());
      expect(restored, isNotNull);
      expect(restored!.kind, content.kind);
      expect(restored.conceptId, content.conceptId);
      expect(restored.lessonId, content.lessonId);
      expect(restored.languageCode, content.languageCode);
      expect(restored.title, content.title);
      expect(restored.body, content.body);
    });

    test('malformed JSON degrades to null, never a throw', () {
      expect(GeneratedContent.fromJson(const {'kind': 'nonsense'}), isNull);
      expect(GeneratedContent.fromJson(const {'kind': 'example'}), isNull);
    });
  });
}
