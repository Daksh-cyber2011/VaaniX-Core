/// Learn Mode 2.0 — Learning State (M1 Architecture Spine)
///
/// The fast-changing EVIDENCE side of the learner model: where the learner
/// actually IS right now (Master Brief §50 personal learning graph):
///
///   CONCEPT A = MASTERED / B = STRONG / C = DEVELOPING / D = WEAK / …
///
/// Everything in here is derived from REAL persisted progress data — the
/// existing per-lesson completed/mastered-exercise records are the single
/// evidence source; no stage is ever fabricated. The derivation
/// ([fromProgressData]) is the M1 mapping of old data onto the new
/// concept-based model:
///
///   lesson completed, no exercises           → introduced
///   lesson completed, some exercises mastered → practiced
///   lesson completed, ALL exercises mastered  → understood
///   lesson not completed                      → (no record)
///
/// Higher stages (recalled/applied/mastered/maintained) need evidence the
/// current engine does not collect yet — they arrive with M6's session
/// engine, keeping M1 honest rather than speculative.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';

/// Why a concept is in the review queue (Master Brief §20 practical
/// review policy — deliberately simple, no fake scientific model).
enum ReviewReason {
  /// Recently weak → review soon.
  recentlyWeak,

  /// Strong but aging → review later.
  agingStrong,

  /// Mastered + consistently strong → low-frequency maintenance.
  maintenance;

