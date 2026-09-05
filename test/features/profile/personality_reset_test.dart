// Personality Reset Tests — Phase 5 (audit row J)
//
// The Van Profile screen's "Reset to default" button previously forced
// `PersonalityMode.cheerleader` under that label — cheerleader is only
// the first option in the picker, not a default, and once a mode was
// chosen there was NO way back to the un-personalised state (copyWith
// cannot null a field out). Phase 5 adds a real clear path through the
// repository and the notifier.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/auth/core_auth_session.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/profile/data/local_user_profile_repository.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late LocalUserProfileRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    repo = LocalUserProfileRepository(storage);
  });

  group('repository', () {
    test('clearPersonalityMode removes the persisted mode', () async {
      await storage.setPersonalityMode(PersonalityMode.calm.name);
      expect(storage.personalityMode, PersonalityMode.calm.name);

      final result = await repo.clearPersonalityMode();
      result.fold(
        (_) => fail('expected success'),
        (_) {},
      );

      expect(storage.personalityMode, isNull);
    });

    test('clearing is idempotent', () async {
      await repo.clearPersonalityMode();
      final second = await repo.clearPersonalityMode();
      second.fold(
        (_) => fail('expected success on re-clear'),
        (_) {},
      );
      expect(storage.personalityMode, isNull);
    });

    test('getProfile reports null mode after a clear, other fields kept',
        () async {
      await repo.updatePersonalityMode(PersonalityMode.fun);
      await repo.updateCompanionName('Quackers');
      await repo.clearPersonalityMode();

      final result = await repo.getProfile();
      result.fold(
        (_) => fail('expected success'),
        (profile) {
          expect(profile.personalityMode, isNull);
          expect(profile.companionName, 'Quackers',
              reason: 'a personality reset must not wipe identity fields');
        },
      );
    });
  });

  group('notifier', () {
    late UserProfileNotifier notifier;

    setUp(() {
      notifier = UserProfileNotifier(
        repo,
        const AuthSession(status: AuthStatus.unauthenticated),
        const NoopAnalyticsClient(),
      );
    });

    tearDown(() => notifier.dispose());

    test('clearPersonalityMode nulls the in-memory mode', () async {
      // Wait for the constructor's async _load to settle.
      await pumpEventQueue();
      await notifier.updatePersonalityMode(PersonalityMode.cheerleader);
      expect(notifier.state.personalityMode, PersonalityMode.cheerleader);

      await notifier.clearPersonalityMode();
      expect(notifier.state.personalityMode, isNull);
    });

    test('clearing keeps every other profile field intact', () async {
      await pumpEventQueue();
      await notifier.updateCompanionName('Sir Duckworth');
      await notifier.updateDailyGoal(15);
      await notifier.updatePersonalityMode(PersonalityMode.calm);

      await notifier.clearPersonalityMode();

      final state = notifier.state;
      expect(state.personalityMode, isNull);
      expect(state.companionName, 'Sir Duckworth');
      expect(state.dailyGoalMinutes, 15);
    });

    test('the cleared state survives a repository reload (app restart)',
        () async {
      await pumpEventQueue();
      await notifier.updatePersonalityMode(PersonalityMode.fun);
      await notifier.clearPersonalityMode();

      // A fresh notifier re-reads the profile from storage.
      final reloaded = UserProfileNotifier(
        repo,
        const AuthSession(status: AuthStatus.unauthenticated),
        const NoopAnalyticsClient(),
      );
      await pumpEventQueue();
      expect(reloaded.state.personalityMode, isNull);
      reloaded.dispose();
    });

    test('storage key is gone after the notifier-level clear', () async {
      await pumpEventQueue();
      await notifier.updatePersonalityMode(PersonalityMode.calm);
      expect(
        storage.keys.contains(AppConstants.keyPersonalityMode),
        isTrue,
      );

      await notifier.clearPersonalityMode();
      expect(
        storage.keys.contains(AppConstants.keyPersonalityMode),
        isFalse,
        reason: 'the reset must REMOVE the key, not write a placeholder — '
            'a leftover mode name would resurrect on next load',
      );
    });
  });
}
