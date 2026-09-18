/// Learn Mode 2.0 — Adaptive Exercise Engine (M6, Master Brief §18)
///
/// The live session engine M1 reserved: it drives practice through ALL
/// SIX activity kinds —
///
///   newLearning · practice · review · weakRepair · masteryCheck ·
///   challenge
///
/// — and adapts (§18):
///
///   "If a learner repeatedly gets something correct: reduce repetition.
///    If a learner repeatedly gets something wrong: identify the
///    underlying concept. Then: prerequisite → explanation → easier
///    exercise → guided exercise → normal exercise → mastery check.
///    Do not merely repeat the same question."
///
/// Adaptation policy (deterministic, testable, no AI):
///
/// - TWO consecutive first-try correct answers on one concept → the
///   remaining same-concept steps at the same or easier difficulty are
///   TRIMMED (reduce repetition) and the session advances.
/// - TWO consecutive wrong answers on one concept → the engine descends
///   the §18 ladder for that concept: a PREREQUISITE exercise (when the
///   trusted graph offers one), then a TRUSTED EXPLANATION beat, then an
///   EASIER exercise, then a GUIDED exercise (same concept, a DIFFERENT
///   exercise, hint surfaced), then back to a NORMAL exercise. A mastery
///   check for the repaired concept is LEFT TO ITS OWN SESSION KIND —
///   the engine never escalates into one mid-session.
/// - The same exercise id is never asked twice in one session.
/// - Every step is grounded in trusted material (the existing banks) or
///   a VALIDATED AI-generated exercise handed in by the caller (M5's
///   GeneratedContent.practice already carries a real [Exercise] with
///   forced trusted anchors — the engine adopts it unchanged, §15/§45).
///
/// The engine is PURE (no Flutter, no I/O, no clock reads): callers feed
/// answers in and read steps out, so tests can drive every branch.
/// UI pacing, persistence and mastery/review writes are the providers'
/// job (`session_providers.dart` + `mastery_scheduling.dart`).
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/evaluation.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';

/// How one exercise step is presented (the §18 ladder, expressed).
enum StepPresentation {
  /// A regular exercise at the session's difficulty.
  normal,

  /// An easier exercise after repeated failure (lower band / generated).
  easier,

  /// A different exercise on the same concept with its hint surfaced.
  guided,

  /// An exercise on the PREREQUISITE concept (§18 ladder step 1).
  prerequisite,

  /// The strict end-of-ladder probe (own [ActivityKind.masteryCheck]
  /// sessions; never inserted mid-session).
  masteryCheck,
}

/// One step the engine asks the learner to take.
///
/// Either an [exercise] step (always a REAL trusted-shape [Exercise])
/// or a [support] beat (explanation text from the trusted lesson —
/// never scoreable). Sealed-ish via [isSupport].
class SessionStep extends Equatable {
  const SessionStep._({
    this.exercise,
    this.conceptId,
    this.presentation,
    this.explanation,
    this.explanationTitle,
  });

  /// An exercise step. [conceptId] is the concept this step develops;
  /// [presentation] says where in the §18 ladder it sits.
  factory SessionStep.exercise({
    required Exercise exercise,
    required String conceptId,
    StepPresentation presentation = StepPresentation.normal,
  }) {
    assert(exercise.isValid, 'session steps must carry valid exercises');
    return SessionStep._(
      exercise: exercise,
      conceptId: conceptId,
      presentation: presentation,
    );
  }

  /// A support beat: trusted explanation text (never scoreable).
  factory SessionStep.support({
    required String explanation,
    String? title,
  }) {
    return SessionStep._(
      explanation: explanation,
      explanationTitle: title,
    );
  }

  final Exercise? exercise;
  final String? conceptId;
  final StepPresentation? presentation;
  final String? explanation;
  final String? explanationTitle;

  bool get isSupport => exercise == null;

