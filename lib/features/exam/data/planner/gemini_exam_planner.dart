/// Exam Mode 2.0 — Gemini Exam Planner (M5, §13–§18, §42)
///
/// The Gemini-backed exam planner, mirroring the Learn Mode M4 planner
/// discipline (EXTEND the proven pattern, master plan §53):
///
///   PlannerInputs (scope + learner profile + exam profile)
///     → structured prompts (bounded digest, STRICT JSON schema)
///     → [PlannerTextClient] (the ONLY network hop; the SAME interface
///       and rate-limit budget the Learn planner uses — §18 one
///       app-wide Gemini budget)
///     → ExamPlanParser (untrusted text → typed plan)
///     → [ExamPlanValidator] (§16 checks; the app enforces, §14)
///     → write-through plan cache (feeds the fallback chain, §17)
///     → Right(plan) — or Left(Failure), NEVER a throw
///
/// Failure modes that must NOT break the student (§17): no API key,
/// outage, timeout, rate limit, garbage JSON, hallucinated topics,
/// over-budget days. Every one becomes a Left so the provider chain
/// falls through: cached plan → deterministic planner.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_validator.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart'
    show PlannerTextClient;

/// Everything the planner needs (§13 inputs): VERIFIED SYLLABUS +
/// SELECTED SCOPE + LEARNER PROFILE + READINESS TARGET + AVAILABLE
/// TIME. Trusted content rides inside the scope digest (official
/// syllabus data only — Gemini never decides syllabus truth, §14).
class ExamPlannerContext {
  const ExamPlannerContext({
    required this.trackId,
    required this.view,
    required this.selection,
    required this.profile,
    required this.learner,
    required this.scopeRevision,
    this.weakAreaDigest = const [],
    this.studentOverrideTopicIds = const [],
  });

  final String trackId;
  final ExamScopeView view;
  final ExamScopeSelection selection;
  final ExamProfile profile;
  final ExamLearnerProfile learner;
  final int scopeRevision;

  /// M8 weak-area lines (§21/§22/§23 digest for the prompt): findings
  /// + the recommended recovery day + due revision topics. Empty = no
  /// weak-area evidence yet (honest omission, never fabrication).
  final List<String> weakAreaDigest;

  /// Recent student-led topic choices. They are trusted only after the
  /// application filters them against [selection]; Gemini never receives a
  /// free-form topic outside the official scope.
  final List<String> studentOverrideTopicIds;
}

/// Prompt builder — bounded, structured, strict-schema (§18).
class ExamPlannerPrompt {
  const ExamPlannerPrompt._();

  static String system() => '''
You are the VaaniX exam planner engine for Indian CBSE students.
You create a personalized 7-day study plan as STRICT JSON.

HARD CONSTRAINTS:
- Use ONLY topicId values from the provided SCOPE list. Never invent ids.
- Every day's total minutes MUST be <= the available daily minutes.
- days: exactly 7 entries, dayIndex 0..6 (day 0 = today).
- Each day: 1-4 tasks; every day includes at least one "learn" or "practice" task.
- task types: learn | practice | review | pyq | weakArea | mock.
- task minutes: 5..60.
- "pyq"/"mock" tasks schedule the SLOT only; title must include "PYQ" or "mock" honestly.
- If a WEAK AREA section is provided, schedule its recovery-day recommendation exactly (one
  day's weakArea task on the stated focus topic) and prefer review tasks on its due revision
  topics. Never turn every day into weak-area work.
- rationale: one short paragraph in Hindi explaining priorities (explainable plan).
- STUDENT PREFERENCE is a voluntary in-scope choice. Respect it by giving
  the preferred topic an early non-recovery task; do not guilt or override the student.

OUTPUT ONLY this JSON schema, no prose, no markdown fences:
{"focusSummary": "...", "rationale": "...", "days": [{"dayIndex": 0, "tasks": [{"type": "learn", "topicId": "...", "title": "...", "minutes": 15}]}]}
''';

