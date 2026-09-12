/// Exam Mode 2.0 — Error Intelligence (M8, master plan §47 + §21)
///
/// Pattern-based error analysis over the persisted attempt log.
///
/// §47 requires ERROR CATEGORIES (concept gap, recall gap, application
/// gap, question interpretation, careless mistake, grammar error,
/// structure error, incomplete answer, time issue, misconception) —
/// "much more useful than wrongCount = 7".
///
/// §21 requires PATTERN identification, never raw counting:
/// "Question 1 wrong / 2 correct / 3 wrong / 4 wrong" must surface as a
/// SPECIFIC misconception, not "student is bad at grammar".
///
/// Honesty rules encoded here:
///  * only categories with actual evidence are ever emitted —
///    grammar/time errors need data the loop does not yet persist, so
///    they are NEVER fabricated (§30/§60 spirit);
///  * a category becomes a PATTERN only when it REPEATS on the same
///    topic (occurrences ≥ 2, misconception ≥ 3 wrongs). One-off
///    mistakes stay singletons and never drive weak-area findings;
///  * photo UNCERTAIN verdicts are INPUT problems, not student errors
///    — excluded from error evidence entirely (§26).
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// §47 error categories — the full official vocabulary.
enum ErrorCategory {
  conceptGap,
  recallGap,
  applicationGap,
  questionInterpretation,
  carelessMistake,
  grammarError,
  structureError,
  incompleteAnswer,
  timeIssue,
  misconception,
}

ErrorCategory? errorCategoryFromName(String? name) => switch (name) {
      'conceptGap' => ErrorCategory.conceptGap,
      'recallGap' => ErrorCategory.recallGap,
      'applicationGap' => ErrorCategory.applicationGap,
      'questionInterpretation' => ErrorCategory.questionInterpretation,
      'carelessMistake' => ErrorCategory.carelessMistake,
      'grammarError' => ErrorCategory.grammarError,
      'structureError' => ErrorCategory.structureError,
      'incompleteAnswer' => ErrorCategory.incompleteAnswer,
      'timeIssue' => ErrorCategory.timeIssue,
      'misconception' => ErrorCategory.misconception,
      _ => null,
    };

/// Categories the current evidence can NEVER produce (the loop does
/// not persist grammar-specific or timing rubrics yet). Surfaced so
/// the weak-area engine — and the mirror tests — can assert no
/// fabrication (§21 "do not simply count", §30 honesty).
const Set<ErrorCategory> unfabricatableCategories = {
  ErrorCategory.grammarError,
  ErrorCategory.timeIssue,
};

/// One graded evidence point from the attempt log (a FINAL verdict —
/// the M6 loop records on advance only, after the retry budget).
class ErrorEvidence extends Equatable {
  const ErrorEvidence({
    required this.questionId,
    required this.topicId,
    required this.kind,
    required this.verdict,
    required this.retries,
    required this.atIso,
  });

  final String questionId;
  final String topicId;

  /// 'mcq' | 'typed' | 'photo'.
  final String kind;

  /// 'correct' | 'partiallyCorrect' | 'incorrect' | 'revealed'.
  /// 'uncertain' inputs are filtered before classification (§26).
  final String verdict;

  /// Retry budget consumed BEFORE this final verdict (0 = first-shot).
  final int retries;

  final String atIso;

  bool get isWrong =>
      verdict == 'incorrect' || verdict == 'revealed' ||
      verdict == 'partiallyCorrect';

  factory ErrorEvidence.fromJson(Map<String, dynamic> json) =>
      ErrorEvidence(
        questionId: json['questionId'] as String? ?? '',
        topicId: json['topicId'] as String? ?? '',
        kind: json['kind'] as String? ?? 'mcq',
        verdict: json['verdict'] as String? ?? '',
        retries: (json['retries'] as num?)?.toInt() ?? 0,
        atIso: json['atIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'topicId': topicId,
        'kind': kind,
        'verdict': verdict,
        'retries': retries,
        'atIso': atIso,
      };

  @override
  List<Object?> get props => [questionId, topicId, verdict, retries];
}

/// A REPEATED error pattern on one topic (§21 — patterns, not counts).
class ErrorPattern extends Equatable {
  const ErrorPattern({
    required this.category,
    required this.topicId,
    required this.occurrences,
    required this.questionIds,
    required this.firstSeenIso,
    required this.lastSeenIso,
  });

  final ErrorCategory category;
  final String topicId;

  /// Distinct wrong attempts feeding the pattern (≥ 2 by rule; a
  /// misconception needs ≥ 3).
  final int occurrences;
  final List<String> questionIds;
  final String firstSeenIso;
  final String lastSeenIso;