  /// Friendly ladder label for honest UIs (§63).
  String get presentationLabel => switch (presentation) {
        StepPresentation.normal => 'Warm-up',
        StepPresentation.easier => 'Easier step',
        StepPresentation.guided => 'Guided step',
        StepPresentation.prerequisite => 'Foundations',
        StepPresentation.masteryCheck => 'Mastery check',
        null => 'Refresher',
      };

  @override
  List<Object?> get props =>
      [exercise, conceptId, presentation, explanation, explanationTitle];
}

/// One exercise pool entry handed to the engine.
///
/// Groups the trusted exercises of ONE concept plus optional validated
/// generated variants (M5 cache) the engine may use as easier/guided
/// steps. Pools are copied on build — the engine never mutates caller
/// data.
class SessionExercisePool extends Equatable {
  const SessionExercisePool({
    required this.conceptId,
    required this.exercises,
    this.generatedVariants = const <Exercise>[],
  });

  final String conceptId;
  final List<Exercise> exercises;

  /// VALIDATED AI-generated exercises for this concept (M5
  /// GeneratedContent.practice). Used only as easier/guided ladder
  /// material — the engine never lets them replace trusted anchors.
  final List<Exercise> generatedVariants;

  SessionExercisePool copy() => SessionExercisePool(
        conceptId: conceptId,
        exercises: List.of(exercises),
        generatedVariants: List.of(generatedVariants),
      );

  @override
  List<Object?> get props => [conceptId, exercises, generatedVariants];
}

/// Session shape parameters (per kind — see [AdaptiveSessionEngine]).
class AdaptiveSessionConfig extends Equatable {
  const AdaptiveSessionConfig({
    required this.kind,
    required this.languageCode,
    required this.pools,
    this.explanations = const <String, String>{},
    this.prerequisiteOf = const <String, String?>{},
    this.difficultyKnob = 2,
    this.maxSteps = 10,
    this.reviewFirstConceptIds = const <String>[],
  });

  /// Which of the SIX kinds this session runs (the engine understands
  /// all of them — Master Brief §18).
  final ActivityKind kind;
  final String languageCode;

  /// Trusted pools for the focus concepts (order = session order).
  final List<SessionExercisePool> pools;

  /// conceptId → trusted explanation text (lesson reference text from
  /// the M5 registry) used on the §18 ladder's explanation beat.
  final Map<String, String> explanations;

  /// conceptId → its prerequisite's conceptId (null/absent = none
  /// known). Values must be keys of [pools] to be usable.
  final Map<String, String?> prerequisiteOf;

  /// 1..5 difficulty knob from the plan/diagnostic (mirrors M4/M5).
  final int difficultyKnob;

  /// Hard cap on exercise steps (session budget; support beats extra).
  final int maxSteps;

  /// For review/weakRepair sessions: concepts to put FIRST (from the
  /// persisted review queue).
  final List<String> reviewFirstConceptIds;

  @override
  List<Object?> get props => [
        kind,
        languageCode,
        pools,
        explanations,
        prerequisiteOf,
        difficultyKnob,
        maxSteps,
        reviewFirstConceptIds,
      ];
}

/// Everything recorded about one answered exercise step.
class SessionAnswerRecord extends Equatable {
  const SessionAnswerRecord({
    required this.conceptId,
    required this.exerciseId,
    required this.correct,
    required this.firstTry,
    required this.presentation,
    required this.isGenerated,
  });

  final String conceptId;
  final String exerciseId;
  final bool correct;
  final bool firstTry;
  final StepPresentation presentation;

  /// True for AI-generated exercises (never recorded into trusted
  /// progress by the callers — M5 honesty rule).
  final bool isGenerated;

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'exerciseId': exerciseId,
        'correct': correct,
        'firstTry': firstTry,
        'presentation': presentation.name,
        'isGenerated': isGenerated,
      };

  @override
  List<Object?> get props => [
        conceptId,
        exerciseId,
        correct,
        firstTry,
        presentation,
        isGenerated,
      ];
}

