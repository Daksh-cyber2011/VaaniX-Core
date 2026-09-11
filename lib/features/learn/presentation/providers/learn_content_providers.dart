/// VaaniX Learn Mode — Dynamic Content Providers (M5, Master Brief §15)
///
/// Riverpod wiring for the trusted-content layer and the personalized
/// material flow:
///
/// - [trustedContentRegistryProvider]  — the A–G curricula classified as
///   TRUSTED SEEDED CONTENT (§15/§32) + per-concept knowledge excerpts
///   (§16), built from the active curriculum and the existing banks;
/// - [generatedContentRepositoryProvider] — bounded cache for generated
///   material (§35/§61);
/// - [personalizedContentGeneratorProvider] — the AI material maker
///   (shares the planner's text client → one app-wide Gemini budget);
/// - [smartPracticeProvider] — the Smart Practice controller the screen
///   renders: trusted-first resolution for today's plan activity
///   (§34 priority ladder) with learner-triggered personalization.
///
/// Dependency direction: THIS file imports `spine_providers` (it consumes
/// the validated plan / planner context), so nothing downstream of the
/// spine may import this file — the graph stays one-way and acyclic.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/data/personalized_content_generator.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';

// ─── Trusted seeded content (§15/§32) ───────────────────────────────────────

/// The trusted content registry for the ACTIVE Learn language.
///
/// Empty when no language is selected or the curriculum is a stub —
/// never an error, the smart-practice flow surfaces that honestly.
final trustedContentRegistryProvider =
    FutureProvider<TrustedContentRegistry>((ref) async {
  final selected = ref.watch(selectedLearnLanguageProvider);
  if (selected == null) return TrustedContentRegistry.empty();

  final spec = learnLanguageSpec(selected);
  final chapters = await ref.watch(activeCurriculumProvider.future);
  final graph =
      ConceptGraph.forCurriculum(languageCode: spec.code, chapters: chapters);
  if (graph.isEmpty) {
    return TrustedContentRegistry(
      languageCode: spec.code,
      isRTL: spec.isRTL,
      scriptCode: spec.scriptCode,
      entries: const [],
      excerpts: const {},
    );
  }

  final exercises = <String, List<Exercise>>{};
  for (final concept in graph.concepts) {
    exercises[concept.lessonId] =
        ref.watch(exercisesForLessonProvider(concept.lessonId));
  }

  return TrustedContentRegistry.build(
    graph: graph,
    chapters: chapters,
    exercisesByLesson: exercises,
    isRTL: spec.isRTL,
    scriptCode: spec.scriptCode,
  );
});

// ─── Generated-material plumbing (§16/§35/§61) ──────────────────────────────

/// The bounded cache for AI-personalized material (§35).
final generatedContentRepositoryProvider =
    Provider<GeneratedContentRepository>(
  (ref) => GeneratedContentRepository(ref.watch(localStorageServiceProvider)),
);

/// The AI material maker. It reuses the PLANNER's text client on purpose:
/// one Gemini client configuration, one app-wide 15 RPM budget (§36) —
/// planner and material maker share it. Tests override
/// [plannerTextClientProvider] with a fake; no network anywhere.
final personalizedContentGeneratorProvider =
    Provider<PersonalizedContentGenerator>(
  (ref) => PersonalizedContentGenerator(
    textClient: ref.watch(plannerTextClientProvider),
    cache: ref.watch(generatedContentRepositoryProvider),
  ),
);

// ─── Smart Practice controller (the screen's state machine) ────────────────

/// Phases of the Smart Practice screen. `ready` means trusted content is
/// resolved; personalization happens INSIDE `ready` (it never replaces
/// the trusted view, only adds to it — §34).
enum SmartPracticePhase { idle, loading, ready, unavailable }

/// The plan activity the screen is currently focused on, projected onto
/// the trusted registry.
class SmartPracticeActivity {
  const SmartPracticeActivity({
    required this.activityId,
    required this.kind,
    required this.title,
    required this.reason,
    required this.conceptId,
    required this.lessonId,
    required this.difficultyKnob,
    required this.planSource,
  });

  final String activityId;
  final ActivityKind kind;
  final String title;

  /// The plan's personal "why" (Master Brief §44).
  final String reason;
  final String conceptId;
  final String lessonId;
  final int difficultyKnob;
  final PlanSource planSource;
}

/// Immutable snapshot the Smart Practice screen renders.
class SmartPracticeState {
  const SmartPracticeState({
    this.phase = SmartPracticePhase.idle,
    this.languageCode,
    this.languageName,
    this.unavailableReason,
    this.activity,
    this.lessonEntry,
    this.exerciseEntries = const <TrustedContent>[],
    this.personalizingKind,
    this.material,
    this.materialError,
  });

