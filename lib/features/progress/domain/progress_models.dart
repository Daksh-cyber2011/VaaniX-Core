/// Lesson & Quiz Progress — Domain Models
///
/// Lightweight domain types for structured learning content and the learner's
/// progress through it. These power the Learn tree, Exam quizzes, and the
/// Progress dashboard.

import 'package:equatable/equatable.dart';

/// Difficulty band for a lesson or quiz question.
enum Difficulty { beginner, intermediate, advanced }

/// A single teachable lesson in the Sanskrit roadmap.
class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.title,
    required this.chapterId,
    this.subtitle,
    this.difficulty = Difficulty.beginner,
    this.xpReward = 10,
    this.order = 0,
    this.content,
  });

  final String id;
  final String chapterId;
  final String title;
  final String? subtitle;
  final Difficulty difficulty;
  final int xpReward;
  final int order;

  /// Markdown-like lesson content.
  ///
  /// Supported format (minimal, documented for future JSON-driven curriculum):
  /// - `# Heading` — H1 heading
  /// - Plain text paragraphs (separated by blank lines)
  /// - `- Bullet point` — bullet list items
  /// - `> Tip text` — blockquote (rendered with left accent border)
  /// - `| Col1 | Col2 | Col3 |` — 3-column table (with `|---|---|---|` separator row)
  ///
  /// Devanagari text (Unicode range \u0900-\u097F) is rendered with
  /// [AppTextStyles.sanskritBody] for proper font support.
  final String? content;

  /// Deserialize from JSON (for loading curriculum from assets).
  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      chapterId: json['chapterId'] as String,
      subtitle: json['subtitle'] as String?,
      difficulty: Difficulty.values
          .byName((json['difficulty'] as String?) ?? 'beginner'),
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 10,
      order: (json['order'] as num?)?.toInt() ?? 0,
      content: json['content'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'chapterId': chapterId,
        'subtitle': subtitle,
        'difficulty': difficulty.name,
        'xpReward': xpReward,
        'order': order,
        'content': content,
      };

  /// Returns a copy with the specified fields replaced.
  Lesson copyWith({
    String? id,
    String? title,
    String? chapterId,
    String? subtitle,
    Difficulty? difficulty,
    int? xpReward,
    int? order,
    String? content,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      chapterId: chapterId ?? this.chapterId,
      subtitle: subtitle ?? this.subtitle,
      difficulty: difficulty ?? this.difficulty,
      xpReward: xpReward ?? this.xpReward,
      order: order ?? this.order,
      content: content ?? this.content,
    );
  }

  @override
  List<Object?> get props =>
      [id, chapterId, title, subtitle, difficulty, xpReward, order, content];
}

/// A chapter groups related lessons.
class Chapter extends Equatable {
  const Chapter({
    required this.id,
    required this.title,
    this.subtitle,
    this.lessons = const [],
    this.order = 0,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<Lesson> lessons;
  final int order;

  /// Deserialize from JSON (for loading curriculum from assets).
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((e) => Lesson.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'order': order,
      };

  @override
  List<Object?> get props => [id, title, subtitle, lessons, order];
}

/// A quiz question (multiple choice for V1).
class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.chapterId = '',
    this.difficulty = Difficulty.beginner,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  /// Owning chapter id (for chapter/difficulty exam selection).
  final String chapterId;

  /// Difficulty band of the question.
  final Difficulty difficulty;

  /// Deserialize from JSON (for loading quizzes from assets).
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctIndex: (json['correctIndex'] as num).toInt(),
      explanation: json['explanation'] as String?,
      chapterId: json['chapterId'] as String? ?? '',
      difficulty: json['difficulty'] != null
          ? Difficulty.values.byName(json['difficulty'] as String)
          : Difficulty.beginner,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'chapterId': chapterId,
        'difficulty': difficulty.name,
      };

  QuizQuestion copyWith({
    String? id,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? chapterId,
    Difficulty? difficulty,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      chapterId: chapterId ?? this.chapterId,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  List<Object?> get props =>
      [id, prompt, options, correctIndex, explanation, chapterId, difficulty];
}

/// Result of one quiz attempt.
class QuizResult extends Equatable {
  const QuizResult({
    required this.quizId,
    required this.score,
    required this.total,
    required this.xpEarned,
    this.completedAt,
  });

  final String quizId;
  final int score;
  final int total;
  final int xpEarned;
  final DateTime? completedAt;

  double get percentage => total == 0 ? 0 : score / total;

  /// Deserialize from JSON (for loading persisted attempt history).
  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      quizId: json['quizId'] as String,
      score: (json['score'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      xpEarned: (json['xpEarned'] as num).toInt(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  /// Serialize to JSON (for persisting attempt history).
  Map<String, dynamic> toJson() => {
        'quizId': quizId,
        'score': score,
        'total': total,
        'xpEarned': xpEarned,
        'completedAt': completedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [quizId, score, total, xpEarned, completedAt];
}
