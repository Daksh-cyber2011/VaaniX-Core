/// Learn Mode 2.0 — Mastery Scheduling & Evidence Overlay (M6, Master
/// Brief §19/§20)
///
/// The session-driven HALF of the mastery engine M1 reserved (the
/// vocabulary in `mastery.dart`/`evaluation.dart` existed; nothing drove
/// it). Three jobs, all deterministic and evidence-gated:
///
/// 1. STAGE UPLIFT (§19 ladder) — session kinds EARN the upper stages
///    the M1 derivation could not:
///
///       understood → recalled   (review session, correct first-try)
///       → applied               (challenge session, correct first-try)
///       → mastered              (mastery check passed ≥80% first-try)
///       → maintained            (review of a mastered concept, correct)
///
///    Every uplift requires PRIOR evidence the concept was already
///    learned (practiced+): the engine never promotes what was never
///    seen, and never skips a rung backwards — evidence can only RAISE
///    a stage.
///
/// 2. REVIEW SCHEDULING (§20 — deliberately practical, no fake
///    scientific model):
///
///       recently weak  → review soon  (due in 1 day,  high priority)
///       strong, aging  → review later (due in 3 days, medium priority)
///       mastered+      → maintenance  (due in 7 days, low priority)
///
/// 3. EVIDENCE OVERLAY — merges session-evidence masteries (persisted
///    in the `learn_profile_<iso>_state` extras, a channel M3 opened)
///    onto the M1-derived state WITHOUT ever lowering it: derivation
///    stays authoritative for progress-backed stages; evidence only
///    adds what derivation cannot know (upper stages, recency, due
///    dates).
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';

/// Tunables of the practical review policy (§20 — "a practical adaptive
/// review system is enough").
abstract final class ReviewPolicy {
  /// A missed concept is reviewed SOON.
  static const int kReviewSoonDays = 1;

  /// A strong-but-aging concept is reviewed LATER.
  static const int kAgingReviewDays = 3;

  /// Mastered concepts get low-frequency maintenance reviews.
  static const int kMaintenanceReviewDays = 7;

  /// A concept counts as "aging" when it was last practised at least
  /// this long ago.
  static const Duration kAgingThreshold = Duration(days: 3);

  /// First-try accuracy a mastery check must reach to certify mastery.
  static const double kMasteryCheckAccuracy = 0.8;

  /// Minimum attempts before a mastery check result counts.
  static const int kMasteryCheckMinAttempts = 2;

  /// Hard cap on the persisted review queue (keeps the planner digest
  /// small; the diagnostic seeds up to 8, sessions keep it at most 12).
  static const int kMaxQueueEntries = 12;
}

/// Per-concept evidence accumulated by ONE session (or merged across
/// sessions when re-persisted).
class SessionConceptEvidence extends Equatable {
  const SessionConceptEvidence({
    required this.conceptId,
    this.attempts = 0,
    this.correctCount = 0,
    this.firstTryCount = 0,
    this.lastPracticedAt,
  });

  final String conceptId;
  final int attempts;
  final int correctCount;
  final int firstTryCount;
  final DateTime? lastPracticedAt;

  double? get firstTryAccuracy =>
      attempts == 0 ? null : firstTryCount / attempts;

  SessionConceptEvidence merge(SessionConceptEvidence other) =>
      SessionConceptEvidence(
        conceptId: conceptId,
        attempts: attempts + other.attempts,
        correctCount: correctCount + other.correctCount,
        firstTryCount: firstTryCount + other.firstTryCount,
        lastPracticedAt: _latest(lastPracticedAt, other.lastPracticedAt),
      );

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  @override
  List<Object?> get props =>
      [conceptId, attempts, correctCount, firstTryCount, lastPracticedAt];
}

/// Aggregates engine answer records into per-concept evidence.
Map<String, SessionConceptEvidence> evidenceFromRecords(
  List<SessionAnswerRecord> records, {
  required DateTime at,
}) {
  final map = <String, SessionConceptEvidence>{};
  for (final record in records) {
    final current = map[record.conceptId] ??
        SessionConceptEvidence(conceptId: record.conceptId);
    map[record.conceptId] = SessionConceptEvidence(
      conceptId: record.conceptId,
      attempts: current.attempts + 1,
      correctCount: current.correctCount + (record.correct ? 1 : 0),
      firstTryCount:
          current.firstTryCount + (record.correct && record.firstTry ? 1 : 0),
      lastPracticedAt: at,
    );
  }
  return map;
}

