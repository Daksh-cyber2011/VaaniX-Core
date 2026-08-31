/// Exercise Engine Type Tests
///
/// Synthetic fixtures ONLY (never production curriculum). Proves the engine
/// genuinely handles every declared type - model validity, renderer
/// readiness, answer handling, validation, feedback, retry, scoring,
/// mastery, and malformed/empty data - per the product brief.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

// --- Synthetic fixtures -----------------------------------------------------

const Exercise kMcq = Exercise(
  id: 'ex_test_mcq_1',
  lessonId: 'ls_test',
  type: ExerciseType.mcq,
  prompt: 'Choose the greeting:',
  options: ['namaste', 'dhanyavaad', 'shubha'],
  correctIndex: 0,
  explanation: 'Namaste is the greeting.',
);

const Exercise kFillBlank = Exercise(
  id: 'ex_test_blank_1',
  lessonId: 'ls_test',
  type: ExerciseType.fillBlank,
  prompt: '____ means "thank you".',
  options: ['dhanyavaad', 'namaste', 'kripaya'],
  correctIndex: 0,
);

const Exercise kOrdering = Exercise(
  id: 'ex_test_order_1',
  lessonId: 'ls_test',
  type: ExerciseType.ordering,
  prompt: 'Order the days:',
  items: ['somavaara', 'mangalavaara', 'budhavaara'],
);

const Exercise kTranslation = Exercise(
  id: 'ex_test_translate_1',
  lessonId: 'ls_test',
  type: ExerciseType.translation,
  prompt: 'Type "hello" in romanised Sanskrit:',
  acceptedAnswers: ['namaste', 'namaste!'],
  explanation: 'Namaste is the standard greeting.',
);

const Exercise kMatching = Exercise(
  id: 'ex_test_match_1',
  lessonId: 'ls_test',
  type: ExerciseType.matching,
  prompt: 'Match each number to its word:',
  pairs: [
    (left: '1', right: 'eka'),
    (left: '2', right: 'dvi'),
    (left: '3', right: 'tri'),
  ],
  explanation: '1=eka, 2=dvi, 3=tri.',
);

const Lesson kLesson = Lesson(
  id: 'ls_test',
  chapterId: 'ch_test',
  title: 'Synthetic lesson',
);

List<Exercise> _session(List<Exercise> exercises) => exercises;

