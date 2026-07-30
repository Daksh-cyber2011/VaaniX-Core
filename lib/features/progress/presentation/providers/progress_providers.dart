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

/// Reactive XP total.
final xpTotalProvider = StateNotifierProvider<_XpNotifier, int>((ref) {
  return _XpNotifier(ref.watch(progressRepositoryProvider));
});

class _CompletedLessonsNotifier extends StateNotifier<List<String>> {
  _CompletedLessonsNotifier(this._repo) : super(const []) {
    final result = _repo.getCompletedLessonIds();
    result.fold((_) => null, (ids) => state = ids);
  }

  final ProgressRepository _repo;

  Future<void> markComplete(String lessonId, int xpReward) async {
    if (state.contains(lessonId)) return;
    state = [...state, lessonId];
    await _repo.completeLesson(_dummyLesson(lessonId, xpReward));
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

Lesson _dummyLesson(String id, int xpReward) =>
    // ignore: unused_element — local helper for progress bookkeeping.
    Lesson(id: id, title: '', chapterId: '', xpReward: xpReward);
