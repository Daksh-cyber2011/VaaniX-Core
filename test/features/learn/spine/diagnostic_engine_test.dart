/// Diagnostic Engine — M3 adaptive strategy tests.
///
/// Pins the Master Brief §12 difficulty strategy on the REAL Hindi bank:
///   - baseline probe first, seeded from the self-report level;
///   - two correct in a row → the level estimate moves up;
///   - a miss → the level estimate moves down AND the next probe is a
///     prerequisite of the missed item (same dimension, earlier concept);
///   - the run stops within the 8–16 probe budget with per-dimension
///     coverage, or honestly earlier when pools run dry;
///   - results are truthful (first-try scores, no fabricated dimensions,
///     friendly summary carries no raw numbers);
///   - the whole run is deterministic for a fixed seed + answer script.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';

Future<DiagnosticItemBank> _hindiBank(int seed) async {
  final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
  final graph = ConceptGraph.forCurriculum(
      languageCode: 'hi', chapters: chapters);
  return DiagnosticItemBank.build(
    graph: graph,
    exercisesByLesson: hindiExercisesByLesson,
    seed: seed,
  );
}

/// Drives a full run with a fixed answer script; returns the engine.
Future<DiagnosticEngine> _run({
  required int seed,
  required bool Function(int askedIndex) answerScript,
  int seedLevel = 0,
}) async {
  final bank = await _hindiBank(seed);
  final engine = DiagnosticEngine(bank: bank, seedLevel: seedLevel);
  var asked = 0;
  while (!engine.isFinished) {
    engine.recordAnswer(answerScript(asked));
    engine.advance();
    asked++;
    expect(asked, lessThanOrEqualTo(DiagnosticEngine.kMaxProbes + 1),
        reason: 'engine must respect its own probe budget');
  }
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('baseline and seeding', () {
    test('first probe is a script probe (the gateway dimension)', () async {
      final bank = await _hindiBank(3);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 0);
      expect(engine.currentItem, isNotNull);
      expect(engine.currentItem!.dimension, DiagnosticDimension.script);
      expect(engine.isFinished, isFalse);
      expect(engine.askedCount, 0);
    });

    test('self-report seeds the difficulty track, never the result',
        () async {
      final bank = await _hindiBank(3);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 2);
      expect(engine.levelTrack, 2,
          reason: 'the track starts from the self-report hint');
      // The result is only derived from ANSWERED probes — before any
      // answer, buildResult would have no measured dimension at all.
      expect(engine.answerRecords, isEmpty);
    });
  });

  group('§12 difficulty strategy', () {
    test('two consecutive correct move the track up', () async {
      final bank = await _hindiBank(5);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 0);

      expect(engine.levelTrack, 0);
      engine.recordAnswer(true);
      engine.advance();
      expect(engine.levelTrack, 0, reason: 'one correct is not enough');
      engine.recordAnswer(true);
      engine.advance();
      expect(engine.levelTrack, 1);
    });

    test('a miss moves the track down and serves a prerequisite probe',
        () async {
      final bank = await _hindiBank(5);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 4);
      expect(engine.levelTrack, 4);

      final missed = engine.currentItem!;
      engine.recordAnswer(false);
      expect(engine.levelTrack, 3);
      engine.advance();

      final followUp = engine.currentItem!;
      expect(followUp.dimension, missed.dimension,
          reason: 'the prerequisite probe stays in the missed dimension');
      expect(followUp.conceptOrder, lessThan(missed.conceptOrder),
          reason: 'it must be an EARLIER concept — a true prerequisite');
    });

    test('consecutive-correct counting resets after a miss', () async {
      final bank = await _hindiBank(5);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 0);
      engine.recordAnswer(true);
      engine.advance();
      engine.recordAnswer(false);
      engine.advance();
      expect(engine.levelTrack, 0, reason: 'up-then-down lands back at 0');
      engine.recordAnswer(true);
      engine.advance();
      expect(engine.levelTrack, 0, reason: 'streak was broken — no bump');
      engine.recordAnswer(true);
      engine.advance();
      expect(engine.levelTrack, 1);
    });
  });

  group('full runs on the real bank', () {
    test('a perfect learner reaches the top with clean scores', () async {
      final engine = await _run(seed: 11, answerScript: (_) => true);

      expect(engine.askedCount, 12,
          reason: 'six measurable dimensions × 2 probes each');
      final result = engine.buildResult(language: LearnLanguage.hindi);
      expect(result.overallLevel, 4);
      expect(result.dimensionScores, hasLength(6));
      for (final score in result.dimensionScores.values) {
        expect(score.score, 1.0);
        expect(score.asked, 2);
        expect(score.correct, 2);
        expect(score.confidence, greaterThan(0));
        expect(score.confidence, lessThan(1));
      }
      expect(result.confidence, greaterThan(0.4));
    });

    test('a struggling learner lands at Starter with honest zeros',
        () async {
      final engine = await _run(seed: 11, answerScript: (_) => false);

      final result = engine.buildResult(language: LearnLanguage.hindi);
      expect(result.overallLevel, 0);
      for (final score in result.dimensionScores.values) {
        expect(score.score, 0.0);
      }
    });

    test('a mixed learner lands in the middle band', () async {
      // Alternate: a genuinely borderline learner.
      final engine =
          await _run(seed: 11, answerScript: (i) => i.isEven);

      final result = engine.buildResult(language: LearnLanguage.hindi);
      expect(result.overallLevel, inInclusiveRange(1, 3));
      expect(result.dimensionScores, hasLength(6));
    });

    test('run length stays inside the 3–7 minute budget', () async {
      for (final script in <bool Function(int)>[
        (_) => true,
        (_) => false,
        (i) => i % 3 != 0,
      ]) {
        final engine = await _run(seed: 13, answerScript: script);
        expect(engine.askedCount,
            inInclusiveRange(DiagnosticEngine.kMinProbes, DiagnosticEngine.kMaxProbes));
      }
    });
  });

  group('answer records + state-extras material', () {
    test('records mirror the run truthfully', () async {
      final engine =
          await _run(seed: 21, answerScript: (i) => i.isEven);

      expect(engine.answerRecords, hasLength(engine.askedCount));
      for (final record in engine.answerRecords) {
        expect(record.conceptId, isNotNull);
      }
      // First record matches the first answer in the script.
      expect(engine.answerRecords.first.correct, true);
      expect(engine.answerRecords[1].correct, false);
    });
  });

  group('result honesty', () {
    test('friendly summary never leaks raw numbers', () async {
      final engine =
          await _run(seed: 11, answerScript: (i) => i.isEven);
      final result = engine.buildResult(language: LearnLanguage.hindi);

      final lines = result.friendlySummary();
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line.contains(RegExp(r'\d')), isFalse,
            reason: 'no raw scores in "$line" (Master Brief §11)');
      }
      expect(result.levelLabel, isA<String>());
    });

    test('only dimensions with real answers appear in the result',
        () async {
      final bank = await _hindiBank(31);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 0);
      // Answer exactly ONE probe, then finish by hand.
      engine.recordAnswer(true);
      engine.advance();
      // Force the stop: buildResult must not invent the other five.
      final result = engine.buildResult(language: LearnLanguage.hindi);
      expect(result.dimensionScores, hasLength(1));
      expect(result.dimensionScores.keys.single,
          DiagnosticDimension.script);
    });
  });

  group('determinism', () {
    test('same seed + same answers → identical probe sequence', () async {
      Future<List<String>> sequenceFor(int seed) async {
        final engine = await _run(seed: seed, answerScript: (_) => true);
        return [
          for (final r in engine.answerRecords) r.probeId,
        ];
      }

      final a = await sequenceFor(77);
      final b = await sequenceFor(77);
      expect(a, b);
      expect(a, hasLength(12));
    });

    test('answer-checker parity with the practice engine', () async {
      final bank = await _hindiBank(41);
      final engine = DiagnosticEngine(bank: bank, seedLevel: 0);
      final exercise = engine.currentItem!.exercise;
      final display = prepareExerciseOptions(exercise, 0);

      switch (exercise.type) {
        case ExerciseType.mcq || ExerciseType.fillBlank:
          final correct = DiagnosticChoiceAnswer(display.correctIndex);
          final wrong = DiagnosticChoiceAnswer(
            (display.correctIndex + 1) % display.options.length,
          );
          expect(correct.isCorrectFor(engine.currentItem!), isTrue);
          expect(wrong.isCorrectFor(engine.currentItem!), isFalse);
        case ExerciseType.translation:
          final correct =
              DiagnosticTextAnswer(exercise.acceptedAnswers.first);
          final wrong = const DiagnosticTextAnswer('no chance');
          expect(correct.isCorrectFor(engine.currentItem!), isTrue);
          expect(wrong.isCorrectFor(engine.currentItem!), isFalse);
        case ExerciseType.matching:
          final correctPairs = <int, int>{
            for (var left = 0;
                left < exercise.pairs.length;
                left++)
              left: display.pairIndexByDisplay.indexOf(left),
          };
          final correct = DiagnosticMatchAnswer(correctPairs);
          final wrong = DiagnosticMatchAnswer({
            for (final entry in correctPairs.entries)
              entry.key: (entry.value + 1) % display.options.length,
          });
          expect(correct.isCorrectFor(engine.currentItem!), isTrue);
          expect(wrong.isCorrectFor(engine.currentItem!), isFalse);
        case ExerciseType.ordering:
          final correct = DiagnosticOrderAnswer(exercise.items);
          expect(correct.isCorrectFor(engine.currentItem!), isTrue);
          final wrong = DiagnosticOrderAnswer(exercise.items.reversed.toList());
          if (exercise.items.length > 1) {
            expect(wrong.isCorrectFor(engine.currentItem!), isFalse);
          }
          break;
      }
    });
  });

  group('normalizeDiagnosticAnswer parity', () {
    test('trims, collapses whitespace, ignores case', () {
      expect(
        normalizeDiagnosticAnswer('  Naamste   duniya  '),
        normalizeDiagnosticAnswer('naamste duniya'),
      );
      expect(normalizeDiagnosticAnswer('   '), '',
          reason: 'blank input normalizes to empty and never matches');
    });
  });
}
