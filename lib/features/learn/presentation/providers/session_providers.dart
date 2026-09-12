/// VaaniX Learn Mode — Adaptive Session Providers (M6, Master Brief §18)
///
/// Riverpod wiring for the LIVE adaptive session engine:
///
/// - [adaptiveSessionProvider] — drives one session through any of the
///   SIX activity kinds (§18), materializing engine steps, feedback
///   beats, and the finish pipeline;
/// - the finish pipeline PERSISTS FIRST, then publishes: per-concept
///   session evidence (stage uplifts — review→recalled, challenge→
///   applied, check→mastered — §19), §20 review-queue updates, recent
///   performance events, and trusted-exercise mastery through the
///   EXISTING idempotent progress path;
/// - AI-generated exercises enter sessions ONLY from the M5 validated
///   cache, and their `gen-` ids are NEVER recorded into trusted
///   progress (M5's honesty rule — generated material tunes the path,
///   it never writes it).
///
/// Dependency direction: this file imports `spine_providers` (it reads
/// the validated learning state) — nothing downstream of the spine may
/// import it, the graph stays one-way and acyclic.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery_scheduling.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_content_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';

// ─── Session state ──────────────────────────────────────────────────────────

/// Phases of the guided session flow (mirrors the diagnostic flow's
/// pacing: the engine adapts immediately, the UI shows a feedback beat
/// first — Master Brief §43/§44).
enum AdaptiveSessionPhase {
  idle,
  loading,
  active,
  feedback,
  finished,
  unavailable
}

/// Immutable snapshot the session screen renders.
class AdaptiveSessionState {
  const AdaptiveSessionState._({
    required this.phase,
    this.languageCode,
    this.languageName,
    this.unavailableReason,
    this.kind,
    this.focusConceptId,
    this.focusTitle,
    this.currentStep,
    this.stepIndex = 0,
    this.exerciseBudget = 0,
    this.lastStep,
    this.lastWasCorrect = false,
    this.lastWasFirstTry = false,
    this.answered = 0,
    this.firstTryCorrect = 0,
    this.conceptsTouched = 0,
  });

  const AdaptiveSessionState.idle() : this._(phase: AdaptiveSessionPhase.idle);

  const AdaptiveSessionState.loading({
    required String languageCode,
    required String languageName,
  }) : this._(
          phase: AdaptiveSessionPhase.loading,
          languageCode: languageCode,
          languageName: languageName,
        );

  const AdaptiveSessionState.unavailable(
    String reason, {
    String? languageCode,
    String? languageName,
  }) : this._(
          phase: AdaptiveSessionPhase.unavailable,
          unavailableReason: reason,
          languageCode: languageCode,
          languageName: languageName,
        );

  final AdaptiveSessionPhase phase;
  final String? languageCode;
  final String? languageName;

  /// Set in `unavailable` — the honest "why" (never a crash).
  final String? unavailableReason;

  /// Which of the SIX kinds this session runs (drives copy + honesty).
  final ActivityKind? kind;

  /// The concept the session was launched for (null for pure review runs
  /// that had no trusted pool).
  final String? focusConceptId;
  final String? focusTitle;

  /// The step to render in `active` phase (exercise or support beat).
  final SessionStep? currentStep;

  /// 1-based index of the current step (friendly meter; never a countdown).
  final int stepIndex;

  /// Exercise-step budget (steps may end earlier via adaptation).
  final int exerciseBudget;

  /// The step just answered, shown during `feedback`.
  final SessionStep? lastStep;
  final bool lastWasCorrect;
  final bool lastWasFirstTry;

  /// Running tallies for the finish view (no raw jargon — §44).
  final int answered;
  final int firstTryCorrect;
  final int conceptsTouched;

