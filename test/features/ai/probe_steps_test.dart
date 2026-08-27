import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/van/domain/van_event.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bisect sendMessage steps', () async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    // ignore: avoid_print
    print('A: userProfile=${container.read(userProfileProvider).toString()}');
    final van = container.read(vanControllerProvider.notifier);

    van.dispatch(const VanEvent(VanEventType.userMessageReceived));
    van.dispatch(const VanEvent(VanEventType.aiThinking));
    // ignore: avoid_print
    print('C: dispatched thinking');

    final checker = container.read(achievementCheckerProvider);
    // ignore: avoid_print
    print('D: checker obtained');

    final r1 = await checker.checkAchievements();
    // ignore: avoid_print
    print('E: first check ok unlocked=${r1.length}');

    van.dispatch(const VanEvent(
      VanEventType.aiResponseStarted,
      message: 'Namaste!',
    ));
    // ignore: avoid_print
    print('G: dispatched aiResponseStarted');

    final r2 = await checker.checkAchievements(didChatWithVan: true);
    // ignore: avoid_print
    print('H: second check ok unlocked=${r2.length}');

    // Sanity: container still readable.
    expect(prefs.getKeys(), isA<Set<String>>());
  });
}