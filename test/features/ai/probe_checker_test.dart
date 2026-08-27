import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checker works directly in a container', () async {
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

    final checker = container.read(achievementCheckerProvider);
    final unlocked = await checker.checkAchievements(didChatWithVan: true);
    expect(unlocked, isEmpty);
  });
}