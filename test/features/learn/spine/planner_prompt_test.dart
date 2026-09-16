/// Learn Mode 2.0 — Planner Prompt Assembly tests (M4, Master Brief §62).
///
/// Pins the STRUCTURED PROMPT contract: system prompt carries the JSON
/// output schema + grounding rules + only the supported activity types;
/// the user prompt separates LANGUAGE KNOWLEDGE / LEARNER STATE / TASK;
/// the concept menu is the trusted graph and nothing else; and the JSON
/// extractor survives the usual model wrapper failure modes without
/// trusting them.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';
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
            Lesson(id: 'hi_ls_3', title: 'Numbers', chapterId: 'hi_ch1'),
          ],
        ),
      ],
    );

PlannerContext _context({
  ConceptGraph? graph,
  LearningState? state,
  LearnerProfile? profile,
  int minutes = 15,
  Set<ActivityKind>? kinds,
}) {
  final g = graph ?? _graph();
  return PlannerContext(
    languageCode: g.languageCode,
    languageName: 'Hindi',
    graph: g,
    state: state ?? LearningState(languageCode: g.languageCode),
    profile: profile,
    minutesAvailable: minutes,
    recentMistakeTitles: const ['Greetings'],
    supportedActivityTypes: kinds ?? kDeterministicPlannerActivityKinds,
  );
}

void main() {
  group('buildPlannerSystemPrompt (§62 system + output schema)', () {
    test('demands a single JSON object with the exact schema keys', () {
      final prompt = buildPlannerSystemPrompt(
        supportedActivityTypes: kDeterministicPlannerActivityKinds,
      );
      expect(prompt, contains('ONLY a single JSON object'));
      expect(prompt, contains('"focusSummary"'));
      expect(prompt, contains('"activities"'));
      expect(prompt, contains('"conceptId"'));
      expect(prompt, contains('"activityType"'));
      expect(prompt, contains('"difficulty"'));
      expect(prompt, contains('"reason"'));
      expect(prompt, contains('"estimatedMinutes"'));
    });

    test('pins the grounding rules that mirror §14 validation', () {
      final prompt = buildPlannerSystemPrompt(
        supportedActivityTypes: kDeterministicPlannerActivityKinds,
      );
      expect(
          prompt, contains('ONLY conceptIds that appear in the concept menu'));
      expect(prompt, contains('Never mix languages'));
      expect(prompt, contains('1..5'));
    });

    test('advertises only activity kinds this build supports', () {
      final prompt = buildPlannerSystemPrompt(
        supportedActivityTypes: const {
          ActivityKind.newLearning,
          ActivityKind.practice,
        },
      );
      expect(prompt, contains('"newLearning"'));
      expect(prompt, contains('"practice"'));
      expect(prompt, isNot(contains('"weakRepair"')));
      expect(prompt, isNot(contains('"challenge"')));
    });

    test('includes the activity bound and the no-jargon tone rules', () {
      final prompt = buildPlannerSystemPrompt(
        supportedActivityTypes: kDeterministicPlannerActivityKinds,
        maxActivities: 6,
      );
      expect(prompt, contains('at most 6 activities'));
      expect(prompt, contains('no linguistic jargon'));
    });
  });

  group('buildPlannerUserPrompt (§62 three sections)', () {
    test('separates language knowledge, learner state, and task', () {
      final prompt = buildPlannerUserPrompt(_context());
      expect(prompt, contains('=== LANGUAGE KNOWLEDGE ==='));
      expect(prompt, contains('=== LEARNER STATE ==='));
      expect(prompt, contains('=== TASK ==='));
    });

    test('names the language exactly once in the knowledge section', () {
      final prompt = buildPlannerUserPrompt(_context());
      expect(prompt, contains('Language: Hindi (code: hi).'));
    });

    test('concept menu lists every trusted concept with its status', () {
      final state = LearningState(
        languageCode: 'hi',
        conceptMasteries: {
          'hi_ls_1': const ConceptMastery(
            conceptId: 'hi_ls_1',
            stage: MasteryStage.understood,
          ),
        },
      );
      final prompt = buildPlannerUserPrompt(_context(state: state));

      expect(prompt, contains('- hi_ls_1 | Greetings'));
      expect(prompt, contains('- hi_ls_2 | Family'));
      expect(prompt, contains('- hi_ls_3 | Numbers'));
      expect(prompt, contains('status: understood'));
      expect(prompt, contains('status: not-started'));
      // The menu never leaks concepts the graph does not have.
      expect(prompt, isNot(contains('bn_ls_')));
    });

    test('embeds the structured learner-state digest as JSON', () {
      final profile = LearnerProfile.initial(LearnLanguage.hindi)
          .copyWith(goal: LearningGoal.conversation, dailyGoalMinutes: 20);
      final prompt = buildPlannerUserPrompt(
        _context(profile: profile, minutes: 20),
      );
      expect(prompt, contains('"goal": "conversation"'));
      expect(prompt, contains('"minutesAvailable": 20'));
      expect(prompt, contains('"recentMistakes"'));
      expect(prompt, contains('Greetings'));
    });

    test('task states the session budget in minutes', () {
      final prompt = buildPlannerUserPrompt(_context(minutes: 25));
      expect(prompt, contains('no more than 25 minutes'));
    });

    test('empty graph renders an explicit empty menu (stub languages)', () {
      final emptyGraph = ConceptGraph.forCurriculum(
        languageCode: 'kn',
        chapters: const [],
      );
      final prompt = buildPlannerUserPrompt(_context(graph: emptyGraph));
      expect(prompt, contains('(empty — this language has no curriculum yet)'));
    });
  });

  group('extractPlanJson', () {
    test('decodes a bare JSON object', () {
      final json = extractPlanJson('{"activities": []}');
      expect(json, isNotNull);
      expect(json!['activities'], isEmpty);
    });

    test('decodes JSON inside markdown fences with surrounding prose', () {
      const raw = '''
Here is your plan:

```json
{"focusSummary": "hi", "activities": []}
```

Hope this helps!
''';
      final json = extractPlanJson(raw);
      expect(json, isNotNull);
      expect(json!['focusSummary'], 'hi');
    });

    test('decodes JSON embedded in prose without fences', () {
      final json = extractPlanJson('Sure! {"activities": [{"a": 1}]} — enjoy!');
      expect(json, isNotNull);
      expect(json!['activities'], hasLength(1));
    });

    test('braces inside string values never break the scan', () {
      const raw = '{"focusSummary": "use { and } freely", "activities": []}';
      final json = extractPlanJson('noise $raw noise');
      expect(json, isNotNull);
      expect(json!['focusSummary'], 'use { and } freely');
    });

    test('malformed JSON returns null (never throws)', () {
      expect(extractPlanJson('{"activities": ['), isNull);
      expect(extractPlanJson('no json at all'), isNull);
      expect(extractPlanJson(''), isNull);
    });

    test('a top-level JSON array is not a plan', () {
      expect(extractPlanJson('[{"activities": []}]'), isNull);
    });
  });
}
