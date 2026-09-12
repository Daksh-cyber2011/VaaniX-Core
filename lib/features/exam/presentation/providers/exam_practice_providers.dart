/// Exam Mode 2.0 — Practice Providers (M6 + M7 wiring, M8 evidence)
///
/// [ExamPracticeController] runs the adaptive loop for one track:
///  * builds the grounded content bank (weak topics first, §22);
///  * MCQ answers are absorbed deterministically;
///  * TYPED answers flow through the M7 rubric evaluator;
///  * PHOTO answers flow through the M7 vision pipeline
///    ([PhotoAnswerEvaluator]) — quality gates, honest uncertainty,
///    retake-or-type advice;
///  * finalized attempts update the persistent learner profile
///    (mastery connection, §29) — evidence never lives only in UI
///    state (§12);
///  * M8: finalized attempts are ALSO persisted to the question-level
///    attempt log (batched, one write per finished session) — the
///    §21 pattern-detection evidence the weak-area engines read.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/evaluation/gemini_vision_evaluator.dart';
import 'package:vaanix_app/features/exam/data/evaluation/evaluation_repository.dart';
import 'package:vaanix_app/features/exam/data/practice/practice_content_bank.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_session_engine.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart'
    show ErrorEvidence;
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart'
    show ExamSessionKind, ExamSessionRecord;
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider, examLearnerProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examGamificationProvider, examSessionFingerprintOf;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart'
    show examAttemptLogRepositoryProvider, weakAreaOverviewProvider;

/// Repository for the bounded evaluation log (M7).
final evaluationRepositoryProvider = Provider<EvaluationRepository>((ref) {
  return EvaluationRepository(ref.watch(localStorageServiceProvider));
});

/// Live practice session state + the last evaluation result (the UI
/// renders the M7 feedback panel from it).
class PracticeStateData {
  const PracticeStateData({
    required this.trackId,
    required this.session,
    required this.lastEvaluation,
    required this.summary,
  });

  final String trackId;
  final PracticeSessionState? session;
  final EvaluationResult? lastEvaluation;

  /// §28-style closing summary (set when finished).
  final String? summary;

  bool get isRunning =>
      session != null && !session!.finished && session!.current != null;
  bool get isFinished => session != null && session!.finished;
}

