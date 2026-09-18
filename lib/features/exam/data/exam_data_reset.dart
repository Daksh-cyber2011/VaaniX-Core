/// VaaniX Exam Mode — Full Data Teardown
///
/// Problem this solves
/// -------------------
/// Settings -> "Reset all progress" shows a dialog that tells the learner it
/// clears, among other things, their **exam history**. The handler cleared
/// Learn progress, achievements, the streak, the AI subsystem, milestones and
/// daily-activity counters — and nothing whatsoever from Exam Mode. Every one
/// of the twelve Exam Mode storage keys survived the wipe, so after a reset
/// the learner still had their old target date and daily minutes, their study
/// plan and its day overrides, their weak areas, their question-level attempt
/// log, their written-answer evaluations, their PYQ evidence, their mock
/// history, their scope selection and their exam XP ledger.
///
/// Two of those are worse than cosmetic:
///
/// * `exam_hub_xp_ledger_v1` is a set of once-ever XP fingerprints. A stale
///   entry means "already paid", so sessions the learner re-did after the
///   reset would silently award no XP.
/// * the weak-area and PYQ/attempt evidence feeds the planner, so a "fresh
///   start" would immediately be re-planned around the pre-reset learner.
///
/// Why this is a separate object
/// -----------------------------
/// The teardown has to touch ten repositories. Inlining ten `ref.read(...)`
/// calls in the Settings dialog handler would make the most destructive path
/// in the app the least testable one, and the list would quietly drift as
/// stores are added. Collecting it here gives it one home, one doc comment
/// explaining what "exam history" actually means, and a unit test that seeds
/// every store and asserts every key is gone.
///
/// Each repository exposes a production `clear()`; their `reset()` hooks stay
/// `@visibleForTesting` and now delegate to `clear()`, so there is exactly one
/// teardown implementation per store and production never calls a test-only
/// member.
library;

import 'package:vaanix_app/features/exam/data/evaluation/evaluation_repository.dart';
import 'package:vaanix_app/features/exam/data/exam_learner_profile_repository.dart';
import 'package:vaanix_app/features/exam/data/exam_profile_repository.dart';
import 'package:vaanix_app/features/exam/data/exam_scope_repository.dart';
import 'package:vaanix_app/features/exam/data/hub/exam_hub_repository.dart';
import 'package:vaanix_app/features/exam/data/planner/exam_plan_repository.dart';
import 'package:vaanix_app/features/exam/data/pyq_mock/pyq_performance_repository.dart';
import 'package:vaanix_app/features/exam/data/weakarea/exam_attempt_log_repository.dart';
import 'package:vaanix_app/features/exam/data/weakarea/weak_area_repository.dart';

/// Clears every Exam Mode store. See the library doc for why this exists.
class ExamDataReset {
  const ExamDataReset({
    required this.profiles,
    required this.learnerProfiles,
    required this.scope,
    required this.plans,
    required this.weakAreas,
    required this.attemptLog,
    required this.evaluations,
    required this.pyqPerformance,
    required this.mockResults,
    required this.hub,
  });

  final ExamProfileRepository profiles;
  final ExamLearnerProfileRepository learnerProfiles;
  final ExamScopeRepository scope;
  final ExamPlanRepository plans;
  final WeakAreaRepository weakAreas;
  final ExamAttemptLogRepository attemptLog;
  final EvaluationRepository evaluations;
  final PyqPerformanceRepository pyqPerformance;
  final MockResultRepository mockResults;
  final ExamHubRepository hub;

  /// Every Exam Mode storage key this teardown is responsible for.
  ///
  /// Exposed so the regression test can seed all of them and assert all of
  /// them are gone, rather than re-listing the keys in the test and drifting
  /// from production. The hub's two keys are private to that repository and
  /// are covered by the test through its own store instead.
  static const List<String> storageKeys = <String>[
    ExamProfileRepository.storageKey,
    ExamLearnerProfileRepository.storageKey,
    ExamScopeRepository.storageKey,
    ExamPlanRepository.storageKey,
    ExamPlanRepository.overrideStorageKey,
    WeakAreaRepository.storageKey,
    ExamAttemptLogRepository.storageKey,
    EvaluationRepository.storageKey,
    PyqPerformanceRepository.storageKey,
    MockResultRepository.storageKey,
  ];

  /// Drops every Exam Mode store.
  ///
  /// Sequential rather than `Future.wait`: the underlying `SharedPreferences`
  /// writes share one backing map, and a serial teardown keeps the failure
  /// mode legible (if one store throws, the ones before it are already gone
  /// and the caller's error path is not racing nine other writes).
  Future<void> clearAll() async {
    await profiles.clear();
    await learnerProfiles.clear();
    await scope.clear();
    await plans.clear();
    await weakAreas.clear();
    await attemptLog.clear();
    await evaluations.clear();
    await pyqPerformance.clear();
    await mockResults.clear();
    await hub.clear();
  }
}
