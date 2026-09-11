/// Adaptive Session Engine — M6 tests (Master Brief §18).
///
/// Pins the §18 contract on synthetic pools (fast + exhaustive) and on
/// REAL Hindi bank exercises (parity with the trusted banks):
///   - all SIX activity kinds produce correctly-shaped sessions;
///   - 2 consecutive first-try correct → repetition trimmed;
///   - 2 wrong → the ladder: prerequisite → explanation → easier →
///     guided (each rung best-effort, never the same question twice);
///   - a validated generated variant (gen-) is adopted as the easier
///     rung and marked generated;
///   - support beats never consume the exercise budget;
///   - masteryCheck sessions never ladder and carry check presentation;
///   - evaluation aggregates per-concept M1 evidence semantics.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';

Exercise _mcq(String id, String lessonId,
    {String? hint, String? explanation}) {
  return Exercise(
    id: id,
    lessonId: lessonId,
    type: ExerciseType.mcq,
    prompt: 'Pick the right one ($id)',
    options: const ['alpha', 'beta', 'gamma'],
    correctIndex: 0,
    explanation: explanation,
    hint: hint,
  );
}

SessionExercisePool _pool(
  String conceptId,
  List<Exercise> exercises, {
  List<Exercise> generatedVariants = const [],
}) =>
    SessionExercisePool(
      conceptId: conceptId,
      exercises: exercises,
      generatedVariants: generatedVariants,
    );

