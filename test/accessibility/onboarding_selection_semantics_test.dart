/// Accessibility regression tests — onboarding selection semantics.
///
/// The onboarding selection cards (daily goal, personality mode, class
/// chip) used to communicate the selected state through COLOR ONLY. They
/// now expose the standard `selected` semantics flag (plus button flag
/// and tap action), so a screen-reader user hears the same state a
/// sighted user sees. These tests pin that contract.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/onboarding/data/onboarding_repository.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/features/onboarding/presentation/widgets/ob_goal_page.dart';
import 'package:vaanix_app/features/onboarding/presentation/widgets/ob_personality_page.dart';
import 'package:vaanix_app/features/onboarding/presentation/widgets/ob_subject_page.dart';

/// Helpers over the current semantics API (`flagsCollection` replaced the
/// deprecated `hasFlag` in Flutter 3.33+).
bool isSelected(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;

bool isEnabled(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue;

bool isButton(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isButton;

bool hasTapAction(SemanticsNode node) =>
    node.getSemanticsData().hasAction(SemanticsAction.tap);

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final repo = OnboardingRepository(LocalStorageService(prefs));
  return ProviderContainer(
    overrides: [
      onboardingProvider.overrideWith(
        (ref) => OnboardingNotifier(repo, const NoopAnalyticsClient()),
      ),
    ],
  );
}

Widget _app(ProviderContainer container, Widget page) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: page)),
  );
}

/// Lets the Van speech-bubble timers fired by these pages expire so the
/// test framework's pending-timer check stays quiet.
Future<void> flushVanTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('daily goal tiles expose selected state + tap action',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const ObGoalPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final fiveMin = tester.getSemantics(find.text('5 min / day'));

    // Nothing selected yet; every tile is a tappable button.
    expect(isSelected(fiveMin), isFalse,
        reason: 'no goal selected on a fresh flow');
    expect(isButton(fiveMin), isTrue);
    expect(hasTapAction(fiveMin), isTrue);

    // Selecting a tile flips the selected flag on it — and only on it.
    await tester.tap(find.text('10 min / day'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(isSelected(tester.getSemantics(find.text('10 min / day'))), isTrue,
        reason: 'the chosen tile must announce selected');
    expect(isSelected(tester.getSemantics(find.text('5 min / day'))), isFalse,
        reason: 'sibling tiles must NOT announce selected');

    await flushVanTimers(tester);
  });

  testWidgets('personality mode cards expose selected state',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const ObPersonalityPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Calm'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(isSelected(tester.getSemantics(find.text('Calm'))), isTrue);
    expect(isSelected(tester.getSemantics(find.text('Cheerleader'))), isFalse);

    await flushVanTimers(tester);
  });

  testWidgets('class chip announces a proper class name + selected state',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const ObSubjectPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('7'));
    await tester.pump(const Duration(milliseconds: 300));

    final node = tester.getSemantics(find.text('7'));
    expect(isSelected(node), isTrue);
    expect(node.label, contains('Class 7'),
        reason: 'the chip must read as a class name, not the bare '
            'numeral "7 th"');

    await flushVanTimers(tester);
  });
}
