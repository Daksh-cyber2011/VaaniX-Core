/// VaaniX Learn Mode — AI Course Blueprint Contract
///
/// The structured AI boundary for COURSE-LEVEL personalization, distinct
/// from the session-level [LearningPlanner].
///
/// Session planner: "what should the learner do in today's 10-minute session?"
/// Course blueprint: "what is this learner's multi-unit, multi-lesson roadmap?"
///
/// The AI receives structured context (diagnostic, profile, mastery, graph)
/// and produces structured data (units + lessons). The output is PARSED and
/// VALIDATED before it becomes a [PersonalizedCourse].
///
/// Staged architecture:
///   1. Diagnostic + profile + mastery → AI generates COURSE BLUEPRINT
///   2. Blueprint contains the roadmap (many units, many lessons as metadata)
///   3. VaaniX materializes lesson content PROGRESSIVELY as needed
///   4. Mastery evidence changes → future adaptation requests regenerate
///      upcoming units
///
/// Pure Dart; no Flutter imports.
library;

import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';

// ── Blueprint request ─────────────────────────────────────────────────────

/// Structured context for AI course blueprint generation.
///
/// Reuses [PlannerContext] for the learner state and adds course-specific
/// fields. This avoids duplicating the learner model.
class CourseBlueprintRequest extends Equatable {
  const CourseBlueprintRequest({
    required this.context,
    required this.courseContextKey,
    this.existingCourseId,
    this.adaptationReason,
  });

  /// The stable context key derived from slow-changing inputs (language, diagnostic, profile, curriculum).
  final String courseContextKey;

  /// The full planner context (language, graph, state, profile, diagnostic).
  final PlannerContext context;

  /// When adapting an existing course, the ID of the course being adapted.
  final String? existingCourseId;

  /// Why adaptation is needed (e.g. "mastery_change", "diagnostic_retake").
  final String? adaptationReason;

  @override
  List<Object?> get props => [context, courseContextKey, existingCourseId, adaptationReason];
}

// ── Blueprint response parsing ────────────────────────────────────────────

/// Why a blueprint was rejected during validation.
enum BlueprintRejection {
  malformedJson('AI output was not valid JSON'),
  missingRequiredField('a required field is missing'),
  languageMismatch('blueprint is for a different language'),
  emptyUnits('blueprint contains no units'),
  emptyLessons('a unit contains no lessons'),
  unknownConcept('a referenced concept is not in the trusted graph'),
  invalidLessonAnchor('a lesson anchor does not match its concept'),
  duplicateLessonId('duplicate lesson identity found'),
  invalidPrerequisite('a prerequisite creates an impossible dependency'),
  emptyObjective('a unit or lesson has an empty objective'),
  invalidOrdering('lesson ordering is invalid'),
  excessiveSize('blueprint exceeds safe bounds'),
  crossLanguageContent('content references a different language');

  const BlueprintRejection(this.explanation);
  final String explanation;
}

/// Validates and parses raw AI blueprint output into a [PersonalizedCourse].
///
/// Every concept ID is checked against the trusted [ConceptGraph]. Unknown
/// concepts are rejected. The validator NEVER lets ungrounded material
/// through to navigation.
abstract final class CourseBlueprintParser {
  /// Maximum units per course blueprint (prevents runaway AI output).
  static const int kMaxUnits = 30;

  /// Maximum lessons per unit (prevents runaway AI output).
  static const int kMaxLessonsPerUnit = 20;

  /// Parses raw AI text into a validated [PersonalizedCourse].
  ///
  /// Returns `Left(Failure)` with rejection details on any validation
  /// failure. The caller falls back to the deterministic course.
  static Either<Failure, PersonalizedCourse> parse(
    String rawText, {
    required PlannerContext context,
    required String courseId,
    required String courseContextKey,
  }) {
    // ── Step 1: Extract JSON from the raw text ──
    final jsonStr = _extractJson(rawText);
    if (jsonStr == null) {
      return Left(const AiServiceFailure(
        'AI course blueprint was not valid JSON',
      ));
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        return Left(const AiServiceFailure(
          'AI course blueprint root is not an object',
        ));
      }
      json = decoded;
    } catch (_) {
      return Left(const AiServiceFailure(
        'AI course blueprint JSON parsing failed',
      ));
    }

    // ── Step 2: Validate and build the course ──
    final rejections = <BlueprintRejection>[];
    final graph = context.graph;

    // Language gate
    final language = json['language'] as String?;
    if (language != null &&
        language.isNotEmpty &&
        language != context.languageCode) {
      rejections.add(BlueprintRejection.languageMismatch);
      return Left(AiServiceFailure(
        'Blueprint language mismatch: '
        '${rejections.map((r) => r.explanation).join('; ')}',
      ));
    }

