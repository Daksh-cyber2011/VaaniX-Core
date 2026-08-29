/// Progress Reset Purge Tests
///
/// Reset must clear XP, completed lessons/quizzes, mastery AND attempt
/// history under ANY quiz id (prefix purge), including orphaned history
/// that is not referenced by completedQuizIds.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
      (
        ProviderContainer,
        LocalProgressRepository,
      )> makeRepo() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final repo = LocalProgressRepository(
      container.read(localStorageServiceProvider),
    );
    return (container, repo);
  }

  test('reset purges attempt history for orphaned quiz ids too', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);
    final storage = container.read(localStorageServiceProvider);

    // Real completion flow.
    await repo.completeLesson(const Lesson(
      id: 'ls_orphan_1',
      chapterId: 'ch_orphan',
      title: 'Orphan',
      xpReward: 30,
    ));
    await repo.completeQuiz(
        quizId: 'quiz_ch_orphan_beginner', score: 4, total: 5);
    await repo.recordMasteredExercises('ls_orphan_1', const ['ex_a', 'ex_b']);

    // Simulate STALE history: an attempt key with no matching completed
    // quiz id (schema evolution / old data).
    await storage.setQuizAttempts(
      'quiz_legacy_v0',
      jsonEncode([
        QuizResult(
          quizId: 'quiz_legacy_v0',
          score: 1,
          total: 5,
          xpEarned: 0,
        ).toJson(),
      ]),
    );
    expect(storage.getQuizAttempts('quiz_legacy_v0'), isNotNull);

    await repo.reset();

    expect(repo.getXp().getOrElse(() => -1), 0);
    expect(repo.getCompletedLessonIds().getOrElse(() => ['x']), isEmpty);
    expect(repo.getCompletedQuizIds().getOrElse(() => ['x']), isEmpty);
    expect(repo.getMasteredExercises('ls_orphan_1').getOrElse(() => ['x']),
        isEmpty);
    expect(storage.getQuizAttempts('quiz_ch_orphan_beginner'), isNull,
        reason: 'live attempt keys are removed, not just emptied');
    expect(storage.getQuizAttempts('quiz_legacy_v0'), isNull,
        reason: 'stale attempt keys must not survive a reset');
  });

  test('reset keeps profile identity fields intact', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);
    final storage = container.read(localStorageServiceProvider);

    await storage.setCompanionName('Guru');
    await storage.setDailyGoalMinutes(30);
    await repo.completeLesson(const Lesson(
      id: 'ls_x',
      chapterId: 'ch_x',
      title: 'X',
      xpReward: 10,
    ));

    await repo.reset();

    expect(storage.companionName, 'Guru',
        reason: 'identity stays; only progress is wiped');
    expect(storage.dailyGoalMinutes, 30);
    expect(repo.getXp().getOrElse(() => -1), 0);
  });
}
