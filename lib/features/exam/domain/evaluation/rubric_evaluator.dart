/// Exam Mode 2.0 — Rubric Evaluator (M7, §26–§28, §30)
///
/// The deterministic evaluation engine for TYPED answers (and for
/// photo answers AFTER the vision pipeline extracted their text).
///
/// Design (§27: "For subjective answers, do NOT use simplistic
/// 'keyword exists = correct'"):
///  * Each question carries trusted answer data: accepted full
///    answers (any ONE matching ⇒ correct) + required rubric points
///    (completeness dimension).
///  * Matching is TOKEN-COVERAGE based (normalized), with an explicit
///    GRAY ZONE that yields UNCERTAIN instead of a guess (§26
///    uncertainty handling; never fake confidence).
///  * MCQ questions evaluate deterministically by index (score
///    integrity is NEVER AI's job — §14).
///  * Feedback follows §28: specific, constructive, actionable —
///    says WHICH rubric point was missed, never just "Wrong.", never
///    shame. Retry advice offered where a retry makes sense.
///  * Confidence is a qualitative BAND (§30) — the internal overlap
///    number never surfaces to the student.
///
/// Pure Dart — no Flutter imports, fully unit-testable.
library;

import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_normalizer.dart';

/// The trusted answer data a question carries (from the grounded
/// content bank — official syllabus strings, never invented).
class RubricAnswerData {
  const RubricAnswerData({
    required this.acceptedAnswers,
    this.requiredPoints = const [],
  });

  /// Full accepted answers — any ONE matching (coverage ≥ threshold)
  /// is a correct verdict.
  final List<String> acceptedAnswers;

  /// Required points (completeness): each point is matched by token
  /// coverage against the student's answer.
  final List<String> requiredPoints;
}

/// Coverage thresholds (tuned for school-answer granularity).
class _Thresholds {
  /// ≥ this coverage vs an accepted answer ⇒ CORRECT.
  static const double correct = 0.8;

  /// In [partial, correct) ⇒ PARTIALLY CORRECT.
  static const double partial = 0.5;

  /// In [grayZone, partial) with mixed rubric evidence ⇒ UNCERTAIN
  /// (never guess, §26).
  static const double grayZone = 0.35;
}

class RubricEvaluator {
  const RubricEvaluator();

  /// Deterministic MCQ evaluation (§14: score integrity, never AI).
  static EvaluationResult evaluateMcq({
    required int correctIndex,
    required int selectedIndex,
    required String correctOptionText,
  }) {
    final correct = selectedIndex == correctIndex;
    return EvaluationResult(
      verdict:
          correct ? EvaluationVerdict.correct : EvaluationVerdict.incorrect,
      feedback: correct
          ? 'बिल्कुल सही — «$correctOptionText» सही उत्तर है।'
          : 'सही उत्तर «$correctOptionText» है। फ़र्क़ समझ आया? अगले '
              'प्रश्न में ध्यान रखेंगे।',
      rubricPoints: [
        RubricPoint(
          id: 'mcq',
          requirement: correctOptionText,
          met: correct,
        ),
      ],
      confidenceBand: ConfidenceBand.high,
      retryAdvice:
          correct ? null : 'आगे बढ़ें — यह पैटर्न दोहराव में फिर आएगा।',
    );
  }

