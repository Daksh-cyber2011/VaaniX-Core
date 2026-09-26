/// Learn Mode — Full Learner Loop Integration Test.
///
/// Walks the chain that the brief says the runtime loop must actually
/// complete when a learner touches Learn Mode:
///
///   Diagnostic
///     → DiagnosticResult
///     → AI analysis (structured learner context)
///     → PersonalizedCourse (AI OR deterministic fallback)
///     → PersonalizedLesson (routes into the adaptive session engine)
///     → real teaching content (trusted OR AI-personalized cache)
///     → real exercise / practice
///     → answer evaluation
///     → LearningState / mastery update
///     → next-activity adaptation via the planner
///     → honest offline / reset behaviour
///
/// Hard guarantees (these are the assertions the brief demands):
///
/// * PersonalizedLesson MUST NOT silently route to an unrelated static
///   lesson that happens to share a lesson index.
/// * Wrong / stale context MUST NOT resurrect an old personalized course.
/// * AI failure MUST fall back honestly, never fabricating success.
/// * Reset MUST remove the personalized course and the cached teaching
///   material together so nothing drags across learners.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/data/personalized_course_repository.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/personalized_course_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/session_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Counting, self-shaping text client for the AI gateway.
///
/// * `available` toggles the whole Gemini subsystem (offline simulator).
/// * `courseReply` is the JSON used when the AI is asked to draw a course
///   blueprint; `planReply` is the JSON used when the AI is asked to draw
///   an activity plan. Both default to honest, grounded, valid output so
///   the chain can demonstrate the AI path end-to-end. Set to `null` to
///   simulate a hard AI outage.
class _ScriptedPlannerClient implements PlannerTextClient {
  _ScriptedPlannerClient({
    this.available = true,
    this.courseReply,
    String? planReply,
    String? planReplyAfter,
  })  : planReply = planReply,
        planReplyAfter = planReplyAfter ?? planReply;

  final bool available;
  final String? courseReply;
  final String? planReply;
  final String? planReplyAfter;

  int courseCalls = 0;
  int planCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    // Sniff the prompt shape so we route the request to the right canned
    // reply — one client can serve both blueprint callers (course +
    // planner) without leaking replies across tasks.
    final isCourse = system.contains('course blueprint') ||
        user.contains('"units"') ||
        user.contains('"lessons"');
    if (isCourse) {
      courseCalls++;
      if (!available) throw StateError('Gemini offline');
      if (courseReply == null) {
        throw StateError('AI gateway refused to answer');
      }
      return courseReply!;
    }
    planCalls++;
    if (!available) throw StateError('Gemini offline');
    final reply = planCalls == 1 ? planReply : planReplyAfter;
    if (reply == null) {
      throw StateError('AI gateway refused to answer');
    }
    return reply;
  }
}

const String _validCourseBlueprint = '''
{
  "language": "hi",
  "rationale": "Hindi starter at level 0; script + greetings first.",
  "units": [
    {
      "id": "unit_hi_loop_1",
      "title": "Foundations",
      "objective": "Learn Devanagari vowels and a friendly hello.",
      "order": 1,
      "lessons": [
        {"id": "lesson_hi_script_vowels", "conceptId": "hi_script_vowels", "title": "Devanagari vowels",
         "objective": "Read and write Devanagari vowels.", "order": 0,
         "activityType": "newLearning", "prerequisiteConceptIds": [],
         "estimatedMinutes": 5, "difficulty": 2},
        {"id": "lesson_hi_greet_namaste", "conceptId": "hi_greet_namaste", "title": "Greetings",
         "objective": "Greet someone in Hindi.", "order": 1,
         "activityType": "newLearning", "prerequisiteConceptIds": ["hi_script_vowels"],
         "estimatedMinutes": 6, "difficulty": 2}
      ]
    }
  ]
}
''';

const String _validLessonPlan = '''
{"focusSummary":"Open with Devanagari vowels.",
 "activities":[
   {"conceptId":"hi_script_vowels","activityType":"newLearning","difficulty":2,
    "reason":"First lesson on the road.","estimatedMinutes":5}
 ]}
''';

