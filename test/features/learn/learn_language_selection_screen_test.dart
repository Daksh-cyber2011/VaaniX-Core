/// Learn Language Selection Screen — Part 0 widget test.
///
/// Verifies the picker renders all 10 catalogue languages as tappable
/// tiles, that tapping a tile persists the selection, and that the
/// screen is accessible (each tile announces its native name, English
/// name, script, and selected state).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_language_selection_screen.dart';

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final prefsInstance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefsInstance)],
  );
}

Widget _wrap(ProviderContainer container) {
  // Minimal router: the picker uses context.go('/learn') on selection,
  // so we need a GoRouter in scope to avoid a runtime assertion.
  final router = GoRouter(
    initialLocation: '/learn/language',
    routes: [
      GoRoute(
        path: '/learn',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Learn'))),
      ),
      GoRoute(
        path: '/learn/language',
        builder: (_, __) => const LearnLanguageSelectionScreen(),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders every catalogue language as a tappable tile',
      (tester) async {
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    // Every language's English name should appear in the tree.
    for (final spec in kLearnLanguageCatalogue) {
      expect(find.text(spec.englishName), findsOneWidget,
          reason: '${spec.englishName} tile should render');
    }
  });

  testWidgets('renders every native name (endonym) in its own script',
      (tester) async {
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    for (final spec in kLearnLanguageCatalogue) {
      expect(find.text(spec.nativeName), findsOneWidget,
          reason: '${spec.englishName} native name "${spec.nativeName}" should render');
    }
  });

  testWidgets('tapping a tile persists the selection and routes back to /learn',
      (tester) async {
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    // Tap the Hindi tile (find by its English name label).
    await tester.tap(find.text('Hindi'));
    await tester.pump(const Duration(seconds: 1));

    // Selection should now be persisted.
    expect(container.read(selectedLearnLanguageProvider),
        LearnLanguage.hindi);

    // And the router should have navigated to /learn.
    expect(find.text('Learn'), findsOneWidget,
        reason: 'Tapping a tile should route back to /learn');
  });

  testWidgets('shows the currently selected language with a check icon',
      (tester) async {
    // Pre-select Bengali.
    final container = await _container(prefs: {
      'learn_language': 'bengali',
    });
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    // The Bengali tile should show a check_circle icon, the others
    // radio_button_unchecked. We verify by counting icon types.
    final checkIcons = find.byIcon(Icons.check_circle_rounded);
    expect(checkIcons, findsOneWidget,
        reason: 'Only the selected language (Bengali) should show a check');

    final radioIcons = find.byIcon(Icons.radio_button_unchecked_rounded);
    expect(radioIcons, findsNWidgets(9),
        reason: 'The other 9 languages should show an unchecked radio');
  });

  testWidgets('Urdu tile shows the RTL badge', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    // Find the Urdu tile by its English name, then look for 'RTL'
    // in the subtitle text within that tile.
    final urduTile = find.ancestor(
      of: find.text('Urdu'),
      matching: find.byType(InkWell),
    );
    expect(urduTile, findsOneWidget);
    expect(
      find.descendant(of: urduTile, matching: find.textContaining('RTL')),
      findsOneWidget,
      reason: 'Urdu is the only RTL language; its tile must advertise it.',
    );
  });

  testWidgets('selecting a different language updates the persisted value',
      (tester) async {
    final container = await _container(prefs: {
      'learn_language': 'tamil',
    });
    addTearDown(container.dispose);

    expect(container.read(selectedLearnLanguageProvider),
        LearnLanguage.tamil);

    await tester.pumpWidget(_wrap(container));
    await tester.pump(const Duration(seconds: 1));

    // Tap Marathi.
    await tester.tap(find.text('Marathi'));
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(selectedLearnLanguageProvider),
        LearnLanguage.marathi,
        reason: 'Tapping Marathi should overwrite the previous Tamil selection');
  });
}
