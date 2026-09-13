/// Diagnostic Providers — M3 session + persistence wiring tests.
///
/// Drives the REAL flow end-to-end over the real Hindi curriculum and
/// exercise banks: start (seeded by self-report) → adaptive rounds →
/// finish pipeline. Pins:
///   - persist-first (result, state extras, profile.currentLevel all
///     durable BEFORE the finished state publishes);
///   - the spine picks the placement up (lastDiagnosticProvider,
///     activeLearningStateProvider extras, PlannerContext.diagnostic);
///   - retakes overwrite cleanly;
///   - stub languages surface the honest unavailable state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

/// The correct answer for a probe (computed the same way the UI would).
DiagnosticAnswer _correctAnswerFor(DiagnosticItem item) {
  final exercise = item.exercise;
  final display = prepareExerciseOptions(exercise, 0);
  return switch (exercise.type) {
    ExerciseType.mcq ||
    ExerciseType.fillBlank =>
      DiagnosticChoiceAnswer(display.correctIndex),
    ExerciseType.translation =>
      DiagnosticTextAnswer(exercise.acceptedAnswers.first),
    ExerciseType.matching => DiagnosticMatchAnswer({
        for (var left = 0; left < exercise.pairs.length; left++)
          left: display.pairIndexByDisplay.indexOf(left),
      }),
    ExerciseType.ordering => DiagnosticOrderAnswer(exercise.items),
  };
}

/// A guaranteed-wrong answer for a probe.
DiagnosticAnswer _wrongAnswerFor(DiagnosticItem item) {
  final exercise = item.exercise;
  final display = prepareExerciseOptions(exercise, 0);
  return switch (exercise.type) {
    ExerciseType.mcq ||
    ExerciseType.fillBlank =>
      DiagnosticChoiceAnswer(
          (display.correctIndex + 1) % display.options.length),
    ExerciseType.translation =>
      const DiagnosticTextAnswer('definitely wrong'),
    ExerciseType.matching => DiagnosticMatchAnswer({
        for (var left = 0; left < exercise.pairs.length; left++)
          left: display.pairIndexByDisplay
              .indexOf((left + 1) % exercise.pairs.length),
      }),
    ExerciseType.ordering =>
      DiagnosticOrderAnswer(exercise.items.reversed.toList()),
  };
}

