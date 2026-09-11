/// Learn Mode 2.0 — AI Planner Output Parser tests (M4, Master Brief §14).
///
/// Pins the untrusted-output boundary: every §14 rule (concept exists,
/// language matches, activity type supported, difficulty valid, content
/// source available) drops invalid AI steps; the full-plan AND the
/// single-decision shapes parse; nothing invalid ever survives as a
/// "fixed" step; and an all-invalid plan is a Left that lets the chain
/// fall back — never a crash, never an empty-screen surprise.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_output.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

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

const String _goodPlanJson = '''
{
  "focusSummary": "Repair greetings, then learn family words.",
  "activities": [
    {"conceptId": "hi_ls_1", "activityType": "weakRepair", "difficulty": 2,
     "reason": "Greetings slipped last time - one quick repair.", "estimatedMinutes": 4},
    {"conceptId": "hi_ls_2", "activityType": "newLearning", "difficulty": 2,
     "reason": "Family words are next on your path.", "estimatedMinutes": 6}
  ]
}
''';

LearningPlan _parseOk(String raw, {PlannerContext? context}) {
  final result = AiPlanParser.parse(raw, context ?? _context());
  return result.fold(
    (f) => throw StateError('expected Right, got: ${f.message}'),
    (plan) => plan,
  );
}

Failure _parseFail(String raw, {PlannerContext? context}) {
  final result = AiPlanParser.parse(raw, context ?? _context());
  return result.fold((f) => f, (p) => throw StateError('expected Left'));
}