/// All SIX activity kinds the engine understands (Master Brief §18).
/// Kept explicit so tests and providers share one source of truth.
const Set<ActivityKind> kAllSessionActivityKinds = <ActivityKind>{
  ActivityKind.newLearning,
  ActivityKind.practice,
  ActivityKind.review,
  ActivityKind.weakRepair,
  ActivityKind.masteryCheck,
  ActivityKind.challenge,
};

/// Tunables of the adaptation policy (exposed for tests).
abstract final class AdaptiveSessionPolicy {
  /// Consecutive first-try correct answers that trigger repetition
  /// trimming (§18 "reduce repetition").
  static const int kTrimAfterCorrectStreak = 2;

  /// Consecutive wrong answers that trigger the §18 ladder.
  static const int kLadderAfterWrongStreak = 2;

  /// Exercises per concept a normal session visits before moving on.
  static const int kExercisesPerConcept = 2;

  /// Extra exercises a challenge session visits per concept.
  static const int kChallengeExercisesPerConcept = 3;

  /// Hard cap for [AdaptiveSessionConfig.maxSteps].
  static const int kMaxStepsCeiling = 20;
}

/// The adaptive session engine (Master Brief §18).
///
/// Build once per session with a [SessionExercisePool] set; drive with
/// [submitAnswer] / [advance]; read [currentStep]. The engine owns
/// SELECTION and ADAPTATION only — scoring correctness semantics stay
/// with the caller (parity with the practice engine is pinned by tests).
class AdaptiveSessionEngine {
  AdaptiveSessionEngine({required AdaptiveSessionConfig config})
      : _config = config,
        _pools = [for (final p in config.pools) p.copy()],
        maxSteps = config.maxSteps
            .clamp(1, AdaptiveSessionPolicy.kMaxStepsCeiling)
            .toInt() {
    _queue = _buildQueue();
    _materializeNext();
  }

  final AdaptiveSessionConfig _config;
  final List<SessionExercisePool> _pools;

  /// Effective exercise-step budget (clamped).
  final int maxSteps;

  /// Pending exercise steps, in order (mutated by adaptation).
  List<SessionStep> _queue = [];

  /// The materialized current step (exercise or support beat).
  SessionStep? _current;

  /// Records for evaluation + scheduling.
  final List<SessionAnswerRecord> _records = [];

  /// Exercises already asked — the same question is never repeated
  /// (Master Brief §18 "do not merely repeat the same question").
  final Set<String> _askedIds = {};

  /// Exercises asked so far, plus ids adopted by a pending ladder - so
  /// the ladder's easier/guided rungs can never pick the same exercise
  /// twice before either is even asked. Queued-but-unasked exercises may
  /// still be ADOPTED by a ladder rung (the rung pulls them forward);
  /// applying the ladder then removes the now-duplicate queue step.
  final Set<String> _reservedIds = {};

  /// Consecutive first-try correct answers per concept.
  final Map<String, int> _correctStreak = {};

  /// Consecutive wrong answers per concept.
  final Map<String, int> _wrongStreak = {};

  /// Concepts that already had their explanation beat this session.
  final Set<String> _explained = {};

  /// Concepts that already descended the §18 ladder this session
  /// (a ladder runs at most once per concept per session — otherwise a
  /// hopeless concept would loop forever).
  final Set<String> _laddered = {};

  /// Ladder follow-up queued for the current concept (applied on
  /// [advance] so the feedback beat shows first).
  List<SessionStep>? _pendingLadder;

  /// Concept whose ladder is pending (for honest records).
  String? _pendingLadderConcept;

  /// Exercise steps asked so far.
  int get askedCount => _records.length;

  /// Answer records (unmodifiable view).
  List<SessionAnswerRecord> get records => List.unmodifiable(_records);

  /// The step to render now (null only when finished).
  SessionStep? get currentStep => _current;