  const SmartPracticeState.idle() : this();

  const SmartPracticeState.loading({
    required String languageCode,
    required String languageName,
  }) : this(
          phase: SmartPracticePhase.loading,
          languageCode: languageCode,
          languageName: languageName,
        );

  const SmartPracticeState.unavailable(
    String reason, {
    String? languageCode,
    String? languageName,
  }) : this(
          phase: SmartPracticePhase.unavailable,
          unavailableReason: reason,
          languageCode: languageCode,
          languageName: languageName,
        );

  final SmartPracticePhase phase;
  final String? languageCode;
  final String? languageName;

  /// Set in `unavailable` — the honest "why" (Master Brief §46 safe
  /// states, never a crash).
  final String? unavailableReason;

  /// The resolved plan activity + its trusted content (ready phase).
  final SmartPracticeActivity? activity;
  final TrustedContent? lessonEntry;
  final List<TrustedContent> exerciseEntries;

  /// The kind currently being personalized (null when idle).
  final GeneratedContentKind? personalizingKind;

  /// The last accepted personalization (cached or fresh — see
  /// [GeneratedContentResult.fromCache]).
  final GeneratedContentResult? material;

  /// Friendly, honest failure note for the LAST personalization attempt.
  final String? materialError;

  SmartPracticeState copyWith({
    SmartPracticePhase? phase,
    String? languageCode,
    String? languageName,
    String? unavailableReason,
    SmartPracticeActivity? activity,
    TrustedContent? lessonEntry,
    List<TrustedContent>? exerciseEntries,
    GeneratedContentKind? personalizingKind,
    GeneratedContentResult? material,
    String? materialError,
    bool clearPersonalizing = false,
    bool clearMaterial = false,
    bool clearMaterialError = false,
  }) {
    return SmartPracticeState(
      phase: phase ?? this.phase,
      languageCode: languageCode ?? this.languageCode,
      languageName: languageName ?? this.languageName,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      activity: activity ?? this.activity,
      lessonEntry: lessonEntry ?? this.lessonEntry,
      exerciseEntries: exerciseEntries ?? this.exerciseEntries,
      personalizingKind:
          clearPersonalizing ? null : (personalizingKind ?? this.personalizingKind),
      material: clearMaterial ? null : (material ?? this.material),
      materialError:
          clearMaterialError ? null : (materialError ?? this.materialError),
    );
  }
}

/// Drives the Smart Practice flow for the ACTIVE language:
///
///   prepare()     — trusted-first resolution of today's plan activity
///                   (§34: validated trusted content wins, ZERO AI calls);
///   personalize() — learner-triggered AI personalization of that
///                   activity's concept (§15 "where safe and supported"),
///                   validated + cached + honestly labelled.
class SmartPracticeController extends StateNotifier<SmartPracticeState> {
  SmartPracticeController(this._ref) : super(const SmartPracticeState.idle());

  final Ref _ref;