  static String user(ExamPlannerContext ctx) {
    final scopeLines = <String>[];
    for (final section in ctx.view.sections) {
      for (final unit in section.selectableUnits) {
        if (ctx.selection.isSelected(unit.id)) {
          final marks = unit.marks == null
              ? ''
              : ' [${unit.marks!.toStringAsFixed(0)} marks]';
          scopeLines
              .add('- ${unit.id}$marks: ${unit.title} (${section.title})');
        }
      }
    }
    final weak = ctx.learner.weakTopicsFirst(limit: 8);
    final List<String> learnerLines = ctx.learner.hasDiagnostic
        ? (weak.isEmpty
            ? <String>['- diagnostic: no weak topics']
            : weak.map((t) => '- ${t.topicId}: ${t.stage.name}').toList())
        : const <String>['- diagnostic: not taken yet'];

    final anchor = ctx.profile.readinessAnchor(DateTime.now());
    final anchorLine = anchor == null
        ? 'readiness anchor: unknown'
        : 'readiness anchor: ${anchor.toIso8601String().substring(0, 10)} '
            '(${ctx.profile.weeksToAnchor(DateTime.now()) ?? '?'} weeks away)';

    final weakAreaBlock = ctx.weakAreaDigest.isEmpty
        ? ''
        : 'WEAK AREA (evidence-based — respect it):\n'
            '${ctx.weakAreaDigest.join('\n')}\n';
    final preferred = ctx.studentOverrideTopicIds
        .where(ctx.selection.isSelected)
        .take(3)
        .toList(growable: false);
    final preferenceBlock = preferred.isEmpty
        ? ''
        : 'STUDENT PREFERENCE (selected scope ids): ${preferred.join(', ')}\n';

    return '''
COURSE: ${ctx.trackId}
STUDENT BUDGET: ${ctx.profile.dailyStudyMinutes} min/day, ${ctx.profile.studyDaysPerWeek} days/week
$anchorLine
SCOPE (topicId — title):
${scopeLines.join('\n')}
LEARNER PROFILE:
${learnerLines.join('\n')}
$weakAreaBlock
$preferenceBlock
Create the 7-day plan JSON now.
''';
  }
}

/// Untrusted-text → typed plan parser (§16: structural validation).
class ExamPlanParser {
  const ExamPlanParser._();

  /// Tolerant parse: accepts fenced ```json blocks, strips prose
  /// before/after. Returns null when no JSON object is recoverable.
  static Map<String, dynamic>? _extractJson(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final obj = jsonDecode(text.substring(start, end + 1));
      return obj is Map<String, dynamic> ? obj : null;
    } catch (_) {
      return null;
    }
  }

  /// Parses raw model output into a validated-or-Left plan.
  static Either<Failure, ExamPlan> parse(String raw, ExamPlannerContext ctx) {
    final json = _extractJson(raw);
    if (json == null) {
      return const Left(AiServiceFailure('Planner output was not JSON'));
    }
    json['id'] = 'plan-${ctx.trackId}-${ctx.scopeRevision}';
    json['trackId'] = ctx.trackId;
    json['source'] = 'ai';
    json['scopeRevision'] = ctx.scopeRevision;
    json['createdAtIso'] = DateTime.now().toIso8601String();
    final plan = ExamPlan.fromJson(json);
    if (plan.days.isEmpty) {
      return const Left(AiServiceFailure('Planner plan had no days'));
    }
    final violations = ExamPlanValidator.validate(
      plan: plan,
      view: ctx.view,
      selection: ctx.selection,
      profile: ctx.profile,
    );
    if (violations.isNotEmpty) {
      // §16: hallucination/out-of-budget → reject, chain falls back.
      return Left(AiServiceFailure(
          'Plan failed validation (${violations.length} issues); '
          'fallback engaged'));
    }
    return Right(plan);
  }
}

/// The M5 Gemini planner.
class GeminiExamPlanner {
  GeminiExamPlanner({
    required PlannerTextClient textClient,
    void Function(ExamPlan plan)? onPlanAccepted,
  })  : _textClient = textClient,
        _onPlanAccepted = onPlanAccepted;

  @visibleForTesting
  static const Duration requestTimeout = Duration(seconds: 15);

  final PlannerTextClient _textClient;
  final void Function(ExamPlan plan)? _onPlanAccepted;

  Future<Either<Failure, ExamPlan>> buildPlan(ExamPlannerContext ctx) async {
    try {
      // Unconfigured/offline → immediate Left, zero cost (§17).
      if (!_textClient.isAvailable) {
        return const Left(
            AiServiceFailure('AI planner is not available right now'));
      }
      final raw = await _textClient
          .complete(
              system: ExamPlannerPrompt.system(),
              user: ExamPlannerPrompt.user(ctx))
          .timeout(requestTimeout);
      final result = ExamPlanParser.parse(raw, ctx);
      result.fold(
        (_) {},
        (plan) => _onPlanAccepted?.call(plan), // write-through cache hook
      );
      return result;
    } on TimeoutException {
      return const Left(TimeoutFailure());
    } catch (e) {
      // Never leak raw exception text into Failure messages.
      return const Left(
          AiServiceFailure('VAN could not reach the planner just now. '
              'The offline plan takes over automatically.'));
    }
  }
}