  bool get isFinished => _current == null;

  /// True when the current step is a scoreable exercise.
  bool get currentIsExercise => _current?.exercise != null;

  /// Concept of the current exercise step (null on support beats).
  String? get currentConceptId => _current?.conceptId;

  // ── Session shaping (kind-aware) ────────────────────────────────────────

  /// Builds the initial queue for the configured kind. All six kinds
  /// are understood (Master Brief §18); unknown kinds degrade to
  /// plain practice semantics.
  List<SessionStep> _buildQueue() {
    final pools = _orderedPools();
    final perConcept = switch (_config.kind) {
      ActivityKind.challenge =>
        AdaptiveSessionPolicy.kChallengeExercisesPerConcept,
      ActivityKind.newLearning => 1, // light touch — the lesson teaches
      ActivityKind.masteryCheck => 3, // short, strict, no support
      _ => AdaptiveSessionPolicy.kExercisesPerConcept,
    };
    final queue = <SessionStep>[];
    for (final pool in pools) {
      var taken = 0;
      for (final exercise in pool.exercises) {
        if (taken >= perConcept || queue.length >= maxSteps) break;
        if (_askedIds.contains(exercise.id) || !exercise.isValid) continue;
        if (_reservedIds.contains(exercise.id)) continue;
        _reservedIds.add(exercise.id);
        queue.add(SessionStep.exercise(
          exercise: exercise,
          conceptId: pool.conceptId,
          presentation: _config.kind == ActivityKind.masteryCheck
              ? StepPresentation.masteryCheck
              : StepPresentation.normal,
        ));
        taken++;
      }
    }
    return queue;
  }

  /// Review/weakRepair put the persisted review-queue concepts first.
  List<SessionExercisePool> _orderedPools() {
    final priority = _config.reviewFirstConceptIds;
    if (priority.isEmpty) return _pools;
    final ranked = [..._pools]..sort((a, b) {
        final ai = priority.indexOf(a.conceptId);
        final bi = priority.indexOf(b.conceptId);
        return (ai < 0 ? 1 << 30 : ai).compareTo(bi < 0 ? 1 << 30 : bi);
      });
    return ranked;
  }

  // ── Driving the session ─────────────────────────────────────────────────

  /// Records the learner's answer to the CURRENT exercise step and
  /// applies the §18 adaptation policy. No-ops on support beats or when
  /// finished. [firstTry] mirrors the practice engine's retry semantics
  /// (the caller counts attempts; the engine reasons on the flag).
  void submitAnswer({required bool correct, required bool firstTry}) {
    final step = _current;
    if (step == null || step.isSupport) return;

    final conceptId = step.conceptId!;
    final record = SessionAnswerRecord(
      conceptId: conceptId,
      exerciseId: step.exercise!.id,
      correct: correct,
      firstTry: firstTry,
      presentation: step.presentation ?? StepPresentation.normal,
      isGenerated: step.exercise!.id.startsWith('gen-'),
    );
    _records.add(record);

    // Adaptation state per concept.
    if (correct && firstTry) {
      _correctStreak[conceptId] = (_correctStreak[conceptId] ?? 0) + 1;
      _wrongStreak[conceptId] = 0;
    } else if (!correct) {
      _wrongStreak[conceptId] = (_wrongStreak[conceptId] ?? 0) + 1;
      _correctStreak[conceptId] = 0;
    }

    if ((_wrongStreak[conceptId] ?? 0) >=
            AdaptiveSessionPolicy.kLadderAfterWrongStreak &&
        _config.kind != ActivityKind.masteryCheck &&
        _config.kind != ActivityKind.challenge &&
        !_laddered.contains(conceptId)) {
      // §18: identify the underlying concept and step down the ladder.
      _pendingLadder = _buildLadder(conceptId);
      _pendingLadderConcept = conceptId;
    }
    // Note: trimming of already-queued same-concept steps happens on
    // advance() so the current feedback beat is unaffected.
  }

