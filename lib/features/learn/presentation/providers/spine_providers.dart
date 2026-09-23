/// Learn Mode 2.0 — Spine Providers (M1 Architecture Foundation)
///
/// Riverpod wiring between the EXISTING Learn/progress providers and the
/// NEW M1 spine:
///
///   active curriculum ──► [activeConceptGraphProvider]      (trusted graph)
///   progress data ─────► [activeLearningStateProvider]      (evidence)
///   both ──────────────► [activePlannerContextProvider]     (structured ctx)
///   ctx ───────────────► [learningPlannerProvider]          (validated plan)
///
/// M1 shipped the DETERMINISTIC planner behind the [ValidatingPlanner]
/// guard. M4 swaps the delegate to the Gemini planner (one line here —
/// the whole app keeps consuming [learningPlannerProvider] unchanged),
/// honouring the Master Brief's replaceable-provider rule. The full
/// §36/§60 chain now reads:
///
///   AI plan → cached plan → deterministic → empty-but-valid
///
/// M3: [activeLearningStateProvider] now MERGES the persisted review-queue
/// / recent-performance extras seeded by the placement flow, and
/// [activePlannerContextProvider] carries the structured
/// [DiagnosticResult] — completing the Diagnostic → Planner edge of the
/// spine (Master Brief §13 "planner reads diagnostic results").
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery_scheduling.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/curriculum_compatibility_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// ISO 639-1 code used for the legacy Sanskrit track when NO Learn Mode
/// language is selected (the pre-Part-0 default path).
const String kLegacySanskritLanguageCode = 'sa';

/// Trusted concept graph for the ACTIVE curriculum.
///
/// - Learn language selected → that language's graph (hi/bn/…/ur).
/// - Nothing selected → the legacy Sanskrit curriculum's graph (`sa`).
/// - Stub languages (kn/ml/or) → an EMPTY graph; downstream providers
///   treat that as "curriculum on its way", never as an error.
final activeConceptGraphProvider = FutureProvider<ConceptGraph>((ref) async {
  final chapters = await ref.watch(activeCurriculumProvider.future);
  final selected = ref.watch(selectedLearnLanguageProvider);
  final code = selected == null
      ? kLegacySanskritLanguageCode
      : learnLanguageSpec(selected).code;
  return ConceptGraph.forCurriculum(languageCode: code, chapters: chapters);
});

/// Evidence-based learning state for the ACTIVE language, derived from the
/// EXISTING progress repository data (completed lessons + mastered
/// exercises) mapped onto the concept graph — no new storage in M1.
///
/// M3: the persisted review-queue / recent-performance extras seeded by
/// the placement flow are merged in (the derivation stays authoritative
/// for concept masteries — extras only carry what derivation cannot
/// know). Rebuilds automatically when a diagnostic run persists new
/// extras ([learnStateExtrasProvider] re-reads on the session signal).
///
/// M6: the extras' conceptMasteries now also carry SESSION EVIDENCE
/// (recalled/applied/mastered/maintained stages earned by adaptive
/// sessions, plus review scheduling). The derivation stays
/// authoritative for progress-backed stages; [applyMasteryEvidence]
/// overlays only what derivation cannot know — and never lowers a
/// stage.
final activeLearningStateProvider = FutureProvider<LearningState>((ref) async {
  final selected = ref.watch(selectedLearnLanguageProvider);
  if (selected != null) {
    await ref.watch(curriculumCompatibilityProvider(selected).future);
  }
  final graph = await ref.watch(activeConceptGraphProvider.future);
  final completed = ref.watch(completedLessonIdsProvider).toSet();
  final extras =
      selected == null ? null : ref.watch(learnStateExtrasProvider(selected));

  final masteredByLesson = <String, List<String>>{};
  final exerciseCounts = <String, int>{};
  final validConceptIds = graph.concepts.map((c) => c.id).toSet();
  for (final concept in graph.concepts) {
    final currentExercises =
        ref.watch(exercisesForLessonProvider(concept.lessonId));
    final currentIds = [for (final exercise in currentExercises) exercise.id];
    final persisted = ref.watch(masteredExercisesProvider(concept.lessonId));
    masteredByLesson[concept.lessonId] =
        validMasteredExerciseIds(persisted, currentIds);
    exerciseCounts[concept.lessonId] = currentIds.length;
  }

  final validQueue = extras?.reviewQueue
      .where((entry) => validConceptIds.contains(entry.conceptId))
      .toList(growable: false);
  final validPerformance = extras == null
      ? const RecentPerformance()
      : RecentPerformance(
          events: extras.recentPerformance.events
              .where((event) => validConceptIds.contains(event.conceptId))
              .toList(growable: false),
        );

  final derived = deriveLearningState(
    languageCode: graph.languageCode,
    graph: graph,
    snapshot: ProgressSnapshot(
      completedLessonIds: completed,
      masteredExerciseIdsByLesson: masteredByLesson,
      exerciseCountByLesson: exerciseCounts,
    ),
    reviewQueue: validQueue ?? const <ReviewEntry>[],
    recentPerformance: validPerformance,
  );

  // M6 evidence overlay (no-op when the extras carry no evidence).
  final evidence = extras?.conceptMasteries ?? const <String, ConceptMastery>{};
  if (evidence.isEmpty) return derived;
  return applyMasteryEvidence(
    derived: derived,
    evidence: evidence,
    validConceptIds: validConceptIds,
  );
});

