/// Phase 2.2 curriculum revision safety tests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/presentation/providers/curriculum_compatibility_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_content_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

const _language = LearnLanguage.hindi;
const _concept = 'hi_script_vowels';

Future<({ProviderContainer container, SharedPreferences prefs})> _container({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'learn_language': 'hindi',
    'completed_lesson_ids': [_concept],
    ...seed,
  });
  final prefs = await SharedPreferences.getInstance();
  return (
    container: ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ),
    prefs: prefs,
  );
}

LearningState _state() => const LearningState(
      languageCode: 'hi',
      conceptMasteries: {
        _concept: ConceptMastery(
          conceptId: _concept,
          stage: MasteryStage.recalled,
        ),
      },
    );

DiagnosticResult _diagnostic() => DiagnosticResult(
      language: _language,
      overallLevel: 3,
      confidence: 0.8,
      completedAt: DateTime.utc(2026, 1, 1),
      dimensionScores: const {},
    );

LearningPlan _plan() => LearningPlan.empty(
      languageCode: 'hi',
      source: PlanSource.ai,
      id: 'old-plan',
    );

GeneratedContent _generated() => GeneratedContent(
      id: 'old-content',
      kind: GeneratedContentKind.explanation,
      languageCode: 'hi',
      conceptId: _concept,
      lessonId: _concept,
      difficultyKnob: 2,
      title: 'old content',
      body: 'old body',
      createdAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _seedCurriculumBoundData(ProviderContainer container) async {
  final profile = container.read(learnProfileRepositoryProvider);
  await profile.saveProfile(
    LearnerProfile.initial(_language).copyWith(
      currentLevel: 3,
      goal: LearningGoal.conversation,
      desiredLevel: DesiredLevel.intermediate,
    ),
  );
  await profile.saveLearningState(_language, _state());
  await profile.saveDiagnostic(_diagnostic());
  await container.read(learnPlanRepositoryProvider).savePlan(_plan());
  await container
      .read(generatedContentRepositoryProvider)
      .save(_language, 'old-key', _generated());
}

Future<void> _runCompatibility(ProviderContainer container) async {
  await container.read(curriculumCompatibilityProvider(_language).future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first revision adoption stores the marker without destructive reset',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);
    await _seedCurriculumBoundData(container);

    await _runCompatibility(container);

    final profile = container.read(learnProfileRepositoryProvider);
    expect(profile.getCurriculumRevision(_language), 1);
    expect(profile.getLearningState(_language), isNotNull);
    expect(profile.getDiagnostic(_language), isNotNull);
    expect(profile.getProfile(_language)!.currentLevel, 3);
    expect(container.read(learnPlanRepositoryProvider).getPlan(_language),
        isNotNull);
    expect(
        container
            .read(generatedContentRepositoryProvider)
            .get(_language, 'old-key'),
        isNotNull);
  });

  test('same revision preserves state, diagnostic, plan and generated cache',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);
    await _seedCurriculumBoundData(container);
    final profile = container.read(learnProfileRepositoryProvider);
    await profile.saveCurriculumRevision(_language, 1);

    await _runCompatibility(container);

    expect(profile.getLearningState(_language), isNotNull);
    expect(profile.getDiagnostic(_language), isNotNull);
    expect(profile.getProfile(_language)!.currentLevel, 3);
    expect(container.read(learnPlanRepositoryProvider).getPlan(_language),
        isNotNull);
    expect(
        container
            .read(generatedContentRepositoryProvider)
            .get(_language, 'old-key'),
        isNotNull);
  });

  test(
      'revision mismatch clears curriculum state but preserves intent and raw progress',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);
    await _seedCurriculumBoundData(container);
    final profile = container.read(learnProfileRepositoryProvider);
    await profile.saveCurriculumRevision(_language, 0);
    await container
        .read(progressRepositoryProvider)
        .recordMasteredExercises(_concept, ['historical-id']);

    await _runCompatibility(container);

    expect(profile.getCurriculumRevision(_language), 1);
    expect(profile.getLearningState(_language), isNull);
    expect(profile.getDiagnostic(_language), isNull);
    final preserved = profile.getProfile(_language)!;
    expect(preserved.currentLevel, isNull);
    expect(preserved.goal, LearningGoal.conversation);
    expect(preserved.desiredLevel, DesiredLevel.intermediate);
    expect(
        container.read(learnPlanRepositoryProvider).getPlan(_language), isNull);
    expect(
        container
            .read(generatedContentRepositoryProvider)
            .get(_language, 'old-key'),
        isNull);
    expect(
        container
            .read(progressRepositoryProvider)
            .getMasteredExercises(_concept)
            .getOrElse(() => const []),
        ['historical-id']);
  });

  test('revision marker is committed only after cleanup completes', () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);
    final profile = container.read(learnProfileRepositoryProvider);
    await profile.saveLearningState(_language, _state());
    await profile.saveCurriculumRevision(_language, 0);

    await _runCompatibility(container);

    expect(profile.getLearningState(_language), isNull);
    expect(profile.getCurriculumRevision(_language), 1);
  });

  test('stale mastered IDs do not contribute to current lesson mastery',
      () async {
    final setup = await _container(seed: {
      'mastered_exercises_hi_script_vowels':
          '["ex_hi_vowels_1","old_1","old_2","old_3"]',
    });
    final container = setup.container;
    addTearDown(container.dispose);

    final state = await container.read(activeLearningStateProvider.future);
    final mastery = state.conceptMasteries[_concept]!;
    expect(mastery.stage, MasteryStage.practiced,
        reason: 'only the one current exercise counts');
    expect(mastery.correctCount, 1);
  });

  test('removed concept evidence, review and performance stay out of state',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);
    final profile = container.read(learnProfileRepositoryProvider);
    await profile.saveLearningState(
      _language,
      LearningState(
        languageCode: 'hi',
        conceptMasteries: const {
          'removed_concept': ConceptMastery(
            conceptId: 'removed_concept',
            stage: MasteryStage.mastered,
          ),
        },
        reviewQueue: const [
          ReviewEntry(
            conceptId: 'removed_concept',
            reason: ReviewReason.recentlyWeak,
            priority: 1,
          ),
        ],
        recentPerformance: RecentPerformance(events: [
          PerformanceEvent(
            conceptId: 'removed_concept',
            correct: true,
            firstTry: true,
            at: DateTime.utc(2026, 1, 1),
          ),
        ]),
      ),
    );

    final state = await container.read(activeLearningStateProvider.future);
    expect(state.conceptMasteries.containsKey('removed_concept'), isFalse);
    expect(state.reviewQueue.any((e) => e.conceptId == 'removed_concept'),
        isFalse);
    expect(
        state.recentPerformance.events
            .any((e) => e.conceptId == 'removed_concept'),
        isFalse);
  });
}
