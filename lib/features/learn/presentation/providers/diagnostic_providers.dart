/// VaaniX Learn Mode — Adaptive Diagnostic Providers (M3)
///
/// Riverpod wiring for the VAN-led placement flow (Master Brief §11/§12):
///
/// - [diagnosticItemBankProvider] — trusted probe pools for the ACTIVE
///   language, built from the concept graph + the existing exercise banks;
/// - [diagnosticSessionProvider] — the adaptive run itself (start →
///   answer → feedback → … → friendly result), persisting on finish;
/// - [lastDiagnosticProvider] — the stored placement result per language;
/// - [learnStateExtrasProvider] — persisted review-queue/performance
///   extras (M3 seeds them from the diagnostic run).
///
/// Dependency direction: THIS file never imports `spine_providers` — the
/// spine watches [learnStateExtrasProvider]/[lastDiagnosticProvider] to
/// pick up placement data, so the graph is one-way (spine → here). The
/// probe bank therefore derives its own concept graph from the active
/// curriculum (a one-line pure derivation, same rule as the spine's).
///
/// Contract notes carried over from M2:
/// - Persist FIRST, then publish state, so provider rebuilds never read
///   ahead of the data.
/// - No language selected → no session; stub languages (kn/ml/or) surface
///   an honest "unavailable" state instead of a broken flow.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';

// ─── Trusted probe pools ────────────────────────────────────────────────────

/// Trusted probe pools for the ACTIVE curriculum (deterministic order —
/// the session reshuffles a copy per run, keeping this provider pure to
/// watch and cheap to share).
///
/// Empty when no Learn language is selected (placement is per-language —
/// the legacy Sanskrit track is not diagnosed) or the curriculum is a
/// stub. The concept graph is derived here with the SAME one-line rule
/// the spine uses, keeping the import direction one-way.
final diagnosticItemBankProvider = FutureProvider<DiagnosticItemBank>(
  (ref) async {
    final selected = ref.watch(selectedLearnLanguageProvider);
    if (selected == null) return DiagnosticItemBank.empty();

    final chapters = await ref.watch(activeCurriculumProvider.future);
    final graph = ConceptGraph.forCurriculum(
      languageCode: learnLanguageSpec(selected).code,
      chapters: chapters,
    );
    if (graph.isEmpty) return DiagnosticItemBank.empty();

    final exercises = <String, List<Exercise>>{};
    for (final concept in graph.concepts) {
      exercises[concept.lessonId] =
          ref.watch(exercisesForLessonProvider(concept.lessonId));
    }
    return DiagnosticItemBank.build(graph: graph, exercisesByLesson: exercises);
  },
);

// ─── Session state ──────────────────────────────────────────────────────────

/// Phases of the placement flow. `feedback` is the encourage-first beat
/// after answering (Master Brief §43: a game, not an exam) — the probe
/// stays visible with its explanation until [DiagnosticSessionNotifier.next].
enum DiagnosticPhase { idle, active, feedback, finished, unavailable }

/// Immutable snapshot of the placement flow the screen renders.
class DiagnosticSessionState {
  const DiagnosticSessionState._({
    required this.phase,
    this.currentItem,
    this.askedCount = 0,
    this.estimatedMax = 0,
    this.lastAnsweredItem,
    this.lastAnswerWasCorrect = false,
    this.result,
    this.unavailableReason,
  });

  const DiagnosticSessionState.idle() : this._(phase: DiagnosticPhase.idle);

  const DiagnosticSessionState.active({
    required DiagnosticItem item,
    required int askedCount,
    required int estimatedMax,
  }) : this._(
          phase: DiagnosticPhase.active,
          currentItem: item,
          askedCount: askedCount,
          estimatedMax: estimatedMax,
        );

  const DiagnosticSessionState.feedback({
    required DiagnosticItem answeredItem,
    required bool wasCorrect,
    required int askedCount,
    required int estimatedMax,
  }) : this._(
          phase: DiagnosticPhase.feedback,
          lastAnsweredItem: answeredItem,
          lastAnswerWasCorrect: wasCorrect,
          askedCount: askedCount,
          estimatedMax: estimatedMax,
        );

  const DiagnosticSessionState.finished(DiagnosticResult result)
      : this._(phase: DiagnosticPhase.finished, result: result);