void main() {
  // ─── Session shaping across the six kinds ────────────────────────────────

  group('session shaping (six kinds)', () {
    Exercise mk(int n) => _mcq('ex-a$n', 'lesson-a');

    test('practice visits two exercises per concept', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.practice,
          languageCode: 'hi',
          pools: [_pool('a', [mk(1), mk(2), mk(3)])],
        ),
      );
      expect(engine.maxSteps >= 2, isTrue);
      expect(engine.currentStep!.exercise!.id, 'ex-a1');
    });

    test('newLearning visits ONE exercise per concept (light touch)', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.newLearning,
          languageCode: 'hi',
          pools: [_pool('a', [mk(1), mk(2), mk(3)])],
        ),
      );
      // The only concept contributes exactly one queued exercise.
      var exerciseSteps = 0;
      while (!engine.isFinished) {
        if (engine.currentIsExercise) exerciseSteps++;
        engine.advance();
      }
      expect(exerciseSteps, 1);
    });

    test('masteryCheck visits three with check presentation, never ladders',
        () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.masteryCheck,
          languageCode: 'hi',
          pools: [_pool('a', [mk(1), mk(2), mk(3)])],
        ),
      );
      // Answer everything wrong — no ladder may appear in a check.
      var guard = 0;
      var checksSeen = 0;
      while (!engine.isFinished) {
        if (engine.currentIsExercise) {
          expect(engine.currentStep!.presentation,
              StepPresentation.masteryCheck);
          checksSeen++;
          engine.submitAnswer(correct: false, firstTry: true);
        }
        engine.advance();
        guard++;
        expect(guard, lessThan(40));
      }
      expect(checksSeen, 3);
    });

    test('challenge visits three per concept', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.challenge,
          languageCode: 'hi',
          pools: [
            _pool('a', [mk(1), mk(2), mk(3), mk(4)]),
          ],
        ),
      );
      var exerciseSteps = 0;
      while (!engine.isFinished) {
        if (engine.currentIsExercise) {
          exerciseSteps++;
          engine.submitAnswer(correct: true, firstTry: true);
        }
        engine.advance();
      }
      // 3 queued; trimming after 2 first-try corrects may cut the third.
      expect(exerciseSteps, anyOf(2, 3));
      expect(exerciseSteps, lessThanOrEqualTo(3));
    });

    test('review puts review-queue concepts first', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.review,
          languageCode: 'hi',
          pools: [
            _pool('a', [_mcq('ex-a1', 'lesson-a')]),
            _pool('b', [_mcq('ex-b1', 'lesson-b')]),
          ],
          reviewFirstConceptIds: const ['b'],
        ),
      );
      expect(engine.currentStep!.conceptId, 'b');
    });

    test('empty pools finish immediately without steps', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.practice,
          languageCode: 'hi',
          pools: const [],
        ),
      );
      expect(engine.isFinished, isTrue);
      expect(engine.currentStep, isNull);
    });
  });

  // ─── §18: reduce repetition ──────────────────────────────────────────────

  group('§18 reduce repetition', () {
    test('two first-try corrects trim the remaining same-concept step', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.challenge, // 3 per concept
          languageCode: 'hi',
          pools: [
            _pool('a', [mk(1), mk(2), mk(3)]),
            _pool('b', [_mcq('ex-b1', 'lesson-b')]),
          ],
        ),
      );

      // Two correct first-try answers on concept 'a'.
      expect(engine.currentStep!.conceptId, 'a');
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();
      expect(engine.currentStep!.conceptId, 'a');
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();

      // The third 'a' step was trimmed — concept 'b' comes next.
      expect(engine.currentStep!.conceptId, 'b');
      expect(engine.askedCount, 2);
    });

    test('a wrong answer breaks the streak and keeps the steps', () {
      final engine = AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.challenge,
          languageCode: 'hi',
          pools: [
            _pool('a', [mk(1), mk(2), mk(3)]),
          ],
        ),
      );
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      // Streak reset: the third exercise survives.
      expect(engine.currentStep!.conceptId, 'a');
      expect(engine.currentStep!.exercise!.id, 'ex-a3');
    });
  });

  // ─── §18: the ladder ─────────────────────────────────────────────────────

  group('§18 ladder on repeated wrongs', () {
    AdaptiveSessionEngine buildEngine({
      required List<Exercise> generatedVariants,
      bool withPrereq = true,
      bool withExplanation = true,
    }) {
      return AdaptiveSessionEngine(
        config: AdaptiveSessionConfig(
          kind: ActivityKind.practice,
          languageCode: 'hi',
          pools: [
            _pool(
              'a',
              [
                _mcq('ex-a1', 'lesson-a'),
                _mcq('ex-a2', 'lesson-a'),
                _mcq('ex-a3', 'lesson-a'),
                _mcq('ex-a4', 'lesson-a'),
              ],
              generatedVariants: generatedVariants,
            ),
            if (withPrereq) _pool('p', [_mcq('ex-p1', 'lesson-p')]),
          ],
          explanations: withExplanation
              ? const {'a': 'Refresher text for concept a.'}
              : const {},
          prerequisiteOf: withPrereq
              ? const {'a': 'p'}
              : const {'a': null},
        ),
      );
    }

    test('2 wrongs → prerequisite, explanation, easier, guided — in order',
        () {
      final engine = buildEngine(
        generatedVariants: const [],
      );

      // Fail two consecutive exercises on concept 'a'.
      expect(engine.currentStep!.exercise!.id, 'ex-a1');
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      expect(engine.currentStep!.exercise!.id, 'ex-a2');
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();

      // The ladder replaces the rest of 'a'.
      expect(engine.currentStep!.presentation,
          StepPresentation.prerequisite);
      expect(engine.currentStep!.conceptId, 'p');
      expect(engine.currentStep!.exercise!.id, 'ex-p1');
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();

      // Explanation beat (support, no budget consumed).
      expect(engine.currentStep!.isSupport, isTrue);
      expect(engine.currentStep!.explanation, 'Refresher text for concept a.');
      engine.advance();

      expect(engine.currentStep!.presentation, StepPresentation.easier);
      expect(engine.currentStep!.conceptId, 'a');
      final easierId = engine.currentStep!.exercise!.id;
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();

      expect(engine.currentStep!.presentation, StepPresentation.guided);
      final guidedId = engine.currentStep!.exercise!.id;
      expect(guidedId, isNot(easierId));

      // The ladder runs once per concept — no loop.
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();
      if (!engine.isFinished) {
        expect(
          engine.currentStep!.presentation,
          isNot(StepPresentation.prerequisite),
        );
      }
    });

    test('generated variant is adopted as the easier rung (and flagged)',
        () {
      final generated = Exercise(
        id: 'gen-a-practice-1',
        lessonId: 'lesson-a',
        type: ExerciseType.mcq,
        prompt: 'AI-made easier question',
        options: const ['x', 'y'],
        correctIndex: 0,
        explanation: 'Because the trusted lesson says so.',
      );
      final engine = buildEngine(generatedVariants: [generated]);

      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      // prerequisite → explanation → easier (the generated one).
      engine.submitAnswer(correct: true, firstTry: true); // prereq
      engine.advance(); // → explanation
      engine.advance(); // → easier
      expect(engine.currentStep!.presentation, StepPresentation.easier);
      expect(engine.currentStep!.exercise!.id, generated.id);
      expect(engine.currentStep!.exercise!.id.startsWith('gen-'), isTrue);
    });

    test('ladder rungs skip honestly when no material exists', () {
      final engine = buildEngine(
        generatedVariants: const [],
        withPrereq: false,
        withExplanation: false,
      );
      // Drain the two queued exercises with wrong answers.
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      engine.submitAnswer(correct: false, firstTry: true);
      engine.advance();
      // No prereq, no explanation → the easier rung uses a trusted
      // exercise directly.
      expect(engine.currentStep, isNotNull);
      expect(engine.currentStep!.presentation, StepPresentation.easier);
    });
  });

  // ─── Never repeat the same question ──────────────────────────────────────

  test('no exercise id is ever asked twice in one session', () {
    final engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: ActivityKind.practice,
        languageCode: 'hi',
        pools: [
          _pool('a', [
            _mcq('ex-a1', 'lesson-a'),
            _mcq('ex-a2', 'lesson-a'),
            _mcq('ex-a3', 'lesson-a'),
            _mcq('ex-a4', 'lesson-a'),
          ]),
          _pool('p', [_mcq('ex-p1', 'lesson-p')]),
        ],
        explanations: const {'a': 'Refresher.'},
        prerequisiteOf: const {'a': 'p'},
      ),
    );

    final seen = <String>{};
    var guard = 0;
    // Alternate right/wrong to hit both streak branches repeatedly.
    var flip = false;
    while (!engine.isFinished) {
      final step = engine.currentStep;
      if (step!.isSupport) {
        engine.advance();
      } else {
        expect(seen.add(step.exercise!.id), isTrue,
            reason: 'exercise ${step.exercise!.id} asked twice');
        engine.submitAnswer(correct: flip, firstTry: true);
        flip = !flip;
        engine.advance();
      }
      guard++;
      expect(guard, lessThan(60));
    }
  });

  // ─── Budget: support beats are free, exercises are not ───────────────────

  test('support beats never consume the exercise budget', () {
    final engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: ActivityKind.practice,
        languageCode: 'hi',
        pools: [
          _pool('a', [
            _mcq('ex-a1', 'lesson-a'),
            _mcq('ex-a2', 'lesson-a'),
            _mcq('ex-a3', 'lesson-a'),
          ]),
          _pool('p', [_mcq('ex-p1', 'lesson-p')]),
        ],
        explanations: const {'a': 'Refresher.'},
        prerequisiteOf: const {'a': 'p'},
        maxSteps: 2,
      ),
    );
    // Two wrongs force a ladder even though the budget is spent.
    engine.submitAnswer(correct: false, firstTry: true);
    engine.advance();
    engine.submitAnswer(correct: false, firstTry: true);
    engine.advance();
    // The support beat still materializes.
    expect(engine.currentStep!.isSupport, isTrue);
    expect(engine.askedCount, 2);
    engine.advance();
    // But no further EXERCISE step does.
    if (!engine.isFinished && engine.currentStep!.isSupport != true) {
      fail('budget exceeded: ${engine.currentStep!.exercise!.id}');
    }
  });

  // ─── Evaluation ──────────────────────────────────────────────────────────

  test('buildEvaluation aggregates per-concept M1 evidence semantics', () {
    final engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: ActivityKind.practice,
        languageCode: 'hi',
        pools: [
          _pool('a', [_mcq('ex-a1', 'lesson-a'), _mcq('ex-a2', 'lesson-a')]),
        ],
      ),
    );
    engine.submitAnswer(correct: true, firstTry: true); // a: first-try hit
    engine.advance();
    engine.submitAnswer(correct: false, firstTry: true); // a: miss
    engine.advance();

    final evaluation = engine.buildEvaluation(
      sessionId: 'sess-1',
      completedAt: DateTime(2026, 1, 1),
    );
    expect(evaluation.sessionId, 'sess-1');
    expect(evaluation.conceptEvaluations, hasLength(1));
    final conceptEvaluation = evaluation.conceptEvaluations.first;
    expect(conceptEvaluation.conceptId, 'a');
    expect(conceptEvaluation.correct, isTrue); // any correct
    expect(conceptEvaluation.attempts, 2);
    expect(conceptEvaluation.firstTryCorrect, isTrue);
    expect(evaluation.completedAt, DateTime(2026, 1, 1));
  });

  // ─── Real trusted banks (parity + honesty over real content) ─────────────

  test('real Hindi bank exercises drive a full practice session', () {
    // Real content from the shipped Hindi bank (hi_script_vowels).
    const hindiVowelExercises = <Exercise>[
      Exercise(
        id: 'hi_vow_1',
        lessonId: 'hi_script_vowels',
        type: ExerciseType.mcq,
        prompt: 'Which is the vowel अ?',
        options: ['अ', 'आ', 'इ'],
        correctIndex: 0,
        explanation: 'अ is the first vowel.',
      ),
      Exercise(
        id: 'hi_vow_2',
        lessonId: 'hi_script_vowels',
        type: ExerciseType.translation,
        prompt: 'Type the Hindi vowel "aa" (दीर्घ स्वर):',
        acceptedAnswers: ['आ'],
        explanation: 'आ is the long aa.',
      ),
      Exercise(
        id: 'hi_vow_3',
        lessonId: 'hi_script_vowels',
        type: ExerciseType.mcq,
        prompt: 'Which vowel comes right after इ?',
        options: ['ई', 'उ', 'ए'],
        correctIndex: 0,
        explanation: 'ई follows इ.',
      ),
    ];

    final engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: ActivityKind.practice,
        languageCode: 'hi',
        pools: [_pool('hi_script_vowels', hindiVowelExercises)],
      ),
    );

    var guard = 0;
    while (!engine.isFinished) {
      final step = engine.currentStep;
      if (step!.isSupport) {
        engine.advance();
        continue;
      }
      // Every queued exercise comes from the trusted bank shape.
      expect(step.exercise!.lessonId, 'hi_script_vowels');
      expect(step.exercise!.isValid, isTrue);
      engine.submitAnswer(correct: true, firstTry: true);
      engine.advance();
      guard++;
      expect(guard, lessThan(20));
    }
    expect(engine.askedCount, 2); // practice = 2 per concept
    final records = engine.records;
    expect(records.every((r) => r.correct), isTrue);
    expect(records.every((r) => !r.isGenerated), isTrue);
  });
}
