/// TEMPORARY cross-audit instrumentation — DELETE BEFORE FINISH.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';

Exercise _mcq(String id, String lessonId) => Exercise(
      id: id,
      lessonId: lessonId,
      type: ExerciseType.mcq,
      prompt: 'Pick the right one ($id)',
      options: const ['alpha', 'beta', 'gamma'],
      correctIndex: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('INSTRUMENT ladder reservation state', () {
    final engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: ActivityKind.practice,
        languageCode: 'hi',
        pools: [
          SessionExercisePool(conceptId: 'a', exercises: [
            _mcq('ex-a1', 'lesson-a'),
            _mcq('ex-a2', 'lesson-a'),
            _mcq('ex-a3', 'lesson-a'),
            _mcq('ex-a4', 'lesson-a'),
          ]),
          SessionExercisePool(
              conceptId: 'p', exercises: [_mcq('ex-p1', 'lesson-p')]),
        ],
        explanations: const {'a': 'Refresher text for concept a.'},
        prerequisiteOf: const {'a': 'p'},
      ),
    );
    // ignore: avoid_print
    print('A: initial current=${engine.currentStep!.exercise!.id}');
    engine.submitAnswer(correct: false, firstTry: true);
    engine.advance();
    // ignore: avoid_print
    print('B: current=${engine.currentStep!.exercise!.id}');
    engine.submitAnswer(correct: false, firstTry: true);
    engine.advance();
    final step = engine.currentStep!;
    // ignore: avoid_print
    print(
        'C: after 2 wrongs: isSupport=${step.isSupport} presentation=${step.presentation} '
        'exercise=${step.exercise?.id} concept=${step.conceptId}');
  });

  test('INSTRUMENT diagnostic script pool at seed 5', () async {
    final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
    final graph =
        ConceptGraph.forCurriculum(languageCode: 'hi', chapters: chapters);
    final bank = DiagnosticItemBank.build(
      graph: graph,
      exercisesByLesson: hindiExercisesByLesson,
      seed: 5,
    );
    final engine = DiagnosticEngine(bank: bank, seedLevel: 4);
    final missed = engine.currentItem!;
    // ignore: avoid_print
    print('D: missed probe id=${missed.exercise.id} dim=${missed.dimension} '
        'difficulty=${missed.probe.difficulty} concept=${missed.probe.conceptId} '
        'conceptOrder=${missed.conceptOrder}');

    final all = bank.itemsAnyBand(DiagnosticDimension.script,
        excludeIds: engine.answerRecords.map((r) => r.probeId).toSet());
    // ignore: avoid_print
    print('E: script pool total=${all.length}');
    for (final item in all.take(12)) {
      // ignore: avoid_print
      print('   script item id=${item.exercise.id} order=${item.conceptOrder} '
          'band=${item.probe.difficulty} concept=${item.probe.conceptId}');
    }
    final earlier =
        all.where((c) => c.conceptOrder < missed.conceptOrder).toList();
    // ignore: avoid_print
    print('F: earlier-candidate count=${earlier.length}');

    // Also: which script concepts exist at all, with band composition?
    final byBand = <String, int>{};
    for (final item in all) {
      byBand[item.probe.difficulty.name] =
          (byBand[item.probe.difficulty.name] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('G: script band composition=$byBand');
    // raw (unshuffled, unfiltered) view via a fresh bank with seed 0 isn't needed;
    // print chapter order distribution:
    final orders = all.map((i) => i.conceptOrder).toSet().toList()..sort();
    // ignore: avoid_print
    print('H: distinct script conceptOrders=$orders');
    engine.recordAnswer(false);
    engine.advance();
    final followUp = engine.currentItem!;
    // ignore: avoid_print
    print('I: followUp dim=${followUp.dimension} id=${followUp.exercise.id}');
  });
}
