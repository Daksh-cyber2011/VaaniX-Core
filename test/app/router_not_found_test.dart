/// Router not-found behavior.
///
/// Every declared route resolves; an unknown location must render the
/// branded not-found screen (with a recovery action back into the app)
/// instead of Flutter's default grey error page — and must still honor the
/// onboarding gate when it applies.
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/app/router/app_router.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';

Future<ProviderContainer> makeContainer() async {
  dotenv.testLoad(); // unconfigured environment → noop auth, offline mode
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<void> pumpAt(WidgetTester tester, ProviderContainer container,
    String location) async {
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go(location);
  // Let the guards, asset loads and transition animations settle.
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an unknown location renders the branded not-found screen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    // Mark onboarding complete so the not-found screen itself is reachable.
    await container.read(localStorageServiceProvider).setOnboardingComplete(true);

    await pumpAt(tester, container, '/definitely-not-a-route');

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('This page does not exist'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('the not-found screen recovers back into the app',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    await container.read(localStorageServiceProvider).setOnboardingComplete(true);

    await pumpAt(tester, container, '/definitely-not-a-route');
    await tester.tap(find.text('Back to Home'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('This page does not exist'), findsNothing);
  });

  testWidgets('an unknown deep link still honors the onboarding gate',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    // Onboarding NOT complete: even invalid locations redirect there.

    await pumpAt(tester, container, '/definitely-not-a-route');

    // The gate wins — no not-found screen, the onboarding flow instead.
    expect(find.text('Page not found'), findsNothing);
  });
}
