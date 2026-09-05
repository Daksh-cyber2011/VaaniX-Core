/// Progress Providers — Riverpod wiring
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/errors/failures.dart';

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
  return _CompletedLessonsNotifier(
    ref.watch(progressRepositoryProvider),
    ref.watch(analyticsClientProvider),
  );
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
  _CompletedLessonsNotifier(this._repo, this._analytics)
      : super(const []) {
    final result = _repo.getCompletedLessonIds();
    result.fold((_) => null, (ids) => state = ids);
  }

  final ProgressRepository _repo;
  final AnalyticsClient _analytics;

  Future<void> markComplete(Lesson lesson) async {
    if (state.contains(lesson.id)) return;
    // Persist FIRST, then update state: the previous optimistic update
    // left the in-session list polluted when the repository write failed
    // (lesson looked completed until the next restart, with the XP
    // missing). On failure the error is rethrown so screens can surface
    // their "could not save" feedback and state stays truthful.
    final result = await _repo.completeLesson(lesson);
    Failure? failure;
    result.fold((f) => failure = f, (_) {});
    if (failure != null) {
      throw Exception('completeLesson failed: ${failure!.message}');
    }
    state = [...state, lesson.id];
    _analytics.log(AnalyticsEvent(AnalyticsEventName.lessonCompleted,
        {'lessonId': lesson.id, 'xp': lesson.xpReward}));
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

/// Reactive list of mastered exercise ids per lesson (family keyed by
/// lessonId). Powers Home's "unfinished practice" surfacing and the
/// Progress screen's mastery counts.
final masteredExercisesProvider = StateNotifierProvider.family<
    _MasteredExercisesNotifier, List<String>, String>(
  (ref, lessonId) => _MasteredExercisesNotifier(
    ref.watch(progressRepositoryProvider),
    lessonId,
  ),
);

/// Fire-and-forget persistence hook: records a finished practice
/// session's mastered exercise ids for [lessonId] (idempotent union).
final recordMasteryProvider =
    Provider<Future<void> Function(String lessonId, List<String> ids)>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return (lessonId, ids) async {
    await repo.recordMasteredExercises(lessonId, ids);
  };
});

class _MasteredExercisesNotifier extends StateNotifier<List<String>> {
  _MasteredExercisesNotifier(this._repo, this._lessonId) : super(const []) {
    _load();
  }

  final ProgressRepository _repo;
  final String _lessonId;

  void _load() {
    final result = _repo.getMasteredExercises(_lessonId);
    result.fold((_) => null, (ids) => state = ids);
  }

  /// Re-reads persisted mastery (called after a practice session saves).
  void refresh() => _load();
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