    // Parse units
    final rawUnits = json['units'];
    if (rawUnits is! List || rawUnits.isEmpty) {
      rejections.add(BlueprintRejection.emptyUnits);
      return Left(AiServiceFailure(
        'Blueprint validation failed: '
        '${rejections.map((r) => r.explanation).join('; ')}',
      ));
    }
    if (rawUnits.length > kMaxUnits) {
      rejections.add(BlueprintRejection.excessiveSize);
      return Left(AiServiceFailure(
        'Blueprint exceeds maximum unit count ($kMaxUnits)',
      ));
    }

    final seenLessonIds = <String>{};
    final units = <PersonalizedUnit>[];

    for (var unitIdx = 0; unitIdx < rawUnits.length; unitIdx++) {
      final rawUnit = rawUnits[unitIdx];
      if (rawUnit is! Map<String, dynamic>) {
        rejections.add(BlueprintRejection.malformedJson);
        continue;
      }

      final unitId = rawUnit['id'] as String? ?? 'unit_$unitIdx';
      final unitTitle = rawUnit['title'] as String? ?? '';
      final unitObjective = rawUnit['objective'] as String? ?? '';

      if (unitTitle.isEmpty || unitObjective.isEmpty) {
        rejections.add(BlueprintRejection.emptyObjective);
        continue;
      }

      final rawLessons = rawUnit['lessons'];
      if (rawLessons is! List || rawLessons.isEmpty) {
        rejections.add(BlueprintRejection.emptyLessons);
        continue;
      }
      if (rawLessons.length > kMaxLessonsPerUnit) {
        rejections.add(BlueprintRejection.excessiveSize);
        continue;
      }

      final lessons = <PersonalizedLesson>[];
      final unitPrereqs = <String>{};

      for (var lessonIdx = 0; lessonIdx < rawLessons.length; lessonIdx++) {
        // Enforce per-unit lesson cap — prevents runaway AI output
        if (lessons.length >= kMaxLessonsPerUnit) {
          rejections.add(BlueprintRejection.excessiveSize);
          break;
        }

        final rawLesson = rawLessons[lessonIdx];
        if (rawLesson is! Map<String, dynamic>) continue;

        final conceptId = rawLesson['conceptId'] as String? ?? '';

        // Ground against the trusted graph
        final concept = graph.conceptById(conceptId);
        if (concept == null) {
          rejections.add(BlueprintRejection.unknownConcept);
          continue;
        }

        // Language safety
        if (concept.languageCode != context.languageCode) {
          rejections.add(BlueprintRejection.crossLanguageContent);
          continue;
        }

        // Lesson anchor validation
        final lessonId = rawLesson['lessonId'] as String? ?? concept.lessonId;
        if (lessonId != concept.lessonId) {
          rejections.add(BlueprintRejection.invalidLessonAnchor);
          continue;
        }

        // Duplicate check
        final stableId = 'pl_${conceptId}_$unitIdx';
        if (seenLessonIds.contains(stableId)) {
          rejections.add(BlueprintRejection.duplicateLessonId);
          continue;
        }
        seenLessonIds.add(stableId);

        final title = rawLesson['title'] as String? ?? concept.title;
        final objective = rawLesson['objective'] as String? ??
            'Build confidence with $title.';
        final estimatedMinutes =
            ((rawLesson['estimatedMinutes'] as num?)?.toInt() ?? 5)
                .clamp(1, 60);
        final activityType = rawLesson['activityType'] as String?;

        lessons.add(PersonalizedLesson(
          id: stableId,
          conceptId: conceptId,
          lessonId: concept.lessonId,
          title: title,
          objective: objective,
          order: lessonIdx,
          estimatedMinutes: estimatedMinutes,
          activityType: activityType,
        ));

        // Collect prerequisites from concepts
        unitPrereqs.addAll(concept.prerequisites);
      }

      if (lessons.isEmpty) {
        rejections.add(BlueprintRejection.emptyLessons);
        continue;
      }

      units.add(PersonalizedUnit(
        id: unitId,
        title: unitTitle,
        objective: unitObjective,
        order: unitIdx,
        lessons: lessons,
        prerequisiteConcepts: unitPrereqs.toList(),
      ));
    }

    // If ALL units were rejected, fail
    if (units.isEmpty) {
      return Left(AiServiceFailure(
        'Blueprint produced no valid units: '
        '${rejections.map((r) => r.explanation).toSet().join('; ')}',
      ));
    }

