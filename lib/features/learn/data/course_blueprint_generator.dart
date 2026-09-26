/// VaaniX Learn Mode — AI Course Blueprint Generator (M7)
///
/// The Gemini-backed course blueprint generator. Uses the SAME
/// [PlannerTextClient] as the session planner — no new AI SDK, one
/// shared rate-limit budget.
///
/// Flow:
///   CourseBlueprintRequest
///     → structured prompt (course_blueprint.dart)
///     → [PlannerTextClient] (the ONLY network hop)
///     → CourseBlueprintParser (untrusted text → validated course)
///     → write-through course persistence
///     → Right(PersonalizedCourse) — or Left(Failure), NEVER a throw
///
/// The generator never throws for expected failure modes. Every failure
/// becomes a Left, and the provider falls back to the deterministic
/// course builder.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/personalized_course_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/course_blueprint.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';

class CourseBlueprintGenerator {
  CourseBlueprintGenerator({
    required PlannerTextClient textClient,
    PersonalizedCourseRepository? courseRepository,
  })  : _textClient = textClient,
        _courseRepository = courseRepository;

  final PlannerTextClient _textClient;
  final PersonalizedCourseRepository? _courseRepository;

  /// Hard ceiling for one blueprint request. Blueprints are larger than
  /// session plans so we allow more time, but the fallback chain must
  /// still feel responsive.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Generates a personalized course blueprint from AI.
  ///
  /// Returns `Left(Failure)` when AI is unavailable, times out, or
  /// produces invalid output. The caller falls back to the deterministic
  /// course builder.
  Future<Either<Failure, PersonalizedCourse>> generateBlueprint(
    CourseBlueprintRequest request,
  ) {
    return _guard(() async {
      if (!_textClient.isAvailable) {
        return Left(const AiServiceFailure(
          'AI course blueprint generation is not available',
        ));
      }

      final courseId =
          'course_${request.context.languageCode}_'
          '${DateTime.now().millisecondsSinceEpoch}';

      final raw = await _textClient
          .complete(
            system: buildCourseBlueprintSystemPrompt(),
            user: buildCourseBlueprintUserPrompt(request),
          )
          .timeout(requestTimeout);

      final result = CourseBlueprintParser.parse(
        raw,
        context: request.context,
        courseId: courseId,
        courseContextKey: request.courseContextKey,
      );

      return result.fold(
        (failure) => Left(failure),
        (course) async {
          // Write-through persistence: the next launch serves this course
          // offline. Storage failure must never fail a good blueprint.
          try {
            await _courseRepository?.saveCourse(course);
          } catch (_) {
            // Cache write is best-effort.
          }
          return Right(course);
        },
      );
    });
  }

  /// Contract guard: nothing escapes as a throw.
  Future<Either<Failure, PersonalizedCourse>> _guard(
    Future<Either<Failure, PersonalizedCourse>> Function() body,
  ) async {
    try {
      return await body();
    } on TimeoutException {
      return Left(const TimeoutFailure());
    } catch (e) {
      return Left(AiServiceFailure(
        'Could not generate your personalized course just now. '
        'Your existing learning path is still available.',
      ));
    }
  }
}

/// Builds a deterministic (offline, zero-cost) course from the trusted
/// concept graph. This is the fallback when AI is unavailable.
///
/// Unlike inflating the session planner, this walks the graph in
/// curriculum order, respects prerequisites, and groups by skill/chapter.
/// The result is a legitimate learning path — just not AI-personalized.
PersonalizedCourse buildDeterministicCourse({
  required PlannerContext context,
  required String courseId,
  required String courseContextKey,
}) {
  final graph = context.graph;
  final state = context.state;
  final units = <PersonalizedUnit>[];

  for (final skill in graph.skills) {
    final concepts = graph.conceptsInSkill(skill.id);
    if (concepts.isEmpty) continue;

    final lessons = <PersonalizedLesson>[];
    for (var i = 0; i < concepts.length; i++) {
      final concept = concepts[i];

      // Determine activity type based on learner evidence
      final mastery = state.conceptMasteries[concept.id];
      String activityType;
      if (mastery == null) {
        activityType = 'newLearning';
      } else if (mastery.stage.index < 2) {
        // Below understood — needs more practice
        activityType = 'weakRepair';
      } else if (mastery.stage.index >= 5) {
        // Mastered — brief review
        activityType = 'review';
      } else {
        activityType = 'practice';
      }

      lessons.add(PersonalizedLesson(
        id: 'pl_${concept.id}_${skill.order}',
        conceptId: concept.id,
        lessonId: concept.lessonId,
        title: concept.title,
        objective: concept.subtitle ?? 'Build confidence with ${concept.title}.',
        order: i,
        activityType: activityType,
      ));
    }

    units.add(PersonalizedUnit(
      id: 'unit_${skill.id}',
      title: skill.title,
      objective:
          skill.subtitle ?? 'Grow your ${skill.title.toLowerCase()} skills.',
      order: skill.order,
      lessons: lessons,
      prerequisiteConcepts: concepts.isEmpty
          ? const []
          : [for (final concept in concepts) ...concept.prerequisites],
    ));
  }

  return PersonalizedCourse(
    id: courseId,
    languageCode: context.languageCode,
    source: PlanSource.deterministic,
    generatedAt: DateTime.now(),
    contextKey: courseContextKey,
    diagnosticVersion:
        context.diagnostic?.completedAt.toIso8601String(),
    curriculumRevision: _curriculumRevisionFor(context.languageCode),
    units: units,
  );
}

String? _curriculumRevisionFor(String languageCode) {
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.code == languageCode) {
      return spec.curriculumRevision.toString();
    }
  }
  return null;
}
