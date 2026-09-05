/// Bonus XP Ledger Tests (Phase 1 regression)
///
/// Phase 1 repaired achievement bonus XP: it used to be routed through
/// completeLesson() with a synthetic `ach_*` lesson id, polluting
/// completed_lesson_ids (inflating journey %, lesson stats, the adaptive
/// subtitle and achievement lesson counts). It now flows through the
/// repository's dedicated, idempotent bonus-XP ledger.
///
/// Verified here:
///   - awardBonusXp awards exactly once per source id
///   - bonus XP never touches completed lesson/quiz records
///   - legacy `ach_*` ids are stripped from persisted lesson ids
///   - the achievement checker path leaves lesson ids clean
///   - reset() clears the ledger so cleared achievements can re-award
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad();
  });

  Future<(ProviderContainer, LocalProgressRepository)> makeRepo({
    Map<String, Object> initialStorage = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialStorage);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final repo = LocalProgressRepository(
      container.read(localStorageServiceProvider),
    );
    return (container, repo);
  }

  test('awards bonus XP exactly once per source id', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);

    final first = await repo.awardBonusXp(sourceId: 'ach_test_badge', amount: 25);
    final second = await repo.awardBonusXp(sourceId: 'ach_test_badge', amount: 25);

    expect(first.fold((_) => -1, (v) => v), 25);
    expect(second.fold((_) => -1, (v) => v), 25,
        reason: 'the same source must never double-award');
    expect(repo.getXp().fold((_) => -1, (v) => v), 25);

    // A different source still awards.
    final other = await repo.awardBonusXp(sourceId: 'ach_other', amount: 10);
    expect(other.fold((_) => -1, (v) => v), 35);
  });

  test('bonus XP never touches completed lesson/quiz records', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);

    await repo.awardBonusXp(sourceId: 'ach_test_badge', amount: 30);

    expect(repo.getCompletedLessonIds().fold((_) => ['x'], (v) => v), isEmpty,
        reason: 'bonus XP must not create synthetic lesson ids');
    expect(repo.getCompletedQuizIds().fold((_) => ['x'], (v) => v), isEmpty,
        reason: 'bonus XP must not create synthetic quiz ids');
  });

  test('legacy ach_* lesson ids are sanitized on construction', () async {
    // Simulate a legacy install whose completed_lesson_ids were polluted
    // by the old achievement XP path. Stored as a StringList (matching
    // LocalStorageService.setStringList).
    final (container, repo) = await makeRepo(initialStorage: {
      'flutter.completed_lesson_ids': [
        'ls_alphabet_vowels',
        'ach_first_lesson',
        'ach_three_day_streak',
        'ls_words_greetings',
      ],
    });
    addTearDown(container.dispose);

    final ids = repo.getCompletedLessonIds().fold((_) => <String>[], (v) => v);
    expect(ids, ['ls_alphabet_vowels', 'ls_words_greetings'],
        reason: 'synthetic achievement ids must be stripped');
  });

  test('checker-driven unlock keeps lesson ids clean but awards XP',
      () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);

    await repo.completeLesson(const Lesson(
      id: 'ls_real',
      chapterId: 'ch_real',
      title: 'Real Lesson',
      xpReward: 10,
    ));

    final newly =
        await container.read(achievementCheckerProvider).checkAchievements();
    expect(newly.map((a) => a.id), contains('first_lesson'));

    // 10 lesson XP + 20 first_lesson bonus.
    expect(container.read(xpTotalProvider), 30);

    final ids = repo.getCompletedLessonIds().fold((_) => <String>[], (v) => v);
    expect(ids, ['ls_real'],
        reason: 'no ach_* id may appear in the completed lessons');
  });

  test('reset() clears the bonus ledger so re-earned achievements re-award',
      () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);

    await repo.awardBonusXp(sourceId: 'ach_test_badge', amount: 30);
    await repo.reset();

    // After reset the ledger is empty: the same source can award again
    // (mirrors achievements being cleared in the same reset flow).
    final reAward =
        await repo.awardBonusXp(sourceId: 'ach_test_badge', amount: 30);
    expect(reAward.fold((_) => -1, (v) => v), 30,
        reason: 'ledger must not survive a reset');
  });
}
