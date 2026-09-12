/// Exam Mode 2.0 — M5 Planner Tests
///
/// §16 validation rejections (hallucinated topics, over-budget days),
/// deterministic planner invariants (fits budget, weak-first, PYQ/mock
/// slots honest), Gemini parser paths (good JSON, garbage, fenced
/// JSON), and cached-plan staleness triggers (§33).
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:dartz/dartz.dart' show Left, Right;
import 'package:vaanix_app/features/exam/data/planner/deterministic_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/planner/gemini_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_validator.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart'
    show PlannerTextClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CourseSyllabus syllabus;
  late ExamScopeView view;
  late ExamScopeSelection selection;
  late ExamProfile examProfile;

  setUpAll(() async {
    final raw =
        await rootBundle.loadString('assets/syllabus/cbse/cbse_10_sanskrit.json');
    syllabus =
        CourseSyllabus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    view = ExamScopeView.fromSyllabus(syllabus);
    selection = ExamScopeSelection.empty(view.trackId)
        .selectAll(view.selectableUnitIds);
    examProfile = ExamProfile(
      trackId: view.trackId,
      dailyStudyMinutes: 45,
      studyDaysPerWeek: 5,
      readinessDurationWeeks: 8,
    );
  });

  DeterministicExamContext ctx({ExamLearnerProfile? learner}) =>
      DeterministicExamContext(
        trackId: view.trackId,
        view: view,
        selection: selection,
        profile: examProfile,
        learner: learner ?? ExamLearnerProfile.empty(view.trackId),
        scopeRevision: selection.revision,
      );

  test('deterministic plan passes its own validator', () {
    final plan = DeterministicExamPlanner.build(ctx());
    expect(
      ExamPlanValidator.validate(
          plan: plan, view: view, selection: selection, profile: examProfile),
      isEmpty,
    );
  });

  test('§9: every day fits inside the student budget', () {
    for (final minutes in [5, 15, 30, 45, 120]) {
      final p = ExamProfile(
        trackId: view.trackId,
        dailyStudyMinutes: minutes,
        studyDaysPerWeek: 5,
        readinessDurationWeeks: 8,
      );
      final plan = DeterministicExamPlanner.build(DeterministicExamContext(
        trackId: view.trackId,
        view: view,
        selection: selection,
        profile: p,
        learner: ExamLearnerProfile.empty(view.trackId),
        scopeRevision: selection.revision,
      ));
      for (final day in plan.days) {
        expect(day.totalMinutes <= minutes, isTrue,
            reason: 'day ${day.dayIndex} overflow at $minutes min budget');
      }
    }
  });

  test('§13/§16: all task topicIds are inside the scope', () {
    final plan = DeterministicExamPlanner.build(ctx());
    for (final day in plan.days) {
      for (final task in day.tasks) {
        expect(selection.isSelected(task.topicId), isTrue,
            reason: 'out-of-scope task ${task.title}');
      }
    }
  });

  test('weak topics come first when the diagnostic exists', () {
    final weakId = selection.selectedUnitIds.first;
    final learner = ExamLearnerProfile.empty(view.trackId).recordAttempt(
        topicId: weakId, correct: false);
    final plan = DeterministicExamPlanner.build(ctx(learner: learner));
    final firstTasks = plan.days.first.tasks;
    expect(firstTasks.any((t) => t.topicId == weakId), isTrue,
        reason: 'weak topic should lead day 0');
  });

  test('validator rejects hallucinated topics (§16 rule 1)', () {
    final good = DeterministicExamPlanner.build(ctx());
    final hallucinated = ExamPlan(
      id: good.id,
      trackId: good.trackId,
      source: good.source,
      scopeRevision: good.scopeRevision,
      focusSummary: good.focusSummary,
      rationale: good.rationale,
      days: [
        ExamDayPlan(dayIndex: 0, tasks: [
          ExamPlanTask(
            type: ExamTaskType.learn,
            topicId: 'made_up_topic_xyz',
            title: 'hallucination',
            minutes: 15,
          ),
        ]),
      ],
      createdAtIso: good.createdAtIso,
    );
    expect(
      ExamPlanValidator.validate(
          plan: hallucinated, view: view, selection: selection, profile: examProfile),
      isNotEmpty,
    );
  });

  test('validator rejects over-budget days (§9)', () {
    final good = DeterministicExamPlanner.build(ctx());
    final realId = selection.selectedUnitIds.first;
    final over = ExamPlan(
      id: good.id,
      trackId: good.trackId,
      source: good.source,
      scopeRevision: good.scopeRevision,
      focusSummary: '',
      rationale: '',
      days: [
        ExamDayPlan(dayIndex: 0, tasks: [
          ExamPlanTask(
              type: ExamTaskType.learn, topicId: realId, title: 'x', minutes: 60),
          ExamPlanTask(
              type: ExamTaskType.practice, topicId: realId, title: 'y', minutes: 60),
        ]),
      ],
      createdAtIso: '',
    );
    expect(
      ExamPlanValidator.validate(
          plan: over, view: view, selection: selection, profile: examProfile),
      anyElement(contains('available')),
    );
  });

  test('parser accepts clean JSON and fences, rejects garbage (§16)', () {
    final plannerCtx = ExamPlannerContext(
      trackId: view.trackId,
      view: view,
      selection: selection,
      profile: examProfile,
      learner: ExamLearnerProfile.empty(view.trackId),
      scopeRevision: selection.revision,
    );
    final topicId = selection.selectedUnitIds.first;

    final goodJson = jsonEncode({
      'focusSummary': 'कमज़ोर विषय पहले',
      'rationale': 'डायग्नोस्टिक आधारित',
      'days': [
        for (var d = 0; d < 7; d++)
          {
            'dayIndex': d,
            'tasks': [
              {
                'type': 'learn',
                'topicId': topicId,
                'title': 'सीखें',
                'minutes': 15,
              },
            ],
          },
      ],
    });
    final parsed = ExamPlanParser.parse(goodJson, plannerCtx);
    expect(parsed.isRight(), isTrue);

    final fenced = '```json\n$goodJson\n```';
    expect(ExamPlanParser.parse(fenced, plannerCtx).isRight(), isTrue);

    expect(ExamPlanParser.parse('AI is down today', plannerCtx).isLeft(), isTrue);

    // Hallucinated topic inside AI output → rejected.
    final hallucinatedJson = jsonEncode({
      'focusSummary': 'x',
      'rationale': 'x',
      'days': [
        {
          'dayIndex': 0,
          'tasks': [
            {'type': 'learn', 'topicId': 'nope', 'title': 'x', 'minutes': 15},
          ],
        },
        for (var d = 1; d < 7; d++)
          {
            'dayIndex': d,
            'tasks': [
              {'type': 'practice', 'topicId': topicId, 'title': 'x', 'minutes': 15},
            ],
          },
      ],
    });
    expect(
        ExamPlanParser.parse(hallucinatedJson, plannerCtx).isLeft(), isTrue);
  });

  test('§17: unavailable client short-circuits without network', () async {
    final planner = GeminiExamPlanner(
      textClient: _FakeTextClient(available: false),
    );
    final result = await planner.buildPlan(ExamPlannerContext(
      trackId: view.trackId,
      view: view,
      selection: selection,
      profile: examProfile,
      learner: ExamLearnerProfile.empty(view.trackId),
      scopeRevision: selection.revision,
    ));
    expect(result.isLeft(), isTrue);
  });

  test('§33: scope revision mismatch marks the plan stale', () {
    final plan = DeterministicExamPlanner.build(ctx());
    final editedScope = selection.toggle(selection.selectedUnitIds.first)!;
    expect(
      ExamPlanValidator.validate(
          plan: plan,
          view: view,
          selection: editedScope,
          profile: examProfile),
      isNotEmpty,
      reason: 'plan built for a different scope revision must not validate '
          'against the edited scope',
    );
  });
}

class _FakeTextClient implements PlannerTextClient {
  _FakeTextClient({required this.available, this.response});

  @override
  final bool available;

  final String? response;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({required String system, required String user}) async {
    final r = response;
    if (r == null) throw Exception('network down');
    return r;
  }
}
