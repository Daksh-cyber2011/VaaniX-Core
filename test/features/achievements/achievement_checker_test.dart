/// Achievement Checker Tests
///
/// Verifies the unlock contract: threshold achievements unlock from real
/// persisted progress, bonus XP is awarded exactly once, special
/// achievements (perfect quiz, Van friend) require their explicit triggers,
/// and an empty account never crashes or unlocks anything.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

ProviderContainer makeContainer(SharedPreferences prefs) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Future<SharedPreferences> prefsFuture;

  setUp(() {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefsFuture = SharedPreferences.getInstance();
  });

  Future<void> flushAsync() =>
      Future<void>.delayed(const Duration(milliseconds: 1));

  test('first_lesson unlocks once, awards bonus XP exactly once', () async {
    final container = makeContainer(
      await prefsFuture,
    );
    addTearDown(container.dispose);

    final repo = container.read(progressRepositoryProvider);
    await repo.completeLesson(const Lesson(
      id: 'l1',
      chapterId: 'chx',
      title: 'Lesson One',
      xpReward: 10,
    ));

    final checker = container.read(achievementCheckerProvider);
    final first = await checker.checkAchievements();
    expect(first.map((a) => a.id), contains('first_lesson'));

    await flushAsync();
    expect(container.read(xpTotalProvider), 30); // 10 lesson + 20 bonus

    final second = await checker.checkAchievements();
    expect(second, isEmpty, reason: 'no double unlock');
    await flushAsync();
    expect(container.read(xpTotalProvider), 30, reason: 'no double XP');
  });

  test('first_quiz unlocks after a quiz completion', () async {
    final container = makeContainer(await prefsFuture);
    addTearDown(container.dispose);

    final repo = container.read(progressRepositoryProvider);
    await repo.completeQuiz(quizId: 'qz1', score: 3, total: 3);

    final newly =
        await container.read(achievementCheckerProvider).checkAchievements();
    expect(newly.map((a) => a.id), contains('first_quiz'));
  });

  test('perfect_quiz only unlocks on a 100% trigger', () async {
    final container = makeContainer(await prefsFuture);
    addTearDown(container.dispose);

    final repo = container.read(progressRepositoryProvider);
    await repo.completeQuiz(quizId: 'qz2', score: 2, total: 4); // 50%

    final checker = container.read(achievementCheckerProvider);
    final atFifty = await checker.checkAchievements(quizScorePercentage: 50);
    expect(atFifty.map((a) => a.id), isNot(contains('perfect_quiz')));

    final atHundred = await checker.checkAchievements(quizScorePercentage: 100);
    expect(atHundred.map((a) => a.id), contains('perfect_quiz'));
  });

  test('van_friend unlocks only via the chat trigger', () async {
    final container = makeContainer(await prefsFuture);
    addTearDown(container.dispose);

    final checker = container.read(achievementCheckerProvider);
    final without = await checker.checkAchievements();
    expect(without.map((a) => a.id), isNot(contains('van_friend')));

    final withChat = await checker.checkAchievements(didChatWithVan: true);
    expect(withChat.map((a) => a.id), contains('van_friend'));
  });

  test('empty account is safe: nothing unlocks, no crash', () async {
    final container = makeContainer(await prefsFuture);
    addTearDown(container.dispose);

    final newly =
        await container.read(achievementCheckerProvider).checkAchievements();
    expect(newly, isEmpty);
  });

  test('a fresh app never re-reports already-unlocked achievements', () async {
    // Session 1: unlock first_lesson.
    final first = makeContainer(await prefsFuture);
    final repo = first.read(progressRepositoryProvider);
    await repo.completeLesson(const Lesson(
      id: 'l_race',
      chapterId: 'chx',
      title: 'Race Lesson',
      xpReward: 10,
    ));
    final unlocked =
        await first.read(achievementCheckerProvider).checkAchievements();
    expect(unlocked.map((a) => a.id), contains('first_lesson'));
    first.dispose();

    // Session 2 (same storage, brand-new provider graph): the async unlock
    // map may still be pending - the checker must consult persisted state
    // so nothing is re-unlocked or re-announced.
    final second = makeContainer(await prefsFuture);
    addTearDown(second.dispose);
    final again =
        await second.read(achievementCheckerProvider).checkAchievements();
    expect(again, isEmpty,
        reason: 'persisted unlocks must never be re-reported');
  });
}
