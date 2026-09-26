/// Riverpod access to the AI-personalized Learn roadmap.
///
/// This is the REAL personalization pipeline:
///
///   Diagnostic + Profile + Mastery + Graph
///       ↓
///   AI Course Blueprint (when online)
///       ↓
///   CourseBlueprintParser (validation + grounding)
///       ↓
///   PersonalizedCourse
///       ↓
///   Persistence (offline survival)
///       ↓
///   Learn UI navigates the personalized roadmap
///
/// Fallback chain:
///   1. AI blueprint → validated course
///   2. Saved AI course (offline / stale context ok if curriculum matches)
///   3. Deterministic course (graph-order, evidence-aware)
///
/// The context key ensures the course is invalidated when material inputs
/// change (diagnostic, profile, curriculum revision). Minor mastery
/// changes do NOT force regeneration — the adaptation provider handles
/// progressive updates.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/course_blueprint_generator.dart';
import 'package:vaanix_app/features/learn/data/personalized_course_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/course_blueprint.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';

final personalizedCourseRepositoryProvider =
    Provider<PersonalizedCourseRepository>(
  (ref) => PersonalizedCourseRepository(ref.watch(localStorageServiceProvider)),
);

/// The AI course blueprint generator.
final courseBlueprintGeneratorProvider = Provider<CourseBlueprintGenerator>(
  (ref) => CourseBlueprintGenerator(
    textClient: ref.watch(plannerTextClientProvider),
    courseRepository: ref.watch(personalizedCourseRepositoryProvider),
  ),
);

/// A stable course context key built from the SLOW-CHANGING inputs that
/// should trigger course regeneration. Mastery changes are intentionally
/// excluded — they drive adaptation, not full regeneration.
///
/// Regeneration triggers:
/// - language change
/// - diagnostic result change
/// - profile goal/level change
/// - curriculum revision change
final _courseContextKeyProvider = FutureProvider<String>((ref) async {
  final context = await ref.watch(activePlannerContextProvider.future);
  final language = ref.watch(selectedLearnLanguageProvider);
  if (language == null) return '';

  // Build a stable key from slow-changing inputs only
  final parts = <String>[
    context.languageCode,
    if (context.diagnostic != null)
      context.diagnostic!.completedAt.toIso8601String(),
    if (context.profile != null) ...[
      context.profile!.goal.name,
      context.profile!.desiredLevel.name,
      context.profile!.pace.name,
    ],
    learnLanguageSpec(language).curriculumRevision.toString(),
  ];
  return parts.join('|');
});

/// Builds, restores, or generates the learner's personalized course.
///
/// This is the primary Learn Mode data source. The personalized course
/// drives the lesson tree, not the static curriculum.
///
/// Flow:
/// 1. Check for a saved course matching the current context key
/// 2. If valid saved course exists → serve it (offline-safe)
/// 3. If AI is available → generate a new AI blueprint
/// 4. If AI fails/unavailable → build a deterministic course
///
/// The course is invalidated automatically via Riverpod dependency when:
/// - Language changes (selectedLearnLanguageProvider)
/// - Diagnostic changes (via activePlannerContextProvider)
/// - Profile changes (via activePlannerContextProvider)
/// - Curriculum revision changes (via _courseContextKeyProvider)
final personalizedCourseProvider = FutureProvider<PersonalizedCourse?>(
  (ref) async {
    final language = ref.watch(selectedLearnLanguageProvider);
    if (language == null) return null;

    final context = await ref.watch(activePlannerContextProvider.future);
    final contextKey = await ref.watch(_courseContextKeyProvider.future);
    final repository = ref.watch(personalizedCourseRepositoryProvider);

    if (contextKey.isEmpty) return null;

    // ── Step 1: Check for a valid saved course ──
    final existing = repository.getCourse(language);
    if (existing != null) {
      // A saved course is valid if its curriculum revision matches.
      // Context key mismatches (diagnostic change, profile change) should
      // trigger regeneration but NOT prevent serving the old course while
      // regeneration is in progress.
      final currentRevision =
          learnLanguageSpec(language).curriculumRevision.toString();
      final revisionOk = existing.curriculumRevision == null ||
          existing.curriculumRevision == currentRevision;

      if (revisionOk && existing.contextKey == contextKey) {
        // Perfect match — serve immediately
        return existing;
      }

      // Curriculum matches but context changed — try AI regeneration,
      // but keep the old course as a fallback
      if (revisionOk) {
        final regenerated = await _tryAiGeneration(ref, context, contextKey);
        return regenerated ?? existing;
      }

      // Curriculum revision changed — must regenerate (old course may
      // reference removed concepts)
    }

    // ── Step 2: No valid saved course — try AI generation ──
    final aiCourse = await _tryAiGeneration(ref, context, contextKey);
    if (aiCourse != null) return aiCourse;

    // ── Step 3: AI unavailable — build deterministic course ──
    final courseId = 'course_${language.name}_det_'
        '${DateTime.now().millisecondsSinceEpoch}';
    final deterministicCourse = buildDeterministicCourse(
      context: context,
      courseId: courseId,
      courseContextKey: contextKey,
    );

    // Persist the deterministic course for offline use
    try {
      await repository.saveCourse(deterministicCourse);
    } catch (_) {
      // Best effort
    }

    return deterministicCourse;
  },
);

/// Attempts AI course blueprint generation. Returns null on failure.
Future<PersonalizedCourse?> _tryAiGeneration(
  Ref ref,
  PlannerContext context,
  String contextKey,
) async {
  final generator = ref.read(courseBlueprintGeneratorProvider);
  final request = CourseBlueprintRequest(
    context: context,
    courseContextKey: contextKey,
  );

  final result = await generator.generateBlueprint(request);

  return result.fold(
    (failure) => null, // AI failed — caller will use fallback
    (course) => course,
  );
}

/// Whether the current personalized course is AI-generated (vs deterministic).
///
/// Used by UI to show honest provenance labels.
final courseIsAiGeneratedProvider = Provider<bool>((ref) {
  final courseAsync = ref.watch(personalizedCourseProvider);
  return courseAsync.whenOrNull(data: (course) => course?.isAiGenerated) ??
      false;
});

/// The total lesson count from the personalized course.
final personalizedLessonCountProvider = Provider<int>((ref) {
  final courseAsync = ref.watch(personalizedCourseProvider);
  return courseAsync.whenOrNull(data: (course) => course?.lessonCount) ?? 0;
});

/// Honest offline status of the personalized course.
final courseOfflineStatusProvider = Provider<String>((ref) {
  final courseAsync = ref.watch(personalizedCourseProvider);
  return courseAsync.whenOrNull(
          data: (course) => course?.offlineStatusDescription) ??
      'Loading...';
});
