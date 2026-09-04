/// Adaptive Learning - Next Action Engine
///
/// Pure, deterministic derivation of the single most useful next action from
/// REAL persisted state (completed lessons, exercise mastery, exam attempts).
/// No randomness, no fabrication: every recommendation traces back to data
/// written by the progress repository.
///
/// Priority order:
///   1. allDone        - every lesson complete AND every chapter exam passed
///   2. takeChapterExam- a chapter's lessons are complete but its exam was
///                       never passed (or the best attempt is below [passPct])
///   3. practiceWeakTopic - an earlier completed lesson still has unmastered
///                       exercises (locked in before moving on)
///   4. continueLesson / startJourney - the next unfinished lesson in order
library;

import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// The kind of next action recommended to the learner.
enum AdaptiveAction {
  /// Nothing started yet - begin with the first lesson.
  startJourney,

  /// Proceed to the next unfinished lesson.
  continueLesson,

  /// Re-practice a completed lesson whose exercises are not all mastered.
  practiceWeakTopic,

  /// A chapter's lessons are done - take (or retake) its exam.
  takeChapterExam,

  /// The whole V1 syllabus is complete and every exam passed.
  allDone,
}

/// A grounded, human-readable next action plus the guidance VAN should give.
class NextAction {
  const NextAction({
    required this.action,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.vanMessage,
    this.lessonId,
    this.chapterId,
  });

  final AdaptiveAction action;

  /// Short primary CTA text (button).
  final String label;

  /// Card headline inside the Nest.
  final String title;

  /// Card detail line.
  final String subtitle;

  /// What VAN says about this next step.
  final String vanMessage;

  /// Target lesson (startJourney / continueLesson / practiceWeakTopic).
  final String? lessonId;

  /// Target chapter (takeChapterExam).
  final String? chapterId;
}

/// Minimum best-attempt fraction for a chapter exam to count as passed.
const double kExamPassFraction = 0.6;

/// Best fraction across all attempts of a quiz group (0.0 if none).
double _bestAttemptFraction(List<QuizResult> attempts) {
  if (attempts.isEmpty) return 0;
  var best = 0.0;
  for (final a in attempts) {
    if (a.percentage > best) best = a.percentage;
  }
  return best;
}

/// True when any quiz of [chapterId] has been passed (>= [kExamPassFraction]).
bool _chapterExamPassed(
  String chapterId,
  Map<String, List<String>> quizIdsByChapter,
  Map<String, List<QuizResult>> attemptsByQuizId,
) {
  return bestExamFractionForChapter(
        chapterId,
        quizIdsByChapter,
        attemptsByQuizId,
      ) >=
      kExamPassFraction;
}

/// Best score fraction across every quiz of [chapterId] (0.0 when none).
/// Used by the Progress screen to surface real exam performance per chapter.
double bestExamFractionForChapter(
  String chapterId,
  Map<String, List<String>> quizIdsByChapter,
  Map<String, List<QuizResult>> attemptsByQuizId,
) {
  final ids = quizIdsByChapter[chapterId] ?? const <String>[];
  var best = 0.0;
  for (final id in ids) {
    final fraction = _bestAttemptFraction(attemptsByQuizId[id] ?? const []);
    if (fraction > best) best = fraction;
  }
  return best;
}

/// Completed lessons whose exercises are not fully mastered, in curriculum
/// order. Powers both the practice recommendation and the Progress screen's
/// weak-area list - one engine, no duplicate logic.
List<Lesson> listWeakLessons({
  required List<Chapter> curriculum,
  required Set<String> completedLessons,
  required Map<String, List<String>> masteredExerciseIdsByLesson,
  required Map<String, int> exerciseCountByLesson,
}) {
  final weak = <Lesson>[];
  for (final chapter in curriculum) {
    for (final lesson in chapter.lessons) {
      if (!completedLessons.contains(lesson.id)) continue;
      final total = exerciseCountByLesson[lesson.id] ?? 0;
      if (total == 0) continue;
      final mastered = masteredExerciseIdsByLesson[lesson.id]?.length ?? 0;
      if (mastered < total) weak.add(lesson);
    }
  }
  return weak;
}