  AdaptiveSessionState copyWith({
    AdaptiveSessionPhase? phase,
    String? unavailableReason,
    SessionStep? currentStep,
    int? stepIndex,
    int? exerciseBudget,
    SessionStep? lastStep,
    bool? lastWasCorrect,
    bool? lastWasFirstTry,
    int? answered,
    int? firstTryCorrect,
    int? conceptsTouched,
    bool clearLastStep = false,
  }) {
    return AdaptiveSessionState._(
      phase: phase ?? this.phase,
      languageCode: languageCode,
      languageName: languageName,
      kind: kind,
      focusConceptId: focusConceptId,
      focusTitle: focusTitle,
      currentStep: currentStep,
      stepIndex: stepIndex ?? this.stepIndex,
      exerciseBudget: exerciseBudget ?? this.exerciseBudget,
      lastStep: clearLastStep ? null : (lastStep ?? this.lastStep),
      lastWasCorrect: lastWasCorrect ?? this.lastWasCorrect,
      lastWasFirstTry: lastWasFirstTry ?? this.lastWasFirstTry,
      answered: answered ?? this.answered,
      firstTryCorrect: firstTryCorrect ?? this.firstTryCorrect,
      conceptsTouched: conceptsTouched ?? this.conceptsTouched,
    );
  }
}

/// Drives ONE adaptive session for the ACTIVE language.
///
/// The engine owns selection + adaptation ([AdaptiveSessionEngine]);
/// this controller owns resolution, UI pacing, analytics, and the
/// persist-first finish pipeline.
class AdaptiveSessionController extends StateNotifier<AdaptiveSessionState> {
  AdaptiveSessionController(this._ref)
      : super(const AdaptiveSessionState.idle());

  final Ref _ref;
  AdaptiveSessionEngine? _engine;
  LearnLanguage? _language;
  ActivityKind _kind = ActivityKind.practice;

  /// Trusted lesson ids per concept (for trusted mastery recording).
  final Map<String, String> _lessonByConcept = {};

  /// Trusted exercise ids per lesson (the recording filter).
  final Map<String, Set<String>> _trustedIdsByLesson = {};

