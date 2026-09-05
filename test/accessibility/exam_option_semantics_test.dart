/// Accessibility regression tests — exam option semantics.
///
/// The exam question options used to communicate selected / correct /
/// wrong / answered state through COLOR ONLY, and the setup screen's
/// chapter tiles / difficulty chips likewise. They now expose:
///   - chapter tiles: selected flag (+ button + tap action);
///   - difficulty chips: selected + enabled flags (chips with no
///     questions announce as disabled instead of just dimming);
///   - question options: button + selected + enabled flags, tap action,
///     and spoken "correct answer"/"incorrect" state after submitting.
/// These tests pin that contract on the real ExamScreen.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_screen.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const chapterId = 'ch_alphabet';

  final questions = [
    const QuizQuestion(
      id: 'qa_a11y_01',
      chapterId: chapterId,
      difficulty: Difficulty.beginner,
      prompt: 'A11y Q1: pick the right word.',
      options: ['alpha', 'beta', 'gamma'],
      correctIndex: 1,
      explanation: 'beta is right.',
    ),
    const QuizQuestion(
      id: 'qa_a11y_02',
      chapterId: chapterId,
      difficulty: Difficulty.intermediate,
      prompt: 'A11y Q2: pick the right word.',
      options: ['delta', 'epsilon', 'zeta'],
      correctIndex: 2,
      explanation: 'zeta is right.',
    ),
  ];

  late SharedPreferences prefs;

  setUp(() async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quizBankProvider.overrideWith((ref) async => questions),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget wrap(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ExamScreen()),
      );

  testWidgets('exam setup: chapter selected flag + disabled empty difficulty',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    await tester.pumpWidget(wrap(container));
    await tester.pump();
    await tester.pump();

    // No chapter chosen yet: the tile is a button, not selected.
    final chapterNode = tester.getSemantics(find.textContaining('Alphabet'));
    expect(isButton(chapterNode), isTrue);
    expect(isSelected(chapterNode), isFalse);
    expect(hasTapAction(chapterNode), isTrue);

    // The difficulty chip with zero questions for the (unselected)
    // chapter is disabled — not merely dimmed.
    expect(isDisabled(tester.getSemantics(find.text('Advanced'))), isTrue,
        reason: 'a difficulty band with no questions must announce '
            'disabled');
    expect(isSelected(tester.getSemantics(find.text('Advanced'))), isFalse);

    // Selecting the chapter flips its selected flag and enables the
    // bands that DO have questions.
    await tester.tap(find.textContaining('Alphabet'));
    await tester.pump();
    expect(isSelected(tester.getSemantics(find.textContaining('Alphabet'))),
        isTrue);
    expect(isEnabled(tester.getSemantics(find.text('Beginner (1)'))), isTrue);

    // Selecting a difficulty flips its selected flag too.
    await tester.tap(find.text('Beginner (1)'));
    await tester.pump();
    expect(isSelected(tester.getSemantics(find.text('Beginner (1)'))), isTrue);
    expect(isSelected(tester.getSemantics(find.text('Intermediate (1)'))),
        isFalse);
  });

  testWidgets('exam options expose selected/correct/wrong/enabled state',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    await tester.pumpWidget(wrap(container));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.textContaining('Alphabet'));
    await tester.pump();
    await tester.tap(find.text('Beginner (1)'));
    await tester.pump();
    await tester.tap(find.text('Start Exam (1 question)'));
    await tester.pump();
    await tester.tap(find.text('Begin Exam'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Before answering: buttons with tap action, none selected.
    final firstNode = tester.getSemantics(find.text('alpha'));
    expect(isButton(firstNode), isTrue);
    expect(isSelected(firstNode), isFalse);
    expect(isEnabled(firstNode), isTrue);
    expect(hasTapAction(firstNode), isTrue);

    // Selecting flips the flag on the chosen option only.
    await tester.tap(find.text('alpha'));
    await tester.pump();
    expect(isSelected(tester.getSemantics(find.text('alpha'))), isTrue);
    expect(isSelected(tester.getSemantics(find.text('beta'))), isFalse);

    // Submitting speaks the state the colors encode: chosen-but-wrong
    // says "incorrect", the real answer says "correct answer", and every
    // option is disabled once answered.
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(tester.getSemantics(find.text('alpha')).label,
        contains('incorrect'));
    expect(tester.getSemantics(find.text('beta')).label,
        contains('correct answer'));
    for (final option in ['alpha', 'beta', 'gamma']) {
      expect(isDisabled(tester.getSemantics(find.text(option))), isTrue);
    }

    // Flush snackbars / Van timers fired by answering.
    await tester.pump(const Duration(seconds: 4));
  });
}
