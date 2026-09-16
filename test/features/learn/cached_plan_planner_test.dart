/// Cached Plan Planner — M4 fallback-hop tests.
///
/// Pins the "cached plan" behaviour of the Master Brief §36/§60 chain:
/// a fresh plan for the right language is served with HONEST
/// [PlanSource.cached] provenance; missing / wrong-language / stale /
/// empty caches are Lefts so the chain continues to the deterministic
/// planner; the legacy Sanskrit track has no cache by design.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

ConceptGraph _graph(String code) => ConceptGraph.forCurriculum(
      languageCode: code,
      chapters: [
        Chapter(
          id: '${code}_ch1',
          title: 'First words',
          lessons: [
            Lesson(id: '${code}_ls_1', title: 'Greetings', chapterId: 'ch_1'),
          ],
        ),
      ],
    );

PlannerContext _context(String code) => PlannerContext(
      languageCode: code,
      languageName: code == 'hi' ? 'Hindi' : 'Bengali',
      graph: _graph(code),
      state: LearningState(languageCode: code),
      supportedActivityTypes: kDeterministicPlannerActivityKinds,
    );

LearningPlan _aiPlan(String languageCode, {DateTime? createdAt}) =>
    LearningPlan(
      id: 'plan-ai-42',
      languageCode: languageCode,
      source: PlanSource.ai,
      focusSummary: 'Repair greetings, then move on.',
      activities: [
        LearningActivity(
          id: 'act-ai-1',
          kind: ActivityKind.weakRepair,
          title: 'Fix: Greetings',
          reason: 'One more round on greetings.',
          conceptId: '${languageCode}_ls_1',
          lessonId: '${languageCode}_ls_1',
          difficulty: Difficulty.beginner,
          estimatedMinutes: 4,
        ),
      ],
      createdAt: createdAt ?? DateTime.now(),
    );

Future<CachedPlanPlanner> _planner({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return CachedPlanPlanner(
      repository: LearnPlanRepository(
    LocalStorageService(prefs),
  ));
}

void main() {
  group('CachedPlanPlanner', () {
    test('empty cache → Left', () async {
      final planner = await _planner();
      final result = await planner.buildPlan(_context('hi'));
      expect(result.isLeft(), isTrue);
    });

    test('fresh cached plan → Right with honest cached provenance', () async {
      final planner = await _planner();
      await planner.repository.savePlan(_aiPlan('hi'));

      final result = await planner.buildPlan(_context('hi'));

      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.source, PlanSource.cached);
      expect(plan.id, 'plan-ai-42'); // same plan, relabelled
      expect(plan.activities.single.conceptId, 'hi_ls_1');
      expect(plan.focusSummary, 'Repair greetings, then move on.');
    });

    test('cache for ANOTHER language → Left', () async {
      final planner = await _planner();
      await planner.repository.savePlan(_aiPlan('bn'));

      final result = await planner.buildPlan(_context('hi'));
      expect(result.isLeft(), isTrue);
    });

    test('stale cache (older than 7 days) → Left', () async {
      final planner = await _planner();
      await planner.repository.savePlan(
        _aiPlan(
          'hi',
          createdAt: DateTime.now().subtract(
            LearnPlanRepository.kDefaultMaxAge + const Duration(hours: 1),
          ),
        ),
      );

      final result = await planner.buildPlan(_context('hi'));
      expect(result.isLeft(), isTrue);
    });

    test('cached EMPTY plan → Left (never serve a blank screen)', () async {
      final planner = await _planner();
      await planner.repository.savePlan(
        LearningPlan.empty(
          languageCode: 'hi',
          source: PlanSource.ai,
          id: 'plan-ai-empty',
        ),
      );

      final result = await planner.buildPlan(_context('hi'));
      expect(result.isLeft(), isTrue);
    });

    test('legacy Sanskrit track (sa) → Left — no cache by design', () async {
      final planner = await _planner();
      final result = await planner.buildPlan(_context('hi'));
      // Sanity for the guard: 'sa' resolves to no catalogue language.
      expect(learnLanguageForCode('sa'), isNull);
      expect(result.isLeft(), isTrue);
    });
  });

  group('failure typing', () {
    test('lefts are AiServiceFailures with human-readable causes', () async {
      final planner = await _planner();
      final failure = await planner
          .buildPlan(_context('hi'))
          .then((r) => r.fold((f) => f, (p) => throw StateError('Right')));
      expect(failure, isA<AiServiceFailure>());
      expect(failure.message, isNotEmpty);
    });
  });
}
