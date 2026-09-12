/// Gemini AI Planner — M4 unit tests.
///
/// Pins the planner's failure-first contract (Master Brief §36/§60):
/// an unconfigured client short-circuits WITHOUT a network call, any
/// client failure becomes a Left (never a throw), garbage output is a
/// Left, a valid plan is returned AND cached write-through, and a cache
/// write failure can never fail a good plan.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
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

/// Configurable fake of the raw-text LLM boundary.
class FakePlannerTextClient implements PlannerTextClient {
  FakePlannerTextClient({
    this.available = true,
    this.reply,
    Object? throwOnCall,
  }) : _throwOnCall = throwOnCall;

  bool available;
  String? reply;
  Object? _throwOnCall;

  int completeCalls = 0;
  String? lastSystem;
  String? lastUser;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({required String system, required String user}) {
    completeCalls++;
    lastSystem = system;
    lastUser = user;
    if (_throwOnCall != null) throw _throwOnCall!;
    return Future.value(reply!);
  }
}

/// Storage whose setString always throws (cache disk-full simulation).
class _DiskFullStorage extends LocalStorageService {
  _DiskFullStorage(SharedPreferences prefs) : super(prefs);

  @override
  Future<void> setString(String key, String value) =>
      throw StateError('disk full');
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

Future<({LearnPlanRepository repo, ILocalStorageService storage})>
    _repo() async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  return (repo: LearnPlanRepository(storage), storage: storage);
}

void main() {
  group('GeminiPlanner', () {
    test('unavailable client → Left WITHOUT calling the model', () async {
      final client = FakePlannerTextClient(available: false);
      final planner = GeminiPlanner(textClient: client);

      final result = await planner.buildPlan(_context());

      expect(result.isLeft(), isTrue);
      expect(client.completeCalls, 0);
    });

    test('valid plan is returned as ai-sourced AND written to the cache',
        () async {
      final client =
          FakePlannerTextClient(available: true, reply: _validPlanJson);
      final m = await _repo();
      final planner = GeminiPlanner(textClient: client, planCache: m.repo);

      final result = await planner.buildPlan(_context());

      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.source, PlanSource.ai);
      expect(plan.activities, hasLength(2));
      expect(plan.activities.first.conceptId, 'hi_ls_1');
      expect(plan.languageCode, 'hi');

      final cached = m.repo.getPlan(LearnLanguage.hindi);
      expect(cached, isNotNull);
      expect(cached!.activities, hasLength(2));
    });

    test('prompts are the structured §62 pair (system + user)', () async {
      final client =
          FakePlannerTextClient(available: true, reply: _validPlanJson);
      final planner = GeminiPlanner(textClient: client, planCache: null);

      await planner.buildPlan(_context());

      expect(client.lastSystem, contains('ONLY a single JSON object'));
      expect(client.lastSystem, contains('no linguistic jargon'));
      expect(client.lastUser, contains('=== LANGUAGE KNOWLEDGE ==='));
      expect(client.lastUser, contains('=== LEARNER STATE ==='));
      expect(client.lastUser, contains('=== TASK ==='));
      expect(client.lastUser, contains('- hi_ls_1 | Greetings'));
    });

    test('client timeout → Left(TimeoutFailure), never a throw', () async {
      final client = FakePlannerTextClient(
        available: true,
        reply: null,
        throwOnCall: TimeoutException('planner timed out'),
      );
      final planner = GeminiPlanner(textClient: client);

      final result = await planner.buildPlan(_context());

      final failure = result.fold((f) => f, (p) => throw StateError('Right'));
      expect(failure, isA<TimeoutFailure>());
    });

    test('arbitrary client failure → Left(AiServiceFailure)', () async {
      final client = FakePlannerTextClient(
        available: true,
        reply: null,
        throwOnCall: StateError('503 backend gone'),
      );
      final planner = GeminiPlanner(textClient: client);

      final result = await planner.buildPlan(_context());

      final failure = result.fold((f) => f, (p) => throw StateError('Right'));
      expect(failure, isA<AiServiceFailure>());
    });

    test('garbage model output → Left (chain falls back)', () async {
      final client = FakePlannerTextClient(
        available: true,
        reply: 'Sorry, I cannot help with that request.',
      );
      final m = await _repo();
      final planner = GeminiPlanner(textClient: client, planCache: m.repo);

      final result = await planner.buildPlan(_context());

      expect(result.isLeft(), isTrue);
      // Nothing was cached — a failed plan must not poison the cache.
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });

    test('a cache disk-full never fails a good plan', () async {
      final client =
          FakePlannerTextClient(available: true, reply: _validPlanJson);
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final planner = GeminiPlanner(
        textClient: client,
        planCache: LearnPlanRepository(_DiskFullStorage(prefs)),
      );

      final result = await planner.buildPlan(_context());

      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.activities, hasLength(2));
    });

    test('planner id is stable (cache keys + diagnostics)', () {
      expect(GeminiPlanner(textClient: FakePlannerTextClient()).id,
          'gemini-planner-v1');
    });
  });
}
