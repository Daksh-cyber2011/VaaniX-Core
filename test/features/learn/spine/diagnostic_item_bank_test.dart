/// Diagnostic Item Bank — M3 trusted-pool tests.
///
/// Pins the honesty guarantees of the probe bank: probes come ONLY from
/// the trusted exercise banks mapped onto the concept graph; only the
/// dimensions A–G can actually measure appear (no listening, no faked
/// comprehension); classification follows the verified chapter themes;
/// and an empty curriculum yields an empty bank (stub languages).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/bengali_exercises.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Future<ConceptGraph> _hindiGraph() async {
  final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
  return ConceptGraph.forCurriculum(languageCode: 'hi', chapters: chapters);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyDiagnosticDimension', () {
    test('type rules take precedence (forward-compatible)', () {
      // Ordering is production no matter the chapter…
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 0, type: ExerciseType.ordering),
        DiagnosticDimension.sentenceFormation,
      );
      // …and fill-in-the-blank is grammar.
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 4, type: ExerciseType.fillBlank),
        DiagnosticDimension.grammar,
      );
    });

    test('A–G chapter themes map to the verified dimensions', () {
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 0, type: ExerciseType.mcq),
        DiagnosticDimension.script,
      );
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 1, type: ExerciseType.matching),
        DiagnosticDimension.practical,
      );
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 2, type: ExerciseType.mcq),
        DiagnosticDimension.vocabulary,
      );
      // Production in the daily-life chapter builds sentences.
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 2, type: ExerciseType.translation),
        DiagnosticDimension.sentenceFormation,
      );
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 3, type: ExerciseType.mcq),
        DiagnosticDimension.grammar,
      );
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 4, type: ExerciseType.mcq),
        DiagnosticDimension.reading,
      );
      expect(
        classifyDiagnosticDimension(
            chapterOrder: 4, type: ExerciseType.translation),
        DiagnosticDimension.sentenceFormation,
      );
    });
  });

  group('DiagnosticItemBank.build on the real Hindi content', () {
    late ConceptGraph graph;
    late DiagnosticItemBank bank;

    setUpAll(() async {
      graph = await _hindiGraph();
      bank = DiagnosticItemBank.build(
        graph: graph,
        exercisesByLesson: hindiExercisesByLesson,
        seed: 7,
      );
    });

    test('measures exactly the six testable dimensions, priority-ordered',
        () {
      expect(bank.isNotEmpty, isTrue);
      expect(bank.activeDimensions, [
        DiagnosticDimension.script,
        DiagnosticDimension.vocabulary,
        DiagnosticDimension.grammar,
        DiagnosticDimension.sentenceFormation,
        DiagnosticDimension.reading,
        DiagnosticDimension.practical,
      ]);
    });

    test('never fabricates unmeasurable dimensions', () {
      // No audio exists → no listening. No long-form passages → no
      // comprehension claim. (Master Brief §11.)
      expect(bank.activeDimensions.contains(DiagnosticDimension.listening),
          isFalse);
      expect(
          bank.activeDimensions
              .contains(DiagnosticDimension.comprehension),
          isFalse);
    });

    test('every pool is non-empty and probes are trusted content', () {
      for (final dimension in bank.activeDimensions) {
        final items = bank.itemsAnyBand(dimension);
        expect(items, isNotEmpty, reason: '$dimension pool must exist');
        for (final item in items) {
          expect(item.exercise.isValid, isTrue,
              reason: 'only well-formed exercises may become probes');
          expect(item.probe.conceptId, isNotNull);
          // The probe must resolve back to a real graph concept.
          expect(graph.conceptById(item.probe.conceptId!), isNotNull);
          // Probe descriptor mirrors the resolved exercise.
          expect(item.probe.id, item.exercise.id);
          expect(item.probe.dimension, item.dimension);
        }
      }
    });

    test('probe ids are unique across the whole bank', () {
      final ids = <String>{};
      for (final dimension in bank.activeDimensions) {
        for (final item in bank.itemsAnyBand(dimension)) {
          expect(ids.add(item.exercise.id), isTrue,
              reason: 'duplicate probe id ${item.exercise.id}');
        }
      }
    });

    test('script pool is substantial (chapter 1 is the gateway)', () {
      expect(bank.itemsAnyBand(DiagnosticDimension.script).length,
          greaterThanOrEqualTo(10));
    });

    test('itemsAt honours the exclusion set (no repeat asks)', () {
      final all = bank.itemsAnyBand(DiagnosticDimension.script);
      final excluded = {all.first.exercise.id, all.last.exercise.id};
      final filtered = bank.itemsAnyBand(
        DiagnosticDimension.script,
        excludeIds: excluded,
      );
      expect(filtered.length, all.length - 2);
      for (final item in filtered) {
        expect(excluded.contains(item.exercise.id), isFalse);
      }
    });
  });

  group('DiagnosticItemBank.build on other shipped languages', () {
    test('Bengali builds the same six-dimension shape', () async {
      final chapters = await loadLearnCurriculum(LearnLanguage.bengali);
      final graph = ConceptGraph.forCurriculum(
          languageCode: 'bn', chapters: chapters);
      final bank = DiagnosticItemBank.build(
        graph: graph,
        exercisesByLesson: bengaliExercisesByLesson,
      );
      expect(bank.activeDimensions.length, 6);
      expect(
        bank.itemsAnyBand(DiagnosticDimension.script),
        isNotEmpty,
      );
    });
  });

  group('empty-curriculum honesty', () {
    test('stub language → empty bank, no dimensions', () {
      final graph = ConceptGraph.forCurriculum(
          languageCode: 'kn', chapters: const []);
      final bank = DiagnosticItemBank.build(
        graph: graph,
        exercisesByLesson: const {},
      );
      expect(bank.isEmpty, isTrue);
      expect(bank.activeDimensions, isEmpty);
      expect(bank.remainingCount(), 0);
    });
  });

  group('reshuffled', () {
    test('keeps the same trusted pools but changes the walk order',
        () async {
      final graph = await _hindiGraph();
      final base = DiagnosticItemBank.build(
        graph: graph,
        exercisesByLesson: hindiExercisesByLesson,
        seed: 1,
      );

      final a = base.reshuffled(11);
      final b = base.reshuffled(12);

      final scriptA = a.itemsAt(DiagnosticDimension.script,
          Difficulty.beginner);
      final scriptB = b.itemsAt(DiagnosticDimension.script,
          Difficulty.beginner);

      // Same content…
      expect(
        scriptA.map((i) => i.exercise.id).toSet(),
        scriptB.map((i) => i.exercise.id).toSet(),
      );
      // …different deterministic order (two LCG seeds colliding on a
      // 10+ item pool is vanishingly unlikely).
      expect(
        scriptA.map((i) => i.exercise.id).toList(),
        isNot(scriptB.map((i) => i.exercise.id).toList()),
      );
    });
  });
}
