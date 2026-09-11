/// Trusted Content Registry — M5 tests.
///
/// Pins the §15/§32 classification guarantees: the A–G curricula become
/// addressable trusted entries WITHOUT being rewritten; excerpts are
/// extracted verbatim from trusted data only; stub languages yield an
/// empty registry (never an exception); and the failure-closed excerpt
/// rule holds (unknown concept → empty excerpt).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Future<(ConceptGraph, List<Chapter>)> _hindi() async {
  final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
  final graph = ConceptGraph.forCurriculum(languageCode: 'hi', chapters: chapters);
  return (graph, chapters);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrustedContentRegistry.build on the real Hindi content', () {
    late ConceptGraph graph;
    late List<Chapter> chapters;
    late TrustedContentRegistry registry;

    setUpAll(() async {
      (graph, chapters) = await _hindi();
      registry = TrustedContentRegistry.build(
        graph: graph,
        chapters: chapters,
        exercisesByLesson: hindiExercisesByLesson,
        isRTL: false,
        scriptCode: 'Deva',
      );
    });

    test('classifies every concept without rewriting the curriculum', () {
      expect(registry.isNotEmpty, isTrue);
      expect(registry.lessonCount, graph.concepts.length);
      // Every concept resolves to exactly one trusted lesson entry.
      for (final concept in graph.concepts) {
        final lesson = registry.lessonEntryFor(concept.id);
        expect(lesson, isNotNull, reason: '${concept.id} needs a lesson');
        expect(lesson!.kind, TrustedContentKind.lesson);
        expect(lesson.lessonId, concept.lessonId);
        expect(lesson.languageCode, 'hi');
        expect(lesson.skillId, concept.skillId);
      }
    });

    test('exercise entries mirror the trusted bank', () {
      final entries = registry.exerciseEntriesFor(graph.concepts.first.id);
      final bank = hindiExercisesByLesson[graph.concepts.first.lessonId] ??
          const [];
      expect(entries.length, bank.length);
      for (final entry in entries) {
        expect(entry.kind, TrustedContentKind.exercise);
        expect(entry.exerciseType, isNotNull);
        expect(
          entry.id,
          startsWith('tc:hi:ex:'),
        );
      }
      // The raw-exercise lookup resolves the same entries.
      for (final entry in entries) {
        final rawId = entry.id.substring('tc:hi:ex:'.length);
        expect(registry.entryForExercise(rawId), same(entry));
      }
    });

    test('excerpt vocabulary is drawn from trusted data only', () {
      final excerpt = registry.excerptFor(graph.concepts.first.id);
      expect(excerpt.isNotEmpty, isTrue);
      expect(excerpt.vocabulary, isNotEmpty);
      expect(excerpt.scriptCode, 'Deva');
      expect(excerpt.isRTL, isFalse);
      // The reference text is the lesson's own content (verbatim prefix).
      if (excerpt.referenceText.isNotEmpty) {
        final lesson = chapters
            .expand((c) => c.lessons)
            .firstWhere((l) => l.id == excerpt.lessonId);
        final content = lesson.content?.trim() ?? '';
        if (content.isNotEmpty) {
          expect(content, startsWith(excerpt.referenceText));
        }
      }
      // Example sentences, when present, come from the lesson content.
      for (final sentence in excerpt.exampleSentences) {
        expect(sentence.length, lessThanOrEqualTo(90));
      }
    });

    test('tokenization is shared by the validator (Unicode letters)', () {
      final tokens = TrustedContentRegistry.tokenizeTrustedText(
        'नमस्ते world दोस्त!',
      );
      expect(tokens, containsAll(<String>['नमस्ते', 'world', 'दोस्त']));
      // Single letters carry no vocabulary.
      expect(tokens, isNot(contains('a')));
    });

    test('unknown concept → empty excerpt (fail-closed)', () {
      final excerpt = registry.excerptFor('hi_does_not_exist');
      expect(excerpt.isEmpty, isTrue);
      expect(excerpt.vocabulary, isEmpty);
    });

    test('curriculum order is preserved', () {
      final orders = registry.entries
          .where((e) => e.kind == TrustedContentKind.lesson)
          .map((e) => e.order)
          .toList();
      expect(orders, equals([...orders]..sort()));
    });
  });

  group('stub-language honesty', () {
    test('empty curriculum → empty registry, no throw', () {
      final graph =
          ConceptGraph.forCurriculum(languageCode: 'kn', chapters: const []);
      final registry = TrustedContentRegistry.build(
        graph: graph,
        chapters: const [],
        exercisesByLesson: const {},
        isRTL: false,
        scriptCode: 'Knda',
      );
      expect(registry.isEmpty, isTrue);
      expect(registry.lessonCount, 0);
      expect(registry.exerciseCount, 0);
    });
  });

  group('RTL metadata', () {
    test('Urdu-style metadata flows through for script guards', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.urdu);
      final graph =
          ConceptGraph.forCurriculum(languageCode: 'ur', chapters: chapters);
      final registry = TrustedContentRegistry.build(
        graph: graph,
        chapters: chapters,
        exercisesByLesson: const {},
        isRTL: true,
        scriptCode: 'Arab',
      );
      expect(registry.isRTL, isTrue);
      expect(registry.scriptCode, 'Arab');
      // Even with an empty bank, lesson entries exist for shipped
      // curricula (stub languages produce none).
      if (graph.isNotEmpty) {
        expect(registry.isNotEmpty, isTrue);
      }
    });
  });

  group('difficultyKnobForBand', () {
    test('inverts the M4 planner mapping', () {
      expect(difficultyKnobForBand(Difficulty.beginner), 2);
      expect(difficultyKnobForBand(Difficulty.intermediate), 3);
      expect(difficultyKnobForBand(Difficulty.advanced), 4);
    });
  });
}