// --- Model validity ---------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model validity', () {
    test('well-formed fixtures are valid for all five types', () {
      expect(kMcq.isValid, isTrue);
      expect(kFillBlank.isValid, isTrue);
      expect(kOrdering.isValid, isTrue);
      expect(kTranslation.isValid, isTrue);
      expect(kMatching.isValid, isTrue);
    });

    test('malformed mcq / fillBlank is invalid', () {
      const bad = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.mcq,
        prompt: 'p',
        options: ['only one'],
        correctIndex: 0,
      );
      const badIndex = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.mcq,
        prompt: 'p',
        options: ['a', 'b'],
        correctIndex: 5,
      );
      const noIndex = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.fillBlank,
        prompt: 'p',
        options: ['a', 'b'],
      );
      expect(bad.isValid, isFalse);
      expect(badIndex.isValid, isFalse);
      expect(noIndex.isValid, isFalse);
    });

    test('malformed translation is invalid', () {
      const noAnswers = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.translation,
        prompt: 'p',
      );
      const blankAnswer = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.translation,
        prompt: 'p',
        acceptedAnswers: ['   '],
      );
      expect(noAnswers.isValid, isFalse);
      expect(blankAnswer.isValid, isFalse);
    });

    test('malformed ordering and matching are invalid', () {
      const singleOrder = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.ordering,
        prompt: 'p',
        items: ['only one'],
      );
      const singlePair = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.matching,
        prompt: 'p',
        pairs: [(left: 'a', right: 'b')],
      );
      const emptySide = Exercise(
        id: 'x',
        lessonId: 'l',
        type: ExerciseType.matching,
        prompt: 'p',
        pairs: [(left: 'a', right: ''), (left: 'b', right: 'd')],
      );
      expect(singleOrder.isValid, isFalse);
      expect(singlePair.isValid, isFalse);
      expect(emptySide.isValid, isFalse);
    });
  });

  group('engine: choice types (mcq / fillBlank)', () {
    test('first-try correct answer scores exactly once', () {
      final n = ExerciseNotifier(_session([kMcq, kFillBlank]));
      final display = n.currentCorrectDisplayIndex;
      n.select(display);
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1);

      n.next();
      final blankDisplay = n.currentCorrectDisplayIndex;
      n.select(blankDisplay);
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 2);
      expect(n.masteredExerciseIds, ['ex_test_mcq_1', 'ex_test_blank_1']);
    });

    test('wrong answer then retry never scores', () {
      final n = ExerciseNotifier(_session([kMcq]));
      final wrong = n.currentCorrectDisplayIndex == 0 ? 1 : 0;
      n.select(wrong);
      n.submit();
      expect(n.currentAnswerIsCorrect, isFalse);
      expect(n.state.score, 0);

      n.retry();
      n.select(n.currentCorrectDisplayIndex);
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1, reason: 'retry must still count the first try');
      expect(n.masteredExerciseIds, ['ex_test_mcq_1']);
    });

    test('submit without a selection does nothing', () {
      final n = ExerciseNotifier(_session([kMcq]));
      n.submit();
      expect(n.state.answered, isFalse);
      expect(n.state.score, 0);
    });
  });

  group('engine: ordering', () {
    test('correct sequence scores; wrong sequence can be retried', () {
      final n = ExerciseNotifier(_session([kOrdering]));
      for (final item in ['somavaara', 'mangalavaara', 'budhavaara']) {
        n.addChosenItem(item);
      }
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1);

      n.next();
      // re-enter via restart for the wrong path
      n.restart();
      for (final item in ['budhavaara', 'mangalavaara', 'somavaara']) {
        n.addChosenItem(item);
      }
      n.submit();
      expect(n.currentAnswerIsCorrect, isFalse);
      expect(n.state.score, 0);
      n.retry();
      expect(n.state.chosenItems, isEmpty);
    });

    test('incomplete sequence cannot be submitted', () {
      final n = ExerciseNotifier(_session([kOrdering]));
      n.addChosenItem('somavaara');
      // The notifier itself guards length; prove it via the screen path below.
      n.submit();
      expect(n.state.answered, isFalse);
    });
  });

  group('engine: translation', () {
    test('exact, case-insensitive and padded answers are accepted', () {
      final n = ExerciseNotifier(_session([kTranslation]));
      n.setAnswerText('Namaste');
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1);
      expect(n.masteredExerciseIds, ['ex_test_translate_1']);
    });

    test('whitespace-collapsed answer is accepted', () {
      final n = ExerciseNotifier(_session([kTranslation]));
      n.setAnswerText('  namaste   ');
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
    });

    test('empty input cannot be submitted and no score is given', () {
      final n = ExerciseNotifier(_session([kTranslation]));
      n.setAnswerText('   ');
      n.submit();
      expect(n.state.answered, isFalse);
      n.setAnswerText('wrong answer');
      n.submit();
      expect(n.state.answered, isTrue);
      expect(n.currentAnswerIsCorrect, isFalse);
      expect(n.state.score, 0);

      n.retry();
      expect(n.state.answerText, isEmpty);
      n.setAnswerText('namaste');
      n.submit();
      expect(n.state.score, 1);
    });
  });

  group('engine: matching', () {
    test('correct pairing scores on first try', () {
      final n = ExerciseNotifier(_session([kMatching]));
      // Right slots are the shuffled display; pair each left with the
      // display slot whose pair index equals the left index.
      final slotToPair = n.currentPairIndexByDisplay;
      for (var left = 0; left < kMatching.pairs.length; left++) {
        final slot = slotToPair.indexOf(left);
        n.addMatch(left, slot);
      }
      expect(n.state.selectedPairs.length, 3);
      n.submit();
      expect(n.currentAnswerIsCorrect, isTrue);
      expect(n.state.score, 1);
      expect(n.masteredExerciseIds, ['ex_test_match_1']);
    });

    test('partial pairing cannot be submitted; wrong pairing fails', () {
      final n = ExerciseNotifier(_session([kMatching]));
      final slotOf = n.currentPairIndexByDisplay;
      n.addMatch(0, slotOf.indexOf(0));
      n.submit();
      expect(n.state.answered, isFalse,
          reason: 'partial matching must not be accepted');

      // Left 1 takes pair-2's slot and left 2 takes pair-1's slot, so the
      // full pairing is wrong for every possible shuffle.
      n.addMatch(1, slotOf.indexOf(2));
      expect(n.state.selectedPairs.length, 2);
      n.addMatch(2, slotOf.indexOf(1));
      n.submit();
      expect(n.state.answered, isTrue);
      expect(n.currentAnswerIsCorrect, isFalse);
      expect(n.state.score, 0);
    });

    test('duplicate slots are rejected and retry clears pairs', () {
      final n = ExerciseNotifier(_session([kMatching]));
      n.addMatch(0, 0);
      expect(n.state.selectedPairs.length, 1);
      n.addMatch(0, 1);
      n.addMatch(0, 2);
      expect(n.state.selectedPairs.length, 1,
          reason: 'a left slot may only be used once');
      n.addMatch(1, 1);
      expect(n.state.selectedPairs.length, 2);
      n.retry();
      expect(n.state.selectedPairs, isEmpty);
    });
  });

  group('engine: mixed session lifecycle', () {
    test('next() resets per-type input state', () {
      final n = ExerciseNotifier(_session([kTranslation, kMatching]));
      n.setAnswerText('namaste');
      n.submit();
      n.next();
      expect(n.current.type, ExerciseType.matching);
      expect(n.state.answerText, isEmpty);
      expect(n.state.selectedPairs, isEmpty);
      expect(n.state.selectedIndex, isNull);
    });

    test('restart clears scoring and input state', () {
      final n = ExerciseNotifier(_session([kTranslation]));
      n.setAnswerText('namaste');
      n.submit();
      n.next();
      expect(n.state.finished, isTrue);
      n.restart();
      expect(n.state.score, 0);
      expect(n.state.answerText, isEmpty);
      expect(n.state.finished, isFalse);
      expect(n.masteredExerciseIds, isEmpty);
    });

    test('empty exercise list is a valid empty session', () {
      final n = ExerciseNotifier(const []);
      expect(n.total, 0);
      expect(n.state.finished, isFalse);
    });
  });

  group('display preparation', () {
    test('matching display is a shuffled bijection of the right column', () {
      final prep = prepareExerciseOptions(kMatching, 0);
      expect(prep.options.length, 3);
      expect(prep.pairIndexByDisplay.toSet(), {0, 1, 2});
      for (var d = 0; d < 3; d++) {
        expect(
          prep.options[d],
          kMatching.pairs[prep.pairIndexByDisplay[d]].right,
        );
      }
    });

    test('translation and ordering pass through cleanly', () {
      final t = prepareExerciseOptions(kTranslation, 0);
      expect(t.options, isEmpty);
      final o = prepareExerciseOptions(kOrdering, 0);
      expect(o.options, kOrdering.items);
    });
  });

  group('widget: renderers', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      List<Exercise> exs,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          exerciseSessionProvider(
            'ls_test',
          ).overrideWith((ref) => ExerciseNotifier(exs)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ExerciseScreen(lesson: kLesson)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return container;
    }

    testWidgets('translation renders a text field and correct feedback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pump(tester, [kTranslation]);
      expect(find.text('Translate'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Namaste');
      await tester.pump();
      await tester.ensureVisible(find.text('Submit'));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('matching renders two columns and scores a correct pairing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await pump(tester, [kMatching]);
      expect(find.text('Match the pairs'), findsOneWidget);
      final n = container.read(exerciseSessionProvider('ls_test').notifier);
      final slotToPair = n.currentPairIndexByDisplay;
      // Tap left item '1', then its right slot ('eka'). The right column is
      // rendered after the left column, so .last disambiguates duplicates.
      await tester.ensureVisible(find.text('1'));
      await tester.tap(find.text('1'), warnIfMissed: false);
      await tester.pump();
      final rightSlot = slotToPair.indexOf(0);
      final rightText = kMatching.pairs[slotToPair[rightSlot]].right;
      await tester.ensureVisible(find.text(rightText).last);
      await tester.tap(find.text(rightText).last, warnIfMissed: false);
      await tester.pump();
      expect(n.state.selectedPairs.length, 1);
      // Complete the rest programmatically, then submit via the button.
      for (var left = 1; left < 3; left++) {
        n.addMatch(left, slotToPair.indexOf(left));
      }
      await tester.pump();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
      expect(n.state.score, 1);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
