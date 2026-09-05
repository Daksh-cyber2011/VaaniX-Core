/// markComplete Rollback Tests (Phase 1 regression)
///
/// Phase 1 changed lesson completion from optimistic-then-persist to
/// persist-then-commit: the reactive completed-lesson list may only grow
/// after the repository write succeeds, and a failure is rethrown so
/// screens can show their "could not save" feedback.
///
/// Previously a failed write left the lesson visible as completed for the
/// whole session while the XP and persisted state were missing.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// Progress repository whose lesson-completion write always fails.
class _FailingProgressRepository implements ProgressRepository {
  @override
  Result<List<String>> getCompletedLessonIds() => ok(const []);

  @override
  Result<List<String>> getCompletedQuizIds() => ok(const []);

  @override
  Result<List<QuizResult>> getQuizAttempts(String quizId) => ok(const []);

  @override
  Future<Result<int>> completeLesson(Lesson lesson) async =>
      err(const ServerFailure());

  @override
  Future<Result<QuizResult>> completeQuiz({
    required String quizId,
    required int score,
    required int total,
  }) async =>
      err(const ServerFailure());

  @override
  Result<int> getXp() => ok(0);

  @override
  Future<Result<int>> awardBonusXp({
    required String sourceId,
    required int amount,
  }) async =>
      err(const ServerFailure());

  @override
  Result<List<String>> getMasteredExercises(String lessonId) => ok(const []);

  @override
  Future<Result<void>> recordMasteredExercises(
    String lessonId,
    List<String> ids,
  ) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> reset() async => err(const ServerFailure());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('failed completion does not pollute the reactive lesson list',
      () async {
    final container = ProviderContainer(overrides: [
      progressRepositoryProvider.overrideWithValue(
        _FailingProgressRepository(),
      ),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(completedLessonIdsProvider.notifier);

    await expectLater(
      notifier.markComplete(const Lesson(
        id: 'ls_fail',
        chapterId: 'ch_fail',
        title: 'Failing Lesson',
        xpReward: 10,
      )),
      throwsException,
      reason: 'the failure must reach the screen so it can show feedback',
    );

    expect(container.read(completedLessonIdsProvider), isEmpty,
        reason: 'state must stay truthful when persistence fails');
  });

  test('successful completion commits after persistence', () async {
    // Drive the happy path against the REAL local repository: a successful
    // completeLesson must append the id exactly once.
    final prefs = await SharedPreferences.getInstance();
    final okContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(okContainer.dispose);
    final okNotifier = okContainer.read(completedLessonIdsProvider.notifier);
    await okNotifier.markComplete(const Lesson(
      id: 'ls_ok',
      chapterId: 'ch_ok',
      title: 'Happy Lesson',
      xpReward: 10,
    ));
    expect(okContainer.read(completedLessonIdsProvider), ['ls_ok']);
    // Repeat is a no-op (repository idempotency + state guard).
    await okNotifier.markComplete(const Lesson(
      id: 'ls_ok',
      chapterId: 'ch_ok',
      title: 'Happy Lesson',
      xpReward: 10,
    ));
    expect(okContainer.read(completedLessonIdsProvider), ['ls_ok']);
  });
}