  /// Launches a session of [kind] anchored at [conceptId]. All SIX
  /// kinds are understood; the trusted graph, banks, M5 generated
  /// cache and review queue shape the session — ZERO AI calls happen
  /// here (personalization stays learner-triggered in Smart Practice;
  /// sessions reuse its validated cache).
  Future<void> start({
    required ActivityKind kind,
    required String conceptId,
    int? difficultyKnob,
  }) async {
    final selected = _ref.read(selectedLearnLanguageProvider);
    if (selected == null) {
      state = const AdaptiveSessionState.unavailable(
        'Pick a language in Learn first — VAN personalizes one language '
        'at a time.',
      );
      return;
    }
    final spec = learnLanguageSpec(selected);
    state = AdaptiveSessionState.loading(
      languageCode: spec.code,
      languageName: spec.englishName,
    );

    final graph = await _ref.read(activeConceptGraphProvider.future);
    final concept = graph.conceptById(conceptId);
    if (concept == null) {
      state = AdaptiveSessionState.unavailable(
        'That concept is no longer in the trusted curriculum.',
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }

    final knob = (difficultyKnob ?? 2).clamp(1, 5).toInt();
    _kind = kind;
    _language = selected;
    _lessonByConcept.clear();
    _trustedIdsByLesson.clear();

    // ── Focus concepts: the anchor first; review/weakRepair sessions
    //    add up to two more due concepts from the persisted queue.
    final focusIds = <String>[concept.id];
    if (kind == ActivityKind.review || kind == ActivityKind.weakRepair) {
      final learningState = await _ref.read(activeLearningStateProvider.future);
      for (final entry in learningState.reviewQueue) {
        if (focusIds.length >= 3) break;
        if (focusIds.contains(entry.conceptId)) continue;
        final c = graph.conceptById(entry.conceptId);
        if (c == null) continue;
        if (_ref.read(exercisesForLessonProvider(c.lessonId)).isEmpty) {
          continue;
        }
        focusIds.add(c.id);
      }
    }

    // ── Pools + explanations + prerequisite map (trusted only).
    final pools = <SessionExercisePool>[];
    final explanations = <String, String>{};
    final prerequisiteOf = <String, String?>{};
    final cache = _ref.read(generatedContentRepositoryProvider);
    final registry = await _ref.read(trustedContentRegistryProvider.future);

    void addConcept(String id) {
      final c = graph.conceptById(id);
      if (c == null || pools.any((p) => p.conceptId == id)) return;
      final trusted = _ref.read(exercisesForLessonProvider(c.lessonId));
      _lessonByConcept[id] = c.lessonId;
      _trustedIdsByLesson[c.lessonId] = {
        for (final e in trusted) e.id,
      };
      pools.add(SessionExercisePool(
        conceptId: id,
        exercises: trusted,
        generatedVariants: _cachedGeneratedVariants(
          cache,
          selected,
          id,
          knob,
        ),
      ));
      final excerpt = registry.excerptFor(id);
      final text = excerpt.referenceText.trim().isEmpty
          ? excerpt.exampleSentences.join(' ')
          : excerpt.referenceText;
      if (text.trim().isNotEmpty) explanations[id] = text.trim();
      prerequisiteOf[id] =
          c.prerequisites.isEmpty ? null : c.prerequisites.first;
    }

    for (final id in focusIds) {
      addConcept(id);
    }
    // Prerequisites need their own pools to serve ladder rungs.
    for (final id in List.of(focusIds)) {
      final prereq = prerequisiteOf[id];
      if (prereq != null) addConcept(prereq);
    }

    final usable = pools.where((p) => p.exercises.isNotEmpty).toList();
    if (usable.isEmpty) {
      state = AdaptiveSessionState.unavailable(
        'There is no trusted practice material for this focus yet — try '
        'again after the next lesson unlocks.',
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }

    final reviewFirst =
        kind == ActivityKind.review || kind == ActivityKind.weakRepair
            ? await _reviewQueueConceptIds()
            : const <String>[];

    _engine = AdaptiveSessionEngine(
      config: AdaptiveSessionConfig(
        kind: kind,
        languageCode: spec.code,
        pools: usable,
        explanations: explanations,
        prerequisiteOf: prerequisiteOf,
        difficultyKnob: knob,
        maxSteps: 10,
        reviewFirstConceptIds: reviewFirst,
      ),
    );

    final engine = _engine!;
    final first = engine.currentStep;
    if (first == null) {
      state = AdaptiveSessionState.unavailable(
        'VAN could not build a session from the trusted material right '
        'now — everything below still works.',
        languageCode: spec.code,
        languageName: spec.englishName,
      );
      return;
    }

    _ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
          VanEventType.quizStarted,
          message: _vanStartLine(kind, concept.title),
          payload: {'conceptId': concept.id, 'kind': kind.name},
        ));

    state = AdaptiveSessionState._(
      phase: AdaptiveSessionPhase.active,
      languageCode: spec.code,
      languageName: spec.englishName,
      kind: kind,
      focusConceptId: concept.id,
      focusTitle: concept.title,
      currentStep: first,
      stepIndex: 1,
      exerciseBudget: engine.maxSteps,
    );
  }

