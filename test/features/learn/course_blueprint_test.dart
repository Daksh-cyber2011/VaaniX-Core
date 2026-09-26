/// Unit tests for the AI Course Blueprint Contract (M7).
///
/// Tests the CourseBlueprintParser grounding invariants:
///   - valid AI output → Right(PersonalizedCourse)
///   - unknown conceptId → filtered (not crashed)
///   - too many units → capped at kMaxUnits
///   - empty AI output → Left(Failure)
///   - invalid JSON → Left(Failure)
///
/// Tests the deterministic fallback builder:
///   - builds a course for every non-empty skill in the graph
///   - assigns correct activity types based on mastery evidence
///   - correct PlanSource (deterministic)
///
/// Pure Dart tests — no Flutter, no network, no Riverpod.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/course_blueprint.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/data/course_blueprint_generator.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────

ConceptGraph _singleSkillGraph() {
  return ConceptGraph.forCurriculum(
    languageCode: 'hi',
    chapters: [
      Chapter(
        id: 'hi_ch1',
        title: 'Basics',
        subtitle: 'Core Hindi basics',
        order: 1,
        lessons: [
          Lesson(
            id: 'hi_01',
            title: 'Greetings',
            subtitle: 'Common greetings',
            content: '',
            difficulty: Difficulty.beginner,
            order: 1,
            chapterId: 'hi_ch1',
          ),
          Lesson(
            id: 'hi_02',
            title: 'Numbers',
            subtitle: 'Numbers 1-10',
            content: '',
            difficulty: Difficulty.beginner,
            order: 2,
            chapterId: 'hi_ch1',
          ),
        ],
      ),
      Chapter(
        id: 'hi_ch2',
        title: 'Phrases',
        subtitle: null,
        order: 2,
        lessons: [
          Lesson(
            id: 'hi_03',
            title: 'Daily Phrases',
            subtitle: null,
            content: '',
            difficulty: Difficulty.beginner,
            order: 1,
            chapterId: 'hi_ch2',
          ),
        ],
      ),
    ],
  );
}

PlannerContext _contextFor(ConceptGraph graph, {LearningState? state}) {
  return PlannerContext(
    languageCode: 'hi',
    languageName: 'Hindi',
    graph: graph,
    state: state ??
        const LearningState(
          languageCode: 'hi',
        ),
    supportedActivityTypes: const {
      ActivityKind.newLearning,
      ActivityKind.review,
      ActivityKind.practice,
      ActivityKind.weakRepair,
      ActivityKind.masteryCheck,
    },
    minutesAvailable: 10,
  );
}

String _validBlueprintJson(ConceptGraph graph) {
  final concepts = graph.concepts;
  return jsonEncode({
    'units': [
      {
        'id': 'unit_1',
        'title': 'Basics',
        'objective': 'Learn the basics',
        'lessons': [
          {
            'conceptId': concepts[0].id,
            'title': concepts[0].title,
            'objective': 'Learn greetings',
            'estimatedMinutes': 5,
            'activityType': 'newLearning',
          },
          {
            'conceptId': concepts[1].id,
            'title': concepts[1].title,
            'objective': 'Learn numbers',
            'estimatedMinutes': 8,
            'activityType': 'newLearning',
          },
        ],
      },
      {
        'id': 'unit_2',
        'title': 'Phrases',
        'objective': 'Common daily phrases',
        'lessons': [
          {
            'conceptId': concepts[2].id,
            'title': concepts[2].title,
            'objective': 'Use daily phrases',
            'estimatedMinutes': 7,
            'activityType': 'practice',
          },
        ],
      },
    ],
  });
}

// ── CourseBlueprintParser tests ───────────────────────────────────────────

