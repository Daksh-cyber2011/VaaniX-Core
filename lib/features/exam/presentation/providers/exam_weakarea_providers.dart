/// Exam Mode 2.0 — Weak-Area Providers (M8, §21/§22/§23)
///
/// The wiring hub for the weak-area system:
///
///  * repositories — attempt log (question-level evidence) + weak-area
///    state (recovery history, revision ladder, recheck outcomes);
///  * [WeakAreaOverview] — the computed, always-fresh bundle the UI
///    and the planner read: error patterns → weak-topic report,
///    forgetting-aware revision schedule, recovery-day decision;
///  * [ExamWeakAreaController] — runs the two M8 sessions on the M6
///    loop engine:
///      recovery (§22): recap → mistake retry → targeted practice →
///        held-aside mastery recheck → outcome persisted;
///      revision (§23): due/overdue topics, mistake-first mixed
///        review — never the original lesson's order; performance
///        expands or contracts each topic's revision interval.
///
/// Honesty rules carried through: findings only from real evidence
/// (§21), no fabricated signals (§30), §22 frequency caps, §23
/// evidence-based spacing — and a storage failure NEVER blocks the
/// session (§41 best-effort persistence).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/practice/practice_content_bank.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/data/weakarea/exam_attempt_log_repository.dart';
import 'package:vaanix_app/features/exam/data/weakarea/weak_area_repository.dart';
import 'package:vaanix_app/features/exam/data/pyq_mock/pyq_performance_repository.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_session_engine.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart'
    show MockSectionResult;
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart'
    show ExamSessionKind, ExamSessionRecord;
import 'package:vaanix_app/features/exam/domain/weakarea/remediation_engine.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examGamificationProvider, examSessionFingerprintOf;
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider, examLearnerProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart';

final examAttemptLogRepositoryProvider = Provider<ExamAttemptLogRepository>(
    (ref) => ExamAttemptLogRepository(ref.watch(localStorageServiceProvider)));

final weakAreaRepositoryProvider = Provider<WeakAreaRepository>(
    (ref) => WeakAreaRepository(ref.watch(localStorageServiceProvider)));

/// The computed M8 snapshot for one track (UI + planner input).
///
/// Computed live from the three evidence sources — never persisted as
/// a whole (derived data; §12 stores the SOURCES, not the views).
class WeakAreaOverview {
  const WeakAreaOverview({
    required this.trackId,
    required this.patterns,
    required this.report,
    required this.revisionItems,
    required this.decision,
    required this.wrongByTopic,
    required this.state,
  });

  final String trackId;
  final List<ErrorPattern> patterns;
  final WeakAreaReport report;
  final List<RevisionItem> revisionItems;
  final WeakAreaDayDecision decision;

  /// topicId → previously-wrong question ids (rolling window).
  final Map<String, Set<String>> wrongByTopic;

  /// The persisted weak-area state (recovery history + ladder).
  final WeakAreaState state;

  bool get hasRevisionDue => revisionItems
      .any((i) => i.bandOf(DateTime.now()) != RevisionRiskBand.fresh);

  List<RevisionItem> dueRevision({int limit = 3}) =>
      RevisionEngine.dueToday(revisionItems, DateTime.now(), limit: limit);
}

/// Loads + computes the overview (§21/§22/§23 chain, deterministic).
/// M9: real PYQ performance + weak mock sections are fed in — the
/// weakPyq/weakMock §21 signals fire only when this data exists.
Future<WeakAreaOverview> computeWeakAreaOverview(
  Ref ref,
  String trackId,
) async {
  final learner = await ref.read(examLearnerProfileProvider(trackId).future);
  final attemptRepo = ref.read(examAttemptLogRepositoryProvider);
  final weakRepo = ref.read(weakAreaRepositoryProvider);
  final pyqRepo = ref.read(pyqPerformanceRepositoryProvider);
  final mockRepo = ref.read(mockResultRepositoryProvider);
  final evidence = await attemptRepo.load(trackId);
  final state = await weakRepo.load(trackId);
  final pyqPerformance = await pyqRepo.load(trackId);
  final mockResults = await mockRepo.load(trackId);

  final patterns = ErrorIntelligence.analyze(evidence);
  final revisionItems = RevisionEngine.schedule(
    learner: learner,
    patterns: patterns,
    history: state.revision,
  );

  // §22 window inputs from persisted history.
  final lastRecovery = DateTime.tryParse(state.lastRecoveryDayIso);
  final daysSince = lastRecovery == null
      ? null
      : DateTime.now().difference(lastRecovery).inDays;

  // §21 weak mock sections: the NEWEST mock's weak sections (the
  // current state — older history stays in the bounded log).
  final weakMockSections = mockResults.isNotEmpty
      ? mockResults.last.weakSections
      : const <MockSectionResult>[];

  final report = WeakAreaEngine.build(
    learner: learner,
    patterns: patterns,
    revisionItems: revisionItems,
    pyqPerformance: pyqPerformance,
    weakMockSections: weakMockSections,
  );
  final decision = WeakAreaDayEngine.decide(
    report: report,
    revisionItems: revisionItems,
    dayCount: 7,
    daysSinceLastRecovery: daysSince,
  );

  return WeakAreaOverview(
    trackId: trackId,
    patterns: patterns,
    report: report,
    revisionItems: revisionItems,
    decision: decision,
    wrongByTopic: ExamAttemptLogRepository.wrongQuestionIdsByTopic(evidence),
    state: state,
  );
}

