/// Learn Mode 2.0 — Learning Plan & Planner Decision (M1 Architecture Spine)
///
/// Typed structures for everything a planner CONSUMES and PRODUCES
/// (Master Brief §63). The AI provider is replaceable; whatever it is,
/// its output must pass [PlannerDecisionValidator] before it can drive
/// any navigation (Master Brief §14):
///
///   "The application validates: concept exists, language matches,
///    activity type supported, difficulty valid, content source available.
///    If invalid: fallback safely."
///
/// Arbitrary AI prose NEVER controls navigation directly — only validated
/// structured objects do.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// The kind of learning activity (Master Brief §18 — the exercise engine
/// must understand all six).
enum ActivityKind {
  newLearning('New lesson'),
  practice('Practice'),
  review('Review'),
  weakRepair('Weak-area repair'),
  masteryCheck('Mastery check'),
  challenge('Challenge');

  const ActivityKind(this.label);

  final String label;

  static ActivityKind? tryParse(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Where a plan came from (drives UI honesty + cache behaviour).
enum PlanSource {
  /// Local deterministic planner (offline / AI unavailable — Master
  /// Brief §36 fallback chain).
  deterministic,

  /// AI planner output that PASSED validation.
  ai,

  /// Previously generated plan reused (cache hit — Master Brief §35).
  cached,
}

/// One step in a learning plan.
class LearningActivity extends Equatable {
  const LearningActivity({
    required this.id,
    required this.kind,
    required this.title,
    required this.reason,
    this.conceptId,
    this.lessonId,
    this.difficulty = Difficulty.beginner,
    this.estimatedMinutes = 5,
  });

  final String id;
  final ActivityKind kind;
  final String title;

  /// Human-readable why (Master Brief §44 — personal, not jargon).
  final String reason;

  /// Concept this activity develops (validated against the graph).
  final String? conceptId;

  /// Trusted content anchor (validated lesson id).
  final String? lessonId;

  final Difficulty difficulty;

  /// Planner sizing hint (Master Brief §27 — flexible session lengths).
  final int estimatedMinutes;

  LearningActivity copyWith({
    String? id,
    ActivityKind? kind,
    String? title,
    String? reason,
    String? conceptId,
    String? lessonId,
    Difficulty? difficulty,
    int? estimatedMinutes,
  }) {
    return LearningActivity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      conceptId: conceptId ?? this.conceptId,
      lessonId: lessonId ?? this.lessonId,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'reason': reason,
        'conceptId': conceptId,
        'lessonId': lessonId,
        'difficulty': difficulty.name,
        'estimatedMinutes': estimatedMinutes,
      };

  factory LearningActivity.fromJson(Map<String, dynamic> json) {
    return LearningActivity(
      id: json['id'] as String? ?? '',
      kind: ActivityKind.tryParse(json['kind'] as String?) ??
          ActivityKind.practice,
      title: json['title'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      conceptId: json['conceptId'] as String?,
      lessonId: json['lessonId'] as String?,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == (json['difficulty'] as String?),
        orElse: () => Difficulty.beginner,
      ),
      estimatedMinutes:
          (((json['estimatedMinutes'] as num?)?.toInt() ?? 5).clamp(5, 60))
              .toInt(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        title,
        reason,
        conceptId,
        lessonId,
        difficulty,
        estimatedMinutes,
      ];
}

/// A validated learning plan for one session (or several).
class LearningPlan extends Equatable {
  const LearningPlan({
    required this.id,
    required this.languageCode,
    required this.source,
    required this.activities,
    required this.createdAt,
    this.focusSummary,
    this.plannerContextKey,
  });

  /// The safe plan a failing chain falls back to (Master Brief §60):
  /// empty-but-valid, never a crash, never a blank screen.
  factory LearningPlan.empty({
    required String languageCode,
    required PlanSource source,
    required String id,
    String reason = '',
  }) {
    return LearningPlan(
      id: id,
      languageCode: languageCode,
      source: source,
      activities: const <LearningActivity>[],
      createdAt: DateTime.now(),
      focusSummary: reason,
    );
  }

  final String id;
  final String languageCode;
  final PlanSource source;

  /// Ordered steps. Empty is legal (safe fallback state).
  final List<LearningActivity> activities;

  /// One human line about what this plan focuses on (nullable).
  final String? focusSummary;

  final DateTime createdAt;

  /// Stable planner-input identity for cache compatibility. Null is retained
  /// for backwards-compatible decoding of pre-Phase-2.4 plans.
  final String? plannerContextKey;

  bool get isEmpty => activities.isEmpty;

  int get totalEstimatedMinutes =>
      activities.fold(0, (sum, a) => sum + a.estimatedMinutes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'languageCode': languageCode,
        'source': source.name,
        'activities': [for (final a in activities) a.toJson()],
        'focusSummary': focusSummary,
        'createdAt': createdAt.toIso8601String(),
        'plannerContextKey': plannerContextKey,
      };

  factory LearningPlan.fromJson(Map<String, dynamic> json) {
    return LearningPlan(
      id: json['id'] as String? ?? '',
      languageCode: json['languageCode'] as String? ?? '',
      source: PlanSource.values.firstWhere(
        (s) => s.name == (json['source'] as String?),
        orElse: () => PlanSource.deterministic,
      ),
      activities: (json['activities'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LearningActivity.fromJson)
          .toList(),
      focusSummary: json['focusSummary'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      plannerContextKey: json['plannerContextKey'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        languageCode,
        source,
        activities,
        focusSummary,
        createdAt,
        plannerContextKey
      ];
}

/// Why a planner decision was rejected (Master Brief §14 validation list).
enum PlannerRejection {
  /// Output missing required fields / wrong types.
  malformedOutput,

  /// Referenced concept is not in the trusted graph.
  unknownConcept,

  /// Decision's language does not match the active one.
  languageMismatch,

  /// Activity kind is not supported by this build/flow.
  unsupportedActivity,

  /// Difficulty outside the valid range.
  invalidDifficulty,

  /// Required content source (lesson) does not exist.
  unavailableContent;

  String get explanation => switch (this) {
        PlannerRejection.malformedOutput =>
          'planner output was missing required fields',
        PlannerRejection.unknownConcept =>
          'referenced concept does not exist in the trusted curriculum',
        PlannerRejection.languageMismatch =>
          'decision belongs to a different language',
        PlannerRejection.unsupportedActivity =>
          'activity type is not supported here',
        PlannerRejection.invalidDifficulty => 'difficulty is out of range',
        PlannerRejection.unavailableContent =>
          'the referenced lesson content does not exist',
      };
}

/// A single next-step decision as an AI planner would emit it
/// (Master Brief §14 example shape).
class PlannerDecision extends Equatable {
  const PlannerDecision({
    required this.nextConceptId,
    required this.difficulty,
    required this.activityType,
    required this.reason,
    required this.languageCode,
    this.lessonId,
  });

  final String nextConceptId;

  /// 1..5 planner difficulty knob (validated by [PlannerDecisionValidator]).
  final int difficulty;

  final ActivityKind activityType;

  /// Human-readable why (shown to the learner after validation).
  final String reason;

  /// Language the decision claims to belong to.
  final String languageCode;

  /// Optional lesson hint (validated when present).
  final String? lessonId;

  /// Difficulty range the planner knob is allowed to use.
  static const int kMinDifficulty = 1;
  static const int kMaxDifficulty = 5;

  Map<String, dynamic> toJson() => {
        'nextConcept': nextConceptId,
        'difficulty': difficulty,
        'activityType': activityType.name,
        'reason': reason,
        'language': languageCode,
        if (lessonId != null) 'lessonId': lessonId,
      };

  /// Defensive parse of RAW planner output (e.g. decoded JSON). Missing or
  /// malformed fields surface as [PlannerRejection.malformedOutput] during
  /// validation — never as an exception here.
  factory PlannerDecision.fromRawJson(Map<String, dynamic> json) {
    String asString(Object? v) => v is String ? v : '';
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    final kind = ActivityKind.tryParse(asString(json['activityType']));
    return PlannerDecision(
      nextConceptId: asString(json['nextConcept']),
      difficulty: asInt(json['difficulty']) ?? 0,
      activityType: kind ?? ActivityKind.practice,
      reason: asString(json['reason']),
      languageCode: asString(json['language']),
      lessonId: json['lessonId'] is String ? json['lessonId'] as String : null,
    );
  }

  @override
  List<Object?> get props => [
        nextConceptId,
        difficulty,
        activityType,
        reason,
        languageCode,
        lessonId,
      ];
}

/// Validates planner decisions against the trusted graph (Master Brief
/// §14 — the hard security boundary between AI output and navigation).
class PlannerDecisionValidator {
  PlannerDecisionValidator._();

  /// Validates [decision]. Returns `null` when the decision is valid and
  /// may drive navigation; otherwise the FIRST failing reason.
  static PlannerRejection? validate({
    required PlannerDecision decision,
    required ConceptGraph graph,
    required Set<ActivityKind> supportedActivityTypes,
  }) {
    // 1. Structural integrity.
    if (decision.nextConceptId.isEmpty ||
        decision.languageCode.isEmpty ||
        decision.reason.trim().isEmpty) {
      return PlannerRejection.malformedOutput;
    }

    // 2. Difficulty knob in range.
    if (decision.difficulty < PlannerDecision.kMinDifficulty ||
        decision.difficulty > PlannerDecision.kMaxDifficulty) {
      return PlannerRejection.invalidDifficulty;
    }

    // 3. Activity type supported by this build.
    if (!supportedActivityTypes.contains(decision.activityType)) {
      return PlannerRejection.unsupportedActivity;
    }

    // 4. Language match (Master Brief §14 + §47 — no cross-language leak).
    if (decision.languageCode != graph.languageCode) {
      return PlannerRejection.languageMismatch;
    }

    // 5. Concept exists in the trusted graph.
    final concept = graph.conceptById(decision.nextConceptId);
    if (concept == null) {
      return PlannerRejection.unknownConcept;
    }

    // 6. Content source available: the lesson hint (when given) must match
    //    the concept's trusted anchor; otherwise the concept's own anchor
    //    must exist in the graph.
    final lessonId = decision.lessonId ?? concept.lessonId;
    if (lessonId != concept.lessonId) {
      return PlannerRejection.unavailableContent;
    }

    return null; // valid — may drive navigation
  }
}