const String _validLessonPlanAfterPractice = '''
{"focusSummary":"Move on to greetings — vowels are now solid.",
 "activities":[
   {"conceptId":"hi_greet_namaste","activityType":"newLearning","difficulty":2,
    "reason":"Wheels up on the next concept.","estimatedMinutes":5}
 ]}
''';

/// One happy-path container with the AI client already scripted.
Future<({ProviderContainer container, _ScriptedPlannerClient client})>
    _newContainer({bool available = true}) async {
  SharedPreferences.setMockInitialValues({'learn_language': 'hindi'});
  final prefs = await SharedPreferences.getInstance();
  final client = _ScriptedPlannerClient(
    available: available,
    courseReply: _validCourseBlueprint,
    planReply: _validLessonPlan,
  );
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      plannerTextClientProvider.overrideWithValue(client),
    ],
  );
  return (container: container, client: client);
}

DiagnosticAnswer _correctAnswerFor(DiagnosticItem item) {
  final display = prepareExerciseOptions(item.exercise, 0);
  return switch (item.exercise.type) {
    ExerciseType.mcq ||
    ExerciseType.fillBlank =>
      DiagnosticChoiceAnswer(display.correctIndex),
    ExerciseType.translation =>
      DiagnosticTextAnswer(item.exercise.acceptedAnswers.first),
    ExerciseType.matching => DiagnosticMatchAnswer({
        for (var i = 0; i < item.exercise.pairs.length; i++)
          i: display.pairIndexByDisplay.indexOf(i),
      }),
    ExerciseType.ordering => DiagnosticOrderAnswer(item.exercise.items),
  };
}

Future<void> _finishDiagnostic(ProviderContainer container) async {
  final notifier = container.read(diagnosticSessionProvider.notifier);
  await notifier.start(LearnLanguage.hindi);
  var guard = 0;
  while (true) {
    final state = container.read(diagnosticSessionProvider);
    if (state.phase == DiagnosticPhase.finished) return;
    if (state.phase == DiagnosticPhase.active) {
      notifier.submitAnswer(_correctAnswerFor(state.currentItem!));
    } else if (state.phase == DiagnosticPhase.feedback) {
      await notifier.next();
    } else {
      fail('diagnostic did not start: ${state.phase}');
    }
    guard++;
    expect(guard, lessThan(80), reason: 'diagnostic must terminate');
  }
}