final weakAreaOverviewProvider =
    FutureProvider.family<WeakAreaOverview, String>((ref, trackId) async {
  return computeWeakAreaOverview(ref, trackId);
});

/// The recovery session's phase progression (§22 order).
enum WeakSessionPhase { intro, recap, practice, recheck, done }

/// What kind of M8 session is running.
enum WeakSessionMode { recovery, revision }

/// Live weak-area session state.
class WeakAreaSessionData {
  const WeakAreaSessionData({
    required this.mode,
    required this.phase,
    required this.topicId,
    required this.topicTitle,
    required this.session,
    required this.plan,
    required this.outcome,
    required this.notice,
  });

  final WeakSessionMode mode;
  final WeakSessionPhase phase;

  /// Recovery focus topic ('' for revision mode).
  final String topicId;
  final String topicTitle;

  /// The M6 loop engine state over the current phase's questions.
  final PracticeSessionState? session;

  /// The §22 remediation plan (recovery mode only).
  final RemediationPlan? plan;

  /// §22 mastery-recheck outcome (recovery mode, set at done).
  final RemediationOutcome outcome;

  /// Honest status line (§30-clean).
  final String? notice;

  bool get isDone => phase == WeakSessionPhase.done;
}

class ExamWeakAreaController
    extends FamilyAsyncNotifier<WeakAreaSessionData, String> {
  final PracticeSessionEngine _engine = const PracticeSessionEngine();

  @override
  Future<WeakAreaSessionData> build(String trackId) async {
    return WeakAreaSessionData(
      mode: WeakSessionMode.recovery,
      phase: WeakSessionPhase.intro,
      topicId: '',
      topicTitle: '',
      session: null,
      plan: null,
      outcome: RemediationOutcome.notRun,
      notice: null,
    );
  }

  /// Starts the §22 recovery session for [topicId] (from the report's
  /// findings or the decision's focus topic).
  Future<void> startRecovery(String topicId) async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty || scope.view == null) {
      state = AsyncError(
        StateError('No scope selected — nothing to recover'),
        StackTrace.current,
      );
      return;
    }

    // Grounded per-topic pool (§60 — nothing invented).
    final pool = PracticeContentBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
      weakTopicIds: {topicId},
      topicFilter: {topicId},
      targetSize: 8,
    );
    if (pool.isEmpty) {
      state = AsyncError(
        StateError('No grounded questions for this topic'),
        StackTrace.current,
      );
      return;
    }

    final overview = await ref.read(weakAreaOverviewProvider(trackId).future);
    final previouslyWrong = overview.wrongByTopic[topicId] ?? const <String>{};

    // §15/§60 recap: official title, official section, official
    // sub-topics — never invented.
    final item = syllabus.allItems
        .where((i) => i.id == topicId)
        .firstOrNull;
    final section = scope.view!.sections
        .where((s) => s.id == item?.sectionId)
        .firstOrNull;
    final subtopics = item == null
        ? const <String>[]
        : _subtopicsOf(item).take(4).toList();
    final recap = RemediationRecap(
      topicTitle: item?.title ?? topicId,
      sectionTitle: section?.title ?? '',
      subtopics: subtopics,
    );

    final plan = RemediationEngine.build(
      topicId: topicId,
      recap: recap,
      topicPool: pool,
      previouslyWrongQuestionIds: previouslyWrong,
    );

    if (!plan.isViable) {
      // Honest §30 floor: not enough fresh questions for a real
      // mastery check — say so, offer revision instead of faking it.
      state = AsyncData(WeakAreaSessionData(
        mode: WeakSessionMode.recovery,
        phase: WeakSessionPhase.intro,
        topicId: topicId,
        topicTitle: recap.topicTitle,
        session: null,
        plan: null,
        outcome: RemediationOutcome.notRun,
        notice: 'इस विषय के लिए अभी पर्याप्त नए प्रश्न नहीं हैं — थोड़ा '
            'और अभ्यास करने पर recovery session बनेगा। फ़िलहाल दोहराव '
            'देखें।',
      ));
      return;
    }

    state = AsyncData(WeakAreaSessionData(
      mode: WeakSessionMode.recovery,
      phase: WeakSessionPhase.recap,
      topicId: topicId,
      topicTitle: recap.topicTitle,
      session: null,
      plan: plan,
      outcome: RemediationOutcome.notRun,
      notice: null,
    ));
  }

  /// Moves recap → practice (the §22 mistake-retry + targeted loop).
  Future<void> beginPractice() async {
    final current = state.value;
    final plan = current?.plan;
    if (current == null || plan == null) return;
    state = AsyncData(WeakAreaSessionData(
      mode: current.mode,
      phase: WeakSessionPhase.practice,
      topicId: current.topicId,
      topicTitle: current.topicTitle,
      session: _engine.start(plan.mainQuestions),
      plan: plan,
      outcome: current.outcome,
      notice: null,
    ));
  }

  /// Moves practice → recheck when the main loop finishes.
  Future<void> _beginRecheck(WeakAreaSessionData current) async {
    final plan = current.plan;
    if (plan == null) return;
    state = AsyncData(WeakAreaSessionData(
      mode: current.mode,
      phase: WeakSessionPhase.recheck,
      topicId: current.topicId,
      topicTitle: current.topicTitle,
      session: _engine.start(plan.recheckQuestions),
      plan: plan,
      outcome: current.outcome,
      notice: 'अब mastery जाँच — दो नए प्रश्न, बिना कोई मदद।',
    ));
  }

  /// Starts the §23 revision session: due/overdue topics, mistake
  /// re-encounters first, mixed order — never the original lesson.
  Future<void> startRevision() async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty || scope.view == null) {
      state = AsyncError(
        StateError('No scope selected — nothing to revise'),
        StackTrace.current,
      );
      return;
    }
    final overview = await ref.read(weakAreaOverviewProvider(trackId).future);
    final due = overview.dueRevision(limit: 3);
    if (due.isEmpty) {
      state = AsyncData(WeakAreaSessionData(
        mode: WeakSessionMode.revision,
        phase: WeakSessionPhase.intro,
        topicId: '',
        topicTitle: '',
        session: null,
        plan: null,
        outcome: RemediationOutcome.notRun,
        notice: 'अभी किसी विषय का दोहराव देय नहीं है — बढ़िया चल रहा है।',
      ));
      return;
    }

    final pool = PracticeContentBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
      weakTopicIds: due.map((i) => i.topicId).toSet(),
      topicFilter: due.map((i) => i.topicId).toSet(),
      targetSize: 8,
    );
    if (pool.isEmpty) {
      state = AsyncError(
        StateError('No grounded questions for the due topics'),
        StackTrace.current,
      );
      return;
    }

    final wrongIds = <String>{};
    for (final topicId in due.map((i) => i.topicId)) {
      wrongIds.addAll(overview.wrongByTopic[topicId] ?? const <String>{});
    }
    final mix = RevisionEngine.reviewMix(
      questions: pool,
      previouslyWrongQuestionIds: wrongIds,
      dueTopicIds: due.map((i) => i.topicId).toSet(),
      targetSize: 8,
    );
    if (mix.isEmpty) {
      state = AsyncError(
        StateError('Revision mix came out empty'),
        StackTrace.current,
      );
      return;
    }

    state = AsyncData(WeakAreaSessionData(
      mode: WeakSessionMode.revision,
      phase: WeakSessionPhase.practice,
      topicId: due.first.topicId,
      topicTitle: '',
      session: _engine.start(mix),
      plan: null,
      outcome: RemediationOutcome.notRun,
      notice: 'दोहराव — पहले पुरानी गलतियाँ, फिर मिला-जुला अभ्यास।',
    ));
  }

  Future<void> submitMcq(int selectedIndex) async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.submitMcq(current!.session!, selectedIndex);
    await _absorb(current, next);
  }

  Future<void> submitTyped(String text) async {
    final current = state.value;
    if (current?.session == null || text.trim().isEmpty) return;
    final next = _engine.submitTyped(current!.session!, text);
    await _absorb(current, next);
  }

  Future<void> retryAttempt() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.retryAttempt(current!.session!);
    _emit(current, next);
  }

  Future<void> reveal() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.reveal(current!.session!);
    _emit(current, next);
  }

  Future<void> advance() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.advance(current!.session!);
    await _absorb(current, next);
  }

  /// Returns to the report (session closed without persistence).
  Future<void> close() async {
    state = AsyncData(await build(arg));
  }

  void _emit(WeakAreaSessionData current, PracticeSessionState next) {
    state = AsyncData(_withSession(current, next));
  }

  Future<void> _absorb(
    WeakAreaSessionData current,
    PracticeSessionState next,
  ) async {
    if (next.finished) {
      await _finishPhase(current, next);
      return;
    }
    _emit(current, next);
  }

  WeakAreaSessionData _withSession(
      WeakAreaSessionData current, PracticeSessionState next) {
    return WeakAreaSessionData(
      mode: current.mode,
      phase: current.phase,
      topicId: current.topicId,
      topicTitle: current.topicTitle,
      session: next,
      plan: current.plan,
      outcome: current.outcome,
      notice: null,
    );
  }

  /// End-of-phase handling (§22 recheck judging, §23 ladder updates,
  /// §29 mastery + §21 evidence persistence — all best-effort, §41).
  Future<void> _finishPhase(
    WeakAreaSessionData current,
    PracticeSessionState next,
  ) async {
    final trackId = arg;

    // Persist question-level evidence FIRST (§21 patterns need it —
    // also for recovery/revision questions, not just M6 practice).
    await _persistAttempts(trackId, next);
    await _persistMastery(trackId, next);

    if (current.mode == WeakSessionMode.recovery &&
        current.phase == WeakSessionPhase.practice) {
      // Main loop done → mastery recheck phase (§22).
      state = AsyncData(_withSession(current, next));
      await _beginRecheck(current);
      return;
    }

    if (current.mode == WeakSessionMode.recovery &&
        current.phase == WeakSessionPhase.recheck) {
      final plan = current.plan;
      final recheckIds = plan?.recheckQuestions.map((q) => q.id).toSet() ??
          const <String>{};
      final recheckAttempts = next.attempts
          .where((a) => recheckIds.contains(a.questionId))
          .map((a) => (questionId: a.questionId, verdict: a.verdict))
          .toList();
      final outcome = RemediationEngine.judgeRecheck(
        recheckAttempts: recheckAttempts,
      );

      // Persist the outcome + revision ladder move (best-effort §41):
      // recovered ⇒ interval expands; still weak ⇒ contracts.
      try {
        final repo = ref.read(weakAreaRepositoryProvider);
        var waState = await repo.load(trackId);
        final t = DateTime.now();
        final item = waState.revision[current.topicId] ??
            RevisionItem(
              topicId: current.topicId,
              intervalIndex: 0,
              lastReviewedIso: t.toIso8601String(),
              dueIso: t.toIso8601String(),
            );
        final moved = outcome == RemediationOutcome.recovered
            ? RevisionEngine.expand(item, t)
            : RevisionEngine.contract(item, t);
        waState = waState
            .withRevision({...waState.revision, current.topicId: moved})
            .withRecheckOutcome(RecheckOutcomeRecord(
              topicId: current.topicId,
              outcome: outcome,
              atIso: t.toIso8601String(),
            ))
            .withRecoveryCompleted(t);
        await repo.save(waState);
        ref.invalidate(weakAreaOverviewProvider(trackId));
      } catch (_) {
        // §41: persistence failure never blocks the session outcome.
      }

      // M10: the COMPLETED recovery session (practice + recheck both
      // done) feeds the app-wide gamification — best-effort, §41.
      await _recordGamification(current, next, ExamSessionKind.recovery);

      state = AsyncData(WeakAreaSessionData(
        mode: current.mode,
        phase: WeakSessionPhase.done,
        topicId: current.topicId,
        topicTitle: current.topicTitle,
        session: next,
        plan: current.plan,
        outcome: outcome,
        notice: RemediationEngine.outcomeSummary(outcome),
      ));
      return;
    }

    if (current.mode == WeakSessionMode.revision) {
      // §23 ladder update per topic from THIS session's performance:
      // clean topic ⇒ expand, any miss ⇒ contract (relearning).
      try {
        final repo = ref.read(weakAreaRepositoryProvider);
        var waState = await repo.load(trackId);
        final t = DateTime.now();
        final byTopic = <String, bool>{};
        for (final a in next.attempts) {
          final ok = a.verdict == 'correct' || a.verdict == 'partiallyCorrect';
          byTopic[a.topicId] = ok && (byTopic[a.topicId] ?? true);
        }
        final revision = {...waState.revision};
        byTopic.forEach((topicId, clean) {
          final item = revision[topicId] ??
              RevisionItem(
                topicId: topicId,
                intervalIndex: 0,
                lastReviewedIso: t.toIso8601String(),
                dueIso: t.toIso8601String(),
              );
          revision[topicId] =
              clean ? RevisionEngine.expand(item, t) : RevisionEngine.contract(item, t);
        });
        waState = waState.withRevision(revision);
        await repo.save(waState);
        ref.invalidate(weakAreaOverviewProvider(trackId));
      } catch (_) {
        // §41.
      }

      // M10: the finished revision session feeds the app-wide
      // gamification — best-effort, §41.
      await _recordGamification(current, next, ExamSessionKind.revision);

      state = AsyncData(WeakAreaSessionData(
        mode: current.mode,
        phase: WeakSessionPhase.done,
        topicId: current.topicId,
        topicTitle: current.topicTitle,
        session: next,
        plan: current.plan,
        outcome: RemediationOutcome.notRun,
        notice: PracticeSessionEngine.summary(next),
      ));
      return;
    }

    state = AsyncData(_withSession(current, next));
  }

  /// Question-level evidence write (batched, one write per finished
  /// phase — §18; kind from the question pool, §21 vocabulary).
  Future<void> _persistAttempts(String trackId, PracticeSessionState next) async {
    try {
      final repo = ref.read(examAttemptLogRepositoryProvider);
      final kinds = {
        for (final q in next.questions)
          q.id: q.kind == PracticeQuestionKind.mcq ? 'mcq' : 'typed',
      };
      await repo.recordSession(
        trackId: trackId,
        attempts: [
          for (final a in next.attempts)
            ErrorEvidence(
              questionId: a.questionId,
              topicId: a.topicId,
              kind: kinds[a.questionId] ?? 'mcq',
              verdict: a.verdict,
              retries: a.retries,
              atIso: a.attemptedAtIso,
            ),
        ],
      );
      ref.invalidate(weakAreaOverviewProvider(trackId));
    } catch (_) {
      // §41: logging failure never blocks the loop.
    }
  }

  /// §29 mastery connection (same contract as the M6 provider).
  Future<void> _persistMastery(
      String trackId, PracticeSessionState next) async {
    try {
      final repo = ref.read(examLearnerProfileRepositoryProvider);
      var profile = await repo.load(trackId);
      PracticeSessionEngine.masteryUpdates(next).forEach((topicId, ok) {
        profile = profile.recordAttempt(topicId: topicId, correct: ok);
      });
      await repo.save(profile);
      ref.invalidate(examLearnerProfileProvider(trackId));
    } catch (_) {
      // §41.
    }
  }

  /// M10: session-level gamification (§41 best-effort). Uses the
  /// finalized attempts of the phase that just completed (recovery:
  /// the recheck loop; revision: the mixed review set). The
  /// kind-specific completion bonus carries the recovery/revision
  /// weight; the fingerprint keeps each finish once-ever.
  Future<void> _recordGamification(
    WeakAreaSessionData current,
    PracticeSessionState next,
    ExamSessionKind kind,
  ) async {
    try {
      final gamification = ref.read(examGamificationProvider);
      await gamification.sessionFinished(ExamSessionRecord(
        kind: kind,
        trackId: arg,
        correctCount: next.attempts
            .where((a) => a.verdict == 'correct')
            .length,
        totalCount: next.attempts.length,
        questionFingerprint: examSessionFingerprintOf(
          [for (final a in next.attempts) a.questionId],
          [for (final a in next.attempts) a.verdict],
        ),
        finishedAt: DateTime.now(),
      ));
    } catch (_) {
      // §41: gamification failure degrades to "no XP", never a crash.
    }
  }
}

final examWeakAreaProvider = AsyncNotifierProvider.family<
    ExamWeakAreaController, WeakAreaSessionData, String>(
  ExamWeakAreaController.new,
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Official sub-topics of a syllabus item (same extraction as the
/// practice bank — §15 trusted content, no invention).
List<String> _subtopicsOf(dynamic item) {
  final details = item.details;
  if (details == null) return const [];
  final out = <String>[];
  void addList(List<dynamic> list) {
    for (final v in list) {
      final s = v is String ? v.trim() : '';
      if (s.isNotEmpty && s.length <= 40) out.add(s);
    }
  }

  for (final value in details.values) {
    if (value is List) {
      addList(value);
    } else if (value is Map) {
      value.forEach((_, v) {
        if (v is List) addList(v);
      });
    }
  }
  return out;
}
