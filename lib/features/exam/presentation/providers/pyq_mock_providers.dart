/// Exam Mode 2.0 — PYQ + Mock Providers (M9, §25/§41/§21)
///
/// [ExamPyqController] — the PYQ practice track: bank built from the
/// official exam patterns (§25 provenance labels), §25 filtering, MCQ
/// + typed sessions on the M6 loop engine, and per-topic PYQ
/// performance persistence (feeds §21 weak-area detection).
///
/// [ExamMockController] — the mock ladder: builds mini/section/full
/// papers from OFFICIAL structure, runs the paper on the loop engine
/// under the paper's time limit (soft — the student is never punished
/// mid-question; the timer only informs), and finishes into a
/// DETERMINISTIC [MockResult] (§41 — scoring is never AI) that is
/// persisted and fed back into the weak-area overview.
///
/// Both sessions reuse the M8 persistence hooks: §29 mastery updates,
/// §21 attempt-log evidence, §30-clean summaries.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_session_engine.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_engine.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_bank.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart'
    show ExamSessionKind, ExamSessionRecord;
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examGamificationProvider, examSessionFingerprintOf;
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider, examLearnerProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart'
    show examAttemptLogRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart'
    show pyqPerformanceRepositoryProvider, mockResultRepositoryProvider;

// The PYQ/mock repository providers now live in the shared leaf file
// (M10 wiring fix — the weak-area overview reads both repositories
// and must not import this controller file). Re-exported here so
// existing imports of THIS file keep resolving.
export 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart'
    show pyqPerformanceRepositoryProvider, mockResultRepositoryProvider;

/// Live PYQ-track state.
class PyqStateData {
  const PyqStateData({
    required this.trackId,
    required this.session,
    required this.filter,
    required this.availableSectionIds,
    required this.performance,
    required this.summary,
  });

  final String trackId;
  final PracticeSessionState? session;
  final PyqFilter filter;
  final Set<String> availableSectionIds;
  final Map<String, PyqTopicPerformance> performance;
  final String? summary;

  bool get isRunning =>
      session != null && !session!.finished && session!.current != null;
  bool get isFinished => session != null && session!.finished;
}

class ExamPyqController extends FamilyAsyncNotifier<PyqStateData, String> {
  final PracticeSessionEngine _engine = const PracticeSessionEngine();

  @override
  Future<PyqStateData> build(String trackId) async {
    final performance =
        await ref.read(pyqPerformanceRepositoryProvider).load(trackId);
    return PyqStateData(
      trackId: trackId,
      session: null,
      filter: const PyqFilter(),
      availableSectionIds: const {},
      performance: performance,
      summary: null,
    );
  }

  /// Starts (or restarts) a filtered PYQ session.
  Future<void> start({PyqFilter filter = const PyqFilter()}) async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty || scope.view == null) {
      state = AsyncError(
        StateError('No scope selected — no PYQ practice'),
        StackTrace.current,
      );
      return;
    }
    final learner = await ref.read(examLearnerProfileProvider(trackId).future);
    final weakIds = learner
        .weakTopicsFirst(limit: 30)
        .map((t) => t.topicId)
        .where((id) => scope.selection.isSelected(id))
        .toSet();

    final bank = PyqBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
      weakTopicIds: weakIds,
      filter: filter,
    );
    if (bank.isEmpty) {
      state = AsyncError(
        StateError('No grounded PYQ-style questions for this filter'),
        StackTrace.current,
      );
      return;
    }
    final sections = PyqBank.availableSections(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
    );
    state = AsyncData(PyqStateData(
      trackId: trackId,
      session: _engine.start([for (final q in bank) q.question]),
      filter: filter,
      availableSectionIds: sections,
      performance: await _loadPerformance(),
      summary: null,
    ));
  }

  Future<void> submitMcq(int selectedIndex) async {
    final current = state.value;
    if (current?.session == null) return;
    await _absorb(current!, _engine.submitMcq(current.session!, selectedIndex));
  }

  Future<void> submitTyped(String text) async {
    final current = state.value;
    if (current?.session == null || text.trim().isEmpty) return;
    await _absorb(current!, _engine.submitTyped(current.session!, text));
  }

  Future<void> retryAttempt() async {
    final current = state.value;
    if (current?.session == null) return;
    _emit(current!, _engine.retryAttempt(current.session!));
  }

  Future<void> reveal() async {
    final current = state.value;
    if (current?.session == null) return;
    _emit(current!, _engine.reveal(current.session!));
  }

  Future<void> advance() async {
    final current = state.value;
    if (current?.session == null) return;
    await _absorb(current!, _engine.advance(current.session!));
  }

  Future<Map<String, PyqTopicPerformance>> _loadPerformance() async =>
      ref.read(pyqPerformanceRepositoryProvider).load(arg);

  void _emit(PyqStateData current, PracticeSessionState next) {
    state = AsyncData(PyqStateData(
      trackId: current.trackId,
      session: next,
      filter: current.filter,
      availableSectionIds: current.availableSectionIds,
      performance: current.performance,
      summary: null,
    ));
  }

  Future<void> _absorb(PyqStateData current, PracticeSessionState next) async {
    if (next.finished) {
      await _persistAll(next);
      // M10: the finished PYQ session feeds the app-wide gamification
      // (XP once-ever, streak evidence, checkers, VAN) — §41.
      await _recordSessionGamification(ref, arg, next, ExamSessionKind.pyq);
      state = AsyncData(PyqStateData(
        trackId: current.trackId,
        session: next,
        filter: current.filter,
        availableSectionIds: current.availableSectionIds,
        performance: await _loadPerformance(),
        summary: PracticeSessionEngine.summary(next),
      ));
      return;
    }
    _emit(current, next);
  }

  /// §29 mastery + §21 attempt evidence + §21 PYQ performance
  /// (best-effort §41 — a storage failure never blocks the session).
  Future<void> _persistAll(PracticeSessionState next) async {
    final trackId = arg;
    try {
      final kinds = {
        for (final q in next.questions)
          q.id: q.kind == PracticeQuestionKind.mcq ? 'mcq' : 'typed',
      };
      await ref.read(examAttemptLogRepositoryProvider).recordSession(
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
    } catch (_) {
      // §41.
    }
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
    try {
      final perTopic = <String, PyqTopicPerformance>{};
      for (final a in next.attempts) {
        final ok = a.verdict == 'correct' || a.verdict == 'partiallyCorrect';
        final current = perTopic[a.topicId] ??
            PyqTopicPerformance(topicId: a.topicId, attempted: 0, correct: 0);
        perTopic[a.topicId] = PyqTopicPerformance(
          topicId: a.topicId,
          attempted: current.attempted + 1,
          correct: current.correct + (ok ? 1 : 0),
        );
      }
      await ref
          .read(pyqPerformanceRepositoryProvider)
          .mergeSession(trackId: trackId, outcomes: perTopic.values.toList());
    } catch (_) {
      // §41.
    }
  }
}

