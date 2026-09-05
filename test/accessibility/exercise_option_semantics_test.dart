/// Accessibility regression tests — practice exercise semantics.
///
/// The practice option tiles (MCQ / fill blank), ordering chips and
/// matching chips used to communicate selected / correct / wrong / done
/// state through COLOR ONLY. They now expose it to screen readers:
///   - option tiles: button + selected + enabled flags, tap action, and
///     spoken "correct answer"/"incorrect" state after submitting;
///   - ordering chips: spoken position ("Position 2 of 3: ...");
///   - matching chips: selected flag while pending, spoken "already
///     matched" when paired, pairing hint on the opposite column.
/// These tests pin that contract on the real ExerciseScreen.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Helpers over the current semantics API (`flagsCollection` replaced the
/// deprecated `hasFlag` in Flutter 3.33+).
bool isSelected(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;

bool isEnabled(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue;

bool isDisabled(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isEnabled == Tristate.isFalse;

bool isButton(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isButton;

bool hasTapAction(SemanticsNode node) =>
    node.getSemanticsData().hasAction(SemanticsAction.tap);

const String testLessonId = 'ls_a11y_semantics';

/// Deterministic synthetic bank covering the three stateful interactive
/// types (the matching/ordering types have no curriculum-authored bank
/// entries, which is exactly why the session provider reads the bank
/// through an overridable provider now).
final List<Exercise> testExercises = [
  const Exercise(
    id: 'ex_a11y_mcq_1',
    lessonId: testLessonId,
    type: ExerciseType.mcq,
    prompt: 'Which word means "water"?',
    options: ['जलम्', 'वृक्षः', 'अग्निः'],
    correctIndex: 0,
    explanation: 'जलम् is water.',
  ),
  const Exercise(
    id: 'ex_a11y_matching_1',
    lessonId: testLessonId,
    type: ExerciseType.matching,
    prompt: 'Match each animal to its sound.',
    pairs: [
      (left: 'cat', right: 'meow'),
      (left: 'dog', right: 'woof'),
    ],
    explanation: 'Classic pairings.',
  ),
  const Exercise(
    id: 'ex_a11y_ordering_1',
    lessonId: testLessonId,
    type: ExerciseType.ordering,
    prompt: 'Order the greeting words.',
    items: ['नमस्ते', 'स्वागतम्', 'धन्यवादः'],
    explanation: 'Standard sequence.',
  ),
];

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      exercisesForLessonProvider(testLessonId).overrideWithValue(testExercises),
    ],
  );
}

Lesson _lesson(String id) =>
    Lesson(id: id, title: 'A11y', chapterId: 'ch_a11y', xpReward: 10);

Widget _app(ProviderContainer container, Lesson lesson) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ExerciseScreen(lesson: lesson)),
  );
}

