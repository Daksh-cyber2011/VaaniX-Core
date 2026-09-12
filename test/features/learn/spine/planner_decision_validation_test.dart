/// Learn Mode 2.0 — Planner decision validation tests (M1 spine).
///
/// Pins the Master Brief §14 security boundary: a planner decision may
/// drive navigation ONLY when the concept exists, the language matches,
/// the activity type is supported, the difficulty is in range, and the
/// content source is available. Everything else is rejected with the
/// right reason — never crashes, never navigates.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

const _kinds = <ActivityKind>{
  ActivityKind.newLearning,
  ActivityKind.practice,
  ActivityKind.review,
  ActivityKind.weakRepair,
  ActivityKind.masteryCheck,
  ActivityKind.challenge,
};

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'ch_1',
          title: 'Chapter 1',
          lessons: [
            Lesson(id: 'hi_ls_1', title: 'one', chapterId: 'ch_1'),
            Lesson(id: 'hi_ls_2', title: 'two', chapterId: 'ch_1'),
          ],
        ),
      ],
    );

PlannerDecision _decision({
  String concept = 'hi_ls_1',
  int difficulty = 2,
  ActivityKind kind = ActivityKind.newLearning,
  String language = 'hi',
  String? lessonId,
  String reason = 'Learner lacks greeting vocabulary',
}) {
  return PlannerDecision(
    nextConceptId: concept,
    difficulty: difficulty,
    activityType: kind,
    reason: reason,
    languageCode: language,
    lessonId: lessonId,
  );
}

void main() {
  final graph = _graph();

  test('a fully grounded decision validates to null (allowed)', () {
    expect(
      PlannerDecisionValidator.validate(
        decision: _decision(),
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      isNull,
    );
  });

  test('unknown concept is rejected', () {
    expect(
      PlannerDecisionValidator.validate(
        decision: _decision(concept: 'bn_ls_1'),
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      PlannerRejection.unknownConcept,
    );
  });

  test('wrong language is rejected (no cross-language leak)', () {
    expect(
      PlannerDecisionValidator.validate(
        decision: _decision(language: 'bn'),
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      PlannerRejection.languageMismatch,
    );
  });

  test('unsupported activity type is rejected', () {
    expect(
      PlannerDecisionValidator.validate(
        decision: _decision(kind: ActivityKind.challenge),
        graph: graph,
        supportedActivityTypes: {ActivityKind.newLearning},
      ),
      PlannerRejection.unsupportedActivity,
    );
  });

  test('difficulty outside 1..5 is rejected', () {
    for (final bad in [0, -1, 6, 99]) {
      expect(
        PlannerDecisionValidator.validate(
          decision: _decision(difficulty: bad),
          graph: graph,
          supportedActivityTypes: _kinds,
        ),
        PlannerRejection.invalidDifficulty,
        reason: 'difficulty $bad must be rejected',
      );
    }
  });

  test('lesson hint pointing at foreign content is rejected', () {
    expect(
      PlannerDecisionValidator.validate(
        decision: _decision(lessonId: 'bn_ls_1'),
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      PlannerRejection.unavailableContent,
    );
  });

  test('malformed raw JSON degrades to malformedOutput, never throws', () {
    final decision = PlannerDecision.fromRawJson({
      'nextConcept': '',
      'difficulty': 'not-a-number',
      'activityType': 'does-not-exist',
      // reason missing, language missing
    });
    expect(
      PlannerDecisionValidator.validate(
        decision: decision,
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      anyOf(
        PlannerRejection.malformedOutput,
        PlannerRejection.invalidDifficulty,
      ),
    );
  });

  test('raw JSON with a valid decision shape parses and validates', () {
    final decision = PlannerDecision.fromRawJson({
      'nextConcept': 'hi_ls_2',
      'difficulty': 3,
      'activityType': 'review',
      'reason': 'Learner saw this yesterday',
      'language': 'hi',
    });
    expect(decision.activityType, ActivityKind.review);
    expect(
      PlannerDecisionValidator.validate(
        decision: decision,
        graph: graph,
        supportedActivityTypes: _kinds,
      ),
      isNull,
    );
  });
}
