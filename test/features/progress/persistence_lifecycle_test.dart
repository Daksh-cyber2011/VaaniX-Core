/// Persistence Lifecycle QA
///
/// Walks the complete V1 user journey at the repository/provider level with
/// simulated app restarts (fresh ProviderContainer over the same storage):
/// practice mastery -> lesson completion -> exam attempt -> achievements,
/// then restart verification, duplicate-completion XP idempotency, and a
/// full reset that must clear progress, mastery, history AND achievements.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Simulates launching the app: a fresh provider graph over the SAME
  /// persisted storage (equivalent to closing and reopening the app).
  ProviderContainer launchApp() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  const lesson = Lesson(
    id: 'ls_lifecycle',
    chapterId: 'ch_lifecycle',
    title: 'Lifecycle Lesson',
    xpReward: 15,
  );
  const quizId = 'quiz_all_beginner';

  test(
      'full journey survives restarts; duplicates award nothing; reset clears all',
      () async {
    // ---- Session 1: learn + practice + exam + achievements ----
    var app = launchApp();
    var repo = app.read(progressRepositoryProvider);

    await repo.recordMasteredExercises(lesson.id, ['ex_a', 'ex_b']);
    await repo.completeLesson(lesson);
    final firstQuiz =
        (await repo.completeQuiz(quizId: quizId, score: 3, total: 4))
            .fold((_) => throw StateError('quiz failed'), (v) => v);
    expect(firstQuiz.xpEarned, 30); // 3 * xpPerCorrectAnswer

    final unlocked = await app
        .read(achievementCheckerProvider)
        .checkAchievements(quizScorePercentage: 75);
    expect(
        unlocked.map((a) => a.id), containsAll(['first_lesson', 'first_quiz']));
    app.dispose();

    // ---- Session 2 (restart): everything must still be there ----
    app = launchApp();
    repo = app.read(progressRepositoryProvider);

    expect(repo.getCompletedLessonIds().fold((_) => const <String>[], (v) => v),
        contains(lesson.id));
    expect(
        repo
            .getMasteredExercises(lesson.id)
            .fold((_) => const <String>[], (v) => v),
        ['ex_a', 'ex_b']);
    expect(repo.getCompletedQuizIds().fold((_) => const <String>[], (v) => v),
        contains(quizId));
    expect(
        repo
            .getQuizAttempts(quizId)
            .fold((_) => const <QuizResult>[], (v) => v),
        hasLength(1));

    // XP = lesson 15 + quiz 30 + achievement bonuses 20 + 20 = 85.
    final xpAfterFirstSession = repo.getXp().fold((_) => -1, (v) => v);
    expect(xpAfterFirstSession, 85);

    final unlockedAfterRestart =
        await app.read(unlockedAchievementsProvider.future);
    expect(
        unlockedAfterRestart.keys, containsAll(['first_lesson', 'first_quiz']));
    app.dispose();

    // ---- Session 3: re-completing everything must not duplicate XP ----
    app = launchApp();
    repo = app.read(progressRepositoryProvider);
    await repo.completeLesson(lesson);
    final secondQuiz =
        (await repo.completeQuiz(quizId: quizId, score: 4, total: 4))
            .fold((_) => throw StateError('quiz failed'), (v) => v);
    expect(secondQuiz.xpEarned, 0, reason: 'repeat quiz awards no XP');

    final xpAfterRepeats = repo.getXp().fold((_) => -1, (v) => v);
    expect(xpAfterRepeats, xpAfterFirstSession,
        reason: 'repeats must not change XP');

    // Attempt history still grows (for analytics), but XP does not.
    expect(
        repo
            .getQuizAttempts(quizId)
            .fold((_) => const <QuizResult>[], (v) => v),
        hasLength(2));

    // Re-running the checker must not re-unlock achievements that were
    // already unlocked and persisted in an earlier session. The 100%
    // trigger legitimately unlocks perfect_quiz for the first time.
    final again = await app
        .read(achievementCheckerProvider)
        .checkAchievements(quizScorePercentage: 100);
    expect(again.map((a) => a.id), ['perfect_quiz'],
        reason: 'only the first-time perfect score is new');
    expect(repo.getXp().fold((_) => -1, (v) => v), xpAfterFirstSession + 50);
    app.dispose();

    // ---- Session 4: full reset clears EVERYTHING ----
    app = launchApp();
    repo = app.read(progressRepositoryProvider);
    await repo.reset();
    await app.read(achievementRepositoryProvider).clear();

    expect(repo.getCompletedLessonIds().fold((_) => const ['stale'], (v) => v),
        isEmpty);
    expect(
        repo
            .getMasteredExercises(lesson.id)
            .fold((_) => const ['stale'], (v) => v),
        isEmpty);
    expect(repo.getCompletedQuizIds().fold((_) => const ['stale'], (v) => v),
        isEmpty);
    expect(repo.getQuizAttempts(quizId).fold((_) => const ['stale'], (v) => v),
        isEmpty);
    expect(repo.getXp().fold((_) => -1, (v) => v), 0);

    // A cleared account can earn achievements again once progress resumes.
    await repo.completeLesson(lesson);
    final afterReset =
        await app.read(achievementCheckerProvider).checkAchievements();
    expect(afterReset.map((a) => a.id), contains('first_lesson'),
        reason: 'a cleared account can earn achievements again');
    app.dispose();
  });
}
