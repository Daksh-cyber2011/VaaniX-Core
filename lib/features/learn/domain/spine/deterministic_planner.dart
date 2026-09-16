/// Learn Mode 2.0 — Deterministic Planner (M1 Architecture Spine)
///
/// The local, offline, zero-cost planner that guarantees Learn Mode keeps
/// working when AI is unavailable (Master Brief §36/§60 fallback chain):
///
///   AI plan (M4) → cached plan → [DeterministicPlanner] → empty-but-valid
///
/// It converts the EXISTING proven adaptive ladder (progress/adaptive.dart:
/// weak-repair before advance, curriculum-order progression) into the new
/// concept-based [LearningPlan] format, driven by the trusted graph and
/// real progress evidence. No randomness, no fabrication — every activity
/// traces back to graph concepts.
///
/// The Gemini planner (M4) implements the same [LearningPlanner] contract
/// and is wrapped by the same [ValidatingPlanner]; swapping is one line in
/// the provider wiring.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';

/// Activity kinds the deterministic planner emits. Kept explicit so the
/// provider wiring and the validation tests share one source of truth.
const Set<ActivityKind> kDeterministicPlannerActivityKinds = <ActivityKind>{
  ActivityKind.newLearning,
  ActivityKind.practice,
  ActivityKind.review,
  ActivityKind.weakRepair,
  ActivityKind.masteryCheck,
  ActivityKind.challenge,
};

/// Deterministic, grounded plan builder.
class DeterministicPlanner implements LearningPlanner {
  const DeterministicPlanner();

  /// Maximum activities per plan (matches [ValidatingPlanner] default).
  static const int kMaxPlanActivities = 6;

  @override
  String get id => 'deterministic-v1';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(
    PlannerContext context,
  ) async {
    final graph = context.graph;

    // Empty curriculum (stub languages) → valid empty plan; the UI shows
    // its own "coming soon" state. Never an error.
    if (graph.isEmpty) {
      return Right(
        LearningPlan.empty(
          languageCode: context.languageCode,
          source: PlanSource.deterministic,
          id: 'plan-empty-${context.languageCode}',
          reason: 'Curriculum for ${context.languageName} is on its way.',
        ),
      );
    }

    final state = context.state;
    final activities = <LearningActivity>[];

    // ── 1. Weak repair: completed-but-unmastered concepts come FIRST
    //      (the proven "lock it in before moving on" ladder).
    final weak = <LearnConcept>[];
    for (final concept in graph.concepts) {
      final mastery = state.conceptMasteries[concept.id];
      if (mastery == null) continue; // not started → not "weak"
      if (mastery.stage.index < MasteryStage.understood.index)
        weak.add(concept);
    }
    for (final concept in weak.take(2)) {
      activities.add(LearningActivity(
        id: 'act-repair-${concept.id}',
        kind: ActivityKind.weakRepair,
        title: 'Practice: ${concept.title}',
        reason: '${concept.title} still needs practice to lock it in.',
        conceptId: concept.id,
        lessonId: concept.lessonId,
        difficulty: concept.difficulty,
        estimatedMinutes: 5,
      ));
    }

    // ── 2. Review queue: due reviews next (M1 queue is derived; M6 fills
    //      it with scheduling. Empty today, the rule is ready).
    for (final entry in state.reviewQueue.take(2)) {
      final concept = graph.conceptById(entry.conceptId);
      if (concept == null) continue; // stale queue entry — skip, not crash
      activities.add(LearningActivity(
        id: 'act-review-${concept.id}',
        kind: ActivityKind.review,
        title: 'Review: ${concept.title}',
        reason: 'A quick review keeps ${concept.title} fresh.',
        conceptId: concept.id,
        lessonId: concept.lessonId,
        difficulty: concept.difficulty,
        estimatedMinutes: 3,
      ));
    }

    // ── 3. New learning: the next unlocked, unstarted concept.
    if (activities.length < kMaxPlanActivities) {
      final started = {
        for (final e in state.conceptMasteries.entries) e.key,
      };
      LearnConcept? next;
      for (final concept in graph.concepts) {
        if (started.contains(concept.id)) continue;
        if (!graph.isUnlocked(concept.id, {
          for (final e in state.conceptMasteries.entries) e.key: e.value.stage,
        })) {
          continue;
        }
        next = concept;
        break;
      }
      if (next != null) {
        activities.add(LearningActivity(
          id: 'act-new-${next.id}',
          kind: ActivityKind.newLearning,
          title: next.title,
          reason: 'Up next on your ${context.languageName} journey.',
          conceptId: next.id,
          lessonId: next.lessonId,
          difficulty: next.difficulty,
          estimatedMinutes: 7,
        ));
      }
    }

    // ── 4. Closing practice on the most recently started concept, when
    //      there is session room left.
    if (activities.length < kMaxPlanActivities) {
      LearnConcept? lastStarted;
      var bestOrder = -1;
      for (final e in state.conceptMasteries.entries) {
        final concept = graph.conceptById(e.key);
        if (concept == null) continue;
        if (concept.order > bestOrder) {
          bestOrder = concept.order;
          lastStarted = concept;
        }
      }
      if (lastStarted != null) {
        activities.add(LearningActivity(
          id: 'act-practice-${lastStarted.id}',
          kind: ActivityKind.practice,
          title: 'Practice: ${lastStarted.title}',
          reason: 'One more round on ${lastStarted.title} makes it stick.',
          conceptId: lastStarted.id,
          lessonId: lastStarted.lessonId,
          difficulty: lastStarted.difficulty,
          estimatedMinutes: 5,
        ));
      }
    }

    // Everything grounded already; still run the trim through the same
    // cap the validating facade uses.
    final bounded = activities.take(kMaxPlanActivities).toList();

    return Right(
      LearningPlan(
        id: 'plan-det-${context.languageCode}-${bounded.length}',
        languageCode: context.languageCode,
        source: PlanSource.deterministic,
        activities: bounded,
        focusSummary: bounded.isEmpty
            ? 'All caught up — revise with VAN anytime.'
            : _focusLine(context),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Human one-liner (Master Brief §44 — personal, no jargon).
  String _focusLine(PlannerContext context) {
    final state = context.state;
    final done = state.conceptIdsAtLeast(MasteryStage.understood).length;
    final total = context.graph.concepts.length;
    if (done == 0) {
      return 'Let us begin your ${context.languageName} journey.';
    }
    return '$done of $total concepts locked in — keep the momentum!';
  }
}
