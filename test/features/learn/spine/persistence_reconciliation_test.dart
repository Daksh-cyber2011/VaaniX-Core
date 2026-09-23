/// Learn Mode spine — persistence reconciliation regression tests.
///
/// The raw progress store owns per-lesson exercise-id evidence.  The Learn
/// profile store owns session-only concept evidence, review scheduling and
/// recent performance.  These tests pin the provider-level reconciliation
/// boundary that combines both persisted sources.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

const _language = LearnLanguage.hindi;
const _lessonId = 'hi_script_vowels';
const _exerciseIds = [
  'ex_hi_vowels_1',
  'ex_hi_vowels_2',
  'ex_hi_vowels_3',
  'ex_hi_vowels_4',
];

Future<({ProviderContainer container, SharedPreferences preferences})>
    _container() async {
  SharedPreferences.setMockInitialValues({
    'learn_language': 'hindi',
    'completed_lesson_ids': [_lessonId],
  });
  final preferences = await SharedPreferences.getInstance();
  return (
    container: ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    ),
    preferences: preferences,
  );
}

LearningState _extras({
  MasteryStage stage = MasteryStage.mastered,
  DateTime? practicedAt,
  int events = 1,
}) {
  final at = practicedAt ?? DateTime.utc(2026, 1, 2);
  return LearningState(
    languageCode: 'hi',
    conceptMasteries: {
      _lessonId: ConceptMastery(
        conceptId: _lessonId,
        stage: stage,
        strength: 0.9,
        correctCount: 8,
        attemptCount: 9,
        lastPracticedAt: at,
      ),
    },
    reviewQueue: const [
      ReviewEntry(
        conceptId: _lessonId,
        reason: ReviewReason.maintenance,
        priority: 0.3,
      ),
    ],
    recentPerformance: RecentPerformance(events: [
      PerformanceEvent(
        conceptId: _lessonId,
        correct: true,
        firstTry: true,
        at: DateTime.utc(2026, 1, 2),
      ),
      if (events > 1)
        PerformanceEvent(
          conceptId: _lessonId,
          correct: true,
          firstTry: true,
          at: DateTime.utc(2026, 1, 3),
        ),
    ]),
  );
}

Future<void> _recordMastery(
    ProviderContainer container, List<String> ids) async {
  await container
      .read(progressRepositoryProvider)
      .recordMasteredExercises(_lessonId, ids);
}

void _invalidateReconciliation(ProviderContainer container) {
  container.invalidate(learnStateExtrasProvider(_language));
  container.invalidate(masteredExercisesProvider(_lessonId));
}

Future<LearningState> _writeAndRead({
  required bool stateFirst,
  required LearningState extras,
  List<String> ids = _exerciseIds,
}) async {
  final setup = await _container();
  final container = setup.container;
  try {
    final profile = container.read(learnProfileRepositoryProvider);
    if (stateFirst) {
      await profile.saveLearningState(_language, extras);
      await _recordMastery(container, ids);
    } else {
      await _recordMastery(container, ids);
      await profile.saveLearningState(_language, extras);
    }
    _invalidateReconciliation(container);
    return await container.read(activeLearningStateProvider.future);
  } finally {
    container.dispose();
  }
}