void main() {
  group('happy paths', () {
    test('a full valid plan parses with grounded activities', () {
      final plan = _parseOk(_goodPlanJson);
      expect(plan.source, PlanSource.ai);
      expect(plan.languageCode, 'hi');
      expect(plan.id, startsWith('plan-ai-'));
      expect(plan.activities, hasLength(2));

      expect(plan.activities.first.kind, ActivityKind.weakRepair);
      expect(plan.activities.first.conceptId, 'hi_ls_1');
      expect(plan.activities.first.lessonId, 'hi_ls_1');
      expect(plan.activities.first.difficulty, Difficulty.beginner);
      expect(plan.activities.first.estimatedMinutes, 4);

      expect(plan.activities.last.kind, ActivityKind.newLearning);
      expect(plan.activities.last.difficulty, Difficulty.beginner);
    });

    test('the Master Brief §14 single-decision shape parses to one step',
        () {
      const raw = '''
{"nextConcept": "hi_ls_1", "difficulty": 1, "activityType": "practice",
 "reason": "Learner lacks greeting vocabulary", "language": "hi"}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(1));
      expect(plan.activities.single.kind, ActivityKind.practice);
      expect(plan.activities.single.conceptId, 'hi_ls_1');
    });

    test('fences and surrounding prose are tolerated', () {
      const raw = 'Here you go:\n```json\n$_goodPlanJson\n```\nDone!';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(2));
    });

    test('AI-supplied titles win; fallback titles are kind-labelled',
        () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "review", "difficulty": 1,
   "reason": "keep it fresh", "title": "Namaste again"},
  {"conceptId": "hi_ls_2", "activityType": "practice", "difficulty": 2,
   "reason": "one more round"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities.first.title, 'Namaste again');
      expect(plan.activities.last.title, 'Practice: Family');
    });

    test('difficulty knob maps onto the app difficulty bands', () {
      expect(AiPlanParser.difficultyFromKnob(1), Difficulty.beginner);
      expect(AiPlanParser.difficultyFromKnob(2), Difficulty.beginner);
      expect(AiPlanParser.difficultyFromKnob(3), Difficulty.intermediate);
      expect(AiPlanParser.difficultyFromKnob(4), Difficulty.advanced);
      expect(AiPlanParser.difficultyFromKnob(5), Difficulty.advanced);
    });

    test('a missing focusSummary gets an honest default line', () {
      const raw = '''
{"activities": [{"conceptId": "hi_ls_1", "activityType": "practice",
  "difficulty": 1, "reason": "keep greetings fresh"}]}
''';
      final plan = _parseOk(raw);
      expect(plan.focusSummary, contains('Hindi'));
    });

    test('estimatedMinutes are clamped to a sane range', () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "warm up", "estimatedMinutes": 500},
  {"conceptId": "hi_ls_2", "activityType": "review", "difficulty": 1,
   "reason": "cool down", "estimatedMinutes": 0}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities.first.estimatedMinutes, 30);
      expect(plan.activities.last.estimatedMinutes, 5);
    });
  });

  group('§14 validation drops', () {
    test('unknown concepts are dropped', () {
      const raw = '''
{"activities": [
  {"conceptId": "zz_fake_concept", "activityType": "practice",
   "difficulty": 1, "reason": "invented"},
  {"conceptId": "hi_ls_1", "activityType": "practice",
   "difficulty": 1, "reason": "real"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(1));
      expect(plan.activities.single.conceptId, 'hi_ls_1');
    });

    test('the brief\'s own example activityType "lesson" is unsupported',
        () {
      // Master Brief §14 example uses "lesson" — not a kind this build
      // can execute, so it must never drive navigation.
      const raw = '''
{"nextConcept": "kn_basic_greetings", "difficulty": 1,
 "activityType": "lesson", "reason": "Learner lacks greeting vocabulary"}
''';
      expect(_parseFail(raw), isA<AiServiceFailure>());
    });

    test('out-of-range difficulty is dropped', () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 0,
   "reason": "too easy to be valid"},
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 9,
   "reason": "too hard to be valid"},
  {"conceptId": "hi_ls_2", "activityType": "practice", "difficulty": 3,
   "reason": "valid middle"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(1));
      expect(plan.activities.single.conceptId, 'hi_ls_2');
    });

    test('a lesson hint that is not the concept\'s trusted anchor is dropped',
        () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "wrong anchor", "lessonId": "hi_ls_2"},
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "right anchor", "lessonId": "hi_ls_1"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(1));
      expect(plan.activities.single.reason, 'right anchor');
    });

    test('steps without a reason are dropped (the learner reads reasons)',
        () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "   "},
  {"conceptId": "hi_ls_2", "activityType": "practice", "difficulty": 1,
   "reason": "valid"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(1));
    });

    test('duplicate concept+kind steps are deduplicated (first wins)',
        () {
      const raw = '''
{"activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "first"},
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 2,
   "reason": "second"},
  {"conceptId": "hi_ls_1", "activityType": "review", "difficulty": 1,
   "reason": "same concept, different kind is allowed"}
]}
''';
      final plan = _parseOk(raw);
      expect(plan.activities, hasLength(2));
      expect(plan.activities.first.reason, 'first');
      expect(plan.activities.last.kind, ActivityKind.review);
    });

    test('a plan claiming ANOTHER language is rejected whole', () {
      const raw = '''
{"language": "bn", "activities": [
  {"conceptId": "hi_ls_1", "activityType": "practice", "difficulty": 1,
   "reason": "grounded but wrong-language plan"}
]}
''';
      final failure = _parseFail(raw);
      expect(failure.message, contains('bn'));
    });

    test('no decodable JSON is a Left, never a crash', () {
      expect(_parseFail('I cannot help with that.'),
          isA<AiServiceFailure>());
      expect(_parseFail('{"activities": [broken'),
          isA<AiServiceFailure>());
    });

    test('an empty activity list is a Left (chain falls back)', () {
      expect(_parseFail('{"activities": []}'), isA<AiServiceFailure>());
    });

    test('ALL-invalid activities leave nothing grounded → Left', () {
      const raw = '''
{"activities": [
  {"conceptId": "zz_fake", "activityType": "practice", "difficulty": 1,
   "reason": "invented"},
  {"conceptId": "hi_ls_1", "activityType": "lesson", "difficulty": 1,
   "reason": "unsupported kind"}
]}
''';
      expect(_parseFail(raw), isA<AiServiceFailure>());
    });

    test('plans are capped at kMaxActivities', () {
      const kinds = [
        ActivityKind.practice,
        ActivityKind.review,
        ActivityKind.weakRepair,
        ActivityKind.masteryCheck,
        ActivityKind.newLearning,
      ];
      final buffer = StringBuffer('{"activities": [');
      for (var i = 0; i < 12; i++) {
        final concept = i.isEven ? 'hi_ls_1' : 'hi_ls_2';
        final kind = kinds[i % kinds.length].name;
        buffer.write(
          '{"conceptId": "$concept", "activityType": "$kind", '
          '"difficulty": 1, "reason": "step $i"}${i == 11 ? '' : ','}',
        );
      }
      buffer.write(']}');
      final plan = _parseOk(buffer.toString());
      // 12 raw steps -> 10 unique (concept, kind) pairs -> capped to 8.
      expect(plan.activities.length, AiPlanParser.kMaxActivities);
    });
  });
}