  /// Resolves today's trusted content. Reads the validated plan (no
  /// re-planning — the spine's cached plan is reused) and the registry;
  /// makes NO AI calls by design (§34: trusted content is preferred).
  Future<void> prepare() async {
    final selected = _ref.read(selectedLearnLanguageProvider);
    if (selected == null) {
      state = const SmartPracticeState.unavailable(
        'Pick a language in Learn first — VAN personalizes one language '
        'at a time.',
      );
      return;
    }
    final spec = learnLanguageSpec(selected);
    state = SmartPracticeState.loading(
      languageCode: spec.code,
      languageName: spec.englishName,
    );

    final plan = await _ref.read(activeLearningPlanProvider.future);
    final registry = await _ref.read(trustedContentRegistryProvider.future);

    if (registry.isEmpty) {
      state = SmartPracticeState.unavailable(
        'VAN can personalize once this language has lessons with trusted '
        'material.',
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }
    if (plan.isEmpty) {
      state = SmartPracticeState.unavailable(
        'No plan yet — play the placement game or finish a lesson and '
        "VAN will shape today's focus.",
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }

    // First plan activity whose concept has trusted content — the plan
    // is validated against the same graph, so this is a lookup, not a
    // second validation pass.
    SmartPracticeActivity? resolved;
    TrustedContent? lessonEntry;
    List<TrustedContent> exerciseEntries = const [];
    for (var i = 0; i < plan.activityConceptIds.length; i++) {
      final conceptId = plan.activityConceptIds[i];
      if (conceptId == null) continue;
      final entry = registry.lessonEntryFor(conceptId);
      if (entry == null) continue;
      resolved = SmartPracticeActivity(
        activityId: i < plan.activityIds.length
            ? plan.activityIds[i]
            : 'act-$i',
        kind: i < plan.activityKinds.length
            ? plan.activityKinds[i]
            : ActivityKind.practice,
        title: i < plan.activityTitles.length
            ? plan.activityTitles[i]
            : entry.title,
        reason: i < plan.activityReasons.length
            ? plan.activityReasons[i]
            : '',
        conceptId: conceptId,
        lessonId: entry.lessonId,
        difficultyKnob: i < plan.activityDifficulties.length
            ? difficultyKnobForBand(plan.activityDifficulties[i])
            : 2,
        planSource: plan.source,
      );
      lessonEntry = entry;
      exerciseEntries = registry.exerciseEntriesFor(conceptId);
      break;
    }

    if (resolved == null) {
      state = SmartPracticeState.unavailable(
        'VAN could not ground today\'s plan in trusted material — open a '
        'lesson below instead.',
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }

    state = SmartPracticeState(
      phase: SmartPracticePhase.ready,
      languageCode: spec.code,
      languageName: spec.englishName,
      activity: resolved,
      lessonEntry: lessonEntry,
      exerciseEntries: exerciseEntries,
    );
  }

  /// Generates (or serves cached) personalized material of [kind] for
  /// the resolved activity's concept. Never throws; on failure the
  /// trusted view stays untouched and an honest note is set (§46).
  Future<void> personalize(GeneratedContentKind kind) async {
    final current = state;
    if (current.phase != SmartPracticePhase.ready || current.activity == null) {
      return;
    }
    if (current.personalizingKind != null) return; // one at a time

    final activity = current.activity!;
    state = current.copyWith(personalizingKind: kind, clearMaterialError: true);

    try {
      final selected = _ref.read(selectedLearnLanguageProvider);
      if (selected == null) {
        state = state.copyWith(
          personalizingKind: null,
          clearPersonalizing: true,
          materialError: 'Pick a language first.',
        );
        return;
      }
      final spec = learnLanguageSpec(selected);
      final graph = await _ref.read(activeConceptGraphProvider.future);
      final concept = graph.conceptById(activity.conceptId);
      final registry = await _ref.read(trustedContentRegistryProvider.future);
      final context = await _ref.read(activePlannerContextProvider.future);
      final generator = _ref.read(personalizedContentGeneratorProvider);

      if (concept == null) {
        state = state.copyWith(
          personalizingKind: null,
          clearPersonalizing: true,
          materialError:
              'That concept is no longer in the trusted curriculum.',
        );
        return;
      }

      final result = await generator.generate(
        spec: spec,
        conceptId: concept.id,
        conceptTitle: concept.title,
        conceptSubtitle: concept.subtitle,
        excerpt: registry.excerptFor(concept.id),
        kind: kind,
        difficultyKnob: activity.difficultyKnob,
        learnerDigest: context.toStructuredDigest(),
      );

      result.fold(
        (failure) => state = state.copyWith(
          personalizingKind: null,
          clearPersonalizing: true,
          materialError: _friendlyMessage(failure),
        ),
        (material) => state = state.copyWith(
          personalizingKind: null,
          clearPersonalizing: true,
          material: material,
          clearMaterialError: true,
        ),
      );
    } catch (_) {
      // Absolute safety net (§46): personalization can never break the
      // trusted view.
      state = state.copyWith(
        personalizingKind: null,
        clearPersonalizing: true,
        materialError: 'VAN could not personalize just now — the trusted '
            'material below stays your path.',
      );
    }
  }

  /// Clears the personalization result (back to the trusted-only view).
  void dismissMaterial() {
    state = state.copyWith(clearMaterial: true, clearMaterialError: true);
  }

  /// Returns to idle (screen closed / language switched).
  void reset() => state = const SmartPracticeState.idle();

  /// §44 tone: human words for the typed failures, honest about the
  /// fallback. Raw reasons stay in the failure for diagnostics.
  String _friendlyMessage(Failure failure) {
    final message = failure.message;
    if (message.contains('declined')) {
      return 'VAN could not craft this one safely from the trusted '
          'material — try again in a little while.';
    }
    if (message.contains('not available') || message.contains('not grounded')) {
      return "VAN's AI helper is offline right now. The trusted material "
          'below still works.';
    }
    if (failure is TimeoutFailure) {
      return 'That took too long — VAN kept the trusted material instead.';
    }
    return 'VAN could not personalize just now — the trusted material '
        'below stays your path.';
  }
}

final smartPracticeProvider =
    StateNotifierProvider<SmartPracticeController, SmartPracticeState>(
  (ref) => SmartPracticeController(ref),
);
