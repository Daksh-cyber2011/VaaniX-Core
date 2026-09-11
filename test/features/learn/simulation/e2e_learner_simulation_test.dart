/// M11 — End-to-End Learner Simulation (Master Brief §91/§92).
///
/// Simulates COMPLETE learner journeys through the REAL Learn 2.0 spine —
/// the actual engines, the actual trusted data, no mocks of anything the
/// brief asks about:
///
///   onboarding → diagnostic → plan → lesson → exercise → mistakes →
///   mastery → review → replanning
///
/// Five personas (§91):
///   A — complete beginner
///   B — knows basic vocabulary but weak grammar
///   C — strong beginner trying to reach intermediate
///   D — already advanced in one skill but weak in another
///   E — returning learner after a break
///
/// §92 CRITICAL DEMONSTRATION: two learners choosing the SAME language
/// receive DIFFERENT learning paths because their current levels,
/// strengths, weaknesses, goals and mastery differ.
///
/// ── What is REAL vs what is SIMULATED ────────────────────────────────
/// REAL (the systems under test):
///   · ConceptGraph, DiagnosticItemBank, DiagnosticEngine  (M1/M3)
///   · deriveLearningState, applyMasteryEvidence           (M1/M6)
///   · DeterministicPlanner + ValidatingPlanner            (M1/M4 facade)
///   · AdaptiveSessionEngine incl. the §18 ladder          (M6)
///   · mastery scheduling: evidenceFromRecords,
///     buildEvidenceMasteries, scheduleReviewUpdates,
///     mergeReviewQueue                                    (M6)
///   · TrustedContentRegistry (session explanations)       (M5)
///   · the shipped Hindi curriculum asset + exercise bank  (Parts A–G)
///
/// SIMULATED (thin, documented mirrors of the provider finish pipelines —
/// the engines above are what the brief's §91 arc exercises):
///   · diagnostic finish pipeline (extras seeding)     — mirror of
///     DiagnosticSessionNotifier.next/_extrasFrom (M3)
///   · lesson completion + first-try practice mastery  — mirror of the
///     lesson route + ExerciseNotifier.masteredExerciseIds recording
///   · session finish pipeline                          — mirror of
///     AdaptiveSessionController.next (persist-first flow, M6)
///
/// The Riverpod/IO layer is intentionally NOT re-tested here — M3/M6
/// already pin it (diagnostic_providers_test, session_providers_test);
/// M11 proves the ADAPTIVE ARC those layers orchestrate.
///
/// Determinism: every run pins its seed; the same persona always
/// produces the same trace (pinned below), so this file doubles as a
/// regression canary for the whole adaptive pipeline.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery_scheduling.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';

// ─── Simulation world (real data, built once per group) ─────────────────────

/// Everything a simulated learner interacts with. All fields are REAL
/// app data — the shipped Hindi curriculum, the shipped exercise bank,
/// and the engines built from them.
class SimWorld {
  SimWorld._({
    required this.chapters,
    required this.graph,
    required this.registry,
  });

  final List<Chapter> chapters;
  final ConceptGraph graph;
  final TrustedContentRegistry registry;

  /// The REAL Hindi bank (same map the practice screens read).
  Map<String, List<Exercise>> get bank => hindiExercisesByLesson;

  static Future<SimWorld> build() async {
    final chapters = await loadLearnCurriculum(LearnLanguage.hindi);
    expect(chapters, isNotEmpty, reason: 'the real Hindi curriculum loads');
    final graph = ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: chapters,
    );
    expect(graph.concepts.length, 20,
        reason: 'hi ships 5 chapters × 4 lessons');
    final registry = TrustedContentRegistry.build(
      graph: graph,
      chapters: chapters,
      exercisesByLesson: hindiExercisesByLesson,
      isRTL: false,
      scriptCode: 'Deva',
    );
    return SimWorld._(chapters: chapters, graph: graph, registry: registry);
  }

  List<Exercise> exercisesFor(String lessonId) =>
      bank[lessonId] ?? const <Exercise>[];
}

// ─── The learner's persisted pocket ─────────────────────────────────────────

/// What the repositories would hold for one learner between steps:
/// per-lesson progress (progress repo), the persisted learning-state
/// extras (learn_profile_<iso>_state), and the profile itself.
class SimLearner {
  SimLearner({
    required this.name,
    required this.profile,
    Set<String> completedLessons = const <String>{},
    Map<String, Set<String>> masteredByLesson = const <String, Set<String>>{},
    Map<String, ConceptMastery> evidenceMasteries =
        const <String, ConceptMastery>{},
    List<ReviewEntry> reviewQueue = const <ReviewEntry>[],
    RecentPerformance recentPerformance = const RecentPerformance(),
  })  : completedLessons = Set.of(completedLessons),
        masteredByLesson = {
          for (final e in masteredByLesson.entries)
            e.key: Set.of(e.value),
        },
        evidenceMasteries = Map.of(evidenceMasteries),
        reviewQueue = List.of(reviewQueue),
        recentPerformance = recentPerformance;

  final String name;
  LearnerProfile profile;

  /// Progress repository: completed lessons + mastered exercise ids
  /// (the single evidence source of the M1 derivation).
  final Set<String> completedLessons;
  final Map<String, Set<String>> masteredByLesson;

  /// Persisted session-evidence masteries (M6 extras channel).
  Map<String, ConceptMastery> evidenceMasteries;