  /// Student-facing, §30-clean sentence naming the PATTERN (never a
  /// percentage, never "you are bad at X").
  String get evidenceSentence => switch (category) {
        ErrorCategory.conceptGap => 'यह विषय दो बार समझने के बाद भी '
            'गड़बड़ा रहा है — छोटा concept-gap है, आदत नहीं।',
        ErrorCategory.recallGap => 'याद रखने में दो बार अटके — recall '
            'को हल्के दोहराव से पक्का करेंगे।',
        ErrorCategory.applicationGap => 'लागू करने (apply) वाले सवालों में '
            'दो बार गलती — अभ्यास की दिशा बदलेंगे।',
        ErrorCategory.questionInterpretation => 'प्रश्न के अर्थ से दो बार '
            'भटके — सवाल धीरे पढ़ने की आदत बनाएँगे।',
        ErrorCategory.carelessMistake => 'बताने पर सुधार कर लेते हैं, पर '
            'पहली बार में दो बार फिसले — सावधानी का अभ्यास।',
        ErrorCategory.structureError => 'उत्तर की बनावट में दो बार कमी '
            'आई — structure पर छोटा focus।',
        ErrorCategory.incompleteAnswer => 'उत्तर दो बार अधूरे रहे — '
            'मुख्य बिंदु गिनकर लिखने की आदत।',
        ErrorCategory.misconception => 'एक ही गलतफहमी बार-बार लौट रही '
            'है — पहले उसे साफ़ करेंगे, फिर अभ्यास।',
        ErrorCategory.grammarError ||
        ErrorCategory.timeIssue =>
          '', // Unfabricatable — never rendered.
      };

  @override
  List<Object?> get props => [category, topicId, occurrences];
}

/// Deterministic pattern finder over the attempt log (§47 → §21).
class ErrorIntelligence {
  const ErrorIntelligence._();

  /// Singleton threshold: a category must repeat on the SAME topic.
  static const int patternThreshold = 2;

  /// Misconception threshold: same topic wrong three times, or wrong
  /// after a retry twice — a specific recurring wrong belief (§21).
  static const int misconceptionThreshold = 3;

  /// Classifies ONE evidence point into its raw category. Verdict +
  /// retry + kind are the only honest discriminators available —
  /// everything else stays unclassified rather than invented.
  static ErrorCategory? classify(ErrorEvidence e) {
    if (e.verdict == 'uncertain') return null; // input problem (§26)
    if (e.verdict == 'correct') {
      // Corrected after feedback = self-corrected slip: careless-ish
      // (becomes a pattern only if it repeats, §21).
      if (e.retries >= 1) return ErrorCategory.carelessMistake;
      return null;
    }
    if (e.verdict == 'revealed') return ErrorCategory.recallGap;
    if (e.verdict == 'partiallyCorrect') {
      // Typed/photo answers with partial coverage → incomplete answer;
      // recurring ones are the "structure error" pattern (§47).
      if (e.kind == 'mcq') return ErrorCategory.questionInterpretation;
      return e.retries >= 1
          ? ErrorCategory.structureError
          : ErrorCategory.incompleteAnswer;
    }
    // 'incorrect'
    if (e.retries >= 1) {
      // Tried again after feedback and STILL wrong → persistent
      // concept gap (the deepest non-misconception category).
      return ErrorCategory.conceptGap;
    }
    // First-shot miss: MCQ = recall; typed = application.
    return e.kind == 'typed'
        ? ErrorCategory.applicationGap
        : ErrorCategory.recallGap;
  }

  /// Finds all REPEATED patterns in the log. Singletons and emerging
  /// slips are deliberately dropped — one wrong answer is a mistake,
  /// not a weakness (§21).
  static List<ErrorPattern> analyze(List<ErrorEvidence> evidence) {
    // topicId → category → evidence list.
    final byTopicCategory =
        <String, Map<ErrorCategory, List<ErrorEvidence>>>{};
    for (final e in evidence) {
      final category = classify(e);
      if (category == null) continue;
      byTopicCategory
          .putIfAbsent(e.topicId, () => {})
          .putIfAbsent(category, () => [])
          .add(e);
    }

    final patterns = <ErrorPattern>[];
    byTopicCategory.forEach((topicId, categories) {
      categories.forEach((category, list) {
        final wrongs = list.length;
        if (wrongs < patternThreshold) return;

        // Misconception escalation (§21): the same topic wrong
        // repeatedly, or still-wrong after retry repeatedly, is a
        // SPECIFIC recurring misconception — not "weak at subject".
        final wrongAfterRetry =
            list.where((e) => e.isWrong && e.retries >= 1).length;
        if (category == ErrorCategory.conceptGap &&
            (wrongs >= misconceptionThreshold || wrongAfterRetry >= 2)) {
          patterns.add(_patternOf(ErrorCategory.misconception, topicId, list));
          return;
        }

        patterns.add(_patternOf(category, topicId, list));
      });
    });

    // Deterministic order: misconception first, then by occurrences
    // desc, then topicId — stable across runs (mirror parity).
    patterns.sort((a, b) {
      const rank = {
        ErrorCategory.misconception: 0,
        ErrorCategory.conceptGap: 1,
        ErrorCategory.applicationGap: 2,
        ErrorCategory.structureError: 3,
        ErrorCategory.incompleteAnswer: 4,
        ErrorCategory.recallGap: 5,
        ErrorCategory.questionInterpretation: 6,
        ErrorCategory.carelessMistake: 7,
      };
      final r = (rank[a.category] ?? 9).compareTo(rank[b.category] ?? 9);
      if (r != 0) return r;
      final o = b.occurrences.compareTo(a.occurrences);
      if (o != 0) return o;
      return a.topicId.compareTo(b.topicId);
    });
    return patterns;
  }

  static ErrorPattern _patternOf(
      ErrorCategory category, String topicId, List<ErrorEvidence> list) {
    final sorted = [...list]..sort((a, b) => a.atIso.compareTo(b.atIso));
    return ErrorPattern(
      category: category,
      topicId: topicId,
      occurrences: sorted.length,
      questionIds: sorted.map((e) => e.questionId).toList(),
      firstSeenIso: sorted.first.atIso,
      lastSeenIso: sorted.last.atIso,
    );
  }
}
