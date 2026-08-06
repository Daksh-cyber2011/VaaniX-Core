/// Progress Providers — Riverpod wiring

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return LocalProgressRepository(ref.watch(localStorageServiceProvider));
});

/// Reactive list of completed lesson IDs.
final completedLessonIdsProvider =
    StateNotifierProvider<_CompletedLessonsNotifier, List<String>>((ref) {
  return _CompletedLessonsNotifier(ref.watch(progressRepositoryProvider));
});

/// Reactive list of completed quiz IDs (at least once each).
final completedQuizIdsProvider =
    StateNotifierProvider<_CompletedQuizIdsNotifier, List<String>>((ref) {
  return _CompletedQuizIdsNotifier(ref.watch(progressRepositoryProvider));
});

/// Reactive XP total. Single source of truth for XP across the app —
/// the profile module delegates to this instead of maintaining its own copy.
final xpTotalProvider = StateNotifierProvider<_XpNotifier, int>((ref) {
  return _XpNotifier(ref.watch(progressRepositoryProvider));
});

class _CompletedLessonsNotifier extends StateNotifier<List<String>> {
  _CompletedLessonsNotifier(this._repo) : super(const []) {
    final result = _repo.getCompletedLessonIds();
    result.fold((_) => null, (ids) => state = ids);
  }

  final ProgressRepository _repo;

  Future<void> markComplete(Lesson lesson) async {
    if (state.contains(lesson.id)) return;
    state = [...state, lesson.id];
    await _repo.completeLesson(lesson);
  }
}

class _CompletedQuizIdsNotifier extends StateNotifier<List<String>> {
  _CompletedQuizIdsNotifier(this._repo) : super(const []) {
    final result = _repo.getCompletedQuizIds();
    result.fold((_) => null, (ids) => state = ids);
  }

  final ProgressRepository _repo;

  /// Called after a quiz is persisted so the UI updates reactively.
  void refresh() {
    final result = _repo.getCompletedQuizIds();
    result.fold((_) => null, (ids) => state = ids);
  }
}

class _XpNotifier extends StateNotifier<int> {
  _XpNotifier(this._repo) : super(0) {
    final result = _repo.getXp();
    result.fold((_) => null, (xp) => state = xp);
  }

  final ProgressRepository _repo;

  Future<void> add(int amount) async {
    // XP is updated inside completeLesson/completeQuiz; this is a refresh hook.
    final result = _repo.getXp();
    result.fold((_) => null, (xp) => state = xp);
  }
}