/// Lets Van speech-bubble timers expire so the pending-timer check in the
/// test framework stays quiet.
Future<void> flushVanTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MCQ option tiles expose selected/correct/wrong/enabled state',
      (tester) async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final lesson = _lesson(testLessonId);
    await tester.pumpWidget(_app(container, lesson));

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 50));

    final notifier =
        container.read(exerciseSessionProvider(testLessonId).notifier);
    final options = notifier.currentOptions;
    final correctDisplay = notifier.currentCorrectDisplayIndex;

    // Before answering: every tile is a button with a tap action; none
    // is selected or disabled.
    for (final option in options) {
      final node = tester.getSemantics(find.text(option));
      expect(isButton(node), isTrue);
      expect(isSelected(node), isFalse);
      expect(isEnabled(node), isTrue);
      expect(hasTapAction(node), isTrue);
      expect(node.label, contains(option),
          reason: 'option content must be readable');
    }

    // Selecting one tile flips its selected flag only.
    await tester.tap(find.text(options[0]));
    await tester.pump(const Duration(milliseconds: 200));
    expect(isSelected(tester.getSemantics(find.text(options[0]))), isTrue);
    expect(isSelected(tester.getSemantics(find.text(options[1]))), isFalse);

    // After submitting, the state a sighted user sees in tile colors is
    // spoken: the correct tile says so, a wrongly chosen tile says
    // "incorrect", and ALL tiles become disabled.
    await tester.tap(find.text('Submit'));
    await tester.pump(const Duration(milliseconds: 200));

    for (final option in options) {
      expect(isDisabled(tester.getSemantics(find.text(option))), isTrue,
          reason: 'answered options must announce as disabled');
    }
    final correctNode = tester.getSemantics(find.text(options[correctDisplay]));
    expect(correctNode.label, contains('correct answer'),
        reason: 'the green tile must announce its correctness');
    if (correctDisplay != 0) {
      final wrongNode = tester.getSemantics(find.text(options[0]));
      expect(wrongNode.label, contains('incorrect'),
          reason: 'the wrongly chosen (red) tile must announce incorrect');
      expect(isSelected(wrongNode), isTrue);
    }

    await flushVanTimers(tester);
  });

  testWidgets('matching chips expose pending/matched state and pairing hint',
      (tester) async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final lesson = _lesson(testLessonId);
    await tester.pumpWidget(_app(container, lesson));

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 50));

    final notifier =
        container.read(exerciseSessionProvider(testLessonId).notifier);
    // Advance to the matching exercise (index 1).
    notifier.next();
    await tester.pump(const Duration(milliseconds: 100));

    final rightOptions = notifier.currentOptions;
    final slotForPair0 = notifier.currentPairIndexByDisplay.indexOf(0);

    // Nothing matched yet: chips are enabled, nothing selected.
    final catNode = tester.getSemantics(find.text('cat'));
    expect(isSelected(catNode), isFalse);
    expect(isEnabled(catNode), isTrue);

    // Tap a left chip: it becomes the pending selection...
    await tester.tap(find.text('cat'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(isSelected(tester.getSemantics(find.text('cat'))), isTrue);

    // ...and the right column announces what it would pair with —
    // information a sighted user gets from the pending highlight.
    final rightNode =
        tester.getSemantics(find.text(rightOptions[slotForPair0]));
    expect(rightNode.hint, contains('match with cat'));

    // Forming the pair moves BOTH chips to a spoken "already matched"
    // state and disables them (no semantics flag exists for "matched",
    // so the wording rides on the label — pinned here).
    await tester.tap(find.text(rightOptions[slotForPair0]));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.getSemantics(find.text('cat')).label,
        contains('already matched'));
    expect(isDisabled(tester.getSemantics(find.text('cat'))), isTrue);
    expect(tester.getSemantics(find.text(rightOptions[slotForPair0])).label,
        contains('already matched'));
    expect(isSelected(tester.getSemantics(find.text('dog'))), isFalse,
        reason: 'unmatched chips must not announce selected');

    // Complete the exercise so submit becomes available; the remaining
    // chips are enabled until answered.
    final slotForPair1 = notifier.currentPairIndexByDisplay.indexOf(1);
    await tester.tap(find.text('dog'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(rightOptions[slotForPair1]));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Submit'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(isDisabled(tester.getSemantics(find.text('dog'))), isTrue,
        reason: 'after answering, all chips announce disabled');

    await flushVanTimers(tester);
  });

  testWidgets('ordering chips announce their position in the sequence',
      (tester) async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final lesson = _lesson(testLessonId);
    await tester.pumpWidget(_app(container, lesson));

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 50));

    final notifier =
        container.read(exerciseSessionProvider(testLessonId).notifier);
    // Advance to the ordering exercise (index 2).
    notifier.next();
    notifier.next();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the first item from the remaining pool: it moves into the
    // sequence and its chip now speaks its position — the only thing a
    // sighted user gets from the visual order of the Wrap.
    await tester.tap(find.text('नमस्ते'));
    await tester.pump(const Duration(milliseconds: 200));

    final node = tester.getSemantics(find.text('नमस्ते'));
    expect(node.label, contains('Position 1 of 3'));
    expect(node.label, contains('नमस्ते'));

    await flushVanTimers(tester);
  });
}
