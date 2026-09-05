/// Streak Achievement Trigger Tests (Phase 1 regression)
///
/// Phase 1 wired the achievement checker into the Home screen's daily
/// activity recording. Previously a 3-day / 7-day streak achievement
/// could only unlock the next time the learner happened to finish a
/// lesson, quiz or chat — streak activity alone never triggered a check.
///
/// Verified here (provider level, the exact chain Home drives):
///   - recordDailyActivity reaching a streak threshold unlocks the
///     streak achievement on the immediately following check
///   - a repository failure leaves the in-memory profile untouched
///     (no false lastActiveDate stamp)
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';

/// Profile repository whose daily-activity write always fails.
class _FailingProfileRepository implements UserProfileRepository {
  @override
  Future<Result<UserProfile>> getProfile() async => err(const ServerFailure());

  @override
  Future<Result<void>> saveProfile(UserProfile profile) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> updateDisplayName(String name) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> updateCompanionName(String name) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> updatePersonalityMode(PersonalityMode mode) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> clearPersonalityMode() async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> updateCbseClass(CbseClass? cbseClass) async =>
      err(const ServerFailure());

  @override
  Future<Result<void>> updateDailyGoal(int minutes) async =>
      err(const ServerFailure());

  @override
  Future<Result<int>> recordDailyActivity() async => err(const ServerFailure());

  @override
  Future<Result<void>> resetLearningStreak() async => err(const ServerFailure());
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('reaching a 3-day streak unlocks three_day_streak on the next check',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    // Seed an in-progress 2-day streak whose last active day was yesterday
    // (through the typed storage service, matching the app's key handling).
    final storage = container.read(localStorageServiceProvider);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await storage.setCurrentStreak(2);
    await storage.setLastActiveDate(_isoDate(yesterday));

    // The exact chain Home runs in its post-frame callback.
    final streak = await container
        .read(userProfileProvider.notifier)
        .recordDailyActivity();
    expect(streak, 3, reason: 'yesterday + today extends the streak to 3');

    final newly =
        await container.read(achievementCheckerProvider).checkAchievements();
    expect(newly.map((a) => a.id), contains('three_day_streak'),
        reason: 'streak activity alone must trigger the unlock');
  });

  test('no unlock below the streak threshold', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final storage = container.read(localStorageServiceProvider);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await storage.setCurrentStreak(1);
    await storage.setLastActiveDate(_isoDate(yesterday));

    await container.read(userProfileProvider.notifier).recordDailyActivity();
    final newly =
        await container.read(achievementCheckerProvider).checkAchievements();
    expect(newly.map((a) => a.id), isNot(contains('three_day_streak')));
  });

  test('repository failure leaves profile state untouched (no false stamp)',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProfileRepositoryProvider.overrideWithValue(
          _FailingProfileRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // The failing repository also fails getProfile, so the notifier state
    // holds UserProfile.empty. A failed daily-activity write must leave
    // that state exactly as it is (no false lastActiveDate stamp).
    final notifier = container.read(userProfileProvider.notifier);
    final returned = await notifier.recordDailyActivity();

    expect(returned, container.read(userProfileProvider).currentStreak,
        reason: 'failure must fall back to the current in-memory streak');
    expect(container.read(userProfileProvider).lastActiveDate, isNull,
        reason: 'a failed write must not stamp lastActiveDate as today');
  });
}
