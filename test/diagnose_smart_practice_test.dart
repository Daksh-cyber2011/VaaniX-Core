// TEMPORARY diagnostic — not a test. Finds which provider level stalls
// under testWidgets when the AI text client is overridden.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';

class _Fake implements PlannerTextClient {
  int calls = 0;
  @override
  bool get isAvailable => true;
  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    calls++;
    return 'definitely not a plan';
  }
}

void main() {
  testWidgets('reproduce hang', (tester) async {
    SharedPreferences.setMockInitialValues({'learn_language': 'hindi'});
    final prefs = await SharedPreferences.getInstance();
    final client = _Fake();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        plannerTextClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(c.dispose);

    Future<void> settle(String label, bool Function() ready) async {
      for (var i = 0; i < 60; i++) {
        if (ready()) {
          // ignore: avoid_print
          print('DIAG: $label OK after $i pumps');
          return;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      // ignore: avoid_print
      print('DIAG: $label *** STALLED ***');
    }

    await settle('curriculum', () => c.read(activeCurriculumProvider).hasValue);
    await settle('graph', () => c.read(activeConceptGraphProvider).hasValue);
    await settle('learningState', () => c.read(activeLearningStateProvider).hasValue);
    await settle('plannerContext', () => c.read(activePlannerContextProvider).hasValue);
    await settle('plan', () => c.read(activeLearningPlanProvider).hasValue);
    // ignore: avoid_print
    print('DIAG: client calls = ${client.calls}');
  });
}
