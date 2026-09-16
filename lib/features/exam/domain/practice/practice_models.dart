/// Exam Mode 2.0 — Practice Domain Models (M6, §19/§24)
///
/// The adaptive learning loop's content types: MCQ + TYPED short
/// answer (the two question types the V1 loop drives; ordering/
/// matching and longer types extend [PracticeQuestionKind] later per
/// course needs — §24 "do NOT force every type onto every subject").
///
/// Every question is GROUNDED in the official syllabus (topicId +
/// strings from the canonical JSON). The evaluation rubric data
/// (accepted answers, required points) is derived from official
/// titles/sub-topics — trusted content (§15), never invented.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// The question kinds the loop supports (§24 V1 subset).
enum PracticeQuestionKind { mcq, shortAnswer }

extension PracticeQuestionKindX on PracticeQuestionKind {
  bool get isTyped => this == PracticeQuestionKind.shortAnswer;
}

/// One practice question.
class PracticeQuestion extends Equatable {
  const PracticeQuestion({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.kind,
    required this.prompt,
    this.options = const [],
    this.correctIndex,
    this.acceptedAnswers = const [],
    this.requiredPoints = const [],
    this.explanation,
    this.difficultyTier = 2,
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final PracticeQuestionKind kind;
  final String prompt;

  /// MCQ options (4, grounded).
  final List<String> options;

  /// MCQ correct index.
  final int? correctIndex;

  /// Typed-answer accepted answers (normalized comparison via the M7
  /// rubric evaluator).
  final List<String> acceptedAnswers;

  /// Typed-answer required points (completeness rubric).
  final List<String> requiredPoints;

  /// §28 feedback shown after the retry budget is spent (reveal).
  final String? explanation;

  /// 1..3 (adaptive difficulty within the loop).
  final int difficultyTier;

  bool get isValid => switch (kind) {
        PracticeQuestionKind.mcq => options.length == 4 &&
            correctIndex != null &&
            correctIndex! >= 0 &&
            correctIndex! < options.length,
        PracticeQuestionKind.shortAnswer => acceptedAnswers.isNotEmpty,
      };

  @override
  List<Object?> get props => [id, topicId, kind, prompt];
}

/// One graded attempt inside a session.
class PracticeAttempt extends Equatable {
  const PracticeAttempt({
    required this.questionId,
    required this.topicId,
    required this.verdict,
    required this.retries,
    required this.attemptedAtIso,
  });

  final String questionId;
  final String topicId;

  /// Final verdict for the question (after retry budget).
  final String verdict;
  final int retries;
  final String attemptedAtIso;

  @override
  List<Object?> get props => [questionId, verdict, retries];
}

/// The live session state (M6 loop: question → answer → feedback →
/// retry → next; §19 "learn, practice, feedback, retry, mastery,
/// next step").
class PracticeSessionState extends Equatable {
  const PracticeSessionState({
    required this.questions,
    required this.index,
    required this.attempts,
    required this.currentVerdictText,
    required this.currentRetryCount,
    required this.currentVerdict,
    required this.awaitingNext,
    required this.finished,
  });

  final List<PracticeQuestion> questions;
  final int index;
  final List<PracticeAttempt> attempts;

  /// Feedback text for the CURRENT question (null when input mode).
  final String? currentVerdictText;
  final int currentRetryCount;

  /// Verdict of the current question's latest evaluation (null while
  /// in input mode): 'correct' | 'partiallyCorrect' | 'incorrect' |
  /// 'uncertain' | 'revealed'.
  final String? currentVerdict;

  /// True when the verdict is FINAL for this question (correct, or
  /// retry budget spent, or revealed) and the loop waits for the
  /// student's "next" tap. The attempt is recorded on advance (§29).
  final bool awaitingNext;

  final bool finished;

  PracticeQuestion? get current =>
      index < questions.length ? questions[index] : null;

  int get correctCount => attempts
      .where((a) => a.verdict == 'correct' || a.verdict == 'partiallyCorrect')
      .length;

  @override
  List<Object?> get props => [questions, index, attempts, finished];
}