/// Assembled structured planner context for the ACTIVE language.
///
/// M2: the learner's saved profile (goal / desired level / pace / daily
/// goal) now flows into the context — session sizing comes from the
/// learner's own daily-goal minutes.
///
/// M3: the last placement result flows in as well (Master Brief §13 —
/// "diagnostic results" are planner input); `null` until the learner
/// takes the placement game, and the digest stays truthful because every
/// field is derived from real data.
final activePlannerContextProvider =
    FutureProvider<PlannerContext>((ref) async {
  final graph = await ref.watch(activeConceptGraphProvider.future);
  final state = await ref.watch(activeLearningStateProvider.future);
  final selected = ref.watch(selectedLearnLanguageProvider);
  final profile = ref.watch(activeLearnerProfileProvider);
  final diagnostic =
      selected == null ? null : ref.watch(lastDiagnosticProvider(selected));

  final languageName =
      selected == null ? 'Sanskrit' : learnLanguageSpec(selected).englishName;

  return PlannerContext(
    languageCode: graph.languageCode,
    languageName: languageName,
    graph: graph,
    state: state,
    profile: profile,
    diagnostic: diagnostic,
    minutesAvailable:
        profile?.dailyGoalMinutes ?? LearnerProfile.kDefaultDailyGoalMinutes,
    supportedActivityTypes: kDeterministicPlannerActivityKinds,
  );
});

/// The replaceable planning boundary for the whole app.
///
/// M4 chain (Master Brief §36/§60): the Gemini planner is the delegate;
/// when it fails, returns nothing grounded, or is simply not configured,
/// the fallback facade serves the last cached AI plan, and only then the
/// deterministic plan. EVERY hop re-validates against the trusted graph,
/// so an AI outage degrades one step at a time instead of breaking
/// Learn Mode.
final learningPlannerProvider = Provider<LearningPlanner>((ref) {
  const deterministic = DeterministicPlanner();
  final gemini = ref.watch(geminiPlannerProvider);
  final cached = ref.watch(cachedPlanPlannerProvider);
  return ValidatingPlanner(
    delegate: gemini,
    fallback: ValidatingPlanner(delegate: cached, fallback: deterministic),
  );
});

/// Convenience: the validated plan for the ACTIVE language right now.
///
/// Returns an empty-but-valid plan while the graph/state are still loading
/// (never blocks callers) — consumers render their own loading/empty UI.
final activeLearningPlanProvider = FutureProvider<LearningPlanLike>(
  (ref) async {
    final context = await ref.watch(activePlannerContextProvider.future);
    final planner = ref.watch(learningPlannerProvider);
    final result = await planner.buildPlan(context);
    return result.fold(
      (failure) => LearningPlanLike.empty(
        languageCode: context.languageCode,
        reason: failure.message,
      ),
      (plan) => LearningPlanLike.fromPlan(plan),
    );
  },
);

/// UI-facing plan view that is always safe to render.
///
/// (Small wrapper so screens never need to unwrap Either or AsyncValue —
/// the spine guarantees one of: a validated plan, or an empty plan with a
/// human-readable reason.)
///
/// M5 (additive): per-activity parallel lists (concept anchors, kinds,
/// reasons, difficulties) so content resolution can ground plan steps in
/// the trusted registry WITHOUT widening the plan contract itself. All
/// M4 consumers keep working unchanged.
class LearningPlanLike {
  const LearningPlanLike._({
    required this.languageCode,
    required this.source,
    required this.activityIds,
    required this.activityTitles,
    required this.focusSummary,
    this.activityConceptIds = const <String?>[],
    this.activityKinds = const <ActivityKind>[],
    this.activityReasons = const <String>[],
    this.activityDifficulties = const <Difficulty>[],
  });

  factory LearningPlanLike.fromPlan(LearningPlan plan) {
    return LearningPlanLike._(
      languageCode: plan.languageCode,
      source: plan.source,
      activityIds: [for (final a in plan.activities) a.id],
      activityTitles: [for (final a in plan.activities) a.title],
      focusSummary: plan.focusSummary,
      activityConceptIds: [for (final a in plan.activities) a.conceptId],
      activityKinds: [for (final a in plan.activities) a.kind],
      activityReasons: [for (final a in plan.activities) a.reason],
      activityDifficulties: [for (final a in plan.activities) a.difficulty],
    );
  }

  factory LearningPlanLike.empty({
    required String languageCode,
    required String reason,
    PlanSource source = PlanSource.deterministic,
  }) {
    return LearningPlanLike._(
      languageCode: languageCode,
      source: source,
      activityIds: const [],
      activityTitles: const [],
      focusSummary: reason,
    );
  }

  final String languageCode;

  /// Where this plan came from (M4 — honest AI labelling, Master Brief
  /// §63): ai / cached / deterministic. UIs may show it; logic must not
  /// branch on it (the plan is already validated either way).
  final PlanSource source;

  final List<String> activityIds;
  final List<String> activityTitles;
  final String? focusSummary;

  /// M5 parallel projections (index-aligned with [activityIds]).
  final List<String?> activityConceptIds;
  final List<ActivityKind> activityKinds;
  final List<String> activityReasons;
  final List<Difficulty> activityDifficulties;

  bool get isEmpty => activityIds.isEmpty;
}
