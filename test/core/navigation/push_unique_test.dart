/// Duplicate-push protection.
///
/// A rapid double tap on any "open this screen" control used to stack two
/// identical pages (one push per pointer-up, both delivered before the first
/// transition rebuilt the navigator). These tests pin the three behaviours
/// that matter and would catch a regression in either direction:
///
///   1. two taps in the same frame push the destination exactly once;
///   2. pushing a DIFFERENT destination is never suppressed;
///   3. back navigation still pops normally, and the destination can be
///      opened again afterwards (the guard is stack state, not a latch).
///
/// A minimal local router is used on purpose: the guard is router-lifecycle
/// behaviour, so the test must not depend on the app's guards, prefs or
/// curriculum assets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/navigation/push_unique.dart';

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('open-details'),
            onPressed: () => context.pushUnique('/details'),
            child: const Text('Open details'),
          ),
          ElevatedButton(
            key: const Key('open-other'),
            onPressed: () => context.pushUnique('/other'),
            child: const Text('Open other'),
          ),
        ],
      ),
    );
  }
}

class _DetailsScreen extends StatelessWidget {
  const _DetailsScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('details')));
}

class _OtherScreen extends StatelessWidget {
  const _OtherScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('other')));
}

/// Stand-in for the exam flow's `.../:trackId` routes, which push by name
/// with a path parameter rather than a literal location string.
class _TrackScreen extends StatelessWidget {
  const _TrackScreen({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('track-$trackId')));
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _HomeScreen()),
      GoRoute(path: '/details', builder: (_, __) => const _DetailsScreen()),
      GoRoute(path: '/other', builder: (_, __) => const _OtherScreen()),
      GoRoute(
        path: '/track/:trackId',
        name: 'track',
        builder: (_, state) =>
            _TrackScreen(trackId: state.pathParameters['trackId'] ?? ''),
      ),
    ],
  );
}

Future<GoRouter> pumpApp(WidgetTester tester) async {
  final router = _buildRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a double tap in a single frame pushes the destination once',
      (tester) async {
    await pumpApp(tester);

    // Both taps land before any pump, i.e. before the navigator has rebuilt
    // for the first push — exactly the real double-tap race.
    await tester.tap(find.byKey(const Key('open-details')));
    await tester.tap(find.byKey(const Key('open-details')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(_DetailsScreen), findsOneWidget);
  });

  testWidgets('pushing a different destination is not suppressed',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('open-details')));
    await tester.pumpAndSettle();
    expect(find.byType(_DetailsScreen), findsOneWidget);

    // Same-destination push is a duplicate; a different one must go through.
    final router = GoRouter.of(
      tester.element(find.byType(_DetailsScreen)),
    );
    router.pushUnique('/details');
    await tester.pumpAndSettle();
    expect(find.byType(_DetailsScreen), findsOneWidget);

    router.pushUnique('/other');
    await tester.pumpAndSettle();
    expect(find.byType(_OtherScreen), findsOneWidget);
  });

  testWidgets('back navigation pops once and the screen can be reopened',
      (tester) async {
    final router = await pumpApp(tester);

    await tester.tap(find.byKey(const Key('open-details')));
    await tester.tap(find.byKey(const Key('open-details')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // A single pop must return to Home: proof no second copy was stacked.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(_DetailsScreen), findsNothing);
    expect(find.byKey(const Key('open-details')), findsOneWidget);

    // The guard is derived from stack state, so reopening still works.
    await tester.tap(find.byKey(const Key('open-details')));
    await tester.pumpAndSettle();
    expect(find.byType(_DetailsScreen), findsOneWidget);
  });

  group('pushNamedUnique (the exam flow\'s .../:trackId screens)', () {
    testWidgets('a double tap on the same track pushes once', (tester) async {
      final router = await pumpApp(tester);
      final context = tester.element(find.byType(_HomeScreen));

      // Two taps land before either transition settles — the same race as
      // the plain-push case, but resolved through name + pathParameters
      // instead of a literal location string.
      context.pushNamedUnique('track', pathParameters: {'trackId': 'a'});
      context.pushNamedUnique('track', pathParameters: {'trackId': 'a'});
      await tester.pumpAndSettle();

      expect(find.byType(_TrackScreen), findsOneWidget);
      expect(find.text('track-a'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      // A single pop reaching Home proves only one copy was ever stacked.
      expect(find.byType(_HomeScreen), findsOneWidget);
    });

    testWidgets('pushing a DIFFERENT track is never suppressed',
        (tester) async {
      await pumpApp(tester);
      final context = tester.element(find.byType(_HomeScreen));

      context.pushNamedUnique('track', pathParameters: {'trackId': 'a'});
      await tester.pumpAndSettle();
      expect(find.text('track-a'), findsOneWidget);

      // Same name, different resolved location — must go through even
      // though the destination screen TYPE is identical.
      final trackContext = tester.element(find.byType(_TrackScreen));
      trackContext.pushNamedUnique('track', pathParameters: {'trackId': 'b'});
      await tester.pumpAndSettle();
      expect(find.text('track-b'), findsOneWidget);
    });
  });
}