  static ReviewReason? tryParse(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// One entry in the learner's review queue.
class ReviewEntry extends Equatable implements Comparable<ReviewEntry> {
  const ReviewEntry({
    required this.conceptId,
    required this.reason,
    required this.priority,
    this.dueAt,
  });

  final String conceptId;
  final ReviewReason reason;

  /// Higher = more urgent (0..1). Queue is sorted descending by this.
  final double priority;

  /// When this review becomes due (null = due now).
  final DateTime? dueAt;

  @override
  int compareTo(ReviewEntry other) => other.priority.compareTo(priority);

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'reason': reason.name,
        'priority': priority,
        'dueAt': dueAt?.toIso8601String(),
      };

  factory ReviewEntry.fromJson(Map<String, dynamic> json) {
    return ReviewEntry(
      conceptId: json['conceptId'] as String? ?? '',
      reason: ReviewReason.tryParse(json['reason'] as String?) ??
          ReviewReason.recentlyWeak,
      priority: (json['priority'] as num?)?.toDouble() ?? 0,
      dueAt: json['dueAt'] != null
          ? DateTime.tryParse(json['dueAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [conceptId, reason, priority, dueAt];
}

/// One recorded performance event (bounded history — Master Brief §13
/// "recent performance").
class PerformanceEvent extends Equatable {
  const PerformanceEvent({
    required this.conceptId,
    required this.correct,
    required this.firstTry,
    required this.at,
  });

  final String conceptId;
  final bool correct;
  final bool firstTry;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'correct': correct,
        'firstTry': firstTry,
        'at': at.toIso8601String(),
      };

  factory PerformanceEvent.fromJson(Map<String, dynamic> json) {
    return PerformanceEvent(
      conceptId: json['conceptId'] as String? ?? '',
      correct: json['correct'] as bool? ?? false,
      firstTry: json['firstTry'] as bool? ?? false,
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [conceptId, correct, firstTry, at];
}

/// Bounded rolling window of recent performance events.
class RecentPerformance extends Equatable {
  const RecentPerformance({this.events = const []});

  /// Window cap — keeps the planner prompt small and memory bounded.
  static const int kMaxEvents = 30;

  final List<PerformanceEvent> events;

  /// Overall accuracy across the window (null when empty — never 0%,
  /// which would read as "failing" for a learner with no history).
  double? get accuracy {
    if (events.isEmpty) return null;
    final correct = events.where((e) => e.correct).length;
    return correct / events.length;
  }

  /// First-try accuracy (the engine's quality signal), null when empty.
  double? get firstTryAccuracy {
    if (events.isEmpty) return null;
    final firstTryCorrect = events.where((e) => e.correct && e.firstTry).length;
    return firstTryCorrect / events.length;
  }

  RecentPerformance add(PerformanceEvent event) => RecentPerformance(
      events: [...events, event].toList()
        ..sort((a, b) => a.at.compareTo(b.at)));

  List<Map<String, dynamic>> toRawJsonList() =>
      [for (final e in events) e.toJson()];

  static RecentPerformance fromRawJsonList(List<dynamic>? raw) =>
      RecentPerformance(events: [
        if (raw != null)
          for (final e in raw)
            if (e is Map<String, dynamic>) PerformanceEvent.fromJson(e),
      ]);

  @override
  List<Object?> get props => [events];
}

/// The learner's per-language learning state (evidence side).
class LearningState extends Equatable {
  const LearningState({
    required this.languageCode,
    this.conceptMasteries = const <String, ConceptMastery>{},
    this.reviewQueue = const <ReviewEntry>[],
    this.recentPerformance = const RecentPerformance(),
  });

  /// ISO 639-1 code of the language this state belongs to.
  final String languageCode;

  /// Concept id → mastery. Absent = never started (implicit zero stage).
  final Map<String, ConceptMastery> conceptMasteries;

  /// Sorted descending by priority (most urgent first).
  final List<ReviewEntry> reviewQueue;

  final RecentPerformance recentPerformance;

  /// Concept ids currently at or beyond [stage].
  List<String> conceptIdsAtLeast(MasteryStage stage) => [
        for (final e in conceptMasteries.entries)
          if (e.value.stage.isAtLeast(stage)) e.key,
      ];

  /// Mastery stage of [conceptId], or `null` when never started.
  MasteryStage? stageOf(String conceptId) => conceptMasteries[conceptId]?.stage;

  /// Concepts whose prerequisites are satisfied but which have no mastery
  /// record yet — the planner's "ready to learn" pool.
  List<LearnConcept> readyToLearn(ConceptGraph graph) {
    final stages = {
      for (final e in conceptMasteries.entries) e.key: e.value.stage,
    };
    return [
      for (final c in graph.concepts)
        if (stageOf(c.id) == null && graph.isUnlocked(c.id, stages)) c,
    ];
  }

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'conceptMasteries': {
          for (final e in conceptMasteries.entries) e.key: e.value.toJson(),
        },
        'reviewQueue': [for (final r in reviewQueue) r.toJson()],
        'recentPerformance': recentPerformance.toRawJsonList(),
      };

  factory LearningState.fromJson(Map<String, dynamic> json) {
    final rawMasteries =
        json['conceptMasteries'] as Map<String, dynamic>? ?? {};
    final queue = (json['reviewQueue'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReviewEntry.fromJson)
        .toList()
      ..sort();
    return LearningState(
      languageCode: json['languageCode'] as String? ?? '',
      conceptMasteries: {
        for (final e in rawMasteries.entries)
          if (e.value is Map<String, dynamic>)
            e.key: ConceptMastery.fromJson(e.value as Map<String, dynamic>),
      },
      reviewQueue: queue,
      recentPerformance: RecentPerformance.fromRawJsonList(
        json['recentPerformance'] as List<dynamic>?,
      ),
    );
  }

  @override
  List<Object?> get props =>
      [languageCode, conceptMasteries, reviewQueue, recentPerformance];
}

/// Derivation input bundle — everything [deriveLearningState] needs,
/// all of it REAL persisted data (no fabrication).
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.completedLessonIds,
    required this.masteredExerciseIdsByLesson,
    required this.exerciseCountByLesson,
  });

  final Set<String> completedLessonIds;
  final Map<String, List<String>> masteredExerciseIdsByLesson;
  final Map<String, int> exerciseCountByLesson;
}

/// Derives the concept-based [LearningState] for one language from the
/// graph plus the raw progress snapshot (the M1 old→new data mapping
/// documented in the library docs).
LearningState deriveLearningState({
  required String languageCode,
  required ConceptGraph graph,
  required ProgressSnapshot snapshot,
  List<ReviewEntry> reviewQueue = const <ReviewEntry>[],
  RecentPerformance recentPerformance = const RecentPerformance(),
}) {
  final masteries = <String, ConceptMastery>{};
  for (final concept in graph.concepts) {
    final completed = snapshot.completedLessonIds.contains(concept.lessonId);
    if (!completed) continue; // no evidence → no record (implicit zero)

    final total = snapshot.exerciseCountByLesson[concept.lessonId] ?? 0;
    final masteredIds =
        snapshot.masteredExerciseIdsByLesson[concept.lessonId] ??
            const <String>[];

    MasteryStage stage;
    if (total == 0) {
      // Read but nothing to practise → the learner has at least seen it.
      stage = MasteryStage.introduced;
    } else if (masteredIds.length >= total) {
      // Every exercise mastered → consistent performance demonstrated.
      stage = MasteryStage.understood;
    } else {
      stage = MasteryStage.practiced;
    }

    masteries[concept.id] = ConceptMastery(
      conceptId: concept.id,
      stage: stage,
      strength: total == 0 ? 0.2 : masteredIds.length / total,
      correctCount: masteredIds.length,
      attemptCount: total,
    );
  }

  final sortedQueue = [...reviewQueue]..sort();
  return LearningState(
    languageCode: languageCode,
    conceptMasteries: masteries,
    reviewQueue: sortedQueue,
    recentPerformance: recentPerformance,
  );
}
