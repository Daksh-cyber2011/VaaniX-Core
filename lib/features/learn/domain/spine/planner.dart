/// Learn Mode 2.0 — Planner Contract (M1 Architecture Spine)
///
/// The AI-facing boundary of Learn Mode (Master Brief §9/§13/§14):
///
///   PlannerContext (structured learner state)  →  LearningPlanner  →
///   LearningPlan (structured, validated)
///
/// Design commitments (all from the Master Brief):
/// - the planner CONSUMES structured learner state and PRODUCES structured
///   plans — never free prose driving navigation (§13);
/// - the AI provider stays replaceable: M1 ships the deterministic local
///   planner; M4 plugs Gemini in BEHIND the same interface (§9, §36);
/// - if the planner fails, Learn Mode degrades gracefully: cached plan →
///   deterministic plan → empty-but-valid plan (§36/§60);
/// - AI never handles security-sensitive logic (§64) — this contract only
///   ever produces educational plans.
///
/// [ValidatingPlanner] is the runtime guard: every delegate plan is checked
/// activity-by-activity against the trusted graph; invalid activities are
/// dropped, and a plan with nothing valid left falls back.
///
/// Pure Dart; no Flutter imports (dartz matches project conventions).
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart'
    show MasteryStage;

/// Structured learner state handed to every planner call
/// (Master Brief §13 field list).
class PlannerContext extends Equatable {
  const PlannerContext({
    required this.languageCode,
    required this.languageName,
    required this.graph,
    required this.state,
    required this.supportedActivityTypes,
    this.profile,
    this.diagnostic,
    this.minutesAvailable = 10,
    this.recentMistakeTitles = const <String>[],
  });

  /// ISO 639-1 code + English name of the active language.
  final String languageCode;
  final String languageName;

  /// The trusted knowledge graph for [languageCode] (validation anchor).
  final ConceptGraph graph;

  /// Evidence side of the learner model.
  final LearningState state;

  /// Intent side (goal / desired level / pace), when known.
  final LearnerProfile? profile;

  /// Placement result, when the learner has been diagnosed (M3 output).
  final DiagnosticResult? diagnostic;

  /// Session sizing (Master Brief §27 — 5/10/20/30 minute sessions).
  final int minutesAvailable;

  /// Titles of recently mistaken concepts (bounded input for prompt
  /// assembly, M4; bounded to keep prompts small).
  final List<String> recentMistakeTitles;

  /// Activity kinds the current build can actually execute. Anything
  /// outside this set is rejected during validation.
  final Set<ActivityKind> supportedActivityTypes;

  /// Concept ids at/above [stage] — convenience for prompt assembly.
  List<String> conceptIdsAtLeast(MasteryStage stage) =>
      state.conceptIdsAtLeast(stage);

  /// Compact, structured digest used by prompt assembly (M4). Pure data —
  /// no prose, no jargon leaks to the user.
  Map<String, Object?> toStructuredDigest() => {
        'language': languageCode,
        'languageName': languageName,
        'currentLevel': profile?.currentLevel,
        'desiredLevel': profile?.desiredLevel.name,
        'goal': profile?.goal.name,
        'pace': profile?.pace.name,
        'minutesAvailable': minutesAvailable,
        'masteredConcepts': state.conceptIdsAtLeast(MasteryStage.understood),
        'weakConcepts': [
          for (final e in state.conceptMasteries.entries)
            if (e.value.stage.index < MasteryStage.understood.index) e.key,
        ],
        'reviewQueue': [for (final r in state.reviewQueue) r.conceptId],
        'recentMistakes': recentMistakeTitles,
        'diagnostic': diagnostic == null
            ? null
            : {
                'overallLevel': diagnostic!.overallLevel,
                'dimensions': {
                  for (final e in diagnostic!.dimensionScores.entries)
                    e.key.name: e.value.score,
                },
              },
        'graphSize': graph.concepts.length,
      };

  @override
  List<Object?> get props => [
        languageCode,
        languageName,
        graph,
        state,
        supportedActivityTypes,
        profile,
        diagnostic,
        minutesAvailable,
        recentMistakeTitles,
      ];
}

/// The replaceable planning boundary. M1: [DeterministicPlanner].
/// M4: a Gemini-backed implementation behind this same contract.
abstract interface class LearningPlanner {
  /// Stable planner id (used for cache keys + diagnostics).
  String get id;