/// Computes the next action from persisted state. All inputs are real
/// repository data - this function never guesses.
NextAction computeNextAction({
  required List<Chapter> curriculum,
  required Set<String> completedLessons,
  required Map<String, List<String>> masteredExerciseIdsByLesson,
  required Map<String, int> exerciseCountByLesson,
  required Map<String, List<String>> quizIdsByChapter,
  required Map<String, List<QuizResult>> attemptsByQuizId,
}) {
  if (curriculum.isEmpty) {
    return const NextAction(
      action: AdaptiveAction.startJourney,
      label: 'Start Learning',
      title: 'Your journey begins',
      subtitle: 'The syllabus is on its way...',
      vanMessage: 'Namaste! I am ready whenever you are.',
    );
  }

  final allLessons = curriculum.expand((c) => c.lessons).toList();
  final allLessonIds = allLessons.map((l) => l.id).toSet();
  final allLessonsDone = allLessonIds.difference(completedLessons).isEmpty;
  final allExamsPassed = curriculum.every(
      (c) => _chapterExamPassed(c.id, quizIdsByChapter, attemptsByQuizId));

  // 1. Complete journey.
  if (allLessonsDone && allExamsPassed) {
    return const NextAction(
      action: AdaptiveAction.allDone,
      label: 'Revise with VAN',
      title: 'Syllabus complete!',
      subtitle: 'Every lesson and every exam - wonderful.',
      vanMessage:
          'You did it - the whole V1 syllabus is complete! Chat with me '
          'anytime to revise or explore more.',
    );
  }

  // 2. First chapter whose lessons are done but whose exam is not passed.
  final Chapter? examReadyChapter = curriculum
      .where((c) {
        final chapterDone =
            c.lessons.every((l) => completedLessons.contains(l.id));
        return chapterDone &&
            !_chapterExamPassed(c.id, quizIdsByChapter, attemptsByQuizId);
      })
      .cast<Chapter?>()
      .firstWhere((c) => c != null, orElse: () => null);

  if (examReadyChapter != null) {
    return NextAction(
      action: AdaptiveAction.takeChapterExam,
      label: 'Take the ${examReadyChapter.title} exam',
      title: 'Exam time!',
      subtitle:
          'You have completed every lesson in ${examReadyChapter.title} - '
          'now show what you know.',
      vanMessage:
          'You finished ${examReadyChapter.title}! Ready to shine in the '
          'exam? I believe in you.',
      chapterId: examReadyChapter.id,
    );
  }

  // 3. Weak spot: earliest completed lesson with unmastered exercises.
  final weakLessons = listWeakLessons(
    curriculum: curriculum,
    completedLessons: completedLessons,
    masteredExerciseIdsByLesson: masteredExerciseIdsByLesson,
    exerciseCountByLesson: exerciseCountByLesson,
  );

  if (weakLessons.isNotEmpty) {
    final weakLesson = weakLessons.first;
    final total = exerciseCountByLesson[weakLesson.id] ?? 0;
    final mastered = masteredExerciseIdsByLesson[weakLesson.id]?.length ?? 0;
    return NextAction(
      action: AdaptiveAction.practiceWeakTopic,
      label: 'Practice: ${weakLesson.title}',
      title: 'Practice makes permanent',
      subtitle: '$mastered of $total exercises mastered - finish them '
          'to lock in ${weakLesson.title}.',
      vanMessage:
          'Let us master ${weakLesson.title} together - a quick practice '
          'round and it is yours.',
      lessonId: weakLesson.id,
    );
  }

  // 4. Fresh start vs. next lesson.
  final Lesson? next = _nextLessonInCurriculum(curriculum, completedLessons);
  if (completedLessons.isEmpty && next != null) {
    return NextAction(
      action: AdaptiveAction.startJourney,
      label: 'Start Learning',
      title: 'Your journey begins',
      subtitle: next.title,
      vanMessage: 'Namaste! Let us begin with ${next.title}. I will guide you '
          'every step of the way.',
      lessonId: next.id,
    );
  }
  if (next != null) {
    return NextAction(
      action: AdaptiveAction.continueLesson,
      label: 'Continue: ${next.title}',
      title: 'Continue learning',
      subtitle: '${completedLessons.length} of ${allLessonIds.length} '
          'lessons done - keep the momentum!',
      vanMessage: 'Ready for ${next.title}? Let us keep going together.',
      lessonId: next.id,
    );
  }

  // Unreachable in practice (covered by rules 1-2), but be safe.
  return const NextAction(
    action: AdaptiveAction.allDone,
    label: 'Revise with VAN',
    title: 'Syllabus complete!',
    subtitle: 'Everything is mastered and every exam passed.',
    vanMessage: 'You can always revise with me - just say the word.',
  );
}

/// The first lesson (in chapter/lesson order) that is not yet completed.
Lesson? _nextLessonInCurriculum(
    List<Chapter> curriculum, Set<String> completedLessons) {
  for (final chapter in curriculum) {
    for (final lesson in chapter.lessons) {
      if (!completedLessons.contains(lesson.id)) return lesson;
    }
  }
  return null;
}