/// Runs a whole session to completion with the given answer policy.
Future<void> _runToFinish(
  ProviderContainer container,
  LearnLanguage language, {
  required bool correct,
}) async {
  final notifier = container.read(diagnosticSessionProvider.notifier);
  await notifier.start(language);
  var guard = 0;
  while (true) {
    final state = container.read(diagnosticSessionProvider);
    if (state.phase == DiagnosticPhase.finished) return;
    expect(state.phase, anyOf(DiagnosticPhase.active, DiagnosticPhase.feedback),
        reason: 'unexpected phase ${state.phase}');
    if (state.phase == DiagnosticPhase.active) {
      notifier.submitAnswer(
        correct
            ? _correctAnswerFor(state.currentItem!)
            : _wrongAnswerFor(state.currentItem!),
      );
    } else {
      await notifier.next();
    }
    guard++;
    expect(guard, lessThan(80), reason: 'session must terminate');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bank provider builds trusted pools for the active language',
      () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    final bank = await container.read(diagnosticItemBankProvider.future);
    expect(bank.isNotEmpty, isTrue);
    expect(bank.activeDimensions, hasLength(6));
  });

  test('bank provider is honest with no language selected', () async {
    final container = await _container();
    addTearDown(container.dispose);

    final bank = await container.read(diagnosticItemBankProvider.future);
    expect(bank.isEmpty, isTrue);
  });

  test('a perfect run persists result + level + extras, and the spine sees it',
      () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await _runToFinish(container, LearnLanguage.hindi, correct: true);

    final session = container.read(diagnosticSessionProvider);
    expect(session.phase, DiagnosticPhase.finished);
    final result = session.result!;
    expect(result.language, LearnLanguage.hindi);
    expect(result.overallLevel, 4);

    // 1. Persisted result (read through a fresh repository look-up).
    final stored =
        container.read(learnProfileRepositoryProvider).getDiagnostic(
              LearnLanguage.hindi,
            );
    expect(stored, isNotNull);
    expect(stored!.overallLevel, 4);

    // 2. Profile currentLevel written (the M2 model, extended by M3).
    final profile = container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.currentLevel, 4);

    // 3. State extras seeded: performance events for every probe, empty
    //    review queue (nothing was missed).
    final extras =
        container.read(learnProfileRepositoryProvider).getLearningState(
              LearnLanguage.hindi,
            );
    expect(extras, isNotNull);
    expect(extras!.recentPerformance.events, hasLength(result.askedCount));
    expect(extras.reviewQueue, isEmpty);

    // 4. The spine sees the placement (persist-before-publish + the
    //    session-state rebuild signal).
    expect(container.read(lastDiagnosticProvider(LearnLanguage.hindi)),
        isNotNull);

    final learningState =
        await container.read(activeLearningStateProvider.future);
    expect(learningState.reviewQueue, isEmpty);
    expect(learningState.recentPerformance.accuracy, 1.0);

    // 5. The planner context carries the structured result (§13).
    final context = await container.read(activePlannerContextProvider.future);
    expect(context.diagnostic, isNotNull);
    expect(context.diagnostic!.overallLevel, 4);
    expect(
      context.toStructuredDigest()['diagnostic'] != null,
      isTrue,
      reason: 'the digest exposes the placement to prompt assembly (M4)',
    );
  });

  test('a struggling run lands at Starter and seeds weak-concept reviews',
      () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await _runToFinish(container, LearnLanguage.hindi, correct: false);

    final session = container.read(diagnosticSessionProvider);
    final result = session.result!;
    expect(result.overallLevel, 0);

    final profile = container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.currentLevel, 0);

    final extras =
        container.read(learnProfileRepositoryProvider).getLearningState(
              LearnLanguage.hindi,
            );
    expect(extras, isNotNull);
    expect(extras!.reviewQueue, isNotEmpty,
        reason: 'missed concepts enter the review queue');
    expect(extras.reviewQueue.length,
        lessThanOrEqualTo(kMaxDiagnosticReviewSeeds));
    expect(
      extras.reviewQueue.every(
        (e) => e.reason == ReviewReason.recentlyWeak,
      ),
      isTrue,
    );
    expect(extras.recentPerformance.accuracy, 0.0);

    final learningState =
        await container.read(activeLearningStateProvider.future);
    expect(learningState.reviewQueue, isNotEmpty,
        reason: 'extras merge into the derived learning state');
  });

  test('a retake overwrites result, extras and level', () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await _runToFinish(container, LearnLanguage.hindi, correct: true);
    final firstLevel =
        container.read(lastDiagnosticProvider(LearnLanguage.hindi))!
            .overallLevel;

    // Fresh run with the opposite outcome.
    container.read(diagnosticSessionProvider.notifier).reset();
    await _runToFinish(container, LearnLanguage.hindi, correct: false);

    final second =
        container.read(lastDiagnosticProvider(LearnLanguage.hindi))!;
    expect(second.overallLevel, 0);
    expect(firstLevel, 4);

    final profile = container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.currentLevel, 0);
  });

  test('newly supported Kannada language builds a diagnostic session',
      () async {
    final container =
        await _container(prefs: {'learn_language': 'kannada'});
    addTearDown(container.dispose);

    final notifier = container.read(diagnosticSessionProvider.notifier);
    await notifier.start(LearnLanguage.kannada);

    final state = container.read(diagnosticSessionProvider);
    expect(state.phase, DiagnosticPhase.active);
    expect(state.currentItem, isNotNull);
  });

  test('submitAnswer is a no-op outside the active phase', () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    // Session never started — idle phase.
    container
        .read(diagnosticSessionProvider.notifier)
        .submitAnswer(const DiagnosticTextAnswer('x'));
    expect(container.read(diagnosticSessionProvider).phase,
        DiagnosticPhase.idle);
  });
}