void main() {
  group('CourseBlueprintParser', () {
    late ConceptGraph graph;
    late PlannerContext context;

    setUp(() {
      graph = _singleSkillGraph();
      context = _contextFor(graph);
    });

    test('parses valid AI output into a PersonalizedCourse', () {
      final json = _validBlueprintJson(graph);
      final result = CourseBlueprintParser.parse(
        json,
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_1',
      );

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('Expected Right'), (course) {
        expect(course.id, 'test_course_1');
        expect(course.languageCode, 'hi');
        expect(course.source, PlanSource.ai);
        expect(course.units.length, 2);
        expect(course.lessonCount, 3);
        expect(course.isEmpty, isFalse);
      });
    });

    test('filters unknown conceptIds from AI output', () {
      final badJson = jsonEncode({
        'units': [
          {
            'id': 'unit_1',
            'title': 'Basics',
            'objective': 'Learn the basics',
            'lessons': [
              {
                'conceptId': 'hi_01', // real
                'title': 'Greetings',
                'objective': 'Learn greetings',
                'estimatedMinutes': 5,
                'activityType': 'newLearning',
              },
              {
                'conceptId': 'FAKE_CONCEPT_HALLUCINATED', // filtered
                'title': 'Hallucinated',
                'objective': 'Fake content',
                'estimatedMinutes': 5,
                'activityType': 'newLearning',
              },
            ],
          },
        ],
      });

      final result = CourseBlueprintParser.parse(
        badJson,
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_2',
      );

      result.fold((_) => fail('Expected Right'), (course) {
        expect(course.units.length, 1);
        expect(course.units[0].lessons.length, 1);
        expect(course.units[0].lessons[0].conceptId, 'hi_01');
      });
    });

    test('returns Left on empty JSON string', () {
      final result = CourseBlueprintParser.parse(
        '',
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_3',
      );
      expect(result.isLeft(), isTrue);
    });

    test('returns Left on invalid JSON', () {
      final result = CourseBlueprintParser.parse(
        'this is not json {{{',
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_4',
      );
      expect(result.isLeft(), isTrue);
    });

    test('returns Left on JSON with no units', () {
      final result = CourseBlueprintParser.parse(
        jsonEncode({'units': []}),
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_5',
      );
      expect(result.isLeft(), isTrue);
    });

    test('returns Left when exceeding kMaxUnits', () {
      final units = List.generate(CourseBlueprintParser.kMaxUnits + 5, (i) => {
            'id': 'unit_$i',
            'title': 'Unit $i',
            'objective': 'Objective $i',
            'lessons': [
              {
                'conceptId': 'hi_01',
                'title': 'Greetings',
                'objective': 'Learn greetings',
                'estimatedMinutes': 5,
                'activityType': 'newLearning',
              },
            ],
          });

      final result = CourseBlueprintParser.parse(
        jsonEncode({'units': units}),
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_6',
      );

      // Parser rejects courses exceeding the max unit count
      expect(result.isLeft(), isTrue);
    });

    test('caps lessons per unit at kMaxLessonsPerUnit via lesson count', () {
      // The graph has 3 concepts; generate 3 lessons (all valid, distinct)
      // and verify they all survive (fewer than cap).
      final concepts = graph.concepts;
      final lessons = concepts
          .map((c) => {
                'conceptId': c.id,
                'title': c.title,
                'objective': 'Learn ${c.title}',
                'estimatedMinutes': 5,
                'activityType': 'newLearning',
              })
          .toList();

      final result = CourseBlueprintParser.parse(
        jsonEncode({
          'units': [
            {
              'id': 'unit_1',
              'title': 'All Concepts',
              'objective': 'Objective',
              'lessons': lessons,
            },
          ],
        }),
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_7',
      );

      result.fold((_) => fail('Expected Right'), (course) {
        for (final unit in course.units) {
          expect(
            unit.lessons.length,
            lessThanOrEqualTo(CourseBlueprintParser.kMaxLessonsPerUnit),
          );
          // All 3 valid unique lessons should survive
          expect(unit.lessons.length, concepts.length);
        }
      });
    });

    test('filters duplicate conceptIds within a unit', () {
      // Same conceptId repeated → only first survives (stable id dedup)
      final conceptId = graph.concepts[0].id;
      final result = CourseBlueprintParser.parse(
        jsonEncode({
          'units': [
            {
              'id': 'unit_1',
              'title': 'Basics',
              'objective': 'Objective',
              'lessons': [
                {
                  'conceptId': conceptId,
                  'title': 'L1',
                  'objective': 'Obj',
                  'estimatedMinutes': 5,
                  'activityType': 'newLearning',
                },
                {
                  'conceptId': conceptId, // duplicate
                  'title': 'L1 dup',
                  'objective': 'Obj',
                  'estimatedMinutes': 5,
                  'activityType': 'newLearning',
                },
              ],
            },
          ],
        }),
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_7b',
      );

      result.fold((_) => fail('Expected Right'), (course) {
        expect(course.units[0].lessons.length, 1); // duplicate filtered
      });
    });

    test('clamps estimatedMinutes to [1, 60]', () {
      final json = jsonEncode({
        'units': [
          {
            'id': 'unit_1',
            'title': 'Test',
            'objective': 'Test',
            'lessons': [
              {
                'conceptId': 'hi_01',
                'title': 'Greetings',
                'objective': 'Learn greetings',
                'estimatedMinutes': 9999,
                'activityType': 'newLearning',
              },
            ],
          },
        ],
      });

      final result = CourseBlueprintParser.parse(
        json,
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'test_course_8',
      );
      result.fold((_) => fail('Expected Right'), (course) {
        final lesson = course.units[0].lessons[0];
        expect(lesson.estimatedMinutes, lessThanOrEqualTo(60));
        expect(lesson.estimatedMinutes, greaterThanOrEqualTo(1));
      });
    });
  });

  // ── PersonalizedCourse model tests ──────────────────────────────────────

  group('PersonalizedCourse', () {
    test('isAiGenerated true when source is ai', () {
      final course = PersonalizedCourse(
        id: 'c1',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime.now(),
        contextKey: 'ctx',
        units: const [],
      );
      expect(course.isAiGenerated, isTrue);
    });

    test('isAiGenerated false when source is deterministic', () {
      final course = PersonalizedCourse(
        id: 'c1',
        languageCode: 'hi',
        source: PlanSource.deterministic,
        generatedAt: DateTime.now(),
        contextKey: 'ctx',
        units: const [],
      );
      expect(course.isAiGenerated, isFalse);
    });

    test('cachedLessonCount counts contentCached=true lessons', () {
      final course = PersonalizedCourse(
        id: 'c1',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime.now(),
        contextKey: 'ctx',
        units: [
          PersonalizedUnit(
            id: 'u1',
            title: 'Unit 1',
            objective: 'Obj',
            order: 0,
            lessons: [
              const PersonalizedLesson(
                id: 'l1',
                conceptId: 'hi_01',
                title: 'L1',
                objective: 'Obj',
                order: 0,
                contentCached: true,
              ),
              const PersonalizedLesson(
                id: 'l2',
                conceptId: 'hi_02',
                title: 'L2',
                objective: 'Obj',
                order: 1,
                contentCached: false,
              ),
            ],
          ),
        ],
      );
      expect(course.cachedLessonCount, 1);
      expect(course.lessonCount, 2);
    });

    test('toJson / fromJson round-trips correctly', () {
      final course = PersonalizedCourse(
        id: 'c1',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime(2025, 9, 26, 10, 0),
        contextKey: 'key123',
        diagnosticVersion: '2025-01-01T00:00:00.000Z',
        curriculumRevision: '4',
        units: [
          PersonalizedUnit(
            id: 'u1',
            title: 'Basics',
            objective: 'Core basics',
            order: 0,
            lessons: [
              const PersonalizedLesson(
                id: 'l1',
                conceptId: 'hi_01',
                title: 'Greetings',
                objective: 'Learn greetings',
                order: 0,
                lessonId: 'hi_01',
                estimatedMinutes: 5,
                activityType: 'newLearning',
                contentCached: false,
              ),
            ],
          ),
        ],
      );

      final json = course.toJson();
      final restored = PersonalizedCourse.fromJson(json);

      expect(restored.id, course.id);
      expect(restored.languageCode, course.languageCode);
      expect(restored.source, course.source);
      expect(restored.contextKey, course.contextKey);
      expect(restored.units.length, 1);
      expect(restored.units[0].lessons.length, 1);
      expect(restored.units[0].lessons[0].activityType, 'newLearning');
      expect(restored.units[0].lessons[0].contentCached, isFalse);
    });
  });

  // ── Deterministic fallback builder tests ─────────────────────────────────

  group('buildDeterministicCourse', () {
    test('builds one unit per non-empty skill', () {
      final graph = _singleSkillGraph();
      final context = _contextFor(graph);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_1',
      );

      expect(course.source, PlanSource.deterministic);
      expect(course.units.length, 2);
      expect(course.units[0].lessons.length, 2);
      expect(course.units[1].lessons.length, 1);
    });

    test('assigns newLearning to concepts with no mastery', () {
      final graph = _singleSkillGraph();
      final context = _contextFor(graph);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_2',
      );

      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          expect(lesson.activityType, 'newLearning');
        }
      }
    });

    test('assigns review to mastered concepts', () {
      final graph = _singleSkillGraph();
      final state = LearningState(
        languageCode: 'hi',
        conceptMasteries: {
          'hi_01': ConceptMastery(
            conceptId: 'hi_01',
            stage: MasteryStage.maintained,
            lastPracticedAt: DateTime.now(),
          ),
        },
      );
      final context = _contextFor(graph, state: state);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_3',
      );

      final hi01Lesson = course.units
          .expand((u) => u.lessons)
          .firstWhere((l) => l.conceptId == 'hi_01');
      expect(hi01Lesson.activityType, 'review');
    });

    test('assigns weakRepair to low-stage concepts', () {
      final graph = _singleSkillGraph();
      final state = LearningState(
        languageCode: 'hi',
        conceptMasteries: {
          'hi_02': ConceptMastery(
            conceptId: 'hi_02',
            stage: MasteryStage.introduced,
            lastPracticedAt: DateTime.now(),
          ),
        },
      );
      final context = _contextFor(graph, state: state);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_4',
      );

      final hi02Lesson = course.units
          .expand((u) => u.lessons)
          .firstWhere((l) => l.conceptId == 'hi_02');
      expect(hi02Lesson.activityType, 'weakRepair');
    });

    test('lessonId matches the trusted lesson anchor', () {
      final graph = _singleSkillGraph();
      final context = _contextFor(graph);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_5',
      );

      for (final unit in course.units) {
        for (final lesson in unit.lessons) {
          expect(lesson.lessonId, lesson.conceptId);
        }
      }
    });

    test('empty graph produces empty course', () {
      final emptyGraph = ConceptGraph.forCurriculum(
        languageCode: 'kn',
        chapters: [],
      );
      final context = _contextFor(emptyGraph);
      final course = buildDeterministicCourse(
        context: context,
        courseContextKey: context.plannerContextKey,
        courseId: 'det_empty',
      );

      expect(course.isEmpty, isTrue);
      expect(course.units, isEmpty);
    });
  });

  // ── Prompt assembly smoke tests ──────────────────────────────────────────

  group('Blueprint prompt assembly', () {
    test('system prompt is non-empty and contains key rules', () {
      final prompt = buildCourseBlueprintSystemPrompt();
      expect(prompt, isNotEmpty);
      expect(prompt, contains('conceptId'));
      expect(prompt, contains('JSON'));
    });

    test('user prompt contains language code and concept list', () {
      final graph = _singleSkillGraph();
      final context = _contextFor(graph);
      final request = CourseBlueprintRequest(
        context: context,
        courseContextKey: context.plannerContextKey,
      );
      final prompt = buildCourseBlueprintUserPrompt(request);

      expect(prompt, contains('hi'));
      expect(prompt, contains('hi_01'));
      expect(prompt, contains('hi_02'));
    });
  });
}