  /// Records the learner's answer to the current exercise step and
  /// moves to the feedback beat. [firstTry] mirrors the practice
  /// engine's retry semantics.
  void submitAnswer({required bool correct, required bool firstTry}) {
    final engine = _engine;
    final step = state.currentStep;
    if (engine == null || step == null || step.isSupport) return;
    if (state.phase != AdaptiveSessionPhase.active) return;

    engine.submitAnswer(correct: correct, firstTry: firstTry);

    _ref.read(analyticsClientProvider).log(AnalyticsEvent(
          AnalyticsEventName.exerciseCompleted,
          {
            'exerciseId': step.exercise!.id,
            'correct': correct,
            'firstTry': firstTry,
            'source': 'adaptive_session',
            'kind': _kind.name,
          },
        ));

    _ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
          correct
              ? VanEventType.quizAnswerCorrect
              : VanEventType.quizAnswerWrong,
          message: correct ? null : "Let's take this one step at a time.",
          payload: {'conceptId': step.conceptId},
        ));

    state = state.copyWith(
      phase: AdaptiveSessionPhase.feedback,
      lastStep: step,
      lastWasCorrect: correct,
      lastWasFirstTry: firstTry,
      answered: state.answered + 1,
      firstTryCorrect: state.firstTryCorrect + (correct && firstTry ? 1 : 0),
    );
  }

  /// Leaves the feedback beat (or a support/explanation beat): shows the
  /// engine's next step, or runs the finish pipeline (persist first,
  /// publish last).
  Future<void> next() async {
    final engine = _engine;
    if (engine == null) return;
    final onFeedback = state.phase == AdaptiveSessionPhase.feedback;
    final onSupport = state.phase == AdaptiveSessionPhase.active &&
        (state.currentStep?.isSupport ?? false);
    if (!onFeedback && !onSupport) return;

    engine.advance();
    final nextStep = engine.currentStep;
    if (nextStep != null) {
      state = state.copyWith(
        phase: AdaptiveSessionPhase.active,
        currentStep: nextStep,
        stepIndex: state.stepIndex + 1,
        clearLastStep: true,
      );
      return;
    }

    // ── Finish pipeline: persist first, publish last. ──
    final now = DateTime.now();
    final records = engine.records;
    final evidence = evidenceFromRecords(records, at: now);
    final language = _language!;

    final learningState = await _ref.read(activeLearningStateProvider.future);
    final currentStages = <String, MasteryStage?>{
      for (final id in evidence.keys) id: learningState.stageOf(id),
    };
    final lastPracticed = <String, DateTime?>{
      for (final id in evidence.keys)
        id: learningState.conceptMasteries[id]?.lastPracticedAt,
    };

    final repo = _ref.read(learnProfileRepositoryProvider);
    final priorExtras = repo.getLearningState(language);
    final priorEvidence = priorExtras?.conceptMasteries ?? const {};

    final newEvidence = buildEvidenceMasteries(
      kind: _kind,
      evidence: evidence,
      priorEvidence: priorEvidence,
      currentStages: currentStages,
      at: now,
    );
    final queueUpdates = scheduleReviewUpdates(
      kind: _kind,
      evidence: evidence,
      currentStages: currentStages,
      lastPracticedByConcept: lastPracticed,
      now: now,
    );
    final newQueue = mergeReviewQueue(
      priorExtras?.reviewQueue ?? const <ReviewEntry>[],
      queueUpdates,
    );

    var perf = priorExtras?.recentPerformance ?? RecentPerformance();
    for (final record in records) {
      perf = perf.add(PerformanceEvent(
        conceptId: record.conceptId,
        correct: record.correct,
        firstTry: record.firstTry,
        at: now,
      ));
    }

    await repo.saveLearningState(
      language,
      LearningState(
        languageCode: learnLanguageSpec(language).code,
        conceptMasteries: newEvidence,
        reviewQueue: newQueue,
        recentPerformance: perf,
      ),
    );

    // Trusted-exercise mastery through the EXISTING idempotent path
    // (feeds the M1 derivation on the next rebuild). Generated `gen-`
    // exercises are NEVER recorded — they are not trusted content.
    final touchedLessons = await _recordTrustedMastery(records);

    // Refresh the watched data sources the spine derives from: the
    // persisted extras (queue/performance/evidence) and per-lesson
    // mastered sets. activeLearningStateProvider / planner context /
    // plan providers rebuild from these automatically.
    _ref.invalidate(learnStateExtrasProvider);
    for (final lessonId in touchedLessons) {
      _ref.invalidate(masteredExercisesProvider(lessonId));
    }

    _ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
          VanEventType.quizCompleted,
          message: _vanFinishLine(records),
          payload: {'kind': _kind.name},
        ));

    final touched = evidence.keys.length;
    state = AdaptiveSessionState._(
      phase: AdaptiveSessionPhase.finished,
      languageCode: state.languageCode,
      languageName: state.languageName,
      kind: _kind,
      focusConceptId: state.focusConceptId,
      focusTitle: state.focusTitle,
      exerciseBudget: engine.maxSteps,
      answered: records.length,
      firstTryCorrect: records.where((r) => r.correct && r.firstTry).length,
      conceptsTouched: touched,
    );
  }

  /// Returns to idle (screen closed / language switched).
  void reset() {
    _engine = null;
    _language = null;
    _lessonByConcept.clear();
    _trustedIdsByLesson.clear();
    state = const AdaptiveSessionState.idle();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Validated generated practice exercises for [conceptId] from the M5
  /// cache at the requested knob and one knob EASIER (ladder material).
  /// Never generates — reads the cache only; missing entries degrade to
  /// an empty list (trusted rungs cover the ladder).
  List<Exercise> _cachedGeneratedVariants(
    GeneratedContentRepository cache,
    LearnLanguage language,
    String conceptId,
    int knob,
  ) {
    final variants = <Exercise>[];
    for (final k in {knob, knob > 1 ? knob - 1 : 1}) {
      final key = GeneratedContentRepository.itemKeyFor(
        conceptId,
        GeneratedContentKind.practice,
        k,
      );
      final cached = cache.get(language, key);
      final exercise = cached?.exercise;
      if (exercise != null && exercise.isValid) variants.add(exercise);
    }
    return variants;
  }

  Future<List<String>> _reviewQueueConceptIds() async {
    final learningState = await _ref.read(activeLearningStateProvider.future);
    return [
      for (final entry in learningState.reviewQueue) entry.conceptId,
    ];
  }

  Future<List<String>> _recordTrustedMastery(
    List<SessionAnswerRecord> records,
  ) async {
    final recordMastery = _ref.read(recordMasteryProvider);
    final byLesson = <String, List<String>>{};
    for (final record in records) {
      if (!record.correct) continue;
      if (record.isGenerated) continue; // gen- ids never write progress
      final lessonId = _lessonByConcept[record.conceptId];
      if (lessonId == null) continue;
      final trustedIds = _trustedIdsByLesson[lessonId];
      if (trustedIds == null || !trustedIds.contains(record.exerciseId)) {
        continue; // defensive: only trusted bank ids are recorded
      }
      byLesson.putIfAbsent(lessonId, () => []).add(record.exerciseId);
    }
    for (final entry in byLesson.entries) {
      try {
        await recordMastery(entry.key, entry.value);
      } catch (_) {
        // Idempotent-union persistence must never break the finished
        // state; the derivation simply picks it up next rebuild.
      }
    }
    return byLesson.keys.toList(growable: false);
  }

  String _vanStartLine(ActivityKind kind, String conceptTitle) =>
      switch (kind) {
        ActivityKind.review => "Quick review of $conceptTitle — you've "
            'got this!',
        ActivityKind.weakRepair => "Let's rebuild $conceptTitle step by step.",
        ActivityKind.masteryCheck =>
          'Ready to show what you know about $conceptTitle?',
        ActivityKind.challenge => 'Challenge time on $conceptTitle!',
        ActivityKind.newLearning => "Fresh start on $conceptTitle!",
        ActivityKind.practice => 'Practice round on $conceptTitle!',
      };

  String _vanFinishLine(List<SessionAnswerRecord> records) {
    if (records.isEmpty) return 'Session saved — see you next time!';
    final correct = records.where((r) => r.correct).length;
    if (correct == records.length) return 'Perfect session! VAN is proud.';
    if (correct * 2 >= records.length) return 'Good work — the path is tuned.';
    return 'Tough round! VAN adjusted your path already.';
  }
}

final adaptiveSessionProvider =
    StateNotifierProvider<AdaptiveSessionController, AdaptiveSessionState>(
  (ref) => AdaptiveSessionController(ref),
);