  /// Persisted review queue + recent performance (M3/M6 extras channel).
  List<ReviewEntry> reviewQueue;
  RecentPerformance recentPerformance;

  /// Marks a lesson READ (lesson_content_screen completion path).
  void completeLesson(String lessonId) => completedLessons.add(lessonId);

  /// Records first-try mastered exercise ids for a lesson (the idempotent
  /// mastery path the practice route and adaptive sessions both feed).
  void recordMastered(String lessonId, Iterable<String> exerciseIds) {
    masteredByLesson.putIfAbsent(lessonId, () => <String>{}).addAll(
          exerciseIds.where((id) => !id.startsWith('gen-')),
        );
  }
}

// ─── Pipeline steps (mirrors of the production wiring) ──────────────────────

/// Mirror of `kMaxDiagnosticReviewSeeds` (diagnostic_providers.dart, M3):
/// one diagnostic run seeds at most this many review entries.
const int _kMaxDiagnosticReviewSeeds = 8;

/// The trusted diagnostic bank for the world, reshuffled per run —
/// exactly what diagnosticItemBankProvider builds (M3).
DiagnosticItemBank diagnosticBank(SimWorld world, int seed) =>
    DiagnosticItemBank.build(
      graph: world.graph,
      exercisesByLesson: world.bank,
      seed: seed,
    );

/// ONBOARDING + DIAGNOSTIC (§91 steps 1–2).
///
/// Mirrors DiagnosticSessionNotifier: start (self-report seeds the level
/// track, per-run reshuffle) → answer/feedback loop → buildResult →
/// persist (currentLevel, review-queue seeds, performance events).
///
/// [answerFor] decides each probe's outcome the way a persona would.
DiagnosticResult runDiagnostic({
  required SimWorld world,
  required SimLearner learner,
  required int seed,
  required bool Function(DiagnosticItem item) answerFor,
}) {
  final engine = DiagnosticEngine(
    bank: diagnosticBank(world, seed),
    seedLevel: learner.profile.selfReport.suggestedLevel,
  );
  var guard = 0;
  while (!engine.isFinished) {
    engine.recordAnswer(answerFor(engine.currentItem!));
    engine.advance();
    guard++;
    expect(guard, lessThanOrEqualTo(DiagnosticEngine.kMaxProbes + 1),
        reason: 'diagnostic must respect its own probe budget');
  }

  final result = engine.buildResult(language: LearnLanguage.hindi);

  // Finish pipeline (mirror of DiagnosticSessionNotifier.next/_extrasFrom):
  // currentLevel → profile; missed probes → review-queue seeds
  // (dimension-weak boosted, capped); one first-try event per probe.
  learner.profile = learner.profile.copyWith(
    currentLevel: result.overallLevel,
  );

  final byDimension = <DiagnosticDimension, List<DiagnosticAnswerRecord>>{};
  for (final record in engine.answerRecords) {
    byDimension.putIfAbsent(record.dimension, () => []).add(record);
  }
  final dimensionScores = <DiagnosticDimension, double>{
    for (final e in byDimension.entries)
      e.key: e.value.where((r) => r.correct).length / e.value.length,
  };

  final seenConcepts = <String>{};
  final seeds = <ReviewEntry>[];
  for (final record in engine.answerRecords) {
    final conceptId = record.conceptId;
    if (record.correct || conceptId == null) continue;
    if (!seenConcepts.add(conceptId)) continue;
    final dimScore = dimensionScores[record.dimension] ?? 0.0;
    seeds.add(ReviewEntry(
      conceptId: conceptId,
      reason: ReviewReason.recentlyWeak,
      priority: dimScore < 0.5 ? 0.85 : 0.7,
    ));
    if (seeds.length >= _kMaxDiagnosticReviewSeeds) break;
  }

  learner.reviewQueue = List.of(seeds)..sort();
  learner.recentPerformance = RecentPerformance(
    events: [
      for (final record in engine.answerRecords)
        PerformanceEvent(
          conceptId: record.conceptId ?? record.probeId,
          correct: record.correct,
          firstTry: true,
          at: result.completedAt,
        ),
    ],
  );
  return result;
}

/// LEARNING STATE (M1 derivation + M6 evidence overlay) — the read model
/// activeLearningStateProvider assembles before every planning call.
LearningState learningStateOf(SimWorld world, SimLearner learner) {
  final masteredByLesson = <String, List<String>>{};
  final exerciseCounts = <String, int>{};
  for (final concept in world.graph.concepts) {
    masteredByLesson[concept.lessonId] =
        learner.masteredByLesson[concept.lessonId]?.toList() ??
            const <String>[];
    exerciseCounts[concept.lessonId] =
        world.exercisesFor(concept.lessonId).length;
  }
  final derived = deriveLearningState(
    languageCode: world.graph.languageCode,
    graph: world.graph,
    snapshot: ProgressSnapshot(
      completedLessonIds: learner.completedLessons,
      masteredExerciseIdsByLesson: masteredByLesson,
      exerciseCountByLesson: exerciseCounts,
    ),
    reviewQueue: learner.reviewQueue,
    recentPerformance: learner.recentPerformance,
  );
  return applyMasteryEvidence(
    derived: derived,
    evidence: learner.evidenceMasteries,
  );
}

