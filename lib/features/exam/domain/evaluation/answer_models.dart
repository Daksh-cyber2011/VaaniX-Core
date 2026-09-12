/// Exam Mode 2.0 — Answer Evaluation Domain Models (M7, §26–§28, §30)
///
/// Models for evaluating student answers — TYPED and PHOTO (§26 both
/// V1 submission modes).
///
/// Hard rules encoded here:
///  * §26: photo answers may be unclear/cropped/unreadable — the
///    pipeline NEVER pretends OCR is perfect; low-confidence
///    extraction becomes an UNCERTAIN verdict asking the student to
///    retake or type.
///  * §27: evaluation is rubric-grounded (correctness, completeness,
///    key required points) — NOT "keyword exists = correct".
///  * §28: feedback is specific, constructive, short, actionable —
///    never just "Wrong.", never shaming.
///  * §30: NO confidence percentages. Verdict confidence is a
///    qualitative BAND (low / medium / high) and the feedback text
///    never contains "%" or "प्रतिशत".
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// How the answer was submitted (§26).
enum AnswerKind { typed, photo }

/// The evaluation verdict (§27).
enum EvaluationVerdict { correct, partiallyCorrect, incorrect, uncertain }

extension EvaluationVerdictX on EvaluationVerdict {
  bool get isGraded =>
      this == EvaluationVerdict.correct ||
      this == EvaluationVerdict.partiallyCorrect ||
      this == EvaluationVerdict.incorrect;
}

/// Qualitative confidence band (§30 — never a percentage).
enum ConfidenceBand { low, medium, high }

/// Something wrong with the INPUT itself (not the answer quality).
enum EvaluationIssue {
  emptyAnswer,
  veryLongAnswer,
  unreadablePhoto,
  croppedPhoto,
  tooSmallPhoto,
  ambiguousExtraction,
  offlinePhoto,
}

extension EvaluationIssueX on EvaluationIssue {
  String get studentAdvice => switch (this) {
        EvaluationIssue.emptyAnswer => 'पहले कुछ लिखें — खाली उत्तर का '
            'मूल्यांकन नहीं होता।',
        EvaluationIssue.veryLongAnswer => 'उत्तर काफ़ी लंबा है — प्रश्न जो '
            'माँगता है वही लिखने की कोशिश करें।',
        EvaluationIssue.unreadablePhoto => 'फ़ोटो साफ़ नहीं लगी — अच्छी '
            'रोशनी में दोबारा लें या उत्तर टाइप करें।',
        EvaluationIssue.croppedPhoto => 'फ़ोटो में उत्तर पूरा नहीं दिख रहा — '
            'पूरा दिखाकर दोबारा लें या टाइप करें।',
        EvaluationIssue.tooSmallPhoto => 'फ़ोटो बहुत छोटी/मुख्य हिस्सा छोटा '
            'है — पास से दोबारा लें या टाइप करें।',
        EvaluationIssue.ambiguousExtraction => 'फ़ोटो का पढ़ा हुआ अंश पक्का '
            'नहीं है — कृपया उत्तर टाइप करें।',
        EvaluationIssue.offlinePhoto => 'फ़ोटो का मूल्यांकन इस समय ऑफ़लाइन '
            'है — अभी टाइप करके आगे बढ़ें।',
      };
}

/// One required point of a rubric (§27 "key required points").
class RubricPoint extends Equatable {
  const RubricPoint({
    required this.id,
    required this.requirement,
    required this.met,
    this.evidence,
  });

  final String id;

  /// What the point requires (from trusted answer data).
  final String requirement;

  /// Whether the student's answer satisfied it.
  final bool met;

  /// The matched fragment of the student's answer, when found.
  final String? evidence;

  @override
  List<Object?> get props => [id, requirement, met];
}

/// A student's submission.
class AnswerSubmission extends Equatable {
  const AnswerSubmission({
    required this.kind,
    this.typedText = '',
    this.photoBytes,
    this.photoMime,
  });

  final AnswerKind kind;
  final String typedText;

  /// Raw photo bytes (photo answers; base64 happens at the adapter).
  final List<int>? photoBytes;
  final String? photoMime;

  @override
  List<Object?> get props => [kind, typedText];
}

/// The evaluation outcome (§27/§28/§30).
class EvaluationResult extends Equatable {
  const EvaluationResult({
    required this.verdict,
    required this.feedback,
    required this.rubricPoints,
    this.confidenceBand = ConfidenceBand.medium,
    this.extractedText,
    this.issues = const [],
    this.retryAdvice,
  });

  final EvaluationVerdict verdict;

  /// §28 feedback: specific + constructive + short + actionable.
  final String feedback;

  /// Rubric breakdown (correctness/completeness evidence).
  final List<RubricPoint> rubricPoints;

  /// Qualitative confidence band (§30: NEVER a percentage).
  final ConfidenceBand confidenceBand;

  /// For photo answers: what the vision pipeline read (§26 — surfaced
  /// honestly so the student can verify).
  final String? extractedText;

  /// Input-level issues (photo quality, empty, ambiguous).
  final List<EvaluationIssue> issues;

  /// §26: "ask the student to retake or type the answer".
  final String? retryAdvice;

  bool get needsRetry =>
      verdict == EvaluationVerdict.uncertain || retryAdvice != null;

  /// §30 test hook: feedback must stay percentage-free.
  bool get feedbackIsPercentageFree =>
      !feedback.contains('%') && !feedback.contains('प्रतिशत');

  @override
  List<Object?> get props => [verdict, feedback, rubricPoints, confidenceBand];
}
