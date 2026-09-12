/// Exam Mode 2.0 — M11 Real Student Simulation Tests (master plan M11).
///
/// Nine personas (A–I, exactly the master plan's list) each walk a
/// compact but COMPLETE journey through the REAL Dart engines on the
/// REAL canonical syllabus assets:
///
///     diagnostic → plan → daily sessions → mistakes → replanning →
///     weak-area decision → revision → PYQ → mock → readiness/XP
///
/// The point of M11 is divergence: the journeys must NOT collapse
/// into one template. These tests assert per-persona behavior
/// fingerprints AND cross-persona divergence. The heavy 21-day,
/// 9-persona harness with full persistence lives in
/// `tools/exam/student_simulations.py` (verified by
/// `tools/exam/verify_exam_m11.py`, 136 checks) — this file is the
/// Dart-side executable proof on the shipped engine classes.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/diagnostic/diagnostic_item_bank.dart';
import 'package:vaanix_app/features/exam/data/planner/deterministic_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/practice/practice_content_bank.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_engine.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_engine.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_bank.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 12, 10);

  /// Deterministic answer policy: stable string hash keeps every
  /// journey reproducible (no Random, no flakiness).
  int hashOf(String s) {
    var h = 7;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }

  bool chance(String seed, int percent) => hashOf(seed) % 100 < percent;

  test('A–G journeys complete and diverge (same course)', () async {
    final specs = <String, _PersonaSpec>{
      'A': _PersonaSpec(id: 'A', name: 'Strong student', percent: 100),
      'B': _PersonaSpec(id: 'B', name: 'Average student', percent: 55),
      'C': _PersonaSpec(id: 'C', name: 'Weak student', percent: 25),
      'D': _PersonaSpec(id: 'D', name: 'Skips sessions', percent: 60,
          skipDays: const {2, 3}),
      'E': _PersonaSpec(id: 'E', name: 'Changes syllabus scope',
          percent: 60, editScopeDay: 4),
      'F': _PersonaSpec(id: 'F', name: 'Changes readiness target',
          percent: 60, retargetWeeks: 3, retargetDay: 4),
      'G': _PersonaSpec(id: 'G', name: 'Chooses different tasks',
          percent: 60, preferPyqOverPractice: true),
    };

    final results = <String, _JourneyDigest>{};
    for (final spec in specs.values) {
      results[spec.id] = await _runJourney(spec, chance, now);
    }

    // -- every persona walked every stage ---------------------------

    for (final entry in results.entries) {
      final d = entry.value;
      expect(d.diagnosticResponses, greaterThanOrEqualTo(5),
          reason: '${entry.key} diagnostic too short (§10)');
      expect(d.plan.days, isNotEmpty, reason: '${entry.key} got no plan');
      expect(d.sessions, greaterThanOrEqualTo(3),
          reason: '${entry.key} finished too few sessions');
      expect(d.mockResult, isNotNull,
          reason: '${entry.key} never sat a mock');
      expect(d.xp, greaterThan(0), reason: '${entry.key} earned no XP');
      expect(d.pyqAttempts, greaterThan(0),
          reason: '${entry.key} did no PYQ work');
      expect(d.attempts, greaterThan(0),
          reason: '${entry.key} produced no attempt evidence');
    }

    // -- divergence: ability separates the journeys ------------------

    final a = results['A']!, b = results['B']!, c = results['C']!;
    expect(a.diagCorrect, greaterThan(b.diagCorrect));
    expect(b.diagCorrect, greaterThan(c.diagCorrect));
    expect(a.mockResult!.overallBand, 'strong');
    expect(c.mockResult!.overallBand, 'needsAttention');
    expect(a.weakFindings.length, lessThan(c.weakFindings.length));
    expect(a.xp, greaterThan(c.xp));
    expect(
      a.strongTopicCount,
      greaterThan(c.strongTopicCount),
      reason: 'A must end with more strong/mastered topics than C',
    );
    // §29 honesty: no journey invents out-of-vocabulary stages.
    for (final d in results.values) {
      for (final m in d.learner.topics.values) {
        expect(TopicStage.values.contains(m.stage), isTrue);
      }
    }

    // -- D: skipped days shrink the journey --------------------------

    final d = results['D']!;
    expect(d.skippedDays, 2);
    expect(d.sessions, lessThan(b.sessions));
    expect(results.values.where((x) => x.skippedDays > 0).length, 1,
        reason: 'only D skips days');

    // -- E: the scope edit rebuilt the plan around a smaller scope ---

    final e = results['E']!;
    expect(e.scopeRevision, 2, reason: 'scope edit must bump revision');
    expect(e.selectedCount, lessThan(b.selectedCount));
    expect(e.finalPlanTasks.every((t) => e.selectedIds.contains(t.topicId)),
        isTrue,
        reason: '§16: post-edit tasks must stay inside the new scope');
    expect(results.values.where((x) => x.scopeRevision > 1).length, 1,
        reason: 'only E edits scope');

    // -- F: the target change moved the anchor -----------------------

    final f = results['F']!;
    expect(f.daysLeft, 21,
        reason: 'F retargeted to 3 weeks on day 4 → 21 days left');
    expect(b.daysLeft, 56, reason: 'B keeps the original 8-week anchor');
    expect(f.planCount, greaterThan(b.planCount),
        reason: 'the retarget forced an extra rebuild (§33)');

    // -- G: chose PYQ instead of practice — no punishment (§20) ------

    final g = results['G']!;
    expect(g.pyqAttempts, greaterThan(2 * b.pyqAttempts),
        reason: 'G replaced practice with PYQ volume');
    expect(g.sessions, greaterThanOrEqualTo(b.sessions - 2),
        reason: 'student freedom must not reduce session count');
    expect(g.practiceTasksDone, lessThan(b.practiceTasksDone),
        reason: 'G really did fewer recommended practice tasks');
  });

  test('H: repeatedly failing ONE topic keeps exactly that topic weak',
      () async {
    final syllabus = await _loadSyllabus('cbse_10_sanskrit');
    final view = ExamScopeView.fromSyllabus(syllabus);
    // Highest-marks unit: the planner's marks-weighted rotation
    // reaches it first, so the topic is guaranteed practice evidence.
    final failTopic = view.sections
        .expand((s) => s.selectableUnits)
        .reduce((a, b) =>
            (b.marks ?? 0) > (a.marks ?? 0) ? b : a)
        .id;

    final h = await _runJourney(
      _PersonaSpec(
        id: 'H',
        name: 'Repeatedly fails one topic',
        percent: 60,
        failTopicId: failTopic,
        failPercent: 90,
      ),
      chance,
      now,
    );
    final baseline = await _runJourney(
        _PersonaSpec(id: 'B', name: 'Average student', percent: 55),
        chance, now);
    final c = await _runJourney(
        _PersonaSpec(id: 'C', name: 'Weak student', percent: 25),
        chance, now);

    expect(h.diagnosticResponses, greaterThanOrEqualTo(5));
    expect(h.mockResult, isNotNull);

    // The fail topic has evidence and stays weaker than B's.
    final failMastery = h.learner.topics[failTopic];
    expect(failMastery, isNotNull,
        reason: 'the fail topic must have been practiced');
    expect(failMastery!.attemptCount, greaterThan(0));
    expect(h.learner.topics[failTopic]!.strength,
        lessThan(baseline.learner.topics[failTopic]!.strength),
        reason: 'failing the topic 90% of the time must weaken it vs B');
    // One-topic failure is NOT global weakness (vs the weak student).
    expect(h.weakFindings.length, lessThan(c.weakFindings.length),
        reason: 'one-topic failure ≠ failing everything');
    expect(h.mockResult!.overallBand == 'needsAttention' ||
        h.mockResult!.overallBand == 'learning', isTrue,
        reason: 'H cannot end in the strong band after 90% topic failure');
  });

  test('I: strong in one section, weak in another (Hindi A course)',
      () async {
    final syllabus = await _loadSyllabus('cbse_10_hindi_a');
    final view = ExamScopeView.fromSyllabus(syllabus);
    final sections = view.sections
        .where((s) => s.selectableUnits.isNotEmpty)
        .toList(growable: false);
    expect(sections.length, greaterThanOrEqualTo(2),
        reason: 'the asymmetry test needs 2+ sections');

    final strongSection = sections.first;
    final weakSection = sections.last;

    final i = await _runJourney(
      _PersonaSpec(
        id: 'I',
        name: 'Strong one section, weak another',
        percent: 100,
        weakSectionTitle: weakSection.title,
        weakSectionPercent: 15,
      ),
      chance,
      now,
      syllabusOverride: syllabus,
      viewOverride: view,
      mockFocusSectionId: weakSection.id,
    );

    expect(i.mockResult, isNotNull);
    // Mastery splits by section: strong section topics hold up.
    final strongIds =
        strongSection.selectableUnits.map((u) => u.id).toSet();
    final weakIds = weakSection.selectableUnits.map((u) => u.id).toSet();
    double avgStrength(Set<String> ids) {
      final ms = i.learner.topics.values
          .where((t) => ids.contains(t.topicId) && t.attemptCount > 0)
          .toList();
      if (ms.isEmpty) return 0;
      return ms.map((t) => t.strength).reduce((x, y) => x + y) / ms.length;
    }

    expect(avgStrength(strongIds), greaterThan(avgStrength(weakIds) + 0.2),
        reason: 'section asymmetry must show in mastery strength');
    // §21 findings concentrate in the weak section.
    final findingsInWeak =
        i.weakFindings.where((f) => weakIds.contains(f.topicId)).length;
    final findingsInStrong =
        i.weakFindings.where((f) => strongIds.contains(f.topicId)).length;
    expect(findingsInWeak, greaterThan(findingsInStrong));
    // The mock's weak-section detection is section-honest (§21).
    expect(i.mockResult!.weakSections.map((s) => s.sectionId),
        contains(weakSection.id));
  });
}

