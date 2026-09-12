/// Exam Mode 2.0 — Exam Profile Providers (M3)
///
/// Riverpod wiring for the exam profile. [ExamProfileController] is a
/// family AsyncNotifier per track: it loads the persisted profile (or a
/// sensible draft), exposes edit methods (every field editable — §8
/// "The student must be able to edit this later"), and persists ONLY on
/// [save], which refuses invalid drafts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/exam_profile_repository.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';

final examProfileRepositoryProvider = Provider<ExamProfileRepository>((ref) {
  return ExamProfileRepository(ref.watch(localStorageServiceProvider));
});

/// The persisted snapshot (for flow gating: "profile set?").
final examProfileMapProvider =
    FutureProvider<Map<String, ExamProfile>>((ref) async {
  return ref.watch(examProfileRepositoryProvider).loadAll();
});

/// Live editable state for one track's profile.
class ExamProfileController extends FamilyAsyncNotifier<ExamProfile, String> {
  late ExamProfileRepository _repo;

  @override
  Future<ExamProfile> build(String trackId) async {
    _repo = ref.watch(examProfileRepositoryProvider);
    final saved = await _repo.load(trackId);
    // Draft for a first visit: 30 min × 5 days, no readiness yet — the
    // student must choose their own anchor (§8: never assume).
    return saved ??
        ExamProfile(
          trackId: trackId,
          dailyStudyMinutes: 30,
          studyDaysPerWeek: 5,
        );
  }

  Future<void> setDailyStudyMinutes(int minutes) =>
      _edit((p) => p.copyWith(dailyStudyMinutes: minutes));

  Future<void> setStudyDaysPerWeek(int days) =>
      _edit((p) => p.copyWith(studyDaysPerWeek: days));

  Future<void> setReadinessTargetDate(DateTime? date) =>
      _edit((p) => date == null
          ? p.copyWith(clearReadinessTargetDate: true)
          : p.copyWith(readinessTargetDate: date));

  Future<void> setReadinessDurationWeeks(int? weeks) =>
      _edit((p) => weeks == null
          ? p.copyWith(clearReadinessDurationWeeks: true)
          : p.copyWith(readinessDurationWeeks: weeks));

  Future<void> setActualExamDate(DateTime? date) => _edit((p) => date == null
      ? p.copyWith(clearActualExamDate: true)
      : p.copyWith(actualExamDate: date));

  Future<void> setPace(StudyPace pace) => _edit((p) => p.copyWith(pace: pace));

  /// Persists the draft. Returns the validation errors when the draft is
  /// invalid (nothing saved — the caller shows the first error honestly).
  Future<List<String>> save() async {
    final draft = state.value;
    if (draft == null) return ['Profile not loaded yet'];
    final errors = draft.validate();
    if (errors.isNotEmpty) return errors;
    final ok = await _repo.save(draft.copyWith(
      updatedAtIso: DateTime.now().toIso8601String(),
    ));
    if (!ok) return ['Profile could not be saved'];
    return const [];
  }

  Future<void> _edit(ExamProfile Function(ExamProfile) transform) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(transform(current));
  }
}

/// Profile state per track id.
final examProfileProvider =
    AsyncNotifierProvider.family<ExamProfileController, ExamProfile, String>(
  ExamProfileController.new,
);

/// Whether the track has a SAVED (persisted, valid) profile — the M4
/// diagnostic gate ("profile set?" step of the setup flow).
final hasExamProfileProvider =
    FutureProvider.family<bool, String>((ref, trackId) async {
  final profiles = await ref.watch(examProfileMapProvider.future);
  return profiles[trackId]?.isValid ?? false;
});