class ExamPracticeController
    extends FamilyAsyncNotifier<PracticeStateData, String> {
  final PracticeSessionEngine _engine = const PracticeSessionEngine();

  @override
  Future<PracticeStateData> build(String trackId) async {
    return PracticeStateData(
      trackId: trackId,
      session: null,
      lastEvaluation: null,
      summary: null,
    );
  }

  /// Starts (or restarts) a practice session for the current scope.
  Future<void> start() async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty || scope.view == null) {
      state = AsyncError(
        StateError('No scope selected — nothing to practice'),
        StackTrace.current,
      );
      return;
    }
    final learner = await ref.read(examLearnerProfileProvider(trackId).future);
    final weakIds = learner.weakTopicsFirst(limit: 30)
        .map((t) => t.topicId)
        .where((id) => scope.selection.isSelected(id))
        .toSet();

    final questions = PracticeContentBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
      weakTopicIds: weakIds,
    );
    if (questions.isEmpty) {
      state = AsyncError(
        StateError('Not enough grounded practice content for this scope'),
        StackTrace.current,
      );
      return;
    }
    state = AsyncData(PracticeStateData(
      trackId: trackId,
      session: _engine.start(questions),
      lastEvaluation: null,
      summary: null,
    ));
  }

  /// MCQ submission.
  Future<void> submitMcq(int selectedIndex) async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.submitMcq(current!.session!, selectedIndex);
    await _absorb(current, next);
  }

  /// Typed submission (M7 rubric evaluator).
  Future<void> submitTyped(String text) async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.submitTyped(current!.session!, text);
    await _absorb(current, next);
  }

  /// Photo submission (M7 vision pipeline). Returns the evaluation
  /// result so the UI can show the §26 advice panel immediately.
  Future<EvaluationResult?> submitPhoto({
    required List<int> bytes,
    required String mime,
    int width = 0,
    int height = 0,
  }) async {
    final current = state.value;
    final q = current?.session?.current;
    if (current == null || q == null) return null;
    final isRetry = current.session!.currentRetryCount >= 1;

    final evaluator = PhotoAnswerEvaluator(
      questionPrompt: q.prompt,
      acceptedAnswers: q.acceptedAnswers,
      requiredPoints: q.requiredPoints,
    );
    final result = await evaluator.evaluate(
      photoBytes: bytes,
      mime: mime,
      photoWidth: width,
      photoHeight: height,
      isRetry: isRetry,
    );
    _recordEvaluation(trackId: current.trackId, question: q, result: result);

    if (result.verdict == EvaluationVerdict.uncertain) {
      // §26: uncertain photo ⇒ advice shown, question stays open for
      // retake/typed retry; the session does NOT advance.
      state = AsyncData(PracticeStateData(
        trackId: current.trackId,
        session: current.session,
        lastEvaluation: result,
        summary: null,
      ));
      return result;
    }

    final next = _engine.submitPhotoEvaluation(current.session!, result);
    await _absorb(current, next, lastEvaluation: result);
    return result;
  }

  /// Student taps "try again": re-opens input on the same question.
  Future<void> retryAttempt() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.retryAttempt(current!.session!);
    state = AsyncData(PracticeStateData(
      trackId: current.trackId,
      session: next,
      lastEvaluation: null,
      summary: null,
    ));
  }

  /// Student taps "next": records the finalized attempt (mastery
  /// evidence, §29) and moves the loop forward.
  Future<void> advance() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.advance(current!.session!);
    await _absorb(current, next);
  }

  /// Reveal-the-answer path (student choice, §20).
  Future<void> reveal() async {
    final current = state.value;
    if (current?.session == null) return;
    final next = _engine.reveal(current!.session!);
    state = AsyncData(PracticeStateData(
      trackId: current.trackId,
      session: next,
      lastEvaluation: null,
      summary: null,
    ));
  }

  Future<void> _absorb(
    PracticeStateData current,
    PracticeSessionState next, {
    EvaluationResult? lastEvaluation,
  }) async {
    String? summary;
    if (next.finished) {
      summary = PracticeSessionEngine.summary(next);
      await _persistMastery(next, current.trackId);
      // M8: the same finalized attempts become §21 pattern evidence.
      await _persistAttemptLog(next, current.trackId);
      // M10: the finished session feeds the app-wide gamification
      // (XP once-ever, streak evidence, checkers, VAN) — best-effort.
      await _recordGamification(next, current.trackId);
    }
    state = AsyncData(PracticeStateData(
      trackId: current.trackId,
      session: next,
      lastEvaluation: lastEvaluation,
      summary: summary,
    ));
  }

  /// Mastery connection (§29): finalized attempts update the
  /// persistent learner profile. A storage failure never blocks the
  /// session (best-effort, logged).
  Future<void> _persistMastery(
      PracticeSessionState session, String trackId) async {
    try {
      final repo = ref.read(examLearnerProfileRepositoryProvider);
      var profile = await repo.load(trackId);
      PracticeSessionEngine.masteryUpdates(session).forEach((topicId, ok) {
        profile = profile.recordAttempt(topicId: topicId, correct: ok);
      });
      await repo.save(profile);
      ref.invalidate(examLearnerProfileProvider(trackId));
    } catch (_) {
      // §41: persistence failure must not crash the learning loop.
    }
  }

  /// M10: gamification for the finished session (§41 best-effort —
  /// the XP/streak chain never blocks the loop). The record is built
  /// ONLY from the finalized attempts — the same evidence the
  /// mastery/§21 engines persisted.
  Future<void> _recordGamification(
      PracticeSessionState session, String trackId) async {
    try {
      final gamification = ref.read(examGamificationProvider);
      await gamification.sessionFinished(ExamSessionRecord(
        kind: ExamSessionKind.practice,
        trackId: trackId,
        correctCount: session.attempts
            .where((a) => a.verdict == 'correct')
            .length,
        totalCount: session.attempts.length,
        questionFingerprint: examSessionFingerprintOf(
          [for (final a in session.attempts) a.questionId],
          [for (final a in session.attempts) a.verdict],
        ),
        finishedAt: DateTime.now(),
      ));
    } catch (_) {
      // §41: gamification failure degrades to "no XP", never a crash.
    }
  }

  /// Question-level evidence persistence (M8, §21/§12): one batched
  /// write per finished session (§18). Photo answers carry their own
  /// kind from the current question; verdicts use the M6 vocabulary.
  Future<void> _persistAttemptLog(
      PracticeSessionState session, String trackId) async {
    try {
      final repo = ref.read(examAttemptLogRepositoryProvider);
      final kinds = <String, String>{};
      for (final q in session.questions) {
        kinds[q.id] = q.kind == PracticeQuestionKind.mcq ? 'mcq' : 'typed';
      }
      await repo.recordSession(
        trackId: trackId,
        attempts: [
          for (final a in session.attempts)
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
      // §41: evidence logging failure never blocks the learning loop.
    }
  }

  void _recordEvaluation({
    required String trackId,
    required PracticeQuestion question,
    required EvaluationResult result,
  }) {
    try {
      final repo = ref.read(evaluationRepositoryProvider);
      repo.record(
        trackId: trackId,
        questionId: question.id,
        topicId: question.topicId,
        kind: AnswerKind.photo,
        verdict: result.verdict.name,
      );
    } catch (_) {
      // Analytics-style logging — best-effort only.
    }
  }
}

final examPracticeProvider = AsyncNotifierProvider.family<
    ExamPracticeController, PracticeStateData, String>(
  ExamPracticeController.new,
);