/// PLAN (§91 step 3) — the deterministic hop of the production chain,
/// through the SAME ValidatingPlanner facade (AI → cached → deterministic;
/// M11 pins the guaranteed-available hop end to end).
Future<LearningPlan> buildPlan({
  required SimWorld world,
  required SimLearner learner,
  required LearningState state,
  required DiagnosticResult? diagnostic,
}) async {
  final context = PlannerContext(
    languageCode: world.graph.languageCode,
    languageName: 'Hindi',
    graph: world.graph,
    state: state,
    profile: learner.profile,
    diagnostic: diagnostic,
    minutesAvailable: learner.profile.dailyGoalMinutes,
    supportedActivityTypes: kDeterministicPlannerActivityKinds,
  );
  const deterministic = DeterministicPlanner();
  final planner = ValidatingPlanner(
    delegate: deterministic,
    fallback: deterministic,
  );
  final result = await planner.buildPlan(context);
  return result.fold(
    (Failure failure) => fail('planner chain failed: ${failure.message}'),
    (plan) => plan,
  );
}

/// One ADAPTIVE SESSION (§91 steps 5–7: exercise → mistakes → mastery).
///
/// Mirrors AdaptiveSessionController.start (trusted pools + explanations +
/// prerequisite map + review-first ordering) and its finish pipeline
/// (evidence → stage uplift → review scheduling → trusted mastery).
/// Returns the engine so tests can inspect the §18 ladder transcript.
class SimSessionOutcome {
  const SimSessionOutcome({
    required this.engine,
    required this.ladderRungs,
    required this.supportBeats,
    required this.uplifts,
    required this.queueUpdates,
  });

  final AdaptiveSessionEngine engine;

  /// The §18 ladder rungs that materialized, in order.
  final List<StepPresentation> ladderRungs;

  /// Trusted explanation beats shown (the ladder's refresher step).
  final int supportBeats;
  final Map<String, MasteryStage> uplifts;
  final List<ReviewEntry> queueUpdates;
}

SimSessionOutcome runSession({
  required SimWorld world,
  required SimLearner learner,
  required LearningState stateBefore,
  required ActivityKind kind,
  required String focusConceptId,
  required (bool, bool) Function(SessionStep step) answerFor,
  DateTime? at,
  int maxSteps = 10,
}) {
  final now = at ?? DateTime.now();
  final concept = world.graph.conceptById(focusConceptId)!;

  // Focus set: the anchor first; review/weakRepair add up to two due
  // concepts from the queue (AdaptiveSessionController.start).
  final focusIds = <String>[focusConceptId];
  if (kind == ActivityKind.review || kind == ActivityKind.weakRepair) {
    for (final entry in stateBefore.reviewQueue) {
      if (focusIds.length >= 3) break;
      if (focusIds.contains(entry.conceptId)) continue;
      final c = world.graph.conceptById(entry.conceptId);
      if (c == null) continue;
      if (world.exercisesFor(c.lessonId).isEmpty) continue;
      focusIds.add(c.id);
    }
  }

  // Pools + explanations + prerequisite map (trusted only).
  final pools = <SessionExercisePool>[];
  final explanations = <String, String>{};
  final prerequisiteOf = <String, String?>{};
  void addConcept(String id) {
    final c = world.graph.conceptById(id);
    if (c == null || pools.any((p) => p.conceptId == id)) return;
    pools.add(SessionExercisePool(
      conceptId: id,
      exercises: world.exercisesFor(c.lessonId),
    ));
    final excerpt = world.registry.excerptFor(id);
    final text = excerpt.referenceText.trim().isEmpty
        ? excerpt.exampleSentences.join(' ')
        : excerpt.referenceText;
    if (text.trim().isNotEmpty) explanations[id] = text.trim();
    prerequisiteOf[id] = c.prerequisites.isEmpty ? null : c.prerequisites.first;
  }

  for (final id in focusIds) {
    addConcept(id);
  }
  for (final id in List.of(focusIds)) {
    final prereq = prerequisiteOf[id];
    if (prereq != null) addConcept(prereq);
  }

  final usable = pools.where((p) => p.exercises.isNotEmpty).toList();
  expect(usable, isNotEmpty,
      reason: 'the trusted bank must back every simulated session');

  final reviewFirst =
      kind == ActivityKind.review || kind == ActivityKind.weakRepair
          ? [for (final e in stateBefore.reviewQueue) e.conceptId]
          : const <String>[];

  final engine = AdaptiveSessionEngine(
    config: AdaptiveSessionConfig(
      kind: kind,
      languageCode: world.graph.languageCode,
      pools: usable,
      explanations: explanations,
      prerequisiteOf: prerequisiteOf,
      difficultyKnob: difficultyKnobForBand(concept.difficulty),
      maxSteps: maxSteps,
      reviewFirstConceptIds: reviewFirst,
    ),
  );

  // Drive: submit once per exercise step, advance through support beats.
  final ladderRungs = <StepPresentation>[];
  var supportBeats = 0;
  var guard = 0;
  while (!engine.isFinished) {
    final step = engine.currentStep!;
    if (step.isSupport) {
      supportBeats++;
      engine.advance();
    } else {
      if (step.presentation == StepPresentation.prerequisite ||
          step.presentation == StepPresentation.easier ||
          step.presentation == StepPresentation.guided) {
        ladderRungs.add(step.presentation!);
      }
      final (correct, firstTry) = answerFor(step);
      engine.submitAnswer(correct: correct, firstTry: firstTry);
      engine.advance();
    }
    guard++;
    expect(guard, lessThan(60),
        reason: 'session drive must terminate (engine bug guard)');
  }

  // ── Finish pipeline (AdaptiveSessionController.next mirror) ──
  final records = engine.records;
  final evidence = evidenceFromRecords(records, at: now);
  final currentStages = <String, MasteryStage?>{
    for (final id in evidence.keys) id: stateBefore.stageOf(id),
  };
  final lastPracticed = <String, DateTime?>{
    for (final id in evidence.keys)
      id: stateBefore.conceptMasteries[id]?.lastPracticedAt,
  };

  final newEvidence = buildEvidenceMasteries(
    kind: kind,
    evidence: evidence,
    priorEvidence: learner.evidenceMasteries,
    currentStages: currentStages,
    at: now,
  );

  // Stage uplifts this session earned (per-concept, vs the prior stage).
  final uplifts = <String, MasteryStage>{};
  for (final id in evidence.keys) {
    final before = currentStages[id];
    final after = newEvidence[id]?.stage;
    if (after != null && (before == null || after.index > before.index)) {
      uplifts[id] = after;
    }
  }

  final queueUpdates = scheduleReviewUpdates(
    kind: kind,
    evidence: evidence,
    currentStages: currentStages,
    lastPracticedByConcept: lastPracticed,
    now: now,
  );
  learner.reviewQueue = mergeReviewQueue(learner.reviewQueue, queueUpdates);

  var perf = learner.recentPerformance;
  for (final record in records) {
    perf = perf.add(PerformanceEvent(
      conceptId: record.conceptId,
      correct: record.correct,
      firstTry: record.firstTry,
      at: now,
    ));
  }
  learner.recentPerformance = perf;
  learner.evidenceMasteries = newEvidence;

  // Trusted-exercise mastery through the idempotent path (gen- never
  // recorded — the harness filters them inside recordMastered too).
  for (final record in records) {
    if (!record.correct || record.isGenerated) continue;
    final c = world.graph.conceptById(record.conceptId);
    if (c == null) continue;
    learner.recordMastered(c.lessonId, [record.exerciseId]);
  }

  return SimSessionOutcome(
    engine: engine,
    ladderRungs: ladderRungs,
    supportBeats: supportBeats,
    uplifts: uplifts,
    queueUpdates: queueUpdates,
  );
}

