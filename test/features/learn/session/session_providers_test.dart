/// Adaptive Session Providers — M6 wiring + persistence tests.
///
/// Drives the REAL controller end-to-end over the real Hindi curriculum
/// and banks (SharedPreferences mocks, no AI anywhere):
///   - a correct run records trusted mastery through the EXISTING
///     idempotent progress path and keeps the queue honest;
///   - a struggling run descends the §18 ladder in the engine, seeds a
///     `recently weak` review entry with a due date, and the SPINE sees
///     the evidence overlay + queue (activeLearningStateProvider);
///   - unknown concepts and missing languages surface the honest
///     unavailable state;
///   - a passed masteryCheck lifts an `understood` concept to `mastered`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/session_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

/// Drives the current session to completion with the given answer
/// policy. Support (explanation) beats are passed with [next].
Future<void> _runToFinish(
  ProviderContainer container, {
  required bool Function(SessionStep step) correct,
}) async {
  final notifier = container.read(adaptiveSessionProvider.notifier);
  var guard = 0;
  while (true) {
    final state = container.read(adaptiveSessionProvider);
    if (state.phase == AdaptiveSessionPhase.finished) return;
    expect(
      state.phase,
      anyOf(AdaptiveSessionPhase.active, AdaptiveSessionPhase.feedback),
      reason: 'unexpected phase ${state.phase} '
          '(${state.unavailableReason ?? ''})',
    );
    if (state.phase == AdaptiveSessionPhase.active) {
      final step = state.currentStep!;
      if (step.isSupport) {
        await notifier.next();
      } else {
        notifier.submitAnswer(correct: correct(step), firstTry: true);
      }
    } else {
      await notifier.next();
    }
    guard++;
    expect(guard, lessThan(80), reason: 'session must terminate');
  }
}