  const DiagnosticSessionState.unavailable(String reason)
      : this._(phase: DiagnosticPhase.unavailable, unavailableReason: reason);

  final DiagnosticPhase phase;

  /// The probe to render in `active` phase.
  final DiagnosticItem? currentItem;

  /// Probes answered so far (drives the friendly progress meter).
  final int askedCount;

  /// Upper bound for the meter (never a countdown).
  final int estimatedMax;

  /// The probe just answered, shown during `feedback` with its explanation.
  final DiagnosticItem? lastAnsweredItem;
  final bool lastAnswerWasCorrect;

  /// Set in `finished` phase — the structured placement result.
  final DiagnosticResult? result;

  /// Set in `unavailable` phase (stub language / empty trusted pools).
  final String? unavailableReason;
}

/// Drives one adaptive placement run for the ACTIVE language.
///
/// The engine owns adaptivity ([DiagnosticEngine]); this notifier owns
/// UI pacing and the finish pipeline:
///   build result → saveDiagnostic → seed state extras (review queue +
///   recent performance) → write profile.currentLevel → invalidate the
///   spine providers → publish the finished state.
class DiagnosticSessionNotifier extends StateNotifier<DiagnosticSessionState> {
  DiagnosticSessionNotifier(this._ref)
      : super(const DiagnosticSessionState.idle());

  final Ref _ref;
  DiagnosticEngine? _engine;
  LearnLanguage? _language;
  DateTime? _startedAt;

  /// Starts a fresh run for [language]. Seeds the difficulty from the
  /// learner's own self-report hint (never shown as a level) and varies
  /// the probe order per run.
  Future<void> start(LearnLanguage language) async {
    final baseBank = await _ref.read(diagnosticItemBankProvider.future);
    if (baseBank.isEmpty) {
      state = const DiagnosticSessionState.unavailable(
        'The placement game unlocks once this language has lessons '
        'and practice content.',
      );
      return;
    }

    final seed = seedFromText(
      'diagnostic#${language.name}#${DateTime.now().millisecondsSinceEpoch}',
    );
    final profile = _ref.read(learnerProfileProvider(language));
    _engine = DiagnosticEngine(
      bank: baseBank.reshuffled(seed),
      seedLevel: profile.selfReport.suggestedLevel,
    );
    _language = language;
    _startedAt = DateTime.now();

    final engine = _engine!;
    state = DiagnosticSessionState.active(
      item: engine.currentItem!,
      askedCount: 0,
      estimatedMax: engine.estimatedMax,
    );
  }

  /// Records the learner's answer to the current probe and moves to the
  /// encourage-first feedback beat. The engine's next probe is chosen
  /// HERE (adaptivity applies immediately) but only surfaces on [next].
  void submitAnswer(DiagnosticAnswer answer) {
    final engine = _engine;
    final item = state.currentItem;
    if (engine == null ||
        item == null ||
        state.phase != DiagnosticPhase.active) {
      return;
    }
    final correct = answer.isCorrectFor(item);
    engine.recordAnswer(correct);
    state = DiagnosticSessionState.feedback(
      answeredItem: item,
      wasCorrect: correct,
      askedCount: engine.askedCount,
      estimatedMax: engine.estimatedMax,
    );
  }

  /// Leaves the feedback beat: shows the engine's next probe, or finishes
  /// the run. On finish the result is persisted BEFORE the finished state
  /// publishes (rebuild-after-publish always sees durable data).
  Future<void> next() async {
    final engine = _engine;
    final language = _language;
    if (engine == null || state.phase != DiagnosticPhase.feedback) return;

    engine.advance();
    if (!engine.isFinished && engine.currentItem != null) {
      state = DiagnosticSessionState.active(
        item: engine.currentItem!,
        askedCount: engine.askedCount,
        estimatedMax: engine.estimatedMax,
      );
      return;
    }

    // ── Finish pipeline: persist first, publish last. ──
    final startedAt = _startedAt ?? DateTime.now();
    final completedAt = DateTime.now();
    final result = engine.buildResult(
      language: language!,
      completedAt: completedAt,
      duration: completedAt.difference(startedAt),
    );

    final repo = _ref.read(learnProfileRepositoryProvider);
    await repo.saveDiagnostic(result);
    await repo.saveLearningState(
        language, _extrasFrom(engine, language, completedAt));
    await _ref
        .read(learnerProfileProvider(language).notifier)
        .update((p) => p.copyWith(currentLevel: result.overallLevel));

    // No manual invalidation needed: the spine WATCHES
    // [learnStateExtrasProvider] (below), which just changed on disk and
    // rebuilds on the session-state signal published at the end of this
    // method — persist-before-publish keeps that read truthful.

    state = DiagnosticSessionState.finished(result);
  }