  /// Leaves the feedback beat: applies pending adaptation (ladder /
  /// trimming) and materializes the next step, or finishes the session.
  void advance() {
    if (_current != null && _current!.isSupport) {
      // Leaving a support beat — continue with whatever follows.
    } else if (_current != null) {
      final conceptId = _current!.conceptId!;
      final record = _records.isEmpty ? null : _records.last;
      final wasCorrectFirstTry =
          record != null && record.correct && record.firstTry;

      // §18 "reduce repetition": after a correct streak, drop queued
      // same-concept steps at the same or easier presentation.
      if (wasCorrectFirstTry &&
          (_correctStreak[conceptId] ?? 0) >=
              AdaptiveSessionPolicy.kTrimAfterCorrectStreak) {
        _queue = _queue
            .where((s) =>
                s.conceptId != conceptId ||
                s.presentation == StepPresentation.masteryCheck)
            .toList();
      }
    }

    // A wrong streak on the step just left may have queued a ladder.
    if (_pendingLadder != null) {
      final ladder = _pendingLadder!;
      final conceptId = _pendingLadderConcept;
      _pendingLadder = null;
      _pendingLadderConcept = null;
      if (conceptId != null) {
        _laddered.add(conceptId);
        // Trim remaining same-concept NORMAL steps - the ladder replaces
        // them (never merely repeats the same question).
        _queue = _queue
            .where((s) =>
                s.conceptId != conceptId ||
                s.presentation == StepPresentation.masteryCheck)
            .toList();
        // A rung may have ADOPTED a queued-but-unasked exercise (e.g. the
        // prerequisite concept's only exercise was sitting in the queue).
        // Drop the now-duplicate queue steps so each id is asked once.
        final ladderIds = {
          for (final s in ladder)
            if (s.exercise != null) s.exercise!.id,
        };
        _queue = _queue
            .where((s) =>
                s.exercise == null || !ladderIds.contains(s.exercise!.id))
            .toList();
        _queue.insertAll(0, ladder);
      }
    }

    _materializeNext();
  }

  /// Pops the next step from the queue (or finishes). Support beats and
  /// exercise steps materialize identically; asked-id bookkeeping
  /// happens for exercise steps.
  void _materializeNext() {
    while (_queue.isNotEmpty) {
      final next = _queue.first;
      final isSupport = next.exercise == null;
      // The exercise budget counts ANSWERED exercise steps only;
      // support beats (trusted explanations) never consume it, and
      // exercise steps beyond the budget are dropped (remediation can
      // still explain, it just stops asking).
      if (!isSupport && _records.length >= maxSteps) {
        _queue.removeAt(0);
        _reservedIds.remove(next.exercise!.id);
        continue;
      }
      _queue.removeAt(0);
      if (!isSupport) {
        _askedIds.add(next.exercise!.id);
        _reservedIds.remove(next.exercise!.id);
      }
      _current = next;
      return;
    }
    _current = null;
  }

  // ── The §18 ladder ──────────────────────────────────────────────────────