    // Allow partial acceptance: some rejected lessons/units are ok if we
    // still have a meaningful course
    final course = PersonalizedCourse(
      id: courseId,
      languageCode: context.languageCode,
      source: PlanSource.ai,
      generatedAt: DateTime.now(),
      contextKey: courseContextKey,
      diagnosticVersion:
          context.diagnostic?.completedAt.toIso8601String(),
      curriculumRevision: _curriculumRevisionFor(context.languageCode),
      units: units,
    );

    return Right(course);
  }

  /// Extracts JSON from AI text that may contain markdown fences or
  /// preamble prose.
  static String? _extractJson(String text) {
    final trimmed = text.trim();

    // Try the whole thing as JSON first
    if ((trimmed.startsWith('{') || trimmed.startsWith('[')) &&
        (trimmed.endsWith('}') || trimmed.endsWith(']'))) {
      return trimmed;
    }

    // Try to find JSON inside markdown code fences
    final fencePattern = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)```');
    final match = fencePattern.firstMatch(trimmed);
    if (match != null) {
      return match.group(1)?.trim();
    }

    // Try to find the first { ... } block
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return trimmed.substring(firstBrace, lastBrace + 1);
    }

    return null;
  }

  static String? _curriculumRevisionFor(String languageCode) {
    // Look up the revision from the catalogue
    for (final spec in kLearnLanguageCatalogue) {
      if (spec.code == languageCode) {
        return spec.curriculumRevision.toString();
      }
    }
    return null;
  }
}

// ── Blueprint prompt assembly ─────────────────────────────────────────────

/// Builds the system prompt for AI course blueprint generation.
String buildCourseBlueprintSystemPrompt() {
  return '''
You are a language-learning curriculum designer for VaaniX, an Indian language learning app.

Your job is to create a PERSONALIZED course blueprint — a structured multi-unit, multi-lesson roadmap tailored to the learner's diagnostic results, profile, goals, and current mastery.

CRITICAL RULES:
1. You MUST only use concept IDs from the provided trusted concept list
2. Every conceptId must exactly match one from the list — do not invent new concepts
3. Structure the course into units (thematic groupings) and lessons (individual learning steps)
4. Order lessons so prerequisites come before dependents
5. Skip or reduce time on concepts the learner has already mastered
6. Emphasize concepts the learner is weak in or has never seen
7. Include review/remediation lessons for struggling areas
8. Each unit should have a clear learning objective
9. Each lesson should have a clear objective and an estimated duration

OUTPUT FORMAT — respond with ONLY this JSON structure, no other text:
{
  "language": "<iso-code>",
  "units": [
    {
      "id": "unit_<index>",
      "title": "<Unit Title>",
      "objective": "<What the learner achieves by completing this unit>",
      "lessons": [
        {
          "conceptId": "<exact concept ID from the trusted list>",
          "title": "<Lesson title>",
          "objective": "<What the learner can do after this lesson>",
          "estimatedMinutes": <3-15>,
          "activityType": "<newLearning|review|practice|weakRepair|masteryCheck>"
        }
      ]
    }
  ]
}

PERSONALIZATION PRIORITIES:
- Weak concepts → more practice and alternate approaches
- Mastered concepts → skip or brief review only
- Diagnostic weaknesses → targeted remediation units early
- Learner goal → weight curriculum toward their objective (conversation, reading, etc.)
- Learning pace → gentle = fewer lessons per unit, intense = more
- Review queue → concepts due for review should appear
''';
}

/// Builds the user prompt containing the learner's structured context.
String buildCourseBlueprintUserPrompt(CourseBlueprintRequest request) {
  final ctx = request.context;
  final digest = ctx.toStructuredDigest();

  // Build the trusted concept list for grounding
  final conceptList = <Map<String, Object?>>[];
  for (final concept in ctx.graph.concepts) {
    conceptList.add({
      'id': concept.id,
      'title': concept.title,
      'skillId': concept.skillId,
      'difficulty': concept.difficulty.name,
      'order': concept.order,
      'prerequisites': concept.prerequisites,
    });
  }

  // Build skills list
  final skillList = <Map<String, Object?>>[];
  for (final skill in ctx.graph.skills) {
    skillList.add({
      'id': skill.id,
      'title': skill.title,
      'order': skill.order,
    });
  }

  final prompt = {
    'learner': digest,
    'trustedSkills': skillList,
    'trustedConcepts': conceptList,
    if (request.adaptationReason != null)
      'adaptationReason': request.adaptationReason,
    if (request.existingCourseId != null)
      'existingCourseId': request.existingCourseId,
  };

  return '''
Create a personalized course blueprint for this learner.

LEARNER CONTEXT:
${jsonEncode(prompt)}

Remember: ONLY use conceptId values from the trustedConcepts list above.
Respond with ONLY the JSON blueprint, no other text.
''';
}