  /// Rubric evaluation of a TYPED (or photo-extracted) answer.
  static EvaluationResult evaluateTyped({
    required String questionPrompt,
    required String studentAnswer,
    required RubricAnswerData answerData,
    bool isRetry = false,
  }) {
    final issues = <EvaluationIssue>[];
    final trimmed = studentAnswer.trim();

    if (trimmed.isEmpty) {
      return EvaluationResult(
        verdict: EvaluationVerdict.incorrect,
        feedback: 'उत्तर खाली है — जो आपको पता है, उतना लिखें। आधा लिखा '
            'उत्तर भी पूरा शून्य नहीं होता।',
        rubricPoints: const [],
        confidenceBand: ConfidenceBand.high,
        issues: const [EvaluationIssue.emptyAnswer],
        retryAdvice: EvaluationIssue.emptyAnswer.studentAdvice,
      );
    }
    if (trimmed.length > 1200) {
      issues.add(EvaluationIssue.veryLongAnswer);
    }

    final studentTokens = tokenizeAnswer(trimmed);

    // 1) Accepted-answer coverage (the correctness dimension).
    var bestCoverage = 0.0;
    for (final accepted in answerData.acceptedAnswers) {
      final acceptedTokens = tokenizeAnswer(accepted);
      var cov = tokenCoverage(acceptedTokens, studentTokens);
      // A meaningful stem inside a trusted compound answer is evidence of
      // topical relevance, but never enough to mark an answer correct.
      // Route that narrow case to the explicit uncertainty path instead of
      // treating it as wholly unrelated.
      if (cov == 0 && _hasCompoundStemOverlap(acceptedTokens, studentTokens)) {
        cov = _Thresholds.grayZone;
      }
      if (cov > bestCoverage) bestCoverage = cov;
    }

    // 2) Required rubric points (the completeness dimension, §27).
    final points = <RubricPoint>[];
    var metCount = 0;
    for (var i = 0; i < answerData.requiredPoints.length; i++) {
      final required = answerData.requiredPoints[i];
      final cov = tokenCoverage(tokenizeAnswer(required), studentTokens);
      final met = cov >= 0.7;
      if (met) metCount++;
      points.add(RubricPoint(
        id: 'p$i',
        requirement: required,
        met: met,
        evidence: met ? _evidenceFor(required, studentTokens) : null,
      ));
    }

    // 3) Verdict synthesis (never a guess — gray zone ⇒ uncertain).
    EvaluationVerdict verdict;
    ConfidenceBand band;
    if (bestCoverage >= _Thresholds.correct) {
      verdict = EvaluationVerdict.correct;
      band = ConfidenceBand.high;
    } else if (bestCoverage >= _Thresholds.partial) {
      verdict = EvaluationVerdict.partiallyCorrect;
      band = ConfidenceBand.medium;
    } else if (bestCoverage >= _Thresholds.grayZone ||
        (points.isNotEmpty && metCount > 0 && metCount < points.length)) {
      verdict = EvaluationVerdict.uncertain;
      band = ConfidenceBand.low;
    } else {
      verdict = EvaluationVerdict.incorrect;
      band = ConfidenceBand.medium;
    }

    // Fully-met rubric with weak full-answer coverage = partial.
    if (verdict == EvaluationVerdict.correct &&
        points.isNotEmpty &&
        metCount < points.length) {
      verdict = EvaluationVerdict.partiallyCorrect;
      band = ConfidenceBand.medium;
    }

    // 4) §28 feedback: specific + constructive + actionable.
    final feedback = _feedback(
      verdict: verdict,
      prompt: questionPrompt,
      points: points,
      metCount: metCount,
      isRetry: isRetry,
    );

    return EvaluationResult(
      verdict: verdict,
      feedback: feedback,
      rubricPoints: points,
      confidenceBand: band,
      issues: issues,
      extractedText: null,
      retryAdvice: _retryAdvice(verdict, isRetry),
    );
  }

  static String _feedback({
    required EvaluationVerdict verdict,
    required String prompt,
    required List<RubricPoint> points,
    required int metCount,
    required bool isRetry,
  }) {
    switch (verdict) {
      case EvaluationVerdict.correct:
        return isRetry
            ? 'इस बार पूरा सही — सुधार दिख रहा है।'
            : 'सही! आपके उत्तर में माँगे गए तत्व मौजूद हैं।';
      case EvaluationVerdict.partiallyCorrect:
        final missed = points.where((p) => !p.met).toList();
        final missedLine = missed.isEmpty
            ? 'उत्तर सही दिशा में है, पूर्णता थोड़ी कम है।'
            : 'सही दिशा में हैं — बस '
                '${missed.map((p) => p.requirement).take(2).join(' और ')} '
                'वाला बिंदु छूट गया।';
        return '$missedLine एक बार और कोशिश करें?';
      case EvaluationVerdict.uncertain:
        return 'उत्तर अधूरा या अस्पष्ट लग रहा है — मूल्यांकन पक्का नहीं '
            'हो पाया। जो जानते हैं उसे थोड़ा और स्पष्ट लिखें (या टाइप करें)।';
      case EvaluationVerdict.incorrect:
        final hint = points.isEmpty
            ? 'प्रश्न फिर से पढ़ें — जो पूछा गया है उसी पर उत्तर लिखें।'
            : 'ज़रूरी: ${points.where((p) => !p.met).map((p) => p.requirement).take(1).join('')} '
                'के बारे में लिखना आवश्यक है।';
        return 'यह उत्तर प्रश्न से मेल नहीं खा रहा। $hint धीरे से दोबारा '
            'कोशिश करें — गलती से सीखते हैं।';
    }
  }

  static String? _retryAdvice(EvaluationVerdict verdict, bool isRetry) {
    if (isRetry) return null; // second attempt: reveal and move on (M6 rule)
    return switch (verdict) {
      EvaluationVerdict.correct => null,
      EvaluationVerdict.partiallyCorrect => 'छूटे हुए बिंदु जोड़कर एक बार '
          'और लिखें।',
      EvaluationVerdict.uncertain => 'उत्तर स्पष्ट करें — या फ़ोटो की जगह '
          'टाइप करें।',
      EvaluationVerdict.incorrect => 'दोबारा कोशिश करें — या "समाधान देखें" '
          'चुनकर आगे बढ़ें।',
    };
  }

  static String? _evidenceFor(String required, List<String> studentTokens) {
    final requiredTokens = tokenizeAnswer(required);
    final hits = requiredTokens.where(studentTokens.contains).take(4).toList();
    return hits.isEmpty ? null : hits.join(' ');
  }

  static bool _hasCompoundStemOverlap(
    List<String> expectedTokens,
    List<String> studentTokens,
  ) =>
      expectedTokens.any((expected) => studentTokens.any((student) =>
          expected.length >= 3 &&
          student.length >= 3 &&
          (expected.startsWith(student) || student.startsWith(expected))));
}
