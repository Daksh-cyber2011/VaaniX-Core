/// Adaptive Learning Providers
///
/// Exposes the persisted attempt index (quizId -> attempts) and the derived
/// [adaptiveNextActionProvider] that Home uses to render the real next
/// learning action for the current learner state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
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
final quizAttemptsIndexProvider =
    StateNotifierProvider<QuizAttemptsIndexNotifier, Map<String, List<QuizResult>>>(
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
      _repo.getQuizAttempts(quizId).fold((_) {}, (attempts) {
        if (attempts.isNotEmpty) index[quizId] = attempts;
      });
    }
    state = index;
  }
}

/// The single most useful next action, derived purely from persisted state.
final adaptiveNextActionProvider = Provider<NextAction>((ref) {
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

  return computeNextAction(
    curriculum: curriculum,
    completedLessons: completed,
    masteredExerciseIdsByLesson: masteredByLesson,
    exerciseCountByLesson: exerciseCounts,
    quizIdsByChapter: quizIdsByChapter,
    attemptsByQuizId: attemptsIndex,
  );
});