/// M10: session-level gamification (§41 best-effort). Library-level
/// so both the PYQ and mock controllers of this file share it.
Future<void> _recordSessionGamification(
  Ref ref,
  String trackId,
  PracticeSessionState next,
  ExamSessionKind kind,
) async {
  try {
    final gamification = ref.read(examGamificationProvider);
    await gamification.sessionFinished(ExamSessionRecord(
      kind: kind,
      trackId: trackId,
      correctCount: next.attempts.where((a) => a.verdict == 'correct').length,
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

final examPyqProvider =
    AsyncNotifierProvider.family<ExamPyqController, PyqStateData, String>(
  ExamPyqController.new,
);

/// Live mock-track state.
class MockStateData {
  const MockStateData({
    required this.trackId,
    required this.paper,
    required this.session,
    required this.result,
    required this.history,
    required this.notice,
  });

  final String trackId;

  /// The paper being run (null before/after).
  final MockPaper? paper;
  final PracticeSessionState? session;

  /// The finished result (null until done).
  final MockResult? result;

  /// Bounded history (newest last).
  final List<MockResult> history;
  final String? notice;

  bool get isRunning =>
      session != null && !session!.finished && session!.current != null;
  bool get isFinished => result != null;
}

class ExamMockController extends FamilyAsyncNotifier<MockStateData, String> {
  final PracticeSessionEngine _engine = const PracticeSessionEngine();

  @override
  Future<MockStateData> build(String trackId) async {
    final history = await ref.read(mockResultRepositoryProvider).load(trackId);
    return MockStateData(
      trackId: trackId,
      paper: null,
      session: null,
      result: null,
      history: history,
      notice: null,
    );
  }

  /// Builds + starts a mock of [kind] (§25 official structure).
  Future<void> start(MockKind kind, {String? focusSectionId}) async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty || scope.view == null) {
      state = AsyncError(
        StateError('No scope selected — no mock'),
        StackTrace.current,
      );
      return;
    }

    // Official board structure (§60 — from the canonical syllabus).
    final boardSections = <({String id, String title, double marks})>[];
    for (final section in scope.view!.sections) {
      final official =
          syllabus.sections.where((s) => s.id == section.id).firstOrNull;
      // Only BOARD sections are mockable — internal assessment is
      // never faked into a mock (§25 honesty).
      if (official == null ||
          official.assessmentType == AssessmentType.internal) {
        continue;
      }
      if (section.selectableUnits.isEmpty) continue;
      boardSections.add((
        id: section.id,
        title: section.title,
        marks: official.marks,
      ));
    }
    if (boardSections.isEmpty) {
      state = AsyncError(
        StateError('No board sections for this track'),
        StackTrace.current,
      );
      return;
    }
    final boardTotal = syllabus.boardExamTotalMarks > 0
        ? syllabus.boardExamTotalMarks
        : boardSections.fold<double>(0, (s, x) => s + x.marks);
    final boardHours = syllabus.boardExamDurationHours > 0
        ? syllabus.boardExamDurationHours.toInt()
        : 3;

    // Grounded question pool grouped by section.
    final bank = PyqBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
    );
    final bySection = <String, List<PyqQuestion>>{};
    final sectionByUnit = <String, String>{};
    for (final section in scope.view!.sections) {
      for (final unit in section.selectableUnits) {
        sectionByUnit[unit.id] = section.id;
      }
    }
    for (final q in bank) {
      final sectionId = sectionByUnit[q.topicId] ?? '';
      if (sectionId.isEmpty) continue;
      bySection.putIfAbsent(sectionId, () => []).add(q);
    }
    if (bySection.isEmpty) {
      state = AsyncError(
        StateError('No grounded mock content for this scope'),
        StackTrace.current,
      );
      return;
    }

    final paper = MockEngine.build(
      trackId: trackId,
      kind: kind,
      boardSections: boardSections,
      boardTotalMarks: boardTotal,
      boardDurationHours: boardHours,
      questionsBySection: bySection,
      focusSectionId: focusSectionId,
    );
    if (paper.allQuestions.isEmpty) {
      state = AsyncError(
        StateError('Mock paper came out empty'),
        StackTrace.current,
      );
      return;
    }

    state = AsyncData(MockStateData(
      trackId: trackId,
      paper: paper,
      session: _engine.start(paper.allQuestions),
      result: null,
      history: await _loadHistory(),
      notice: '${paper.questionCount} प्रश्न • ${paper.timeLimitMinutes} '
          'मिनट • कुल ${paper.totalMarks.toStringAsFixed(0)} अंक',
    ));
  }

  Future<void> submitMcq(int selectedIndex) async {
    final current = state.value;
    if (current?.session == null) return;
    await _absorb(current!, _engine.submitMcq(current.session!, selectedIndex));
  }

  Future<void> submitTyped(String text) async {
    final current = state.value;
    if (current?.session == null || text.trim().isEmpty) return;
    await _absorb(current!, _engine.submitTyped(current.session!, text));
  }

  Future<void> retryAttempt() async {
    final current = state.value;
    if (current?.session == null) return;
    _emit(current!, _engine.retryAttempt(current.session!));
  }

  Future<void> reveal() async {
    final current = state.value;
    if (current?.session == null) return;
    _emit(current!, _engine.reveal(current.session!));
  }

  Future<void> advance() async {
    final current = state.value;
    if (current?.session == null) return;
    await _absorb(current!, _engine.advance(current.session!));
  }

  Future<List<MockResult>> _loadHistory() async =>
      ref.read(mockResultRepositoryProvider).load(arg);

  void _emit(MockStateData current, PracticeSessionState next) {
    state = AsyncData(MockStateData(
      trackId: current.trackId,
      paper: current.paper,
      session: next,
      result: current.result,
      history: current.history,
      notice: null,
    ));
  }

  Future<void> _absorb(MockStateData current, PracticeSessionState next) async {
    if (next.finished) {
      await _finishMock(current, next);
      return;
    }
    _emit(current, next);
  }

  /// §41 DETERMINISTIC finish: analyze → persist → refresh history.
  /// §29 mastery + §21 attempt evidence ride the same hooks as PYQ.
  Future<void> _finishMock(
      MockStateData current, PracticeSessionState next) async {
    final trackId = arg;
    final paper = current.paper;
    if (paper == null) {
      _emit(current, next);
      return;
    }

    // §29 + §21 (same contracts as the other sessions).
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
    try {
      final kinds = {
        for (final q in next.questions)
          q.id: q.kind == PracticeQuestionKind.mcq ? 'mcq' : 'typed',
      };
      await ref.read(examAttemptLogRepositoryProvider).recordSession(
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
    } catch (_) {
      // §41.
    }

    // Deterministic analysis (§41 — mock results are critical state).
    final result = MockEngine.analyze(paper: paper, attempts: next.attempts);
    try {
      await ref.read(mockResultRepositoryProvider).record(result);
    } catch (_) {
      // §41: persistence failure never blocks showing the result.
    }

    // M10: the finished mock feeds the app-wide gamification (XP
    // once-ever, streak evidence, checkers, VAN) — §41.
    await _recordSessionGamification(ref, trackId, next, ExamSessionKind.mock);

    state = AsyncData(MockStateData(
      trackId: trackId,
      paper: paper,
      session: next,
      result: result,
      history: await _loadHistory(),
      notice: result.summary,
    ));
  }
}

final examMockProvider =
    AsyncNotifierProvider.family<ExamMockController, MockStateData, String>(
  ExamMockController.new,
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