/// The stage a session's evidence HONESTLY earns for one concept, given
/// its current stage (derived merged with prior evidence; `null` = the
/// concept has no learning record at all).
///
/// Returns `null` when this session kind provides no uplift (wrong
/// answers never uplift; the ladder stages each need their own kind of
/// evidence — see the library docs).
MasteryStage? evidenceStageFor({
  required ActivityKind kind,
  required SessionConceptEvidence evidence,
  required MasteryStage? currentStage,
}) {
  final stage = currentStage;
  if (evidence.firstTryCount <= 0) return null; // no positive evidence

  bool learnedEnough() =>
      stage != null && stage.index >= MasteryStage.practiced.index;

  switch (kind) {
    case ActivityKind.review:
      // Recalling previously-learned material on request.
      if (!learnedEnough()) return null;
      if (stage!.index >= MasteryStage.mastered.index) {
        return MasteryStage.maintained;
      }
      return MasteryStage.recalled;

    case ActivityKind.challenge:
      // Applying knowledge on harder, unsupported material.
      if (!learnedEnough()) return null;
      return MasteryStage.applied;

    case ActivityKind.masteryCheck:
      // A strict check certifies mastery of understood material.
      final accuracy = evidence.firstTryAccuracy ?? 0;
      if (stage == null ||
          stage.index < MasteryStage.understood.index ||
          evidence.attempts < ReviewPolicy.kMasteryCheckMinAttempts ||
          accuracy < ReviewPolicy.kMasteryCheckAccuracy) {
        return null;
      }
      return MasteryStage.mastered;

    case ActivityKind.newLearning:
    case ActivityKind.practice:
    case ActivityKind.weakRepair:
      // These kinds build evidence (counts/strength) but the M1
      // derivation already covers their reachable stages; no uplift.
      return null;
  }
}

/// Builds the evidence masteries to PERSIST for one finished session:
/// prior extras masteries (accumulated session evidence) merged with
/// this session's uplift. Stages only rise; counters accumulate;
/// `lastPracticedAt` takes the newest.
Map<String, ConceptMastery> buildEvidenceMasteries({
  required ActivityKind kind,
  required Map<String, SessionConceptEvidence> evidence,
  required Map<String, ConceptMastery> priorEvidence,
  required Map<String, MasteryStage?> currentStages,
  required DateTime at,
}) {
  final merged = <String, ConceptMastery>{...priorEvidence};
  evidence.forEach((conceptId, sessionEvidence) {
    final prior = priorEvidence[conceptId];
    final derivedStage = currentStages[conceptId];
    final currentStage = _maxStage(derivedStage, prior?.stage);
    final uplift = evidenceStageFor(
      kind: kind,
      evidence: sessionEvidence,
      currentStage: currentStage,
    );

    final evidenceMastery = ConceptMastery(
      conceptId: conceptId,
      // No uplift → keep the prior evidence stage (may be null-stage
      // via `introduced` placeholder only when prior evidence exists).
      stage: uplift ?? prior?.stage ?? MasteryStage.introduced,
      strength: sessionEvidence.attempts == 0
          ? 0
          : sessionEvidence.correctCount / sessionEvidence.attempts,
      correctCount: sessionEvidence.correctCount,
      attemptCount: sessionEvidence.attempts,
      lastPracticedAt: sessionEvidence.lastPracticedAt,
    );

    merged[conceptId] = prior == null
        ? evidenceMastery
        : ConceptMastery(
            conceptId: conceptId,
            stage: _maxStage(prior.stage, uplift ?? prior.stage)!,
            strength: prior.strength >= evidenceMastery.strength
                ? prior.strength
                : evidenceMastery.strength,
            // Accumulated session counters (NOT the derived progress
            // counters — those stay with the derivation).
            correctCount: prior.correctCount + evidenceMastery.correctCount,
            attemptCount: prior.attemptCount + evidenceMastery.attemptCount,
            lastPracticedAt: SessionConceptEvidence._latest(
              prior.lastPracticedAt,
              evidenceMastery.lastPracticedAt,
            ),
            reviewDueAt: prior.reviewDueAt,
          );
  });
  return merged;
}

