/// Exam Mode 2.0 — Full-Teardown Provider
///
/// Deliberately its own file. [ExamDataReset] needs all ten Exam Mode
/// repository providers, which live across seven provider files;
/// [exam_repository_providers.dart] documents itself as a leaf that other
/// provider files import, so hanging this aggregate off it would invert that
/// and risk a provider-file cycle. Nothing imports this file except the
/// Settings reset handler, so it can safely sit above all of them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/data/exam_data_reset.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart'
    show examHubRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_plan_providers.dart'
    show examPlanRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_practice_providers.dart'
    show evaluationRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_profile_providers.dart'
    show examProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart'
    show mockResultRepositoryProvider, pyqPerformanceRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart'
    show examScopeRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart'
    show examAttemptLogRepositoryProvider, weakAreaRepositoryProvider;

/// The Exam Mode teardown used by Settings -> "Reset all progress".
final examDataResetProvider = Provider<ExamDataReset>((ref) {
  return ExamDataReset(
    profiles: ref.watch(examProfileRepositoryProvider),
    learnerProfiles: ref.watch(examLearnerProfileRepositoryProvider),
    scope: ref.watch(examScopeRepositoryProvider),
    plans: ref.watch(examPlanRepositoryProvider),
    weakAreas: ref.watch(weakAreaRepositoryProvider),
    attemptLog: ref.watch(examAttemptLogRepositoryProvider),
    evaluations: ref.watch(evaluationRepositoryProvider),
    pyqPerformance: ref.watch(pyqPerformanceRepositoryProvider),
    mockResults: ref.watch(mockResultRepositoryProvider),
    hub: ref.watch(examHubRepositoryProvider),
  );
});
