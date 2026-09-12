/// Exam Mode 2.0 — Diagnostic Providers (M4)
///
/// Riverpod wiring: [ExamDiagnosticController] runs the adaptive
/// session for one track against the grounded item bank, records every
/// response immediately (§55 "Diagnostic interrupted / App restarted" —
/// the finished responses are recoverable), and on completion persists
/// the report's estimates into the learner exam profile (the M5/M6
/// input).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/diagnostic/diagnostic_item_bank.dart';
import 'package:vaanix_app/features/exam/data/exam_learner_profile_repository.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_engine.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart'
    show ExamSessionKind, ExamSessionRecord;
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examGamificationProvider, examSessionFingerprintOf;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';

final examLearnerProfileRepositoryProvider =
    Provider<ExamLearnerProfileRepository>((ref) {
  return ExamLearnerProfileRepository(ref.watch(localStorageServiceProvider));
});

/// The learner's exam profile snapshot (live state for M5/M6 too).
final examLearnerProfileProvider =
    FutureProvider.family<ExamLearnerProfile, String>((ref, trackId) async {
  return ref
      .watch(examLearnerProfileRepositoryProvider)
      .load(trackId);
});

/// Live diagnostic session state.
class DiagnosticSessionStateData {
  const DiagnosticSessionStateData({
    required this.session,
    required this.report,
    required this.trackId,
  });

  final DiagnosticSessionState? session;
  final DiagnosticReport? report;
  final String trackId;

  bool get isRunning => session != null && !session!.finished;
  bool get isFinished => report != null;
}

class ExamDiagnosticController
    extends FamilyAsyncNotifier<DiagnosticSessionStateData, String> {
  late ExamLearnerProfileRepository _learnerRepo;
  ExamDiagnosticEngine? _engine;

  @override
  Future<DiagnosticSessionStateData> build(String trackId) async {
    _learnerRepo = ref.watch(examLearnerProfileRepositoryProvider);
    return DiagnosticSessionStateData(
      session: null,
      report: null,
      trackId: trackId,
    );
  }

  /// Starts (or restarts) the adaptive diagnostic from the current
  /// scope. The scope MUST be non-empty — an empty scope has nothing
  /// to diagnose (honest failure, no fake questions §60).
  Future<void> start() async {
    ref.read(examGamificationProvider).clearLastOutcome();
    final trackId = state.value?.trackId ?? arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus =
        await ref.read(courseSyllabusProvider(trackId).future);
    if (syllabus == null || scope.selection.isEmpty) {
      state = AsyncError(
        StateError('No scope selected — nothing to diagnose'),
        StackTrace.current,
      );
      return;
    }

    final bank = DiagnosticItemBank.build(
      syllabus: syllabus,
      view: scope.view!,
      selection: scope.selection,
    );
    if (bank.questions.isEmpty) {
      state = AsyncError(
        StateError('Not enough grounded questions for this scope'),
        StackTrace.current,
      );
      return;
    }

    _engine = ExamDiagnosticEngine(
      topicTitles: bank.topicTitles,
      topicSections: bank.topicSections,
      maxItems: 10,
    )..registerBank(bank.questions);

    state = AsyncData(DiagnosticSessionStateData(
      session: _engine.start(),
      report: null,
      trackId: trackId,
    ));
  }

  /// Answers the current question (-1 = skip) and advances.
  Future<void> answer(int selectedIndex) async {
    final current = state.value;
    final engine = _engine;
    if (current?.session == null || engine == null) return;
    final next = engine.answer(current!.session!, selectedIndex);
    state = AsyncData(DiagnosticSessionStateData(
      session: next,
      report: null,
      trackId: current.trackId,
    ));
    if (next.finished) await _finish(next);
  }

  Future<void> _finish(DiagnosticSessionState session) async {
    final engine = _engine;
    if (engine == null) return;
    final report = engine.buildReport(session);
    // Merge into the persistent learner profile (§12).
    final profile = await _learnerRepo.load(arg);
    final seeded =
        profile.mergeDiagnosticEstimates(report.estimatePairs);
    final withBand = ExamLearnerProfile(
      trackId: seeded.trackId,
      topics: seeded.topics,
      diagnosticCompletedAtIso: report.completedAtIso,
      diagnosticOverallBand: report.overallBand.name,
      schemaVersion: ExamLearnerProfile.currentSchemaVersion,
      updatedAtIso: seeded.updatedAtIso,
    );
    await _learnerRepo.save(withBand);
    ref.invalidate(examLearnerProfileProvider(arg));

    // M10: the finished diagnostic feeds the app-wide gamification
    // (XP once-ever, streak evidence, checkers, VAN) — §41. The
    // fingerprint covers the answered question ids + correctness.
    try {
      await ref.read(examGamificationProvider).sessionFinished(
            ExamSessionRecord(
              kind: ExamSessionKind.diagnostic,
              trackId: arg,
              correctCount:
                  session.responses.where((r) => r.correct).length,
              totalCount: session.responses.length,
              questionFingerprint: examSessionFingerprintOf(
                [
                  for (final r in session.responses) r.questionId,
                ],
                [
                  for (final r in session.responses)
                    r.correct ? 'correct' : 'incorrect',
                ],
              ),
              finishedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      // §41: gamification failure degrades to "no XP", never a crash.
    }

    final current = state.value;
    if (current != null) {
      state = AsyncData(DiagnosticSessionStateData(
        session: session,
        report: report,
        trackId: current.trackId,
      ));
    }
  }
}

final examDiagnosticProvider = AsyncNotifierProvider.family<
    ExamDiagnosticController, DiagnosticSessionStateData, String>(
  ExamDiagnosticController.new,
);

/// Whether the track has a completed diagnostic (the M5 plan gate).
final hasDiagnosticProvider = FutureProvider.family<bool, String>(
    (ref, trackId) async {
  final profile = await ref.watch(examLearnerProfileProvider(trackId).future);
  return profile.hasDiagnostic;
});
