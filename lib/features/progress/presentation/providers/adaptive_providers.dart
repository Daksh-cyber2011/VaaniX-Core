/// Adaptive Learning Providers
///
/// Exposes the persisted attempt index (quizId -> attempts) and the derived
/// [adaptiveNextActionProvider] that Home uses to render the real next
/// learning action for the current learner state, plus the weak-lesson list
/// and per-chapter exam performance that the Progress screen surfaces.
///
/// Phase 2 single source: every quiz id / per-chapter map here is derived
/// from the JSON question bank ([quizBankProvider]) — the hardcoded Dart
/// maps are no longer consulted, so the exam flow and the adaptive engine
/// can never drift apart.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// All quiz ids in the `quiz_<chapter>_<difficulty>` space used by
/// [ExamConfig], derived from the loaded JSON bank. Empty until the bank
/// finishes loading (then recomputed — consumers rebuild reactively).
final quizIdCatalogProvider = Provider<Set<String>>((ref) {
  final bank = ref.watch(quizBankProvider).valueOrNull;
  if (bank == null) return const <String>{};
  return {
    for (final q in bank)
      if (q.chapterId.isNotEmpty) 'quiz_${q.chapterId}_${q.difficulty.name}',
  };
});

/// chapterId -> its quiz ids (same `quiz_<chapter>_<difficulty>` space),
/// derived from the loaded JSON bank. Deterministic per bank order.
final quizIdsByChapterProvider = Provider<Map<String, List<String>>>((ref) {
  final bank = ref.watch(quizBankProvider).valueOrNull;
  if (bank == null) return const <String, List<String>>{};
  final map = <String, List<String>>{};
  for (final q in bank) {
    if (q.chapterId.isEmpty) continue;
    map
        .putIfAbsent(q.chapterId, () => [])
        .add('quiz_${q.chapterId}_${q.difficulty.name}');
  }
  // De-duplicate while preserving the bank's deterministic order.
  return {
    for (final entry in map.entries) entry.key: entry.value.toSet().toList(),
  };
});

/// quizId -> persisted attempt history (newest last). Loaded from the
/// progress repository; invalidate to refresh after a completed exam.
final quizAttemptsIndexProvider = StateNotifierProvider<
        QuizAttemptsIndexNotifier, Map<String, List<QuizResult>>>(
    (ref) => QuizAttemptsIndexNotifier(
          ref.watch(progressRepositoryProvider),
          ref.watch(quizIdCatalogProvider),
        ));

class QuizAttemptsIndexNotifier
    extends StateNotifier<Map<String, List<QuizResult>>> {
  QuizAttemptsIndexNotifier(this._repo, this._quizIds) : super(const {}) {
    // Loads synchronously (storage reads are sync) so consumers reading
    // this provider right after construction see the real index — no
    // transient "no attempts" state.
    _load();
  }

  final ProgressRepository _repo;
  final Set<String> _quizIds;

  void _load() {
    final index = <String, List<QuizResult>>{};
    for (final quizId in _quizIds) {
      _repo.getQuizAttempts(quizId).fold(
        (_) {},
        (List<QuizResult> attempts) {
          if (attempts.isNotEmpty) index[quizId] = attempts;
        },
      );
    }
    state = index;
  }
}

/// Shared assembly of every persisted input the adaptive derivations need.
/// One place to gather state, watched by all adaptive providers so they
/// recompute together.
typedef AdaptiveInputs = ({
  List<Chapter> curriculum,
  Set<String> completedLessons,
  Map<String, List<String>> masteredByLesson,
  Map<String, int> exerciseCounts,
  Map<String, List<String>> quizIdsByChapter,
  Map<String, List<QuizResult>> attemptsIndex,
});

AdaptiveInputs _adaptiveInputs(Ref ref) {
  final curriculum =
      ref.watch(curriculumProvider).valueOrNull ?? const <Chapter>[];
  final completed = ref.watch(completedLessonIdsProvider).toSet();
  final attemptsIndex = ref.watch(quizAttemptsIndexProvider);

  final masteredByLesson = <String, List<String>>{};
  final exerciseCounts = <String, int>{};
  for (final chapter in curriculum) {
    for (final lesson in chapter.lessons) {
      masteredByLesson[lesson.id] =
          ref.watch(masteredExercisesProvider(lesson.id));
      exerciseCounts[lesson.id] = exercisesByLesson[lesson.id]?.length ?? 0;
    }
  }

  final quizIdsByChapter = ref.watch(quizIdsByChapterProvider);

  return (
    curriculum: curriculum,
    completedLessons: completed,
    masteredByLesson: masteredByLesson,
    exerciseCounts: exerciseCounts,
    quizIdsByChapter: quizIdsByChapter,
    attemptsIndex: attemptsIndex,
  );
}

/// The single most useful next action, derived purely from persisted state.
final adaptiveNextActionProvider = Provider<NextAction>((ref) {
  final i = _adaptiveInputs(ref);
  return computeNextAction(
    curriculum: i.curriculum,
    completedLessons: i.completedLessons,
    masteredExerciseIdsByLesson: i.masteredByLesson,
    exerciseCountByLesson: i.exerciseCounts,
    quizIdsByChapter: i.quizIdsByChapter,
    attemptsByQuizId: i.attemptsIndex,
  );
});

/// Completed lessons with unmastered exercises, in curriculum order.
/// The Progress screen renders this as the weak-area list.
final weakLessonsProvider = Provider<List<Lesson>>((ref) {
  final i = _adaptiveInputs(ref);
  return listWeakLessons(
    curriculum: i.curriculum,
    completedLessons: i.completedLessons,
    masteredExerciseIdsByLesson: i.masteredByLesson,
    exerciseCountByLesson: i.exerciseCounts,
  );
});

/// Best exam fraction (0.0..1.0) per chapter, from real attempt history.
///
/// Phase 2 best-score display fix: a chapter appears here whenever the
/// learner has AT LEAST ONE attempt for any of its quizzes — even when the
/// best fraction is 0.0. The previous `best > 0` filter conflated
/// "attempted and scored 0%" with "never attempted", so the Progress screen
/// showed "Exam not attempted" to a learner who had actually sat the exam.
/// Chapters without any attempt are still absent, letting the UI show a
/// clear "not attempted" state instead of a fabricated score.
final chapterBestFractionProvider = Provider<Map<String, double>>((ref) {
  final i = _adaptiveInputs(ref);
  final result = <String, double>{};
  for (final chapter in i.curriculum) {
    final ids = i.quizIdsByChapter[chapter.id] ?? const <String>[];
    final attempted =
        ids.any((id) => (i.attemptsIndex[id] ?? const []).isNotEmpty);
    if (!attempted) continue;
    result[chapter.id] =
        bestExamFractionForChapter(chapter.id, i.quizIdsByChapter, i.attemptsIndex);
  }
  return result;
});
