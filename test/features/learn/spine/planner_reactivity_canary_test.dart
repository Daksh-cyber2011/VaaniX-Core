library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/session_providers.dart';

class _MutablePlannerClient implements PlannerTextClient {
  _MutablePlannerClient({required this.available});

  bool available;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({required String system, required String user}) =>
      Future.value('''{"focusSummary":"Keep going","activities":[
        {"conceptId":"hi_ls_1","activityType":"newLearning",
         "difficulty":2,"reason":"Continue the next lesson.","estimatedMinutes":5}
      ]}''');
}

Future<ProviderContainer> _container({
  required _MutablePlannerClient client,
  Map<String, Object> prefs = const {'learn_language': 'hindi'},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(instance),
      plannerTextClientProvider.overrideWithValue(client),
    ],
  );
}

DiagnosticAnswer _correctAnswerFor(DiagnosticItem item) {
  final display = prepareExerciseOptions(item.exercise, 0);
  return switch (item.exercise.type) {
    ExerciseType.mcq ||
    ExerciseType.fillBlank =>
      DiagnosticChoiceAnswer(display.correctIndex),
    ExerciseType.translation =>
      DiagnosticTextAnswer(item.exercise.acceptedAnswers.first),
    ExerciseType.matching => DiagnosticMatchAnswer({
        for (var i = 0; i < item.exercise.pairs.length; i++)
          i: display.pairIndexByDisplay.indexOf(i),
      }),
    ExerciseType.ordering => DiagnosticOrderAnswer(item.exercise.items),
  };
}

Future<void> _finishDiagnostic(
    ProviderContainer container, bool correct) async {
  final notifier = container.read(diagnosticSessionProvider.notifier);
  await notifier.start(LearnLanguage.hindi);
  var guard = 0;
  while (true) {
    final state = container.read(diagnosticSessionProvider);
    if (state.phase == DiagnosticPhase.finished) return;
    if (state.phase == DiagnosticPhase.active) {
      notifier.submitAnswer(_correctAnswerFor(state.currentItem!));
    } else if (state.phase == DiagnosticPhase.feedback) {
      await notifier.next();
    } else {
      fail('diagnostic did not start: ${state.phase}');
    }
    guard++;
    expect(guard, lessThan(80));
  }
}

Future<void> _finishAdaptive(ProviderContainer container) async {
  final notifier = container.read(adaptiveSessionProvider.notifier);
  await notifier.start(
    kind: ActivityKind.practice,
    conceptId: 'hi_script_vowels',
    difficultyKnob: 2,
  );
  var guard = 0;
  while (true) {
    final state = container.read(adaptiveSessionProvider);
    if (state.phase == AdaptiveSessionPhase.finished) return;
    if (state.phase == AdaptiveSessionPhase.active) {
      if (state.currentStep!.isSupport) {
        await notifier.next();
      } else {
        notifier.submitAnswer(correct: true, firstTry: true);
      }
    } else if (state.phase == AdaptiveSessionPhase.feedback) {
      await notifier.next();
    } else {
      fail('adaptive session did not start: ${state.phase}');
    }
    guard++;
    expect(guard, lessThan(80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile mutation propagates into the active planner context', () async {
    final client = _MutablePlannerClient(available: false);
    final container = await _container(client: client);
    addTearDown(container.dispose);

    final before = await container.read(activePlannerContextProvider.future);
    await container
        .read(learnerProfileProvider(LearnLanguage.hindi).notifier)
        .setDailyGoalMinutes(before.minutesAvailable + 10);
    final after = await container.read(activePlannerContextProvider.future);

    expect(after.minutesAvailable, before.minutesAvailable + 10);
    expect(after.plannerContextKey, isNot(before.plannerContextKey));
  });

  test('diagnostic completion updates lastDiagnostic and planner context',
      () async {
    final container = await _container(
      client: _MutablePlannerClient(available: false),
    );
    addTearDown(container.dispose);

    final before = await container.read(activePlannerContextProvider.future);
    expect(container.read(lastDiagnosticProvider(LearnLanguage.hindi)), isNull);
    await _finishDiagnostic(container, true);
    final diagnostic =
        container.read(lastDiagnosticProvider(LearnLanguage.hindi));
    final after = await container.read(activePlannerContextProvider.future);

    expect(diagnostic, isNotNull);
    expect(after.diagnostic, diagnostic);
    expect(after.plannerContextKey, isNot(before.plannerContextKey));
  });

  test('adaptive session evidence propagates into planner context', () async {
    final container = await _container(
      client: _MutablePlannerClient(available: false),
    );
    addTearDown(container.dispose);

    final before = await container.read(activePlannerContextProvider.future);
    await _finishAdaptive(container);
    final afterState = await container.read(activeLearningStateProvider.future);
    final after = await container.read(activePlannerContextProvider.future);

    expect(afterState.stageOf('hi_script_vowels'), isNotNull);
    expect(after.state.conceptMasteries, isNotEmpty);
    expect(after.plannerContextKey, isNot(before.plannerContextKey));
  });

  test('language selection rebuilds graph and planner context', () async {
    final container = await _container(
      client: _MutablePlannerClient(available: false),
    );
    addTearDown(container.dispose);

    final before = await container.read(activePlannerContextProvider.future);
    await container
        .read(selectedLearnLanguageProvider.notifier)
        .select(LearnLanguage.bengali);
    final after = await container.read(activePlannerContextProvider.future);

    expect(before.languageCode, 'hi');
    expect(after.languageCode, 'bn');
    expect(after.languageName, 'Bengali');
    expect(after.graph.languageCode, 'bn');
    expect(after.plannerContextKey, isNot(before.plannerContextKey));
  });

  test('active plan reacts and rejects a cached plan from the old context',
      () async {
    final client = _MutablePlannerClient(available: true);
    final container = await _container(client: client);
    addTearDown(container.dispose);

    final first = await container.read(activeLearningPlanProvider.future);
    expect(first.activityIds, isNotEmpty);
    final before = await container.read(activePlannerContextProvider.future);

    final conceptId = first.activityConceptIds.firstWhere((id) => id != null)!;
    await container.read(learnPlanRepositoryProvider).savePlan(
          LearningPlan(
            id: 'cached-old-context',
            languageCode: 'hi',
            source: PlanSource.ai,
            activities: [
              LearningActivity(
                id: 'cached-old-activity',
                kind: first.activityKinds.first,
                title: first.activityTitles.first,
                reason: 'cached old context',
                conceptId: conceptId,
              ),
            ],
            createdAt: DateTime.now(),
            plannerContextKey: before.plannerContextKey,
          ),
        );

    client.available = false;
    await container
        .read(learnerProfileProvider(LearnLanguage.hindi).notifier)
        .setDailyGoalMinutes(before.minutesAvailable + 10);
    final after = await container.read(activePlannerContextProvider.future);
    final second = await container.read(activeLearningPlanProvider.future);

    expect(after.plannerContextKey, isNot(before.plannerContextKey));
    expect(second.source, PlanSource.deterministic);
    expect(second.activityIds, isNot(contains('cached-old-activity')));
  });
}