const _focusConcept = 'hi_script_vowels';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a correct practice run records trusted mastery and stays honest',
      () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    final notifier = container.read(adaptiveSessionProvider.notifier);
    await notifier.start(
      kind: ActivityKind.practice,
      conceptId: _focusConcept,
      difficultyKnob: 2,
    );

    final active = container.read(adaptiveSessionProvider);
    expect(active.phase, AdaptiveSessionPhase.active);
    expect(active.kind, ActivityKind.practice);
    expect(active.currentStep, isNotNull);

    await _runToFinish(container, correct: (_) => true);

    final finished = container.read(adaptiveSessionProvider);
    expect(finished.phase, AdaptiveSessionPhase.finished);
    expect(finished.answered, 2, reason: 'practice visits 2 per concept');
    expect(finished.firstTryCorrect, 2);

    // Trusted mastery recorded through the EXISTING idempotent path.
    final mastered =
        container.read(masteredExercisesProvider('hi_script_vowels'));
    expect(mastered, hasLength(2));
    expect(mastered.every((id) => id.startsWith('ex_hi_vowels_')), isTrue,
        reason: 'only trusted bank ids are recorded');

    // All-correct on a fresh concept → no fabricated review entries.
    final extras = container
        .read(learnProfileRepositoryProvider)
        .getLearningState(LearnLanguage.hindi);
    expect(extras, isNotNull);
    expect(
      extras!.reviewQueue.where((e) => e.reason == ReviewReason.recentlyWeak),
      isEmpty,
    );
    expect(extras.recentPerformance.events, hasLength(2));

    // Evidence masteries persisted (what derivation cannot know).
    expect(extras.conceptMasteries.containsKey(_focusConcept), isTrue);
  });

  test(
      'a struggling run ladders, seeds the review queue, and the spine '
      'sees the evidence', () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    final notifier = container.read(adaptiveSessionProvider.notifier);
    await notifier.start(
      kind: ActivityKind.practice,
      conceptId: _focusConcept,
      difficultyKnob: 2,
    );

    // Everything wrong: after two consecutive misses the §18 ladder
    // must surface a trusted explanation beat, and no exercise id is
    // ever asked twice.
    final seenIds = <String>{};
    var sawSupport = false;
    var sawLadderRung = false;
    var consecutiveWrongs = 0;

    var guard = 0;
    while (true) {
      final state = container.read(adaptiveSessionProvider);
      if (state.phase == AdaptiveSessionPhase.finished) break;
      expect(state.phase,
          anyOf(AdaptiveSessionPhase.active, AdaptiveSessionPhase.feedback));
      if (state.phase == AdaptiveSessionPhase.active) {
        final step = state.currentStep!;
        if (step.isSupport) {
          sawSupport = true;
          await notifier.next();
        } else {
          expect(seenIds.add(step.exercise!.id), isTrue,
              reason: 'never ask the same question twice');
          if (consecutiveWrongs >= 2 &&
              (step.presentation == StepPresentation.easier ||
                  step.presentation == StepPresentation.guided ||
                  step.presentation == StepPresentation.prerequisite)) {
            sawLadderRung = true;
          }
          notifier.submitAnswer(correct: false, firstTry: true);
          consecutiveWrongs++;
        }
      } else {
        await notifier.next();
      }
      guard++;
      expect(guard, lessThan(80));
    }
    expect(sawSupport, isTrue,
        reason: 'two wrongs must surface the trusted explanation beat');
    expect(sawLadderRung, isTrue,
        reason: 'the §18 ladder answered with easier/guided rungs');

    // The persisted extras now carry the review queue entry.
    final extras = container
        .read(learnProfileRepositoryProvider)
        .getLearningState(LearnLanguage.hindi);
    expect(extras, isNotNull);
    final weakEntries =
        extras!.reviewQueue.where((e) => e.conceptId == _focusConcept).toList();
    expect(weakEntries, hasLength(1));
    expect(weakEntries.first.reason, ReviewReason.recentlyWeak);
    expect(weakEntries.first.dueAt, isNotNull,
        reason: '§20: review SOON — due dates are set');

    // NOTHING was recorded as mastered (every answer was wrong).
    expect(
        container.read(masteredExercisesProvider('hi_script_vowels')), isEmpty);

    // The spine picks the extras + evidence overlay up.
    final learningState =
        await container.read(activeLearningStateProvider.future);
    expect(
      learningState.reviewQueue.any((e) => e.conceptId == _focusConcept),
      isTrue,
    );
    final evidenceRecord = learningState.conceptMasteries[_focusConcept];
    expect(evidenceRecord, isNotNull,
        reason: 'session evidence is overlaid onto the derived state');
    expect(evidenceRecord!.attemptCount, greaterThan(0));
  });

  test('unknown concept → honest unavailable state', () async {
    final container = await _container(prefs: {'learn_language': 'hindi'});
    addTearDown(container.dispose);

    await container.read(adaptiveSessionProvider.notifier).start(
          kind: ActivityKind.practice,
          conceptId: 'does-not-exist',
        );
    final state = container.read(adaptiveSessionProvider);
    expect(state.phase, AdaptiveSessionPhase.unavailable);
    expect(state.unavailableReason, isNotNull);
  });

  test('no language selected → honest unavailable state', () async {
    final container = await _container();
    addTearDown(container.dispose);

    await container.read(adaptiveSessionProvider.notifier).start(
          kind: ActivityKind.practice,
          conceptId: _focusConcept,
        );
    expect(container.read(adaptiveSessionProvider).phase,
        AdaptiveSessionPhase.unavailable);
  });

  test('a passed masteryCheck lifts an understood concept to mastered',
      () async {
    // Seed the honest path to `understood`: lesson completed + every
    // bank exercise mastered (the M1 derivation rule).
    final container = await _container(prefs: {
      'learn_language': 'hindi',
      'completed_lesson_ids': ['hi_script_vowels'],
      'mastered_exercises_hi_script_vowels':
          '["ex_hi_vowels_1","ex_hi_vowels_2","ex_hi_vowels_3","ex_hi_vowels_4"]',
    });
    addTearDown(container.dispose);

    final learningStateBefore =
        await container.read(activeLearningStateProvider.future);
    expect(learningStateBefore.stageOf(_focusConcept), MasteryStage.understood);

    final notifier = container.read(adaptiveSessionProvider.notifier);
    await notifier.start(
      kind: ActivityKind.masteryCheck,
      conceptId: _focusConcept,
      difficultyKnob: 2,
    );
    await _runToFinish(container, correct: (_) => true);

    // The check's evidence is stored; the OVERLAY surfaces mastered.
    final learningState =
        await container.read(activeLearningStateProvider.future);
    expect(
      learningState.stageOf(_focusConcept),
      MasteryStage.mastered,
      reason: 'a passed mastery check on understood material → mastered',
    );
  });
}