/// Computes the review-queue updates one finished session produces
/// (§20 policy). Only REAL evidence this session produced changes the
/// queue; concepts untouched by the session keep their entries.
List<ReviewEntry> scheduleReviewUpdates({
  required ActivityKind kind,
  required Map<String, SessionConceptEvidence> evidence,
  required Map<String, MasteryStage?> currentStages,
  required Map<String, DateTime?> lastPracticedByConcept,
  required DateTime now,
}) {
  final updates = <ReviewEntry>[];
  evidence.forEach((conceptId, sessionEvidence) {
    if (sessionEvidence.attempts == 0) return;
    final stage = currentStages[conceptId];

    // Missed this session → review SOON (highest priority).
    if (sessionEvidence.correctCount < sessionEvidence.attempts) {
      updates.add(ReviewEntry(
        conceptId: conceptId,
        reason: ReviewReason.recentlyWeak,
        priority: 0.85,
        dueAt: now.add(const Duration(days: ReviewPolicy.kReviewSoonDays)),
      ));
      return;
    }

    // All-correct session on this concept:
    final lastPracticed = lastPracticedByConcept[conceptId];
    final aging = lastPracticed == null ||
        now.difference(lastPracticed) >= ReviewPolicy.kAgingThreshold;

    if (stage != null && stage.index >= MasteryStage.mastered.index) {
      updates.add(ReviewEntry(
        conceptId: conceptId,
        reason: ReviewReason.maintenance,
        priority: 0.3,
        dueAt:
            now.add(const Duration(days: ReviewPolicy.kMaintenanceReviewDays)),
      ));
    } else if (stage != null &&
        stage.index >= MasteryStage.practiced.index &&
        aging &&
        sessionEvidence.firstTryCount > 0) {
      updates.add(ReviewEntry(
        conceptId: conceptId,
        reason: ReviewReason.agingStrong,
        priority: 0.5,
        dueAt: now.add(const Duration(days: ReviewPolicy.kAgingReviewDays)),
      ));
    }
  });
  return updates;
}

/// Merges [updates] into [existing]: per concept the update replaces the
/// old entry (fresh evidence wins), the queue is re-sorted by priority
/// and capped at [ReviewPolicy.kMaxQueueEntries].
List<ReviewEntry> mergeReviewQueue(
  List<ReviewEntry> existing,
  List<ReviewEntry> updates,
) {
  final byConcept = <String, ReviewEntry>{
    for (final e in existing) e.conceptId: e,
    for (final u in updates) u.conceptId: u,
  };
  final merged = byConcept.values.toList()..sort();
  if (merged.length <= ReviewPolicy.kMaxQueueEntries) return merged;
  return merged.sublist(0, ReviewPolicy.kMaxQueueEntries);
}

/// Overlays persisted session-evidence masteries onto the M1-derived
/// learning state. Evidence can only RAISE a stage; the derived
/// progress counters stay authoritative; recency (`lastPracticedAt`)
/// and scheduling (`reviewDueAt`) come from evidence when newer.
LearningState applyMasteryEvidence({
  required LearningState derived,
  required Map<String, ConceptMastery> evidence,
}) {
  if (evidence.isEmpty) return derived;
  final masteries = <String, ConceptMastery>{...derived.conceptMasteries};

  evidence.forEach((conceptId, evidenceMastery) {
    final derivedMastery = masteries[conceptId];
    if (derivedMastery == null) {
      // No derived record — the concept's lesson was never completed,
      // but real session evidence exists (e.g. a passed mastery check).
      // Keep it honestly, with a conservative strength.
      masteries[conceptId] = evidenceMastery;
      return;
    }
    final stage = _maxStage(derivedMastery.stage, evidenceMastery.stage) ??
        derivedMastery.stage;
    masteries[conceptId] = derivedMastery.copyWith(
      stage: stage,
      strength: derivedMastery.strength >= evidenceMastery.strength
          ? derivedMastery.strength
          : evidenceMastery.strength,
      lastPracticedAt: SessionConceptEvidence._latest(
        derivedMastery.lastPracticedAt,
        evidenceMastery.lastPracticedAt,
      ),
      reviewDueAt: evidenceMastery.reviewDueAt,
    );
  });

  return LearningState(
    languageCode: derived.languageCode,
    conceptMasteries: masteries,
    reviewQueue: derived.reviewQueue,
    recentPerformance: derived.recentPerformance,
  );
}

MasteryStage? _maxStage(MasteryStage? a, MasteryStage? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.index >= b.index ? a : b;
}
