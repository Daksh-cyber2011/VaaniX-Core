/// Learn Mode 2.0 — Deterministic Planner tests (M1 spine).
///
/// Pins the offline fallback planner: weak-repair first, then reviews,
/// then new learning, all grounded in the trusted graph; empty curricula
/// produce a valid empty plan; and the ValidatingPlanner facade keeps an
/// ungrounded delegate plan from ever reaching the learner.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'ch_1',
          title: 'Chapter 1',
          lessons: [
            Lesson(id: 'hi_ls_1', title: 'Greetings', chapterId: 'ch_1'),
            Lesson(id: 'hi_ls_2', title: 'Family', chapterId: 'ch_1'),
          ],
        ),
      ],
    );

LearningState _state(Map<String, MasteryStage> stages) {
  return LearningState(
    languageCode: 'hi',
    conceptMasteries: {
      for (final e in stages.entries)
        e.key: ConceptMastery(conceptId: e.key, stage: e.value),
    },
  );
}

PlannerContext _context({
  ConceptGraph? graph,
  LearningState? state,
  Set<ActivityKind>? kinds,
}) {
  final g = graph ?? _graph();
  return PlannerContext(
    languageCode: g.languageCode,
    languageName: 'Hindi',
    graph: g,
    state: state ?? const LearningState(languageCode: 'hi'),
    supportedActivityTypes: kinds ?? kDeterministicPlannerActivityKinds,
  );
}

/// A planner that "hallucinates" — emits ungrounded activities to prove
/// the facade filters them.
class HallucinatingPlanner implements LearningPlanner {
  @override
  String get id => 'hallucinating';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
      PlannerContext context) async {
    return Right(
      LearningPlan(
        id: 'p-hallu',
        languageCode: context.languageCode,
        source: PlanSource.ai,
        activities: [
          const LearningActivity(
            id: 'a1',
            kind: ActivityKind.newLearning,
            title: 'Invented concept',
            reason: 'trust me',
            conceptId: 'zz_does_not_exist',
          ),
          const LearningActivity(
            id: 'a2',
            kind: ActivityKind.newLearning,
            title: 'Cross-language leak',
            reason: 'wrong anchor',
            conceptId: 'hi_ls_1',
            lessonId: 'bn_ls_1',
          ),
          // Only this one is grounded:
          const LearningActivity(
            id: 'a3',
            kind: ActivityKind.practice,
            title: 'Practice: Greetings',
            reason: 'grounded',
            conceptId: 'hi_ls_1',
            lessonId: 'hi_ls_1',
          ),
        ],
        createdAt: DateTime.now(),
      ),
    );
  }
}

/// A planner that always fails (simulated AI outage).
class FailingPlanner implements LearningPlanner {
  @override
  String get id => 'failing';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
      PlannerContext context) async {
    return Left(const AiServiceFailure('simulated outage'));
  }
}

void main() {
  group('DeterministicPlanner', () {
    test('fresh learner: plan starts with new learning of the first concept',
        () async {
      final result = await const DeterministicPlanner().buildPlan(_context());
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.source, PlanSource.deterministic);
      expect(plan.activities.first.kind, ActivityKind.newLearning);
      expect(plan.activities.first.conceptId, 'hi_ls_1');
      expect(plan.activities.first.lessonId, 'hi_ls_1');
    });

    test('weak (completed but not understood) concept gets repair FIRST',
        () async {
      final plan = await const DeterministicPlanner()
          .buildPlan(_context())
          .then((r) => r.fold((f) => throw StateError(f.message), (p) => p));

      final state = _state({
        'hi_ls_1': MasteryStage.practiced, // weak: below understood
      });
      final weakPlan = await const DeterministicPlanner()
          .buildPlan(_context(state: state))
          .then((r) => r.fold((f) => throw StateError(f.message), (p) => p));

      expect(weakPlan.activities.first.kind, ActivityKind.weakRepair);
      expect(weakPlan.activities.first.conceptId, 'hi_ls_1');
      // The plan still keeps new learning after the repair.
      expect(weakPlan.activities.map((a) => a.kind),
          contains(ActivityKind.newLearning));
      expect(plan.isEmpty, isFalse);
    });

    test('empty curriculum (stub language) yields a valid empty plan',
        () async {
      final emptyGraph = ConceptGraph.forCurriculum(
        languageCode: 'kn',
        chapters: const [],
      );
      final result = await const DeterministicPlanner()
          .buildPlan(_context(graph: emptyGraph));
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.isEmpty, isTrue);
      expect(plan.languageCode, 'kn');
      expect(plan.focusSummary, isNotNull);
    });

    test('every emitted activity is grounded in the graph', () async {
      final plan = await const DeterministicPlanner()
          .buildPlan(_context(
              state: _state({
            'hi_ls_1': MasteryStage.understood,
          })))
          .then((r) => r.fold((f) => throw StateError(f.message), (p) => p));

      final graph = _graph();
      for (final a in plan.activities) {
        if (a.conceptId == null) continue;
        expect(graph.conceptById(a.conceptId!), isNotNull,
            reason: '${a.id} references an unknown concept');
        if (a.lessonId != null) {
          expect(a.lessonId, graph.conceptById(a.conceptId!)!.lessonId);
        }
      }
    });
  });

  group('ValidatingPlanner facade', () {
    test('drops ungrounded AI activities, keeps the grounded ones', () async {
      final facade = ValidatingPlanner(
        delegate: HallucinatingPlanner(),
        fallback: const DeterministicPlanner(),
      );
      final result = await facade.buildPlan(_context());
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.activities, hasLength(1));
      expect(plan.activities.single.id, 'a3');
    });

    test('delegate failure falls back to the deterministic plan', () async {
      final facade = ValidatingPlanner(
        delegate: FailingPlanner(),
        fallback: const DeterministicPlanner(),
      );
      final result = await facade.buildPlan(_context());
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.source, PlanSource.deterministic);
      expect(plan.activities, isNotEmpty);
    });

    test('a plan for a DIFFERENT language never executes', () async {
      // Delegate returns a valid plan but tagged with the wrong language.
      final facade = ValidatingPlanner(
        delegate: _WrongLanguagePlanner(),
        fallback: const DeterministicPlanner(),
      );
      final result = await facade.buildPlan(_context());
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.source, PlanSource.deterministic);
    });

    test('empty delegate plan falls back instead of blank-screening', () async {
      final facade = ValidatingPlanner(
        delegate: _EmptyPlanner(),
        fallback: const DeterministicPlanner(),
      );
      final result = await facade.buildPlan(_context());
      final plan = result.fold((f) => throw StateError(f.message), (p) => p);
      expect(plan.activities, isNotEmpty);
    });
  });
}

class _WrongLanguagePlanner implements LearningPlanner {
  @override
  String get id => 'wrong-language';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
      PlannerContext context) async {
    return Right(
      LearningPlan(
        id: 'p-wrong',
        languageCode: 'bn', // NOT the context's language
        source: PlanSource.ai,
        activities: const [
          LearningActivity(
            id: 'a1',
            kind: ActivityKind.practice,
            title: 'x',
            reason: 'y',
            conceptId: 'hi_ls_1',
          ),
        ],
        createdAt: DateTime.now(),
      ),
    );
  }
}

class _EmptyPlanner implements LearningPlanner {
  @override
  String get id => 'empty';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
      PlannerContext context) async {
    return Right(
      LearningPlan.empty(
        languageCode: context.languageCode,
        source: PlanSource.ai,
        id: 'p-empty',
      ),
    );
  }
}