Future<LearningState> _writeExistingUpdate({required bool stateFirst}) async {
  final setup = await _container();
  final container = setup.container;
  try {
    final profile = container.read(learnProfileRepositoryProvider);
    await profile.saveLearningState(
      _language,
      _extras(stage: MasteryStage.recalled),
    );
    await _recordMastery(container, [_exerciseIds.first]);

    final latest = _extras(
      stage: MasteryStage.maintained,
      practicedAt: DateTime.utc(2026, 2, 1),
      events: 2,
    );
    if (stateFirst) {
      await profile.saveLearningState(_language, latest);
      await _recordMastery(container, _exerciseIds.skip(1).toList());
    } else {
      await _recordMastery(container, _exerciseIds.skip(1).toList());
      await profile.saveLearningState(_language, latest);
    }
    _invalidateReconciliation(container);
    return await container.read(activeLearningStateProvider.future);
  } finally {
    container.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LearningState then mastery set yields one reconciled state', () async {
    final state = await _writeAndRead(stateFirst: true, extras: _extras());

    expect(state.stageOf(_lessonId), MasteryStage.mastered);
    expect(state.conceptMasteries, hasLength(1));
    expect(state.conceptMasteries[_lessonId]!.correctCount, 4,
        reason: 'raw progress counters remain authoritative');
    expect(state.reviewQueue.single.conceptId, _lessonId);
    expect(state.recentPerformance.events, hasLength(1));
  });

  test('mastery set then LearningState yields the same effective state',
      () async {
    final stateFirst = await _writeAndRead(stateFirst: true, extras: _extras());
    final masteryFirst =
        await _writeAndRead(stateFirst: false, extras: _extras());

    expect(masteryFirst, stateFirst);
  });

  test('existing mastery updates retain the latest complete evidence',
      () async {
    final stateFirst = await _writeExistingUpdate(stateFirst: true);
    final masteryFirst = await _writeExistingUpdate(stateFirst: false);

    for (final state in [stateFirst, masteryFirst]) {
      final mastery = state.conceptMasteries[_lessonId]!;
      expect(mastery.stage, MasteryStage.maintained);
      expect(mastery.lastPracticedAt, DateTime.utc(2026, 2, 1));
      expect(mastery.correctCount, 4);
      expect(state.recentPerformance.events, hasLength(2));
    }
    expect(masteryFirst, stateFirst);
  });

  test('provider invalidation replaces a cached state with reconciled data',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);

    final before = await container.read(activeLearningStateProvider.future);
    expect(before.stageOf(_lessonId), MasteryStage.practiced,
        reason: 'the current derivation records completed authored lessons '
            'as practiced before session evidence is overlaid');

    await container
        .read(learnProfileRepositoryProvider)
        .saveLearningState(_language, _extras());
    await _recordMastery(container, _exerciseIds);
    _invalidateReconciliation(container);

    expect(container.read(masteredExercisesProvider(_lessonId)), _exerciseIds);
    final after = await container.read(activeLearningStateProvider.future);
    expect(after.stageOf(_lessonId), MasteryStage.mastered);
    expect(after.recentPerformance.events, hasLength(1));
  });

  test('a rebuilt provider container reloads the same reconciled state',
      () async {
    final setup = await _container();
    final first = setup.container;
    final profile = first.read(learnProfileRepositoryProvider);
    await profile.saveLearningState(_language, _extras());
    await _recordMastery(first, _exerciseIds);
    _invalidateReconciliation(first);
    final expected = await first.read(activeLearningStateProvider.future);
    first.dispose();

    final reloaded = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(setup.preferences),
      ],
    );
    addTearDown(reloaded.dispose);

    final restored = await reloaded.read(activeLearningStateProvider.future);
    expect(restored, expected);
    expect(restored.conceptMasteries.keys, [_lessonId],
        reason: 'the overlay creates no duplicate or conflicting mastery');
  });

  test('idempotent mastery writes cannot create contradictory evidence',
      () async {
    final setup = await _container();
    final container = setup.container;
    addTearDown(container.dispose);

    await container
        .read(learnProfileRepositoryProvider)
        .saveLearningState(_language, _extras());
    await _recordMastery(container, [
      _exerciseIds.first,
      _exerciseIds.first,
      ..._exerciseIds.skip(1),
    ]);
    _invalidateReconciliation(container);

    expect(container.read(masteredExercisesProvider(_lessonId)), _exerciseIds);
    final state = await container.read(activeLearningStateProvider.future);
    expect(state.conceptMasteries, hasLength(1));
    expect(state.stageOf(_lessonId), MasteryStage.mastered);
  });
}
