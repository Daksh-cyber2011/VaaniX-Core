/// Learn Mode 2.0 — AI Planner Output Parser (M4, Master Brief §13/§14)
///
/// The ONLY path from raw Gemini text to a [LearningPlan]. The model's
/// output is UNTRUSTED: this parser
///
///   1. extracts the JSON object (tolerating fences/prose — see
///      `extractPlanJson` in planner_prompt.dart);
///   2. accepts the full-plan shape or the single-decision shape from
///      Master Brief §14;
///   3. validates EVERY activity against the same rules the runtime
///      facade ([ValidatingPlanner]) enforces — concept exists, language
///      matches, activity type supported, difficulty in range, content
///      anchor consistent — so an AI plan that survives here also
///      survives there (defence in depth, never a shortcut);
///   4. drops invalid activities, dedupes repeats, caps plan size;
///   5. returns Left(Failure) when nothing valid remains — the provider
///      chain then falls back (cached → deterministic), never crashes.
///
/// The model can never inject an unknown concept, a foreign language, or
/// an unsupported command: those are structurally dropped HERE before any
/// caller sees them (Master Brief §14 "If invalid: fallback safely", §64).
///
/// Pure Dart; no Flutter imports.
library;

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Parses + validates raw planner text into a grounded [LearningPlan].
class AiPlanParser {
  AiPlanParser._();

  /// Maximum activities one AI plan may carry (a session, not a syllabus).
  static const int kMaxActivities = 8;

  /// Parses [rawText] — the model's reply — against [context].
  ///
  /// [now] is injectable for deterministic tests/ids.
  static Either<Failure, LearningPlan> parse(
    String rawText,
    PlannerContext context, {
    DateTime? now,
    int maxActivities = kMaxActivities,
  }) {
    final json = extractPlanJson(rawText);
    if (json == null) {
      return Left(const AiServiceFailure(
        'Planner output was not decodable JSON',
      ));
    }

    // Plan-level language gate (Master Brief §14 + §47): a plan that
    // claims another language is rejected whole — never executed.
    final claimedLanguage = _asString(json['language']);
    if (claimedLanguage.isNotEmpty &&
        claimedLanguage != context.languageCode) {
      return Left(AiServiceFailure(
        'Planner returned a plan for "$claimedLanguage" '
        'while learning "${context.languageCode}"',
      ));
    }

    final rawActivities = <Map<String, dynamic>>[];
    final list = json['activities'];
    if (list is List<dynamic>) {
      for (final item in list) {
        if (item is Map<String, dynamic>) rawActivities.add(item);
      }
    } else if (json['nextConcept'] != null) {
      // Master Brief §14 single-decision shape — normalise to one activity.
      rawActivities.add(json);
    }

    if (rawActivities.isEmpty) {
      return Left(const AiServiceFailure(
        'Planner output contained no activities',
      ));
    }

    final timestamp = now ?? DateTime.now();
    final activities = <LearningActivity>[];
    // Dedupe per (concept, kind): a plan MAY review and then practise the
    // same concept, but eight identical practice steps are junk.
    final seenSteps = <String>{};

    for (final raw in rawActivities) {
      if (activities.length >= maxActivities) break;
      final activity = _buildActivity(raw, context, seenSteps);
      if (activity != null) activities.add(activity);
    }

    if (activities.isEmpty) {
      return Left(const AiServiceFailure(
        'Planner produced no grounded activities',
      ));
    }

    return Right(
      LearningPlan(
        id: 'plan-ai-${timestamp.millisecondsSinceEpoch}',
        languageCode: context.languageCode,
        source: PlanSource.ai,
        activities: activities,
        focusSummary: _focusSummary(json) ??
            'Your ${context.languageName} plan for today.',
        createdAt: timestamp,
      ),
    );
  }

  /// Maps the planner's 1..5 difficulty knob onto the app's [Difficulty]
  /// bands (the same vocabulary the curricula use).
  static Difficulty difficultyFromKnob(int knob) {
    if (knob <= 2) return Difficulty.beginner;
    if (knob == 3) return Difficulty.intermediate;
    return Difficulty.advanced;
  }

  /// Validates ONE raw activity against the trusted context and builds
  /// the typed [LearningActivity] — or `null` when the step is invalid
  /// (mirrors the §14 validation list; invalid means DROPPED, never
  /// "fixed" — silently rewriting AI output would hide grounding bugs).
  static LearningActivity? _buildActivity(
    Map<String, dynamic> raw,
    PlannerContext context,
    Set<String> seenSteps,
  ) {
    final kind = ActivityKind.tryParse(_asString(raw['activityType']));
    if (kind == null || !context.supportedActivityTypes.contains(kind)) {
      return null; // unknown/unsupported activity type
    }

    final conceptId = _asString(raw['conceptId'] ?? raw['nextConcept']);
    if (conceptId.isEmpty) return null; // no concept anchor at all
    if (!seenSteps.add('$conceptId:${kind.name}')) {
      return null; // duplicate step (same concept, same kind)
    }

    final concept = context.graph.conceptById(conceptId);
    if (concept == null) return null; // §14: concept exists
    if (concept.languageCode != context.graph.languageCode) {
      return null; // §14: language matches (graph-level defence)
    }

    // §14: content source available — the lesson hint (when given) must
    // be the concept's own trusted anchor.
    final lessonHint = _asString(raw['lessonId']);
    if (lessonHint.isNotEmpty && lessonHint != concept.lessonId) {
      return null;
    }

    // §14: difficulty valid (1..5).
    final knob = (raw['difficulty'] is num)
        ? (raw['difficulty'] as num).toInt()
        : 0;
    if (knob < PlannerDecision.kMinDifficulty ||
        knob > PlannerDecision.kMaxDifficulty) {
      return null;
    }

    // The reason is what the learner reads (Master Brief §44); an empty
    // one means the step has no honest "why" and is dropped.
    final reason = _asString(raw['reason']).trim();
    if (reason.isEmpty) return null;

    final minutes = (raw['estimatedMinutes'] is num)
        ? (raw['estimatedMinutes'] as num).toInt()
        : 5;

    return LearningActivity(
      id: 'act-ai-${concept.id}',
      kind: kind,
      title: _titleFor(raw, kind, concept.title),
      reason: reason,
      conceptId: concept.id,
      lessonId: concept.lessonId,
      difficulty: difficultyFromKnob(knob),
      estimatedMinutes: minutes.clamp(1, 30).toInt(),
    );
  }

  /// AI-supplied title when usable, otherwise a stable label built from
  /// the kind + the trusted concept title (never model-invented fluff
  /// around an unknown name).
  static String _titleFor(
    Map<String, dynamic> raw,
    ActivityKind kind,
    String conceptTitle,
  ) {
    final supplied = _asString(raw['title']).trim();
    if (supplied.isNotEmpty) return supplied;
    final prefix = switch (kind) {
      ActivityKind.newLearning => '',
      ActivityKind.practice => 'Practice: ',
      ActivityKind.review => 'Review: ',
      ActivityKind.weakRepair => 'Fix: ',
      ActivityKind.masteryCheck => 'Check: ',
      ActivityKind.challenge => 'Challenge: ',
    };
    return '$prefix$conceptTitle';
  }

  static String? _focusSummary(Map<String, dynamic> json) {
    final summary = _asString(json['focusSummary']).trim();
    return summary.isEmpty ? null : summary;
  }

  static String _asString(Object? value) => value is String ? value : '';
}
