/// Learning-Streak Reset Tests
///
/// The day streak + last-active marker measure learning behavior, so the
/// Settings reset flow clears them via [UserProfileRepository.resetLearningStreak].
/// Identity fields (companion name, class, goal) are untouched.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/profile/data/local_user_profile_repository.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, LocalUserProfileRepository)> makeRepo() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final repo = LocalUserProfileRepository(
      container.read(localStorageServiceProvider),
    );
    return (container, repo);
  }

  test('resetLearningStreak clears streak and last-active marker', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);
    final storage = container.read(localStorageServiceProvider);

    // A learner with a 5-day streak, last active yesterday.
    await storage.setCurrentStreak(5);
    await storage.setLastActiveDate('2026-08-28');

    await repo.resetLearningStreak();

    expect(storage.currentStreak, 0);
    expect(storage.lastActiveDate, isNull,
        reason: 'a stale last-active marker would re-inflate the streak');
  });

  test('the streak starts fresh at 1 after a reset', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);
    final storage = container.read(localStorageServiceProvider);

    await storage.setCurrentStreak(5);
    await storage.setLastActiveDate('2026-08-28');
    await repo.resetLearningStreak();

    final streak = await repo.recordDailyActivity();
    expect(streak.getOrElse(() => -1), 1);
    expect(storage.currentStreak, 1);
  });

  test('resetLearningStreak keeps identity fields', () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);
    final storage = container.read(localStorageServiceProvider);

    await storage.setCompanionName('Guru');
    await storage.setCurrentStreak(3);

    await repo.resetLearningStreak();

    expect(storage.companionName, 'Guru');
    expect(storage.currentStreak, 0);
  });

  test('the contract lives on the abstract repository (compile-time)',
      () async {
    final (container, repo) = await makeRepo();
    addTearDown(container.dispose);

    // Use it through the abstract type: a missing abstract member would
    // fail analysis, and a missing implementation would fail here.
    final UserProfileRepository typed = repo;
    await typed.resetLearningStreak();
    expect(
      container.read(localStorageServiceProvider).currentStreak,
      0,
    );
  });
}
