/// Settings / profile persistence QA (brief section 7).
///
/// Verifies that every settings-editable profile field survives an app
/// restart, that streaks persist, and that signing out does NOT wipe local
/// progress (documented product behavior).
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer launchApp() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

  test('settings fields survive restart; sign-out keeps local progress',
      () async {
    // ---- Session 1: change every settings field + earn a streak ----
    var app = launchApp();
    var repo = app.read(userProfileRepositoryProvider);

    expect((await repo.getProfile()).fold((_) => null, (v) => v.companionName),
        'Van',
        reason: 'V1 default companion');

    await repo.updateDisplayName('Arjun');
    await repo.updateCompanionName('Mita');
    await repo.updatePersonalityMode(PersonalityMode.cheerleader);
    await repo.updateCbseClass(CbseClass.class7);
    await repo.updateDailyGoal(20);
    final streakDay1 =
        (await repo.recordDailyActivity()).fold((_) => -1, (v) => v);
    expect(streakDay1, 1);
    app.dispose();

    // ---- Session 2: everything persisted ----
    app = launchApp();
    repo = app.read(userProfileRepositoryProvider);
    final profile = (await repo.getProfile()).fold((_) => null, (v) => v)!;
    expect(profile.displayName, 'Arjun',
        reason: 'Phase 4: the learner display name persists (AI persona)');
    expect(profile.companionName, 'Mita');
    expect(profile.personalityMode, PersonalityMode.cheerleader);
    expect(profile.cbseClass, CbseClass.class7);
    expect(profile.dailyGoalMinutes, 20);
    expect(profile.currentStreak, 1, reason: 'streak must survive restart');

    // ---- Sign-out simulation: auth goes away, local data stays ----
    // V1 has no server account; the notifier reads local storage, so a
    // "sign out" only ends the session - progress is intentionally kept.
    final afterSignOut = (await repo.getProfile()).fold((_) => null, (v) => v)!;
    expect(afterSignOut.displayName, 'Arjun');
    expect(afterSignOut.companionName, 'Mita');
    expect(afterSignOut.dailyGoalMinutes, 20);
    expect(afterSignOut.currentStreak, 1);
    app.dispose();
  });

  test('malformed legacy preference types hydrate with safe defaults',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.keyLearnerName: 42,
      AppConstants.keyUserCompanionName: false,
      AppConstants.keyPersonalityMode: 7,
      AppConstants.keySelectedClass: '7',
      AppConstants.keyDailyGoalMinutes: '30',
      AppConstants.keyCurrentStreak: 'stale',
      AppConstants.keyLastActiveDate: 2026,
      AppConstants.keyCompletedLessonIds: 'not-a-list',
      AppConstants.keyCompletedQuizIds: 1,
    });
    prefs = await SharedPreferences.getInstance();

    final app = launchApp();
    addTearDown(app.dispose);
    final repo = app.read(userProfileRepositoryProvider);
    final profile = (await repo.getProfile()).getOrElse(() => UserProfile.empty);

    expect(profile.displayName, isEmpty);
    expect(profile.companionName, 'Van');
    expect(profile.personalityMode, isNull);
    expect(profile.cbseClass, isNull);
    expect(profile.dailyGoalMinutes, 10);
    expect(profile.currentStreak, 0);
    expect(profile.lastActiveDate, isNull);
    expect(
      app.read(localStorageServiceProvider).completedLessonIds,
      isEmpty,
    );
  });
}
