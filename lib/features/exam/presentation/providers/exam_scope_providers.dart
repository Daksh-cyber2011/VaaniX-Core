/// Exam Mode 2.0 — Exam Scope Providers (M2)
///
/// Riverpod wiring for the scope flow. [ExamScopeController] is a
/// write-through StateNotifier: every selection change is persisted
/// immediately (SharedPreferences writes are cheap; no dirty-state bookkeeping
/// can go stale). The controller is parameterized by track id via a family
/// so each course keeps its own scope, and the syllabus/view is read through
/// the existing validated [courseSyllabusProvider].
///
/// Course isolation is enforced twice: by the domain model (rejects foreign
/// ids) and by the view (ids are namespaced per track by construction).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/data/exam_scope_repository.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/core/providers/app_providers.dart' show localStorageServiceProvider;

/// Repository singleton (tests override SharedPreferences initial values).
final examScopeRepositoryProvider = Provider<ExamScopeRepository>((ref) {
  return ExamScopeRepository(ref.watch(localStorageServiceProvider));
});

/// The saved store snapshot (loaded once; the controller is the live state).
final examScopeStoreProvider = FutureProvider<ExamScopeStore>((ref) async {
  return ref.watch(examScopeRepositoryProvider).load();
});

/// Live scope state for one track.
class ExamScopeState {
  const ExamScopeState({
    required this.selection,
    required this.view,
  });

  final ExamScopeSelection selection;

  /// Null while the syllabus loads or if the course file is invalid.
  final ExamScopeView? view;

  bool get isReady => view != null;

  int get selectedCount => selection.selectedUnitIds.length;

  int get totalSelectable => view?.selectableUnitIds.length ?? 0;

  double get coveredMarks =>
      view == null ? 0 : selection.coveredMarks(view!);

  double get boardMarks => view?.boardMarks ?? 0;
}

class ExamScopeController
    extends FamilyAsyncNotifier<ExamScopeState, String> {
  late ExamScopeRepository _repo;

  @override
  Future<ExamScopeState> build(String trackId) async {
    _repo = ref.watch(examScopeRepositoryProvider);
    final syllabus = await ref.watch(
        courseSyllabusProvider(trackId).future);

    // Invalid/missing course data must not produce a fake selection UI.
    if (syllabus == null) {
      throw StateError('Syllabus unavailable for track $trackId');
    }

    final view = ExamScopeView.fromSyllabus(syllabus);
    var selection = await _repo.loadSelection(trackId);
    // Integrity pass: drop ids that the current syllabus no longer has.
    selection = selection.pruneTo(view);

    return ExamScopeState(selection: selection, view: view);
  }

  /// Toggles one unit. No-op when the unit is not a selectable unit of
  /// this course's view (isolation gate; the domain check is the second
  /// line of defense).
  Future<void> toggleUnit(String unitId) async {
    final view = state.value?.view;
    if (view == null) return;
    if (view.unitById(unitId)?.selectable != true) return;
    await _mutate((s) => s.toggle(unitId));
  }

  /// SELECT ALL (every published board unit of this course).
  Future<void> selectAll() async {
    await _mutate((s) => s.selectAll(state.value!.view!.selectableUnitIds));
  }

  /// CLEAR ALL.
  Future<void> clearAll() async {
    await _mutate((s) => s.clearAll());
  }

  /// Selects/deselects an entire section's selectable units.
  Future<void> toggleSection(String sectionId) async {
    final view = state.value!.view!;
    final section =
        view.sections.firstWhere((s) => s.id == sectionId);
    await _mutate((s) => s.toggleSection(
          section.selectableUnits.map((u) => u.id),
        ));
  }

  /// Confirms the current selection as the active track + persists it.
  Future<void> confirmSelection() async {
    final current = state.value;
    if (current == null) return;
    await _repo.saveSelection(current.selection);
  }

  Future<void> _mutate(
      ExamScopeSelection? Function(ExamScopeSelection) transform) async {
    final current = state.value;
    if (current == null || current.view == null) return;
    final next = transform(current.selection);
    if (next == null || next == current.selection) return;
    state = AsyncData(ExamScopeState(selection: next, view: current.view));
    // Write-through: scope is small; persistence must never lag the UI.
    await _repo.saveSelection(next);
  }
}

/// Scope state per track id.
final examScopeProvider =
    AsyncNotifierProvider.family<ExamScopeController, ExamScopeState, String>(
  ExamScopeController.new,
);

/// Whether the stored active track matches [trackId] (edit-later entry).
final isActiveTrackProvider = FutureProvider.family<bool, String>(
    (ref, trackId) async {
  final active = await ref.watch(examScopeStoreProvider.future);
  return active.activeTrackId == trackId;
});