  /// Builds the ladder steps for [conceptId]:
  ///
  ///   prerequisite → explanation → easier → guided → normal
  ///
  /// Every rung is BEST-EFFORT from trusted material: a rung without
  /// available content is skipped honestly (never faked). A mastery
  /// check is never inserted here — it is its own session kind.
  List<SessionStep> _buildLadder(String conceptId) {
    final steps = <SessionStep>[];

    // 1. Prerequisite exercise (when the graph offers one with pool).
    final prereqId = _config.prerequisiteOf[conceptId];
    if (prereqId != null && prereqId != conceptId) {
      final prereqPool = _pools.firstWhere(
        (p) => p.conceptId == prereqId,
        orElse: () => const SessionExercisePool(
          conceptId: '',
          exercises: [],
        ),
      );
      final prereqExercise = _firstUnused(prereqPool.exercises);
      if (prereqExercise != null) {
        _reservedIds.add(prereqExercise.id);
        steps.add(SessionStep.exercise(
          exercise: prereqExercise,
          conceptId: prereqId,
          presentation: StepPresentation.prerequisite,
        ));
      }
    }

    // 2. Trusted explanation beat (once per concept per session).
    if (_explained.add(conceptId)) {
      final text = _config.explanations[conceptId];
      if (text != null && text.trim().isNotEmpty) {
        steps.add(SessionStep.support(
          explanation: text.trim(),
          title: 'A quick refresher',
        ));
      }
    }

    // 3. Easier exercise: a validated generated variant first (M5 cache
    //    is exactly "an easier take on the same concept"), else another
    //    trusted exercise of the same concept.
    final pool = _pools.firstWhere(
      (p) => p.conceptId == conceptId,
      orElse: () => const SessionExercisePool(conceptId: '', exercises: []),
    );
    final easier =
        _firstUnused(pool.generatedVariants) ?? _firstUnused(pool.exercises);
    if (easier != null) {
      _reservedIds.add(easier.id);
      steps.add(SessionStep.exercise(
        exercise: easier,
        conceptId: conceptId,
        presentation: StepPresentation.easier,
      ));
    }

    // 4. Guided exercise: a DIFFERENT trusted exercise with the hint
    //    surfaced by the UI ([Exercise.hint]).
    final guided = _firstUnused(pool.exercises);
    if (guided != null) {
      _reservedIds.add(guided.id);
      steps.add(SessionStep.exercise(
        exercise: guided,
        conceptId: conceptId,
        presentation: StepPresentation.guided,
      ));
    }

    // 5. Back to normal happens naturally: other concepts' queued steps
    //    (and future sessions) take over — the engine does not loop the
    //    same concept endlessly (the ladder runs once per concept).

    return steps;
  }

  Exercise? _firstUnused(List<Exercise> candidates) {
    // Queued-but-unasked exercises are adoptable: a ladder rung that
    // takes one pulls it forward out of the normal flow, and applying
    // the ladder drops the queue step so the id is still asked exactly
    // once. Only asked ids and ids reserved by an earlier rung of the
    // ladder currently being built are genuinely unavailable.
    final queuedIds = {
      for (final step in _queue)
        if (step.exercise != null) step.exercise!.id,
    };
    for (final exercise in candidates) {
      if (!exercise.isValid) continue;
      if (_askedIds.contains(exercise.id)) continue;
      if (_reservedIds.contains(exercise.id) &&
          !queuedIds.contains(exercise.id)) {
        continue;
      }
      return exercise;
    }
    return null;
  }

  // ── Evaluation (the Plan → Session → Evaluation edge) ──────────────────

  /// Builds the [EvaluationResult] for this session: one
  /// [ConceptEvaluation] per concept with at least one attempt, using
  /// the M1 evidence semantics (correct = any correct answer;
  /// firstTryCorrect = at least one first-try correct). Pure unless
  /// [completedAt] is omitted.
  EvaluationResult buildEvaluation({
    required String sessionId,
    DateTime? completedAt,
  }) {
    final byConcept = <String, List<SessionAnswerRecord>>{};
    for (final record in _records) {
      byConcept.putIfAbsent(record.conceptId, () => []).add(record);
    }
    final evaluations = <ConceptEvaluation>[];
    for (final entry in byConcept.entries) {
      final records = entry.value;
      evaluations.add(ConceptEvaluation(
        conceptId: entry.key,
        correct: records.any((r) => r.correct),
        attempts: records.length,
        firstTryCorrect: records.any((r) => r.correct && r.firstTry),
      ));
    }
    return EvaluationResult(
      sessionId: sessionId,
      conceptEvaluations: evaluations,
      completedAt: completedAt ?? DateTime.now(),
    );
  }
}
