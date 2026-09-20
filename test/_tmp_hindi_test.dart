import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_content_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';

void main() {
  test('hindi registry loads', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'learn_language': 'hindi'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    print('selected: ${c.read(selectedLearnLanguageProvider)}');
    print('reading activeLearningPlanProvider...');
    final p = await c.read(activeLearningPlanProvider.future);
    print('plan: ${p.activityIds.length} activities');
    print('reading trustedContentRegistryProvider...');
    final r = await c.read(trustedContentRegistryProvider.future);
    print('registry: ${r.entries.length} entries');
  });
}
