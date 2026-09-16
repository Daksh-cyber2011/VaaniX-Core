/// M4 Planner Chain — provider wiring + Master Brief §36/§60 fallback
/// chain end-to-end.
///
/// Builds the REAL [learningPlannerProvider] wiring (only the text
/// client and storage are faked) and walks the whole chain:
///
///   AI plan → cached plan → deterministic → (empty-but-valid)
///
/// Pins, in order: AI success (source ai + cache write-through), AI
/// outage with a fresh cache (source cached), AI outage without a cache
/// (source deterministic — the M1 behaviour is preserved), stale cache
/// skipping to deterministic, garbage AI output skipping to cache, and
/// the facade id that documents the exact wiring.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

const String _validPlanJson = '''
{"focusSummary": "Repair greetings, then learn family words.",
 "activities": [
   {"conceptId": "hi_ls_1", "activityType": "weakRepair", "difficulty": 2,
    "reason": "Greetings slipped last time - one quick repair.", "estimatedMinutes": 4},
   {"conceptId": "hi_ls_2", "activityType": "newLearning", "difficulty": 2,
    "reason": "Family words are next on your path.", "estimatedMinutes": 6}
 ]}
''';

/// Local copy of the fake text client (tests stay self-contained).
class _FakeTextClient implements PlannerTextClient {
  _FakeTextClient({this.available = true, this.reply});

  final bool available;
  final String? reply;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) {
    if (reply == null) {
      throw StateError('no reply configured');
    }
    return Future.value(reply);
  }
}

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'hi_ch1',
          title: 'First words',
          lessons: [
            Lesson(id: 'hi_ls_1', title: 'Greetings', chapterId: 'hi_ch1'),
            Lesson(id: 'hi_ls_2', title: 'Family', chapterId: 'hi_ch1'),
          ],
        ),
      ],
    );

PlannerContext _context() => PlannerContext(
      languageCode: 'hi',
      languageName: 'Hindi',
      graph: _graph(),
      state: const LearningState(languageCode: 'hi'),
      supportedActivityTypes: kDeterministicPlannerActivityKinds,
    );

Future<ProviderContainer> _container({
  required PlannerTextClient textClient,
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      plannerTextClientProvider.overrideWithValue(textClient),
      learnPlanRepositoryProvider.overrideWithValue(LearnPlanRepository(
        LocalStorageService(prefs),
      )),
    ],
  );
}

Future<LearningPlan> _planFrom(
  ProviderContainer container,
  PlannerContext context,
) {
  final planner = container.read(learningPlannerProvider);
  return planner.buildPlan(context).then(
        (r) => r.fold((f) => throw StateError(f.message), (p) => p),
      );
}

String _encode(LearningPlan plan) => jsonEncode(plan.toJson());

String _planKey() => LearnPlanRepository.planKey(learnLanguageForCode('hi')!);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('wiring id documents the full §36/§60 chain', () async {
    final c = await _container(
      textClient: _FakeTextClient(available: false),
    );
    addTearDown(c.dispose);
    expect(
      c.read(learningPlannerProvider).id,
      'validating(gemini-planner-v1->'
      'validating(cached-plan-v1->deterministic-v1))',
    );
  });

  test('hop 1 — AI success: ai-sourced plan, cached for the next outage',
      () async {
    final c = await _container(
      textClient: _FakeTextClient(reply: _validPlanJson),
    );
    addTearDown(c.dispose);

    final plan = await _planFrom(c, _context());

    expect(plan.source, PlanSource.ai);
    expect(plan.activities.map((a) => a.conceptId).toList(),
        ['hi_ls_1', 'hi_ls_2']);

    final cached = c.read(learnPlanRepositoryProvider).getPlan(
          learnLanguageForCode('hi')!,
        );
    expect(cached, isNotNull);
    expect(cached!.activities, hasLength(2));
  });

  test('hop 2 — AI outage + fresh cache: cached plan serves, relabelled',
      () async {
    // Produce a real cached plan via a successful AI run.
    final good = await _container(
      textClient: _FakeTextClient(reply: _validPlanJson),
    );
    await _planFrom(good, _context());
    final cachedPlan = good.read(learnPlanRepositoryProvider).getPlan(
          learnLanguageForCode('hi')!,
        )!;
    good.dispose();

    // Now the outage: same storage contents, unavailable client.
    final c = await _container(
      textClient: _FakeTextClient(available: false),
      seed: {_planKey(): _encode(cachedPlan)},
    );
    addTearDown(c.dispose);

    final plan = await _planFrom(c, _context());

    expect(plan.source, PlanSource.cached);
    expect(plan.activities.map((a) => a.conceptId).toList(),
        ['hi_ls_1', 'hi_ls_2']);
  });

  test('hop 3 — AI outage + no cache: deterministic plan (M1 behaviour)',
      () async {
    final c = await _container(
      textClient: _FakeTextClient(available: false),
    );
    addTearDown(c.dispose);

    final plan = await _planFrom(c, _context());

    expect(plan.source, PlanSource.deterministic);
    expect(plan.activities, isNotEmpty);
    expect(plan.activities.first.kind, ActivityKind.newLearning);
  });

  test('stale cache is skipped — the chain falls to deterministic', () async {
    final stale = LearningPlan(
      id: 'plan-ai-old',
      languageCode: 'hi',
      source: PlanSource.ai,
      activities: const [
        LearningActivity(
          id: 'act-1',
          kind: ActivityKind.practice,
          title: 'Old step',
          reason: 'Stale focus.',
          conceptId: 'hi_ls_1',
          lessonId: 'hi_ls_1',
        ),
      ],
      createdAt: DateTime.now().subtract(
        LearnPlanRepository.kDefaultMaxAge + const Duration(hours: 2),
      ),
    );
    final c = await _container(
      textClient: _FakeTextClient(available: false),
      seed: {_planKey(): _encode(stale)},
    );
    addTearDown(c.dispose);

    final plan = await _planFrom(c, _context());
    expect(plan.source, PlanSource.deterministic);
  });

  test('garbage AI output + fresh cache → cached plan', () async {
    final good = await _container(
      textClient: _FakeTextClient(reply: _validPlanJson),
    );
    await _planFrom(good, _context());
    final cachedPlan = good.read(learnPlanRepositoryProvider).getPlan(
          learnLanguageForCode('hi')!,
        )!;
    good.dispose();

    final c = await _container(
      textClient: _FakeTextClient(
        reply: 'I am sorry, I cannot plan that.',
      ),
      seed: {_planKey(): _encode(cachedPlan)},
    );
    addTearDown(c.dispose);

    final plan = await _planFrom(c, _context());
    expect(plan.source, PlanSource.cached);
  });
}
