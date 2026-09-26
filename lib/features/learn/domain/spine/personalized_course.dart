/// A persisted, learner-specific Learn roadmap.
///
/// The trusted concept graph remains the knowledge boundary. A course only
/// stores the planner-selected ordering and metadata; lesson content is
/// resolved from the existing trusted curriculum (and generated-content
/// cache) when the learner opens a lesson.
///
/// Extended for real AI personalization:
/// - [PersonalizedLesson.activityType] drives how content is resolved
/// - [PersonalizedLesson.contentCached] tracks offline availability
/// - [PersonalizedCourse.completionByUnit] tracks per-unit mastery
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';

class PersonalizedLesson extends Equatable {
  const PersonalizedLesson({
    required this.id,
    required this.conceptId,
    required this.title,
    required this.objective,
    required this.order,
    this.lessonId,
    this.estimatedMinutes = 5,
    this.activityType,
    this.contentCached = false,
  });

  final String id;
  final String conceptId;
  final String title;
  final String objective;
  final int order;
  final String? lessonId;
  final int estimatedMinutes;

  /// The kind of learning activity this lesson represents.
  /// Maps to [ActivityKind] — drives how the session engine resolves content.
  /// null defaults to newLearning.
  final String? activityType;

  /// Whether generated/trusted content for this lesson has been cached
  /// for offline use. This is honest metadata — only true when actual
  /// lesson content exists locally, not just the roadmap metadata.
  final bool contentCached;

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptId': conceptId,
        'title': title,
        'objective': objective,
        'order': order,
        'lessonId': lessonId,
        'estimatedMinutes': estimatedMinutes,
        if (activityType != null) 'activityType': activityType,
        'contentCached': contentCached,
      };

  factory PersonalizedLesson.fromJson(Map<String, dynamic> json) {
    return PersonalizedLesson(
      id: json['id'] as String? ?? '',
      conceptId: json['conceptId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      lessonId: json['lessonId'] as String?,
      estimatedMinutes:
          ((json['estimatedMinutes'] as num?)?.toInt() ?? 5).clamp(1, 60),
      activityType: json['activityType'] as String?,
      contentCached: json['contentCached'] as bool? ?? false,
    );
  }

  PersonalizedLesson copyWith({
    String? id,
    String? conceptId,
    String? title,
    String? objective,
    int? order,
    String? lessonId,
    int? estimatedMinutes,
    String? activityType,
    bool? contentCached,
  }) {
    return PersonalizedLesson(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      title: title ?? this.title,
      objective: objective ?? this.objective,
      order: order ?? this.order,
      lessonId: lessonId ?? this.lessonId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      activityType: activityType ?? this.activityType,
      contentCached: contentCached ?? this.contentCached,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conceptId,
        title,
        objective,
        order,
        lessonId,
        estimatedMinutes,
        activityType,
        contentCached,
      ];
}

class PersonalizedUnit extends Equatable {
  const PersonalizedUnit({
    required this.id,
    required this.title,
    required this.objective,
    required this.order,
    required this.lessons,
    this.prerequisiteConcepts = const <String>[],
  });

  final String id;
  final String title;
  final String objective;
  final int order;
  final List<PersonalizedLesson> lessons;
  final List<String> prerequisiteConcepts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'objective': objective,
        'order': order,
        'lessons': [for (final lesson in lessons) lesson.toJson()],
        'prerequisiteConcepts': prerequisiteConcepts,
      };

  factory PersonalizedUnit.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'];
    return PersonalizedUnit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      lessons: rawLessons is List
          ? [
              for (final raw in rawLessons)
                if (raw is Map<String, dynamic>)
                  PersonalizedLesson.fromJson(raw),
            ]
          : const [],
      prerequisiteConcepts: json['prerequisiteConcepts'] is List
          ? [
              for (final value in json['prerequisiteConcepts'] as List)
                if (value is String) value
            ]
          : const [],
    );
  }

  /// Number of lessons with content cached for offline use.
  int get cachedLessonCount =>
      lessons.where((l) => l.contentCached).length;

  /// True when all lessons in this unit have cached content.
  bool get isFullyCached =>
      lessons.isNotEmpty && cachedLessonCount == lessons.length;

  @override
  List<Object?> get props =>
      [id, title, objective, order, lessons, prerequisiteConcepts];
}

class PersonalizedCourse extends Equatable {
  const PersonalizedCourse({
    required this.id,
    required this.languageCode,
    required this.source,
    required this.generatedAt,
    required this.contextKey,
    required this.units,
    this.diagnosticVersion,
    this.curriculumRevision,
  });

  final String id;
  final String languageCode;
  final PlanSource source;
  final DateTime generatedAt;
  final String contextKey;
  final String? diagnosticVersion;
  final String? curriculumRevision;
  final List<PersonalizedUnit> units;

  int get lessonCount =>
      units.fold(0, (sum, unit) => sum + unit.lessons.length);
  bool get isEmpty => units.every((unit) => unit.lessons.isEmpty);

  /// Number of lessons with content actually cached for offline use.
  int get cachedLessonCount =>
      units.fold(0, (sum, unit) => sum + unit.cachedLessonCount);

  /// True when this was generated by AI (not deterministic fallback).
  bool get isAiGenerated => source == PlanSource.ai;

  /// Honest offline status description.
  String get offlineStatusDescription {
    final cached = cachedLessonCount;
    final total = lessonCount;
    if (total == 0) return 'No lessons available';
    if (cached == total) return '$total lessons available offline';
    if (cached > 0) {
      return 'Roadmap available offline · $cached of $total lessons cached';
    }
    return 'Roadmap available offline · lesson content requires connection';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'languageCode': languageCode,
        'source': source.name,
        'generatedAt': generatedAt.toIso8601String(),
        'contextKey': contextKey,
        'diagnosticVersion': diagnosticVersion,
        'curriculumRevision': curriculumRevision,
        'units': [for (final unit in units) unit.toJson()],
      };

  factory PersonalizedCourse.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    return PersonalizedCourse(
      id: json['id'] as String? ?? '',
      languageCode: json['languageCode'] as String? ?? '',
      source: PlanSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => PlanSource.deterministic,
      ),
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      contextKey: json['contextKey'] as String? ?? '',
      diagnosticVersion: json['diagnosticVersion'] as String?,
      curriculumRevision: json['curriculumRevision'] as String?,
      units: rawUnits is List
          ? [
              for (final raw in rawUnits)
                if (raw is Map<String, dynamic>) PersonalizedUnit.fromJson(raw),
            ]
          : const [],
    );
  }

  @override
  List<Object?> get props => [
        id,
        languageCode,
        source,
        generatedAt,
        contextKey,
        diagnosticVersion,
        curriculumRevision,
        units,
      ];
}
