/// Learn Profile Screen — M2 widget test.
///
/// Pins the learner-facing contract: all sections render their option
/// catalogues, tapping an option updates the local selection, Save
/// persists the whole profile (provider + storage + prompt-flag), the
/// no-language state stays safe, and the configured flag drives the
/// Learn screen's prompt card.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_profile_screen.dart';

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

Widget _wrap(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/learn/profile',
    routes: [
      GoRoute(
        path: '/learn',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Learn'))),
      ),
      GoRoute(
        path: '/learn/language',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Language picker'))),
      ),
      GoRoute(
        path: '/learn/profile',
        builder: (_, __) => const LearnProfileScreen(),
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

  testWidgets('without a selected language shows the safe empty state',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Choose a language first'), findsOneWidget);
    expect(find.text('Choose a language'), findsOneWidget,
        reason: 'empty state offers the language picker action');
  });

  testWidgets('renders every option of every section', (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final report in SelfReport.values) {
      expect(find.text(report.label), findsOneWidget);
    }
    for (final goal in LearningGoal.values) {
      expect(find.text(goal.label), findsOneWidget);
    }
    for (final level in DesiredLevel.values) {
      expect(find.text(level.label), findsOneWidget);
    }
    for (final pace in LearningPace.values) {
      expect(find.text(pace.label), findsOneWidget);
    }
    expect(find.text('Save my profile'), findsOneWidget);
  });

  testWidgets('save persists the chosen goal and routes back to /learn',
      (tester) async {
    _useTallSurface(tester);
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Travel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Advanced'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Save my profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Provider state updated...
    final profile =
        container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.goal, LearningGoal.travel);
    expect(profile.desiredLevel, DesiredLevel.advanced);

    // ...storage persisted (fresh repository read over the same prefs)...
    final persisted =
        container.read(learnProfileRepositoryProvider).getProfile(
              LearnLanguage.hindi,
            );
    expect(persisted!.goal, LearningGoal.travel);

    // ...the configured flag flipped (Learn screen prompt disappears)...
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isTrue,
    );

    // ...and the router landed back on /learn.
    expect(find.text('Learn'), findsOneWidget);
  });

  testWidgets('screen pre-fills from an already-saved profile', (tester) async {
    _useTallSurface(tester);
    final saved = LearnerProfile.initial(LearnLanguage.hindi).copyWith(
      goal: LearningGoal.culture,
      desiredLevel: DesiredLevel.elementary,
    );
    final container = await _container(prefs: {
      'learn_language': 'hindi',
      'learn_profile_hi':
          // same shape the repository writes:
          _encoded(saved),
    });
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The saved options show the SELECTED affordance (check icon).
    final cultureTile = find.ancestor(
      of: find.text('Cultural understanding'),
      matching: find.byType(InkWell),
    );
    expect(cultureTile, findsOneWidget);
    expect(
      find.descendant(
        of: cultureTile,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    // Unselected options still show the unchecked radio.
    final travelTile = find.ancestor(
      of: find.text('Travel'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(
        of: travelTile,
        matching: find.byIcon(Icons.radio_button_unchecked_rounded),
      ),
      findsOneWidget,
    );
  });
}

String _encoded(LearnerProfile profile) => jsonEncode(profile.toJson());

/// The profile screen is one long ListView — give the test surface enough
/// height that every section is built and hittable without scrolling.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