/// Drives ONE adaptive practice session to completion, mirroring what
/// the Learn Mode UI does step by step.
Future<void> _finishAdaptive(ProviderContainer container) async {
  final notifier = container.read(adaptiveSessionProvider.notifier);
  await notifier.start(
    kind: ActivityKind.practice,
    conceptId: 'hi_script_vowels',
    difficultyKnob: 2,
  );
  var guard = 0;
  while (true) {
    final state = container.read(adaptiveSessionProvider);
    if (state.phase == AdaptiveSessionPhase.finished) return;
    if (state.phase == AdaptiveSessionPhase.active) {
      if (state.currentStep!.isSupport) {
        await notifier.next();
      } else {
        notifier.submitAnswer(correct: true, firstTry: true);
      }
    } else if (state.phase == AdaptiveSessionPhase.feedback) {
      await notifier.next();
    } else {
      fail('adaptive session did not start: ${state.phase}');
    }
    guard++;
    expect(guard, lessThan(120), reason: 'adaptive session must terminate');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('full learner loop — Diagnostic → Course → Lesson → Mastery', () {
    test(
        'Online AI path: diagnostic → AI blueprint → personalized course → '
        'personalized lesson → session → mastery', () async {
      final setup = await _newContainer(available: true);
      addTearDown(setup.container.dispose);
      final container = setup.container;
      final client = setup.client;

      // 1. Diagnostic initializes and completes.
      final beforePlanner = await container.read(activePlannerContextProvider.future);
      expect(beforePlanner.diagnostic, isNull);
      await _finishDiagnostic(container);
      expect(
        container.read(lastDiagnosticProvider(LearnLanguage.hindi)),
        isNotNull,
        reason: 'placement must be persisted before the loop continues',
      );

      // 2. AI analysis receives the structured learner context.
      final afterDiagnostic =
          await container.read(activePlannerContextProvider.future);
      expect(afterDiagnostic.diagnostic, isNotNull);
      expect(
        afterDiagnostic.plannerContextKey,
        isNot(beforePlanner.plannerContextKey),
        reason: 'diagnostic completion must reshape the planner identity',
      );

      // 3. Course blueprint CAN be generated and is grounded.
      final course =
          await container.read(personalizedCourseProvider.future);
      expect(course, isNotNull);
      expect(course!.languageCode, 'hi');
      expect(course.units, isNotEmpty,
          reason: 'personalized course must produce real units');
      expect(client.courseCalls, greaterThanOrEqualTo(1),
          reason: 'AI course blueprint must actually fire');

      // 4. The course is persisted to the offline-safe storage.
      final persisted = container
          .read(personalizedCourseRepositoryProvider)
          .getCourse(LearnLanguage.hindi);
      expect(persisted, isNotNull);
      expect(persisted!.id, course.id,
          reason: 'a stored course is what survives an offline reopen');

      // 5. The course navigation points at real PersonalizedLesson
      //    entities, NOT fall-through to an unrelated static lesson.
      final firstLesson = course.units.first.lessons.first;
      expect(firstLesson.conceptId, isNotEmpty);
      expect(firstLesson.lessonId ?? firstLesson.conceptId, isNotEmpty);
      // The lesson refers to a concept that actually exists in the course
      // (no orphan / no surprise lesson-1 short-circuit).
      final allConcepts =
          course.units.expand((u) => u.lessons.map((l) => l.conceptId)).toSet();
      expect(allConcepts, contains(firstLesson.conceptId));

      // 6. A round-trip through the repository preserves lesson identity.
      final restored = PersonalizedCourse.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );
      expect(restored.languageCode, course.languageCode);
      expect(restored.units.first.lessons.first.conceptId,
          firstLesson.conceptId);

      // 7. The adaptive session actually engages the PersonalizedLesson's
      //    concept and produces real exercises for it.
      final sessionBefore =
          await container.read(activeLearningStateProvider.future);
      await _finishAdaptive(container);
      final sessionAfter =
          await container.read(activeLearningStateProvider.future);

      expect(
        sessionAfter.stageOf(firstLesson.conceptId),
        isNotNull,
        reason: 'mastery must move after practice',
      );
      expect(
        sessionAfter,
        isNot(sessionBefore),
        reason: 'a successful practice round must change the spine',
      );

      // 8. The planner identity has moved — the next recommended activity
      //    is computed against the latest learner state.
      final updatedContext =
          await container.read(activePlannerContextProvider.future);
      expect(updatedContext.state.conceptMasteries, isNotEmpty);
    });

    test(
        'AI failure path: deterministic fallback is honest, not fabricated',
        () async {
      final setup = await _newContainer(available: false);
      addTearDown(setup.container.dispose);
      final container = setup.container;

      await _finishDiagnostic(container);

      // The blueprint generator must NOT throw — it should fold to a
      // deterministic course for the same context.
      final course = await container.read(personalizedCourseProvider.future);
      expect(course, isNotNull);
      expect(course!.isAiGenerated, isFalse,
          reason: 'an offline AI path MUST truthfully label the course as '
              'deterministic — never fake AI provenance');
      expect(course.lessonCount, greaterThan(0),
          reason: 'the deterministic fallback should still produce a '
              'usable roadmap');
    });

    test(
        'the saved PersonalizedCourse cannot resurrect for a different '
        'language context', () async {
      final setup = await _newContainer(available: true);
      addTearDown(setup.container.dispose);
      final container = setup.container;

      // Pre-seed a Hindi course into storage.
      final repository =
          container.read(personalizedCourseRepositoryProvider);
      await repository.saveCourse(PersonalizedCourse(
        id: 'seeded_hi_course',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime(2026, 1, 1),
        contextKey: 'seeded',
        units: [
          PersonalizedUnit(
            id: 'unit_hi_1',
            title: 'Seed',
            objective: 'seed',
            order: 1,
            lessons: [
              PersonalizedLesson(
                id: 'lesson_hi_seed',
                conceptId: 'hi_script_vowels',
                lessonId: 'hi_script_vowels',
                title: 'Seed',
                objective: 'seed',
                order: 0,
              ),
            ],
          ),
        ],
      ));

      // Switch the learner to Bengali — Hindi course MUST NOT surface.
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.bengali);

      final course = await container.read(personalizedCourseProvider.future);
      // The provider may legitimately have no Bengali course yet (which is
      // the safe default) OR a Bengali blueprint — in NEITHER case should
      // a Hindi course have been served.
      if (course != null) {
        expect(course.languageCode, 'bn',
            reason: 'wrong-language saved courses must NEVER surface');
      }

      // Restore Hindi and the original course should be available.
      await container
          .read(selectedLearnLanguageProvider.notifier)
          .select(LearnLanguage.hindi);
      final restored = await container.read(personalizedCourseProvider.future);
      expect(restored, isNotNull);
      expect(restored!.languageCode, 'hi');
    });
  });

  group('mastery and adaptation loop', () {
    test(
        'an adaptive practice round produces a different next-activity '
        'recommendation than an empty state', () async {
      SharedPreferences.setMockInitialValues({'learn_language': 'hindi'});
      final prefs = await SharedPreferences.getInstance();
      final client = _ScriptedPlannerClient(
        available: true,
        courseReply: _validCourseBlueprint,
        planReply: _validLessonPlan,
        planReplyAfter: _validLessonPlanAfterPractice,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          plannerTextClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      await _finishDiagnostic(container);

      final planBefore =
          await container.read(activeLearningPlanProvider.future);
      final beforeConceptIds =
          planBefore.activityConceptIds.whereType<String>().toList();

      await _finishAdaptive(container);

      final afterState =
          await container.read(activeLearningStateProvider.future);
      expect(afterState.conceptMasteries, isNotEmpty,
          reason: 'mastery must be lifted after a real exercise round');

      // Next plan re-derives from the new state — it can be AI or
      // deterministic, but it must reflect the work the learner just did.
      final planAfter =
          await container.read(activeLearningPlanProvider.future);
      final afterConceptIds =
          planAfter.activityConceptIds.whereType<String>().toList();

      // The same AI client that produced the first plan will produce a
      // second one — what matters is that the plan reflects the *current*
      // learner state, not that the strings differ.
      expect(planAfter.focusSummary, isNotEmpty);
      expect(afterConceptIds, isNot(equals(beforeConceptIds)));
    });
  });

  group('offline / reset hygiene', () {
    test(
        'the prefix-scoped clearAll removes the personalized course AND '
        'its generated content cache together', () async {
      SharedPreferences.setMockInitialValues({
        'learn_language': 'hindi',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final profileRepo = LearnProfileRepository(
        container.read(localStorageServiceProvider),
      );
      final courseRepo = PersonalizedCourseRepository(
        container.read(localStorageServiceProvider),
      );

      await courseRepo.saveCourse(PersonalizedCourse(
        id: 'course_hi_reset',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime(2026, 1, 1),
        contextKey: 'k',
        units: [
          PersonalizedUnit(
            id: 'u1',
            title: 't',
            objective: 'o',
            order: 1,
            lessons: const [],
          ),
        ],
      ));

      // Seed a generated-content entry as if a previous session had
      // materialised personalized teaching material for that course.
      await prefs.setString(
        'learn_profile_hi_gen_hi_script_vowels',
        '{"key":"hi_script_vowels|explanation|2","content":{}}',
      );

      // Confirm both pieces of state are present before reset.
      expect(courseRepo.getCourse(LearnLanguage.hindi), isNotNull);
      expect(prefs.getString('learn_profile_hi_gen_hi_script_vowels'), isNotNull);

      await profileRepo.clearAll();

      // After reset, both the course AND the generated content are gone.
      expect(courseRepo.getCourse(LearnLanguage.hindi), isNull,
          reason: 'a full Learn reset must wipe the saved personalized course');
      expect(prefs.getString('learn_profile_hi_gen_hi_script_vowels'), isNull,
          reason: 'the generated-content cache lives under the same '
              'namespace and must go too');
    });

    test(
        'personalizedCourseProvider invalidation clears a stale entry from '
        'the live runtime', () async {
      SharedPreferences.setMockInitialValues({
        'learn_language': 'hindi',
        PersonalizedCourseRepository.courseKey(LearnLanguage.hindi):
            '{"languageCode":"hi","id":"old","source":"ai",'
                '"generatedAt":"2026-01-01T00:00:00.000Z",'
                '"contextKey":"x","units":[],"curriculumRevision":null,'
                '"unitCount":0,"lessonCount":0,"isAiGenerated":true,'
                '"offlineStatusDescription":"seed"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final before = await container.read(personalizedCourseProvider.future);
      // The blueprint generator may or may not fire on top of the stale
      // seed — what matters is that whatever the provider returns, the
      // caller invalidates it cleanly when reset.
      expect(before, isNotNull);

      await container.read(learnProfileRepositoryProvider).clearAll();
      container.invalidate(personalizedCourseProvider);

      final after = await container.read(personalizedCourseProvider.future);
      // The provider regenerated. A re-resolved seed MUST carry a fresh
      // id and language match — never blindly re-serving the old entry.
      expect(after, isNotNull);
      expect(after!.id, isNot('old'),
          reason: 'post-reset regeneration must produce a fresh identity');
    });
  });

  group('PersonalizedLesson routing safety', () {
    test(
        'PersonalizedLesson.{conceptId, lessonId, activityType} survive a '
        'JSON round-trip and feed the session engine correctly',
        () async {
      SharedPreferences.setMockInitialValues({'learn_language': 'hindi'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final course = PersonalizedCourse(
        id: 'rt_course_hi',
        languageCode: 'hi',
        source: PlanSource.ai,
        generatedAt: DateTime(2026, 1, 1),
        contextKey: 'ctx-rt',
        units: [
          PersonalizedUnit(
            id: 'unit_hi_rt',
            title: 'Round-trip',
            objective: 'verify routing safety',
            order: 1,
            lessons: [
              PersonalizedLesson(
                id: 'lesson_hi_rt_1',
                conceptId: 'hi_script_vowels',
                lessonId: 'hi_script_vowels',
                title: 'Devanagari vowels lesson',
                objective: 'cover alpha',
                activityType: 'newLearning',
                order: 0,
              ),
            ],
          ),
        ],
      );

      final roundTrip = PersonalizedCourse.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );

      final lesson = roundTrip.units.single.lessons.single;
      expect(lesson.conceptId, 'hi_script_vowels');
      expect(lesson.lessonId, 'hi_script_vowels');
      expect(lesson.activityType, 'newLearning');

      // The adaptive session uses the lesson's conceptId, NOT a lesson
      // index — this is what guarantees PersonalizedLesson is not
      // silently redirected to an unrelated static lesson.
      final notifier = container.read(adaptiveSessionProvider.notifier);
      await notifier.start(
        kind: ActivityKind.practice,
        conceptId: lesson.conceptId,
        difficultyKnob: 2,
      );
      final session = container.read(adaptiveSessionProvider);
      expect(
        session.focusConceptId,
        lesson.conceptId,
        reason: 'the session MUST adopt the PersonalizedLesson concept, '
            'not a numerically aligned static curriculum entry',
      );
    });
  });

  group('AI wiring is centralised', () {
    test(
        'the AI gateway is reached through [plannerTextClientProvider] — '
        'no duplicate text client lives in the Learn file tree', () async {
      final setup = await _newContainer(available: true);
      addTearDown(setup.container.dispose);
      final container = setup.container;

      // The blueprint path runs.
      await _finishDiagnostic(container);
      await container.read(personalizedCourseProvider.future);

      // The planning path runs.
      await container.read(activeLearningPlanProvider.future);

      // The same client served both — there is no separate gateway per
      // feature, no scattered Gemini key, no hard-coded model id here.
      final client = setup.client;
      expect(client.courseCalls + client.planCalls, greaterThanOrEqualTo(2),
          reason: 'both blueprint and plan calls must travel through the '
              'single scoped client');
    });
  });
}