// ---------------------------------------------------------------------------
// Journey harness
// ---------------------------------------------------------------------------

Future<CourseSyllabus> _loadSyllabus(String courseId) async {
  final raw =
      await rootBundle.loadString('assets/syllabus/cbse/$courseId.json');
  return CourseSyllabus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class _PersonaSpec {
  const _PersonaSpec({
    required this.id,
    required this.name,
    required this.percent,
    this.skipDays = const {},
    this.editScopeDay,
    this.retargetWeeks,
    this.retargetDay,
    this.preferPyqOverPractice = false,
    this.failTopicId,
    this.failPercent = 100,
    this.weakSectionTitle,
    this.weakSectionPercent = 0,
  });

  final String id;
  final String name;

  /// Base correctness percent for ordinary questions.
  final int percent;

  /// Persona D: days (1-based) entirely skipped.
  final Set<int> skipDays;

  /// Persona E: the day the student edits the scope.
  final int? editScopeDay;

  /// Persona F: retarget to this many weeks on [retargetDay].
  final int? retargetWeeks;
  final int? retargetDay;

  /// Persona G: replaces recommended practice tasks with PYQ.
  final bool preferPyqOverPractice;

  /// Persona H: this topic is failed [failPercent]% of the time.
  final String? failTopicId;
  final int failPercent;

  /// Persona I: questions from this section are answered at
  /// [weakSectionPercent] instead of [percent].
  final String? weakSectionTitle;
  final int weakSectionPercent;
}

class _JourneyDigest {
  final int diagnosticResponses;
  final int diagCorrect;
  final int sessions;
  final int skippedDays;
  final int scopeRevision;
  final int selectedCount;
  final int planCount;
  final int xp;
  final int pyqAttempts;
  final int practiceTasksDone;
  final int daysLeft;
  final int attempts;
  final Set<String> selectedIds;
  final List<ExamPlanTask> finalPlanTasks;
  final MockResult? mockResult;
  final ExamLearnerProfile learner;
  final List<WeakTopicFinding> weakFindings;

  _JourneyDigest({
    required this.diagnosticResponses,
    required this.diagCorrect,
    required this.sessions,
    required this.skippedDays,
    required this.scopeRevision,
    required this.selectedCount,
    required this.planCount,
    required this.xp,
    required this.pyqAttempts,
    required this.practiceTasksDone,
    required this.daysLeft,
    required this.attempts,
    required this.selectedIds,
    required this.finalPlanTasks,
    required this.mockResult,
    required this.learner,
    required this.weakFindings,
  });

  int get strongTopicCount => learner.topics.values
      .where((t) =>
          t.stage == TopicStage.mastered || t.stage == TopicStage.strong)
      .length;
}

Future<_JourneyDigest> _runJourney(
  _PersonaSpec spec,
  bool Function(String seed, int percent) chance,
  DateTime now, {
  CourseSyllabus? syllabusOverride,
  ExamScopeView? viewOverride,
  String? mockFocusSectionId,
}) async {
  final syllabus =
      syllabusOverride ?? await _loadSyllabus('cbse_10_sanskrit');
  var view = viewOverride ?? ExamScopeView.fromSyllabus(syllabus);
  var selection = ExamScopeSelection.empty(view.trackId)
      .selectAll(view.selectableUnitIds);

  var profile = ExamProfile(
    trackId: view.trackId,
    dailyStudyMinutes: 40,
    studyDaysPerWeek: 6,
    readinessTargetDate: now.add(const Duration(days: 56)),
  );

  // Mutable journey state.
  var learner = ExamLearnerProfile.empty(view.trackId);
  final evidence = <ErrorEvidence>[];
  var sessions = 0;
  var skippedDays = 0;
  var pyqAttempts = 0;
  var practiceTasksDone = 0;
  var scopeRevision = 1;
  var planCount = 0;
  var xpTotal = 0;
  MockResult? mockResult;
  var attempts = 0;

  final sectionOfTopic = <String, String>{};
  for (final sec in view.sections) {
    for (final unit in sec.selectableUnits) {
      sectionOfTopic[unit.id] = sec.title;
    }
  }

  bool answerCorrect(String topicId, String salt) {
    if (spec.failTopicId != null && topicId == spec.failTopicId) {
      return chance('${spec.id}-fail-$salt', 100 - spec.failPercent);
    }
    final section = sectionOfTopic[topicId] ?? '';
    if (spec.weakSectionTitle != null &&
        section == spec.weakSectionTitle) {
      return chance('${spec.id}-weaksec-$salt', spec.weakSectionPercent);
    }
    return chance('${spec.id}-$salt', spec.percent);
  }

  // -- helpers ----------------------------------------------------------

  ({WeakAreaReport report, WeakAreaDayDecision decision,
      List<RevisionItem> revision}) runEngines() {
    final patterns = ErrorIntelligence.analyze(evidence);
    final revisionItems = RevisionEngine.schedule(
      learner: learner,
      patterns: patterns,
      history: const {},
      now: now,
    );
    final report = WeakAreaEngine.build(
      learner: learner,
      patterns: patterns,
      revisionItems: revisionItems,
      now: now,
    );
    final decision = WeakAreaDayEngine.decide(
      report: report,
      revisionItems: revisionItems,
      dayCount: 7,
      now: now,
    );
    return (report: report, decision: decision, revision: revisionItems);
  }

  DeterministicExamContext buildContext(WeakAreaReport report,
      WeakAreaDayDecision decision, List<RevisionItem> revision) {
    return DeterministicExamContext(
      trackId: view.trackId,
      view: view,
      selection: selection,
      profile: profile,
      learner: learner,
      scopeRevision: scopeRevision,
      weakArea: WeakAreaPlannerInput(
        decision: decision,
        revisionItems: revision,
        findings: report.findings.map((f) => f.topicId).toList(),
      ),
    );
  }

  /// §28 loop: one retry chance, then the verdict is final.
  void runPool(List<PracticeQuestion> pool, ExamSessionKind kind) {
    if (pool.isEmpty) return;
    var correct = 0;
    for (final q in pool) {
      var ok = answerCorrect(q.topicId, q.id);
      if (!ok && chance('retry-${q.id}', 50)) {
        ok = answerCorrect(q.topicId, '${q.id}-r');
      }
      if (ok) correct++;
      learner = learner.recordAttempt(topicId: q.topicId, correct: ok);
      evidence.add(ErrorEvidence(
        questionId: q.id,
        topicId: q.topicId,
        kind: 'mcq',
        verdict: ok ? 'correct' : 'incorrect',
        retries: ok ? 0 : 1,
        atIso: now.toIso8601String(),
      ));
    }
    attempts += pool.length;
    xpTotal += ExamSessionXp.total(
        kind: kind, correctCount: correct, totalCount: pool.length);
    sessions++;
  }

  MockResult runMiniMock(DateTime t) {
    final boardSections = syllabus.sections
        .where((s) =>
            s.assessmentType == AssessmentType.board && s.marks > 0)
        .map((s) => (id: s.id, title: s.title, marks: s.marks))
        .toList(growable: false);
    final sectionOfUnit = <String, String>{};
    for (final sec in view.sections) {
      for (final unit in sec.selectableUnits) {
        sectionOfUnit[unit.id] = sec.id;
      }
    }
    final pyq = PyqBank.build(
        syllabus: syllabus, view: view, selection: selection);
    final bySection = <String, List<PyqQuestion>>{};
    for (final q in pyq) {
      bySection
          .putIfAbsent(sectionOfUnit[q.question.topicId] ?? '', () => [])
          .add(q);
    }
    final paper = MockEngine.build(
      trackId: syllabus.id,
      kind: MockKind.mini,
      boardSections: boardSections,
      boardTotalMarks: syllabus.boardExamTotalMarks,
      boardDurationHours: syllabus.boardExamDurationHours.round(),
      questionsBySection: bySection,
      focusSectionId: mockFocusSectionId ??
          (boardSections.isEmpty ? null : boardSections.first.id),
      now: t,
    );
    final mockAttempts = <PracticeAttempt>[];
    var correct = 0;
    for (final slice in paper.sections) {
      for (final q in slice.questions) {
        final ok = answerCorrect(q.topicId, 'mock-${q.id}');
        if (ok) correct++;
        mockAttempts.add(PracticeAttempt(
          questionId: q.id,
          topicId: q.topicId,
          verdict: ok ? 'correct' : 'incorrect',
          retries: 0,
          attemptedAtIso: t.toIso8601String(),
        ));
        learner = learner.recordAttempt(topicId: q.topicId, correct: ok);
        evidence.add(ErrorEvidence(
          questionId: q.id,
          topicId: q.topicId,
          kind: 'mcq',
          verdict: ok ? 'correct' : 'incorrect',
          retries: 0,
          atIso: t.toIso8601String(),
        ));
      }
    }
    attempts += mockAttempts.length;
    xpTotal += ExamSessionXp.total(
        kind: ExamSessionKind.mock,
        correctCount: correct,
        totalCount: mockAttempts.length);
    sessions++;
    return MockEngine.analyze(paper: paper, attempts: mockAttempts, now: t);
  }

  // -- 1. Diagnostic ----------------------------------------------------

  final bank = DiagnosticItemBank.build(
    syllabus: syllabus,
    view: view,
    selection: selection,
  );
  final engine = ExamDiagnosticEngine(
    topicTitles: bank.topicTitles,
    topicSections: bank.topicSections,
  )..registerBank(bank.questions);

  var state = engine.start();
  var diagCorrect = 0;
  while (!state.finished) {
    final q = state.current!;
    final correct = answerCorrect(q.topicId, q.id);
    if (correct) diagCorrect++;
    state = engine.answer(
        state, correct ? q.correctIndex : (q.correctIndex + 1) % 4);
  }
  final report = engine.buildReport(state);
  learner = learner.mergeDiagnosticEstimates(report.estimatePairs);
  xpTotal += ExamSessionXp.total(
      kind: ExamSessionKind.diagnostic,
      correctCount: diagCorrect,
      totalCount: report.responses.length);
  attempts += report.responses.length;

  // -- 2. First plan ----------------------------------------------------

  var weak = runEngines();
  var plan = DeterministicExamPlanner.build(buildContext(
      weak.report, weak.decision, weak.revision));
  planCount++;

  // -- 3. Daily loop (7 days) -------------------------------------------

  for (var day = 1; day <= 7; day++) {
    if (spec.skipDays.contains(day)) {
      skippedDays++;
      continue;
    }

    // Persona E: edit the scope (§33 rebuild).
    if (spec.editScopeDay == day) {
      final all = view.selectableUnitIds.toList()..sort();
      final keep = all.take((all.length / 2).ceil()).toSet();
      selection = ExamScopeSelection.empty(view.trackId).selectAll(keep);
      scopeRevision++;
      weak = runEngines();
      plan = DeterministicExamPlanner.build(buildContext(
          weak.report, weak.decision, weak.revision));
      planCount++;
    }

    // Persona F: change the readiness target (§33 rebuild).
    if (spec.retargetDay == day && spec.retargetWeeks != null) {
      profile = ExamProfile(
        trackId: profile.trackId,
        dailyStudyMinutes: profile.dailyStudyMinutes,
        studyDaysPerWeek: profile.studyDaysPerWeek,
        readinessTargetDate:
            now.add(Duration(days: 7 * spec.retargetWeeks!)),
      );
      weak = runEngines();
      plan = DeterministicExamPlanner.build(buildContext(
          weak.report, weak.decision, weak.revision));
      planCount++;
    }

    final dayPlan = plan.days[(day - 1) % plan.days.length];

    for (final task in dayPlan.tasks) {
      // Persona G: student freedom — PYQ instead of practice (§20).
      if (spec.preferPyqOverPractice &&
          task.type == ExamTaskType.practice) {
        final pool = PyqBank.build(
                syllabus: syllabus, view: view, selection: selection)
            .take(6)
            .map((p) => p.question)
            .toList(growable: false);
        runPool(pool, ExamSessionKind.pyq);
        pyqAttempts += pool.length;
        continue;
      }
      switch (task.type) {
        case ExamTaskType.learn:
          break;
        case ExamTaskType.pyq:
          final pool = PyqBank.build(
                  syllabus: syllabus, view: view, selection: selection)
              .take(6)
              .map((p) => p.question)
              .toList(growable: false);
          runPool(pool, ExamSessionKind.pyq);
          pyqAttempts += pool.length;
        case ExamTaskType.mock:
          mockResult = runMiniMock(now.add(Duration(days: day)));
        case ExamTaskType.practice:
        case ExamTaskType.review:
        case ExamTaskType.weakArea:
          final pool = PracticeContentBank.build(
            syllabus: syllabus,
            view: view,
            selection: selection,
            weakTopicIds: learner
                .weakTopicsFirst(limit: 30)
                .map((t) => t.topicId)
                .toSet(),
            topicFilter: {task.topicId},
            targetSize: 6,
          );
          if (task.type == ExamTaskType.practice) practiceTasksDone++;
          final kind = switch (task.type) {
            ExamTaskType.practice => ExamSessionKind.practice,
            ExamTaskType.review => ExamSessionKind.revision,
            _ => ExamSessionKind.recovery,
          };
          runPool(pool, kind);
      }
    }
  }

  // -- 4. Final PYQ + mock regardless of plan shape ---------------------

  final pyqPool = PyqBank.build(
          syllabus: syllabus, view: view, selection: selection)
      .take(6)
      .map((p) => p.question)
      .toList(growable: false);
  runPool(pyqPool, ExamSessionKind.pyq);
  pyqAttempts += pyqPool.length;
  mockResult = runMiniMock(now.add(const Duration(days: 7)));

  // -- 5. Final engines + digest ----------------------------------------

  weak = runEngines();
  final daysLeft = profile.readinessTargetDate!.difference(now).inDays;
  final finalPlanTasks = plan.days.expand((d) => d.tasks).toList();

  return _JourneyDigest(
    diagnosticResponses: report.responses.length,
    diagCorrect: diagCorrect,
    sessions: sessions,
    skippedDays: skippedDays,
    scopeRevision: scopeRevision,
    selectedCount: selection.selectedUnitIds.length,
    planCount: planCount,
    xp: xpTotal,
    pyqAttempts: pyqAttempts,
    practiceTasksDone: practiceTasksDone,
    daysLeft: daysLeft,
    attempts: attempts,
    selectedIds: selection.selectedUnitIds.toSet(),
    finalPlanTasks: finalPlanTasks,
    mockResult: mockResult,
    learner: learner,
    weakFindings: weak.report.findings,
  );
}