// ── persona helpers ──────────────────────────────────────────────────────────

/// Chapter order of a concept (0 script → 1 greetings → 2 daily life →
/// 3 grammar → 4 reading) — the curriculum's own thematic structure.
int chapterOf(SimWorld world, String conceptId) {
  final c = world.graph.conceptById(conceptId)!;
  return c.order ~/ 1000;
}

// ─── M11 §91 — the five learner journeys ────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimWorld world;
  setUpAll(() async {
    world = await SimWorld.build();
  });

  group('LEARNER A — complete beginner (§91)', () {
    test('onboarding → diagnostic places them at Starter', () async {
      final learner = SimLearner(
        name: 'A',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.almostNothing,
          goal: LearningGoal.general,
          desiredLevel: DesiredLevel.beginner,
          pace: LearningPace.steady,
        ),
      );

      // Diagnostic: a beginner misses everything the app can probe.
      final result = runDiagnostic(
        world: world,
        learner: learner,
        seed: 11,
        answerFor: (_) => false,
      );

      expect(result.overallLevel, 0,
          reason: 'all-wrong placement must land at level 0 (Starter)');
      expect(learner.profile.currentLevel, 0);
      expect(learner.reviewQueue, isNotEmpty,
          reason: 'missed probes seed the review queue (M3 finish)');
      expect(learner.recentPerformance.events.length,
          result.dimensionScores.values.fold<int>(0, (s, d) => s + d.asked));
    });

    test('plan → lesson → mistakes → replan turns newLearning into '
        'weakRepair (the path changed)', () async {
      final learner = SimLearner(
        name: 'A',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.almostNothing,
        ),
      );
      runDiagnostic(
        world: world,
        learner: learner,
        seed: 11,
        answerFor: (_) => false,
      );

      final stateBefore = learningStateOf(world, learner);
      final planBefore = await buildPlan(
        world: world,
        learner: learner,
        state: stateBefore,
        diagnostic: null,
      );

      // With no mastery at all, the journey starts at the FIRST concept.
      final firstNew =
          planBefore.activities.firstWhere((a) => a.kind == ActivityKind.newLearning);
      expect(firstNew.conceptId, world.graph.concepts.first.id,
          reason: 'a beginner starts at the very beginning');

      // The learner reads the lesson, then makes mistakes in the session.
      learner.completeLesson(firstNew.lessonId!);
      runSession(
        world: world,
        learner: learner,
        stateBefore: learningStateOf(world, learner),
        kind: ActivityKind.newLearning,
        focusConceptId: firstNew.conceptId!,
        answerFor: (_) => (false, true), // every attempt wrong
      );

      final stateAfter = learningStateOf(world, learner);
      final planAfter = await buildPlan(
        world: world,
        learner: learner,
        state: stateAfter,
        diagnostic: null,
      );

      // THE §91 ADAPTIVITY CLAIM: the path changed because of the mistakes.
      expect(planAfter.activities.first.kind, ActivityKind.weakRepair,
          reason: 'a started-but-unmastered concept must be repaired FIRST');
      expect(planAfter.activities.first.conceptId, firstNew.conceptId);
      expect(planBefore.activities.first.kind, isNot(ActivityKind.weakRepair));
      // The engine also surfaced the §18 ladder for the struggling concept.
      // (its rungs are asserted in detail in the session group below).
      expect(stateAfter.stageOf(firstNew.conceptId!), isNotNull,
          reason: 'the attempt is real evidence — never fabricated');
    });
  });

  group('LEARNER B — vocabulary OK, grammar weak (§91)', () {
    test('diagnostic finds the weak dimension and seeds grammar reviews',
        () async {
      final learner = SimLearner(
        name: 'B',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.understandBasics,
          goal: LearningGoal.conversation,
        ),
      );

      // B knows the script and everyday words but the grammar probes fail.
      final result = runDiagnostic(
        world: world,
        learner: learner,
        seed: 23,
        answerFor: (item) => item.dimension != DiagnosticDimension.grammar,
      );

      expect(result.weakDimension, DiagnosticDimension.grammar,
          reason: 'the placement must NOTICE the grammar weakness');
      expect(result.overallLevel, greaterThanOrEqualTo(1),
          reason: 'B is not a Starter — words carry them up');
      // Grammar concepts B missed are queued for review, boosted.
      final grammarConcepts = {
        for (final c in world.graph.concepts)
          if (chapterOf(world, c.id) == 3) c.id,
      };
      expect(
        learner.reviewQueue.any((e) => grammarConcepts.contains(e.conceptId)),
        isTrue,
        reason: 'missed grammar probes must seed grammar reviews',
      );
    });

    test('the plan repairs/reviews grammar before charging ahead', () async {
      final learner = SimLearner(
        name: 'B',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.understandBasics,
          goal: LearningGoal.conversation,
        ),
      );
      runDiagnostic(
        world: world,
        learner: learner,
        seed: 23,
        answerFor: (item) => item.dimension != DiagnosticDimension.grammar,
      );

      final plan = await buildPlan(
        world: world,
        learner: learner,
        state: learningStateOf(world, learner),
        diagnostic: null,
      );

      final reviewTargets = [
        for (final a in plan.activities)
          if (a.kind == ActivityKind.review) a.conceptId,
      ];
      expect(reviewTargets, isNotEmpty,
          reason: 'B carries diagnostic-seeded grammar reviews');
      for (final conceptId in reviewTargets) {
        expect(chapterOf(world, conceptId!), 3,
            reason: 'B review targets must be GRAMMAR concepts, '
                'not arbitrary ones');
      }
    });
  });

  group('LEARNER C — strong beginner reaching intermediate (§91)', () {
    test('diagnostic places them ABOVE A and B', () async {
      final learner = SimLearner(
        name: 'C',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.conversational,
          desiredLevel: DesiredLevel.intermediate,
          pace: LearningPace.intense,
          dailyGoalMinutes: 20,
        ),
      );

      // C only wobbles once on grammar; everything else is solid.
      var grammarSeen = 0;
      final result = runDiagnostic(
        world: world,
        learner: learner,
        seed: 37,
        answerFor: (item) {
          if (item.dimension != DiagnosticDimension.grammar) return true;
          return grammarSeen++ > 0; // miss exactly the first grammar probe
        },
      );

      expect(result.overallLevel, greaterThan(0),
          reason: 'a strong beginner must not be placed at Starter');
      final beginner = SimLearner(
        name: 'A-ref',
        profile: LearnerProfile(language: LearnLanguage.hindi),
      );
      final beginnerResult = runDiagnostic(
        world: world,
        learner: beginner,
        seed: 11,
        answerFor: (_) => false,
      );
      expect(result.overallLevel, greaterThan(beginnerResult.overallLevel),
          reason: 'placement must separate C from a complete beginner');
    });

    test('correct-heavy sessions TRIM repetition and earn mastery; '
        'the replanned path moves FORWARD, not sideways', () async {
      final learner = SimLearner(
        name: 'C',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.conversational,
          desiredLevel: DesiredLevel.intermediate,
        ),
      );
      var grammarSeen = 0;
      runDiagnostic(
        world: world,
        learner: learner,
        seed: 37,
        answerFor: (item) {
          if (item.dimension != DiagnosticDimension.grammar) return true;
          return grammarSeen++ > 0;
        },
      );

      final planBefore = await buildPlan(
        world: world,
        learner: learner,
        state: learningStateOf(world, learner),
        diagnostic: null,
      );
      final firstNew = planBefore.activities
          .firstWhere((a) => a.kind == ActivityKind.newLearning);

      // Read the lesson, then practise the WHOLE trusted bank of the
      // lesson first-try correct (the practice route's recording rule).
      learner.completeLesson(firstNew.lessonId!);
      learner.recordMastered(
        firstNew.lessonId!,
        world.exercisesFor(firstNew.lessonId!).map((e) => e.id),
      );

      // §19 ladder order matters: a CHALLENGE applies understood material
      // (understood → applied) BEFORE a strict check certifies mastery
      // (applied → mastered). Stages only rise — a challenge can never
      // reward an already-mastered concept with a "new" stage.
      final challengeOutcome = runSession(
        world: world,
        learner: learner,
        stateBefore: learningStateOf(world, learner),
        kind: ActivityKind.challenge,
        focusConceptId: firstNew.conceptId!,
        answerFor: (_) => (true, true),
      );
      expect(
        challengeOutcome.uplifts[firstNew.conceptId!],
        MasteryStage.applied,
        reason: 'correct unsupported challenge work earns applied',
      );

      // Then the strict check certifies mastery (§19: applied → mastered).
      final checkOutcome = runSession(
        world: world,
        learner: learner,
        stateBefore: learningStateOf(world, learner),
        kind: ActivityKind.masteryCheck,
        focusConceptId: firstNew.conceptId!,
        answerFor: (_) => (true, true), // C passes the strict check
      );
      expect(
        checkOutcome.uplifts[firstNew.conceptId!],
        MasteryStage.mastered,
        reason: 'an 80%+ first-try check certifies mastery',
      );

      // Replan: C's next new learning must move FORWARD in the curriculum.
      final planAfter = await buildPlan(
        world: world,
        learner: learner,
        state: learningStateOf(world, learner),
        diagnostic: null,
      );
      final nextNew = planAfter.activities
          .firstWhere((a) => a.kind == ActivityKind.newLearning);
      expect(
        world.graph.conceptById(nextNew.conceptId!)!.order,
        greaterThan(world.graph.conceptById(firstNew.conceptId!)!.order),
        reason: 'mastery must ADVANCE the path — never repeat done work',
      );
      expect(
        planAfter.activities.where((a) => a.kind == ActivityKind.weakRepair),
        isEmpty,
        reason: 'a learner who just passed everything has nothing to repair',
      );
    });
  });

  group('LEARNER D — advanced in one skill, weak in another (§91)', () {
    test('SKIPS mastered material and repairs the weak skill', () async {
      // D arrives with the whole SCRIPT chapter mastered (a learner who
      // can already read Devanagari) but a half-done grammar chapter.
      final ch1 = world.graph.concepts.where((c) => chapterOf(world, c.id) == 0);
      final grammarChapter =
          world.graph.concepts.where((c) => chapterOf(world, c.id) == 3);
      final partialGrammar = grammarChapter.take(2).toList();

      final masteredCh1 = <String, Set<String>>{};
      final completedAll = <String>{};
      for (final c in ch1) {
        completedAll.add(c.lessonId);
        masteredCh1[c.lessonId] = {
          for (final e in world.exercisesFor(c.lessonId)) e.id,
        };
      }
      final partialMastered = <String, Set<String>>{};
      for (final c in partialGrammar) {
        completedAll.add(c.lessonId);
        final ids = world.exercisesFor(c.lessonId).map((e) => e.id).toList();
        partialMastered[c.lessonId] = ids.take(1).toSet(); // attempted, weak
      }

      final learner = SimLearner(
        name: 'D',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.recognizeScript,
          goal: LearningGoal.conversation,
        ),
        completedLessons: completedAll,
        masteredByLesson: {
          ...masteredCh1,
          ...partialMastered,
        },
      );
      // Placement: strong on script/reading, weak on grammar.
      runDiagnostic(
        world: world,
        learner: learner,
        seed: 41,
        answerFor: (item) =>
            item.dimension != DiagnosticDimension.grammar &&
            item.dimension != DiagnosticDimension.sentenceFormation,
      );

      final plan = await buildPlan(
        world: world,
        learner: learner,
        state: learningStateOf(world, learner),
        diagnostic: null,
      );

      // 1. The weak, STARTED grammar concept is repaired FIRST.
      expect(plan.activities.first.kind, ActivityKind.weakRepair);
      expect(
        chapterOf(world, plan.activities.first.conceptId!),
        3,
        reason: 'D repair targets the weak skill (grammar), '
            'never the mastered one',
      );

      // 2. New learning SKIPS the mastered chapter entirely (§95:
      //    "if they are already good at one skill, can it skip
      //    unnecessary material?" — yes).
      final newLearning =
          plan.activities.firstWhere((a) => a.kind == ActivityKind.newLearning);
      expect(
        world.graph.conceptById(newLearning.conceptId!)!.order,
        greaterThanOrEqualTo(1000),
        reason: 'chapter 1 (script) is fully mastered — new learning must '
            'start at chapter 2 or later',
      );
      for (final activity in plan.activities) {
        final conceptId = activity.conceptId;
        if (conceptId == null) continue;
        if (chapterOf(world, conceptId) == 0) {
          fail('no plan activity may target mastered chapter-1 material');
        }
      }
    });
  });

  group('LEARNER E — returning after a break (§91)', () {
    test('the plan front-loads REVIEWS and the review session keeps '
        'mastered material MAINTAINED', () async {
      // E's persisted pocket: solid progress from ~10 days ago (the
      // script AND greetings chapters behind them), one half-done daily-
      // life lesson, and a stale review queue.
      final now = DateTime.now();
      final daysAgo = now.subtract(const Duration(days: 10));
      final ch1 = world.graph.concepts.where((c) => chapterOf(world, c.id) == 0);
      final greetings =
          world.graph.concepts.where((c) => chapterOf(world, c.id) == 1);
      final daily =
          world.graph.concepts.where((c) => chapterOf(world, c.id) == 2);

      final completed = <String>{};
      final mastered = <String, Set<String>>{};
      final evidence = <String, ConceptMastery>{};
      for (final c in ch1) {
        completed.add(c.lessonId);
        mastered[c.lessonId] = {
          for (final e in world.exercisesFor(c.lessonId)) e.id,
        };
        evidence[c.id] = ConceptMastery(
          conceptId: c.id,
          stage: MasteryStage.mastered,
          strength: 0.9,
          correctCount: 6,
          attemptCount: 7,
          lastPracticedAt: daysAgo,
        );
      }
      for (final c in greetings) {
        completed.add(c.lessonId);
        mastered[c.lessonId] = {
          for (final e in world.exercisesFor(c.lessonId)) e.id,
        };
        evidence[c.id] = ConceptMastery(
          conceptId: c.id,
          stage: MasteryStage.recalled,
          strength: 0.8,
          correctCount: 5,
          attemptCount: 6,
          lastPracticedAt: daysAgo,
        );
      }
      final unfinished = daily.first; // started but NOT completed
      completed.add(unfinished.lessonId);
      final unfinishedIds =
          world.exercisesFor(unfinished.lessonId).map((e) => e.id).toList();
      mastered[unfinished.lessonId] = unfinishedIds.take(1).toSet();
      evidence[unfinished.id] = ConceptMastery(
        conceptId: unfinished.id,
        stage: MasteryStage.practiced,
        strength: 0.4,
        correctCount: 1,
        attemptCount: 3,
        lastPracticedAt: daysAgo,
      );

      final learner = SimLearner(
        name: 'E',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.understandBasics,
          goal: LearningGoal.reading,
        ),
        completedLessons: completed,
        masteredByLesson: mastered,
        evidenceMasteries: evidence,
        reviewQueue: [
          ReviewEntry(
            conceptId: ch1.last.id,
            reason: ReviewReason.agingStrong,
            priority: 0.5,
            dueAt: now.subtract(const Duration(days: 7)),
          ),
          ReviewEntry(
            conceptId: ch1.first.id,
            reason: ReviewReason.agingStrong,
            priority: 0.5,
            dueAt: now.subtract(const Duration(days: 5)),
          ),
        ],
        recentPerformance: RecentPerformance(events: [
          PerformanceEvent(
            conceptId: ch1.first.id,
            correct: true,
            firstTry: true,
            at: daysAgo,
          ),
        ]),
      );

      runDiagnostic(
        world: world,
        learner: learner,
        seed: 53,
        answerFor: (item) =>
            item.dimension == DiagnosticDimension.grammar ? false : true,
      );

      final plan = await buildPlan(
        world: world,
        learner: learner,
        state: learningStateOf(world, learner),
        diagnostic: null,
      );

      // The returning learner revisits BEFORE new material.
      final kinds = plan.activities.map((a) => a.kind).toList();
      expect(kinds.first, isIn([ActivityKind.weakRepair, ActivityKind.review]),
          reason: 'a returning learner starts with a refresher, '
              'not a new chapter — E has stale/weak evidence');
      expect(kinds.contains(ActivityKind.review), isTrue,
          reason: 'the aging queue surfaces due reviews');
      final newLearning =
          plan.activities.firstWhere((a) => a.kind == ActivityKind.newLearning);
      expect(
        world.graph.conceptById(newLearning.conceptId!)!.order,
        greaterThanOrEqualTo(2000),
        reason: 'the script + greetings chapters and the unfinished daily '
            'lesson are behind E — new learning resumes at daily-life',
      );

      // The review session itself: E still remembers — correct first try.
      final reviewOutcome = runSession(
        world: world,
        learner: learner,
        stateBefore: learningStateOf(world, learner),
        kind: ActivityKind.review,
        focusConceptId: ch1.last.id,
        answerFor: (_) => (true, true),
        at: now,
      );
      expect(
        reviewOutcome.uplifts[ch1.last.id],
        MasteryStage.maintained,
        reason: 'recalled+ material reviewed correctly is MAINTAINED (§19)',
      );
      expect(
        learner.reviewQueue
            .where((e) => e.conceptId == ch1.last.id)
            .every((e) => e.reason == ReviewReason.maintenance),
        isTrue,
        reason: 'a maintained concept drops to low-frequency maintenance',
      );
    });
  });

  group('§18 ladder under real mistakes (real-bank transcript)', () {
    test('two wrong answers descend the ladder, never repeating a question',
        () async {
      // The ladder needs room to breathe: the focus lesson must spare a
      // 3rd and 4th exercise (easier + guided rungs) and the prerequisite
      // lesson a 3rd (the prereq rung). hi_grammar_postpositions (4
      // exercises, prereq hi_grammar_gender with 4) provides exactly that.
      final focus = world.graph.concepts
          .firstWhere((c) => c.lessonId == 'hi_grammar_postpositions');
      expect(world.exercisesFor(focus.lessonId).length, 4);
      expect(
        world
            .exercisesFor(
                world.graph.conceptById(focus.prerequisites.first)!.lessonId)
            .length,
        greaterThanOrEqualTo(3),
      );

      final learner = SimLearner(
        name: 'ladder',
        profile: LearnerProfile(language: LearnLanguage.hindi),
        completedLessons: {focus.lessonId},
        masteredByLesson: {
          focus.lessonId: {
            world.exercisesFor(focus.lessonId).first.id,
          },
        },
      );

      final outcome = runSession(
        world: world,
        learner: learner,
        stateBefore: learningStateOf(world, learner),
        kind: ActivityKind.practice,
        focusConceptId: focus.id,
        answerFor: (_) => (false, true), // a hard day: everything wrong
      );

      // The §18 ladder really ran, rung by rung, on trusted material:
      // prerequisite → (explanation beat) → easier → guided.
      expect(outcome.ladderRungs.first, StepPresentation.prerequisite,
          reason: 'the graph offers a real prerequisite rung');
      expect(outcome.ladderRungs, contains(StepPresentation.easier));
      expect(outcome.ladderRungs, contains(StepPresentation.guided));
      expect(outcome.supportBeats, greaterThanOrEqualTo(1),
          reason: 'the refresher beat teaches from the trusted lesson');
      // And the same exercise was NEVER asked twice.
      final ids = outcome.engine.records.map((r) => r.exerciseId).toList();
      expect(ids.toSet().length, ids.length,
          reason: '§18: do not merely repeat the same question');
      // The wrong streak scheduled a SOON review.
      expect(
        outcome.queueUpdates
            .any((e) => e.reason == ReviewReason.recentlyWeak),
        isTrue,
      );
    });
  });

  group('§92 CRITICAL DEMONSTRATION — same language, different paths', () {
    test('A (beginner) and D (script-strong, grammar-weak) diverge', () async {
      Future<LearningPlan> planFor({
        required String name,
        required LearnerProfile profile,
        Set<String> completed = const {},
        Map<String, Set<String>> mastered = const {},
        required bool Function(DiagnosticItem) diagnosticAnswers,
        required int seed,
      }) async {
        final learner = SimLearner(
          name: name,
          profile: profile,
          completedLessons: completed,
          masteredByLesson: mastered,
        );
        runDiagnostic(
          world: world,
          learner: learner,
          seed: seed,
          answerFor: diagnosticAnswers,
        );
        return buildPlan(
          world: world,
          learner: learner,
          state: learningStateOf(world, learner),
          diagnostic: null,
        );
      }

      final planA = await planFor(
        name: 'A',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.almostNothing,
          goal: LearningGoal.general,
        ),
        diagnosticAnswers: (_) => false,
        seed: 11,
      );
      final ch1 = world.graph.concepts.where((c) => chapterOf(world, c.id) == 0);
      final grammar =
          world.graph.concepts.where((c) => chapterOf(world, c.id) == 3);
      final planD = await planFor(
        name: 'D',
        profile: LearnerProfile(
          language: LearnLanguage.hindi,
          selfReport: SelfReport.recognizeScript,
          goal: LearningGoal.conversation,
        ),
        completed: {
          for (final c in [...ch1, ...grammar.take(2)]) c.lessonId,
        },
        mastered: {
          for (final c in ch1)
            c.lessonId: {
              for (final e in world.exercisesFor(c.lessonId)) e.id,
            },
          for (final c in grammar.take(2))
            c.lessonId: {
              world.exercisesFor(c.lessonId).first.id,
            },
        },
        diagnosticAnswers: (item) =>
            item.dimension != DiagnosticDimension.grammar &&
            item.dimension != DiagnosticDimension.sentenceFormation,
        seed: 41,
      );

      // ── THE PROOF: same language, different state → different path. ──
      final kindsA = planA.activities.map((a) => a.kind.name).join(',');
      final kindsD = planD.activities.map((a) => a.kind.name).join(',');
      expect(kindsA, isNot(kindsD),
          reason: '§92: two learners on the SAME language must receive '
              'DIFFERENT learning paths');

      final newA =
          planA.activities.firstWhere((a) => a.kind == ActivityKind.newLearning);
      final newD =
          planD.activities.firstWhere((a) => a.kind == ActivityKind.newLearning);
      expect(newA.conceptId, isNot(newD.conceptId),
          reason: 'their next NEW concept differs: A starts at zero, '
              'D resumes past the mastered script chapter');
      expect(
        world.graph.conceptById(newD.conceptId!)!.order,
        greaterThan(world.graph.conceptById(newA.conceptId!)!.order),
      );

      // And every difference traces to a STATE difference:
      // A repairs nothing (nothing started) — D repairs the weak skill.
      expect(
        planA.activities.where((a) => a.kind == ActivityKind.weakRepair),
        isEmpty,
      );
      expect(
        planD.activities.first.kind,
        ActivityKind.weakRepair,
        reason: 'D state carries a started-but-unmastered grammar concept; '
            'A state carries none — the plans honestly reflect that',
      );
    });
  });

  group('determinism of the whole simulation (regression canary)', () {
    test('the same persona + seed reproduces the same diagnostic trace',
        () async {
      List<String> trace(int seed) {
        final learner = SimLearner(
          name: 'canary',
          profile: LearnerProfile(
            language: LearnLanguage.hindi,
            selfReport: SelfReport.understandBasics,
          ),
        );
        final bank = diagnosticBank(world, seed);
        final engine = DiagnosticEngine(
          bank: bank,
          seedLevel: learner.profile.selfReport.suggestedLevel,
        );
        while (!engine.isFinished) {
          engine.recordAnswer(
              engine.currentItem!.dimension != DiagnosticDimension.grammar);
          engine.advance();
        }
        final result = engine.buildResult(language: LearnLanguage.hindi);
        return [
          result.overallLevel.toString(),
          for (final record in engine.answerRecords) record.probeId,
        ];
      }

      expect(trace(23), trace(23),
          reason: 'fixed bank + seed + answers ⇒ identical run');
      expect(trace(23), isNot(trace(24)),
          reason: 'a RETAKE varies its probe list (reshuffle), '
              'so the trace is not accidentally constant');
    });
  });
}