  /// Returns to the idle phase (screen closed / retake from scratch).
  void reset() {
    _engine = null;
    _language = null;
    _startedAt = null;
    state = const DiagnosticSessionState.idle();
  }

  /// Seeds the persisted learning-state extras from the run:
  /// - recent performance: one first-try event per answered probe;
  /// - review queue: missed concepts first, weakest dimensions boosted,
  ///   capped to keep the planner prompt small.
  ///
  /// `conceptMasteries` stays EMPTY here on purpose — mastery derivation
  /// from real progress data remains the spine's job (M1 mapping); these
  /// extras only carry what derivation cannot know.
  LearningState _extrasFrom(
    DiagnosticEngine engine,
    LearnLanguage language,
    DateTime completedAt,
  ) {
    final code = learnLanguageSpec(language).code;
    final records = engine.answerRecords;

    final events = [
      for (final record in records)
        PerformanceEvent(
          conceptId: record.conceptId ?? record.probeId,
          correct: record.correct,
          firstTry: true,
          at: completedAt,
        ),
    ];

    final dimensionScores = <DiagnosticDimension, double>{
      for (final e in engine.answerRecords.groupByDimension().entries)
        e.key: e.value.where((r) => r.correct).length / e.value.length,
    };

    final seenConcepts = <String>{};
    final queue = <ReviewEntry>[];
    for (final record in records) {
      final conceptId = record.conceptId;
      if (record.correct || conceptId == null) continue;
      if (!seenConcepts.add(conceptId)) continue;
      final dimScore = dimensionScores[record.dimension] ?? 0.0;
      queue.add(ReviewEntry(
        conceptId: conceptId,
        reason: ReviewReason.recentlyWeak,
        priority: dimScore < 0.5 ? 0.85 : 0.7,
      ));
      if (queue.length >= kMaxDiagnosticReviewSeeds) break;
    }

    return LearningState(
      languageCode: code,
      conceptMasteries: const {},
      reviewQueue: queue..sort(),
      recentPerformance: RecentPerformance(events: events),
    );
  }
}

final diagnosticSessionProvider =
    StateNotifierProvider<DiagnosticSessionNotifier, DiagnosticSessionState>(
  (ref) => DiagnosticSessionNotifier(ref),
);

/// Cap for review entries seeded by one diagnostic run (keeps the queue
/// meaningful and the planner digest small).
const int kMaxDiagnosticReviewSeeds = 8;

extension on List<DiagnosticAnswerRecord> {
  Map<DiagnosticDimension, List<DiagnosticAnswerRecord>> groupByDimension() {
    final map = <DiagnosticDimension, List<DiagnosticAnswerRecord>>{};
    for (final record in this) {
      map.putIfAbsent(record.dimension, () => []).add(record);
    }
    return map;
  }
}

// ─── Stored result accessors ────────────────────────────────────────────────

/// The last placement result for [language], or `null` when not placed
/// yet. Rebuilds whenever a session finishes (persist-before-publish
/// guarantees the read sees the fresh result).
final lastDiagnosticProvider =
    Provider.family<DiagnosticResult?, LearnLanguage>((ref, language) {
  ref.watch(diagnosticSessionProvider);
  return ref.watch(learnProfileRepositoryProvider).getDiagnostic(language);
});

/// Persisted review-queue/performance extras for [language] (M3 seeds
/// them; M6 sessions will keep them fresh). `null` = nothing persisted.
final learnStateExtrasProvider =
    Provider.family<LearningState?, LearnLanguage>((ref, language) {
  ref.watch(diagnosticSessionProvider);
  return ref.watch(learnProfileRepositoryProvider).getLearningState(language);
});
