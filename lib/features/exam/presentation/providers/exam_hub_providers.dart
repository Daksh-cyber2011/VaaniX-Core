/// Exam Mode 2.0 — Exam Hub Providers (M10)
///
/// Gathers the REAL persisted state of every earlier milestone into
/// the pure [ExamHubSnapshot]:
///
///   M2 scope store   → active track (entry gate)
///   M3 profile       → readiness anchor + countdown
///   M4 diagnostic    → hasDiagnostic (honest gate state)
///   M5 plan repo     → the rolling plan + today's day
///   M8 overview      → weak findings, recovery decision, revision due
///   M9 performance   → PYQ totals + latest mock band
///   M10 completions  → which of today's tasks finished sessions marked
///
/// Every input is best-effort (§41): a failing store degrades that
/// line to its honest "no data" form instead of failing the hub.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examDayCompletionsProvider, examDayKeyOf;
import 'package:vaanix_app/features/exam/presentation/providers/exam_plan_providers.dart'
    show examPlanRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_profile_providers.dart'
    show examProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart'
    show examScopeStoreProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart'
    show computeWeakAreaOverview;
import 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart'
    show mockResultRepositoryProvider, pyqPerformanceRepositoryProvider;

/// The active track id from the M2 scope store (null when unset) —
/// the hub entry uses this to route to setup vs. the track's hub.
final examActiveTrackIdProvider = FutureProvider<String?>((ref) async {
  final store = await ref.watch(examScopeStoreProvider.future);
  return store.activeTrackId;
});

/// Builds the snapshot for one track. All failure modes degrade
/// honestly (§41).
Future<ExamHubSnapshot> computeExamHubSnapshot(
  Ref ref,
  String trackId,
  DateTime now,
) async {
  ExamPlan? plan;
  try {
    plan = await ref.read(examPlanRepositoryProvider).load(trackId);
  } catch (_) {
    plan = null;
  }

  ExamProfile? profile;
  try {
    profile = await ref.read(examProfileRepositoryProvider).load(trackId);
  } catch (_) {
    profile = null;
  }

  var hasDiagnostic = false;
  try {
    final learner = await ref.read(examLearnerProfileProvider(trackId).future);
    hasDiagnostic = learner.hasDiagnostic;
  } catch (_) {
    hasDiagnostic = false;
  }

  var weak = const ExamHubWeakInput(
    findingCount: 0,
    topSeverityName: '',
    recoveryRecommended: false,
    recoveryDayIndex: 0,
    revisionDueCount: 0,
  );
  try {
    final overview = await computeWeakAreaOverview(ref, trackId);
    final findings = overview.report.findings;
    weak = ExamHubWeakInput(
      findingCount: findings.length,
      topSeverityName:
          findings.isEmpty ? '' : findings.first.severity.name,
      recoveryRecommended: overview.decision.shouldRecover,
      recoveryDayIndex: overview.decision.dayIndex,
      revisionDueCount: overview.dueRevision(limit: 10).length,
    );
  } catch (_) {
    // §41: weak-area lines degrade to "no weak areas detected yet".
  }

  var pyqAttempted = 0;
  var pyqCorrect = 0;
  try {
    final performance =
        await ref.read(pyqPerformanceRepositoryProvider).load(trackId);
    for (final t in performance.values) {
      pyqAttempted += t.attempted;
      pyqCorrect += t.correct;
    }
  } catch (_) {
    // §41: PYQ line degrades to "not attempted yet".
  }

  String? lastMockBand;
  String? lastMockKind;
  var mockCount = 0;
  try {
    final history =
        await ref.read(mockResultRepositoryProvider).load(trackId);
    mockCount = history.length;
    if (history.isNotEmpty) {
      lastMockBand = history.last.overallBand;
      lastMockKind = history.last.kind.name;
    }
  } catch (_) {
    // §41: mock line degrades to "no mock yet".
  }

  var completed = const <String>{};
  try {
    completed = await ref.watch(
        examDayCompletionsProvider('$trackId|${examDayKeyOf(now)}').future);
  } catch (_) {
    completed = const <String>{};
  }

  return ExamHubSnapshot(
    now: now,
    hasDiagnostic: hasDiagnostic,
    plan: plan,
    profile: profile,
    weak: weak,
    pyqAttemptedTotal: pyqAttempted,
    pyqCorrectTotal: pyqCorrect,
    lastMockBand: lastMockBand,
    lastMockKindName: lastMockKind,
    mockCount: mockCount,
    completedTaskTypeNames: completed,
  );
}

/// Live hub snapshot per track. Refreshed by invalidation whenever a
/// session finishes (the gamification chain invalidates completions;
/// plan/weak-area providers are invalidated by their own controllers).
final examHubSnapshotProvider =
    FutureProvider.family<ExamHubSnapshot, String>((ref, trackId) {
  return computeExamHubSnapshot(ref, trackId, DateTime.now());
});
