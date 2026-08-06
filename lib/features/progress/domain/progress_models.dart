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
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  @override
  List<Object?> get props => [id, prompt, options, correctIndex, explanation];
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
