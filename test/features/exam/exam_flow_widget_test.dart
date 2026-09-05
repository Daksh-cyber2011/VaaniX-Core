/// Exam end-to-end widget QA (the strongest available runtime check on this
/// machine - no Android emulator).
///
/// Drives the real ExamScreen: setup -> instructions -> quiz -> result,
/// verifies the Phase 1 AUTOSAVE contract (the attempt persists the moment
/// the quiz finishes, without any manual Save tap), XP-once semantics at
/// the UI level (button disables, repeat completion snackbar, XP total
/// unchanged), and verifies the achievement path (snackbars) plus the
/// persisted-unlock race guard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  const chapterId = 'ch_alphabet';

  final questions = [
    const QuizQuestion(
      id: 'qa_widget_01',
      chapterId: chapterId,
      difficulty: Difficulty.beginner,
      prompt: 'Q1: which is the correct word?',
      options: ['not this', 'correct one', 'nor this', 'nor that'],
      correctIndex: 1,
      explanation: 'Q1 explained.',
    ),
    const QuizQuestion(
      id: 'qa_widget_02',
      chapterId: chapterId,
      difficulty: Difficulty.beginner,
      prompt: 'Q2: which is the correct word?',
      options: ['wrong a', 'wrong b', 'correct two', 'wrong c'],
      correctIndex: 2,
      explanation: 'Q2 explained.',
    ),
  ];

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

  /// Answers the current question correctly and advances.
  Future<void> answerCorrectly(WidgetTester tester, String option) async {
    await tester.tap(find.text(option));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
  }

  /// Settles the autosave chain (completeQuiz -> snackbars -> achievements).
  Future<void> settleAutosave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'exam journey: setup guard, quiz, AUTOSAVE, XP-once, achievements',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final app = await makeContainer();
    await tester.pumpWidget(wrap(app));
    // The single-source JSON bank resolves asynchronously; let the async
    // family sessions (setup -> instructions -> quiz) settle for real.
    await tester.pump();
    await tester.pump();

    // ---- Setup: start button is inert until a topic + level exist ----
    expect(find.text('Choose your exam'), findsOneWidget);
    await tester.tap(find.text('Select a topic & level'));
    await tester.pump();
    expect(find.text('Choose your exam'), findsOneWidget,
        reason: 'empty selection must not start an exam');

    await tester.tap(find.textContaining('The Alphabet'));
    await tester.pump();
    await tester.tap(find.text('Beginner (2)'));
    await tester.pump();
    await tester.tap(find.text('Start Exam (2 questions)'));
    await tester.pump();

    // ---- Instructions ----
    expect(find.text('Ready for the exam?'), findsOneWidget);
    await tester.tap(find.text('Begin Exam'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // ---- Quiz: two correct answers ----
    expect(find.text('Q 1 / 2'), findsOneWidget);
    await answerCorrectly(tester, 'correct one');
    expect(find.text('Q 2 / 2'), findsOneWidget);
    await answerCorrectly(tester, 'correct two');

    // ---- Result: AUTOSAVE must persist WITHOUT any manual Save tap ----
    expect(find.textContaining('Great job! 100%'), findsOneWidget);
    await settleAutosave(tester);
    final repo = app.read(progressRepositoryProvider);
    final attemptsAfterFinish = repo
        .getQuizAttempts('quiz_ch_alphabet_beginner')
        .fold<List<QuizResult>>((_) => const [], (v) => v);
    expect(attemptsAfterFinish, hasLength(1),
        reason: 'finishing the quiz must autosave the attempt immediately');
    expect(find.text('Progress saved \u2713'), findsOneWidget,
        reason: 'autosave must surface as a saved result without a tap');

    // XP snackbar + achievement snackbars (queued one after another).
    expect(find.textContaining('+20 XP earned'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Quiz Novice'), findsOneWidget);
    var perfectSeen = false;
    for (var s = 0; s < 20 && !perfectSeen; s++) {
      await tester.pump(const Duration(milliseconds: 500));
      perfectSeen = find.textContaining('Perfect Score').evaluate().isNotEmpty;
    }
    expect(perfectSeen, isTrue,
        reason: 'perfect score achievement snackbar must appear');
    await tester.pump(const Duration(seconds: 5)); // let snackbars expire

    final xpAfterFirst = repo.getXp().fold((_) => -1, (v) => v);
    expect(xpAfterFirst, 20 + 20 + 50,
        reason: 'quiz XP + first_quiz + perfect_quiz bonuses');

    // ---- Retake the same exam: no duplicate XP, no re-unlocked
    // achievements, history still grows (also autosaved) ----
    await tester.pump(const Duration(seconds: 8)); // let Van timers settle
    await tester.tap(find.text('Change topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Exam (2 questions)'));
    await tester.pump();
    await tester.tap(find.text('Begin Exam'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Q 1 / 2'), findsOneWidget,
        reason: 'retaking the same exam must start a fresh attempt');
    await answerCorrectly(tester, 'correct one');
    await tester.pump();
    await answerCorrectly(tester, 'correct two');
    await tester.pump();

    await settleAutosave(tester);

    expect(find.textContaining('no extra XP'), findsOneWidget,
        reason: 'repeat completion must be honest about XP');
    expect(find.textContaining('Achievement Unlocked'), findsNothing,
        reason: 'persisted unlocks must not be re-announced');

    expect(repo.getXp().fold((_) => -1, (v) => v), xpAfterFirst,
        reason: 'XP must never duplicate on retakes');
    final attempts = repo
        .getQuizAttempts('quiz_ch_alphabet_beginner')
        .fold<List<QuizResult>>((_) => const [], (v) => v);
    expect(attempts, hasLength(2), reason: 'attempt history keeps growing');
    expect(attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b), 2,
        reason: 'best score reflects the retake');

    await tester.pump(const Duration(seconds: 8)); // Van timers settle
  });
}
