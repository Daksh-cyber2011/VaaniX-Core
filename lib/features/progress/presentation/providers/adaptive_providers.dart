/// Adaptive Learning Providers
///
/// Exposes the persisted attempt index (quizId -> attempts) and the derived
/// [adaptiveNextActionProvider] that Home uses to render the real next
/// learning action for the current learner state, plus the weak-lesson list
/// and per-chapter exam performance that the Progress screen surfaces.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// All known quiz ids for the current curriculum, in the same
/// `quiz_<chapter>_<difficulty>` space used by [ExamConfig].
List<String> allQuizIds() {
  final ids = <String>[];
  for (final entry in chapterQuizzes.entries) {
    for (final question in entry.value) {
      ids.add('quiz_${entry.key}_${question.difficulty.name}');
    }
  }
  return ids.toSet().toList();
}

/// quizId -> persisted attempt history (newest last). Loaded from the
/// progress repository; invalidate to refresh after a completed exam.
final quizAttemptsIndexProvider = StateNotifierProvider<
        QuizAttemptsIndexNotifier, Map<String, List<QuizResult>>>(
    (ref) => QuizAttemptsIndexNotifier(ref.watch(progressRepositoryProvider)));

class QuizAttemptsIndexNotifier
    extends StateNotifier<Map<String, List<QuizResult>>> {
  QuizAttemptsIndexNotifier(this._repo) : super(const {}) {
    _load();
  }

  final ProgressRepository _repo;

  Future<void> _load() async {
    final index = <String, List<QuizResult>>{};
    for (final quizId in allQuizIds()) {
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

  final quizIdsByChapter = <String, List<String>>{};
  for (final chapter in curriculum) {
    quizIdsByChapter[chapter.id] = chapterQuizzes[chapter.id]
            ?.map((q) => 'quiz_${chapter.id}_${q.difficulty.name}')
            .toList() ??
        const [];
  }

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
/// Chapters without attempts are absent, so UIs can show a clear "not
/// attempted" state instead of a fabricated score.
final chapterBestFractionProvider = Provider<Map<String, double>>((ref) {
  final i = _adaptiveInputs(ref);
  final result = <String, double>{};
  for (final chapter in i.curriculum) {
    final best = bestExamFractionForChapter(
      chapter.id,
      i.quizIdsByChapter,
      i.attemptsIndex,
    );
    if (best > 0) result[chapter.id] = best;
  }
  return result;
});