  /// Builds a plan for [context]. Implementations MUST NOT throw for
  /// expected failure modes (timeout, rate limit, bad output) — they
  /// return Left(Failure) and the caller/facade falls back.
  Future<Either<Failure, LearningPlan>> buildPlan(PlannerContext context);
}

/// Runtime guard around ANY planner (Master Brief §14).
///
/// Validates every activity of the delegate's plan against the trusted
/// graph:
/// - unknown concept → activity dropped;
/// - language mismatch → activity dropped;
/// - unsupported activity kind → activity dropped;
/// - lesson anchor missing → activity dropped.
///
/// If nothing survives, the FALLBACK planner runs (deterministic by
/// default). The facade therefore guarantees: a returned plan is
/// grounded, language-safe, and executable — or empty-but-valid.
class ValidatingPlanner implements LearningPlanner {
  ValidatingPlanner({
    required this.delegate,
    required this.fallback,
    this.maxActivities = 10,
  });

  /// The planner being guarded (AI planner in M4).
  final LearningPlanner delegate;

  /// Used when the delegate fails or produces nothing valid.
  final LearningPlanner fallback;

  /// Plan size bound (keeps AI output from flooding a session).
  final int maxActivities;

  @override
  String get id => 'validating(${delegate.id}->${fallback.id})';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
    PlannerContext context,
  ) async {
    final result = await delegate.buildPlan(context);

    return result.fold(
      (failure) async {
        // Delegate failed outright → fallback chain (Master Brief §60).
        return _fallbackPlan(context, failure);
      },
      (plan) async {
        // Plan-level language gate: a plan for another language is never
        // executed, even if its activities look valid (Master Brief §47).
        if (plan.activities.isEmpty ||
            plan.languageCode != context.languageCode) {
          return _fallbackPlan(
            context,
            UnknownFailure(
                plan.activities.isEmpty
                    ? 'Planner returned an empty plan'
                    : 'Planner returned a plan for a different language',
            ),
          );
        }

        final valid = <LearningActivity>[];
        for (final activity in plan.activities.take(maxActivities)) {
          if (_activityIsValid(activity, context)) valid.add(activity);
        }

        if (valid.isEmpty) {
          return _fallbackPlan(
            context,
            UnknownFailure('Planner produced no grounded activities'),
          );
        }

        return Right(
          LearningPlan(
            id: plan.id,
            languageCode: plan.languageCode,
            source: plan.source,
            activities: valid,
            focusSummary: plan.focusSummary,
            createdAt: plan.createdAt,
          ),
        );
      },
    );
  }

  Future<Either<Failure, LearningPlan>> _fallbackPlan(
    PlannerContext context,
    Failure cause,
  ) async {
    final fallbackResult = await fallback.buildPlan(context);
    return fallbackResult.fold(
      (fallbackFailure) => Left(
        UnknownFailure(
          'Planner and fallback both failed: ${fallbackFailure.message}',
        ),
      ),
      (plan) => Right(plan),
    );
  }

  /// Grounding check for one activity (graph + language + support).
  bool _activityIsValid(LearningActivity activity, PlannerContext context) {
    if (activity.id.isEmpty || activity.title.trim().isEmpty) return false;
    if (activity.kind == ActivityKind.newLearning ||
        activity.kind == ActivityKind.review ||
        activity.kind == ActivityKind.practice ||
        activity.kind == ActivityKind.weakRepair ||
        activity.kind == ActivityKind.masteryCheck) {
      if (activity.conceptId == null) return false;
    }

    if (!context.supportedActivityTypes.contains(activity.kind)) return false;

    final conceptId = activity.conceptId;
    if (conceptId != null) {
      final concept = context.graph.conceptById(conceptId);
      if (concept == null) return false; // unknown concept
      if (concept.languageCode != context.graph.languageCode) return false;
      // Lesson anchor must be the concept's trusted content.
      if (activity.lessonId != null &&
          activity.lessonId != concept.lessonId) {
        return false;
      }
    } else if (activity.kind == ActivityKind.challenge) {
      // Challenges may be language-wide without a single concept, but the
      // language tag must still match.
      if (activity.lessonId != null &&
          context.graph.conceptForLesson(activity.lessonId!) == null) {
        return false;
      }
    } else {
      return false; // every non-challenge activity needs a concept anchor
    }
    return true;
  }
}
