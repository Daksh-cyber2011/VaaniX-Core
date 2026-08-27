import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bisect: container health around chat controller', () async {
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

    // Step 1: direct checker use before anything else.
    final checkerA = container.read(achievementCheckerProvider);
    final r1 = await checkerA.checkAchievements(didChatWithVan: true);
    // ignore: avoid_print
    print('STEP1 direct ok, unlocked=${r1.length}');

    // Step 2: construct the chat controller only.
    final controllerNotifier =
        container.read(chatControllerProvider.notifier);
    // ignore: avoid_print
    print('STEP2 controller constructed');

    // Step 3: re-read the SAME checker provider again.
    final checkerB = container.read(achievementCheckerProvider);
    final r3 = await checkerB.checkAchievements(didChatWithVan: true);
    // ignore: avoid_print
    print('STEP3 second direct ok, unlocked=$r3');

    expect(controllerNotifier.state.isSending, isFalse);
  });
}