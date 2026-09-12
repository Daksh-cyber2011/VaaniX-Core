/// Exam Mode 2.0 — Practice Session Engine (M6, §19/§28/§29)
///
/// The adaptive learning loop (§19): learn → practice → feedback →
/// retry → mastery → next step.
///
/// Loop rules:
///  * MCQ answers are graded deterministically (score integrity is
///    NEVER AI's job, §14).
///  * TYPED (and photo-extracted) answers are graded by the M7
///    [RubricEvaluator] (§27 rubric, §26 uncertainty).
///  * Retry budget: ONE retry for incorrect / partially-correct /
///    uncertain answers (§28 "Then: Try again."). After the budget,
///    the verdict is final and the explanation is revealed —
///    honest, never shaming.
///  * Feedback is ALWAYS shown before advancing: a final verdict
///    sets [PracticeSessionState.awaitingNext]; the attempt is
///    recorded when the student advances (or reveals).
///  * Mastery connection (§29): finalized attempts update the
///    learner profile (correct ⇒ strengthen; incorrect/revealed ⇒
///    the topic re-enters the weak set for the next session).
///  * Closing summary is §28-style constructive — no percentages
///    (§30).
///
/// Pure Dart — no Flutter imports.
library;

import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/rubric_evaluator.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';

class PracticeSessionEngine {
  const PracticeSessionEngine({this.maxRetries = 1});

  /// §28 retry budget per question (one "Try again" per question).
  final int maxRetries;

  /// Starts a session over [questions].
  PracticeSessionState start(List<PracticeQuestion> questions) {
    return PracticeSessionState(
      questions: questions,
      index: 0,
      attempts: const [],
      currentVerdictText: null,
      currentRetryCount: 0,
      currentVerdict: null,
      awaitingNext: false,
      finished: questions.isEmpty,
    );
  }

  /// Submits an MCQ answer for the current question.
  PracticeSessionState submitMcq(
      PracticeSessionState state, int selectedIndex) {
    final q = state.current;
    if (q == null || state.finished || state.awaitingNext) return state;
    final result = RubricEvaluator.evaluateMcq(
      correctIndex: q.correctIndex!,
      selectedIndex: selectedIndex,
      correctOptionText: q.options[q.correctIndex!],
    );
    return _absorb(state, q, result);
  }

  /// Submits a TYPED / photo-extracted answer for the current
  /// question (graded by the M7 rubric evaluator).
  PracticeSessionState submitTyped(
    PracticeSessionState state,
    String studentAnswer,
  ) {
    final q = state.current;
    if (q == null || state.finished || state.awaitingNext) return state;
    final result = RubricEvaluator.evaluateTyped(
      questionPrompt: q.prompt,
      studentAnswer: studentAnswer,
      answerData: RubricAnswerData(
        acceptedAnswers: q.acceptedAnswers,
        requiredPoints: q.requiredPoints,
      ),
      isRetry: state.currentRetryCount >= maxRetries,
    );
    return _absorb(state, q, result);
  }

  /// Records a photo-evaluation result (M7 vision pipeline already
  /// produced the evaluation; the loop only absorbs it). Uncertain
  /// photo results keep the question OPEN for retake/typing (§26).
  PracticeSessionState submitPhotoEvaluation(
      PracticeSessionState state, EvaluationResult result) {
    final q = state.current;
    if (q == null || state.finished || state.awaitingNext) return state;
    if (result.verdict == EvaluationVerdict.uncertain) {
      // The photo path hands uncertainty back to the UI as advice;
      // the loop itself treats it as a retry-consumed miss ONLY when
      // the budget is spent (handled by _absorb below).
    }
    return _absorb(state, q, result);
  }

  /// Student chose "try again" after feedback: re-opens input on the
  /// SAME question (retry count already consumed by the missed
  /// attempt).
  PracticeSessionState retryAttempt(PracticeSessionState state) {
    if (state.awaitingNext || state.finished) return state;
    return PracticeSessionState(
      questions: state.questions,
      index: state.index,
      attempts: state.attempts,
      currentVerdictText: null,
      currentRetryCount: state.currentRetryCount,
      currentVerdict: null,
      awaitingNext: false,
      finished: false,
    );
  }

  /// Reveals the answer without retrying (student choice — §20
  /// freedom). Sets the reveal feedback; the attempt is recorded on
  /// [advance] as 'revealed' (not-correct for mastery honesty, §29).
  PracticeSessionState reveal(PracticeSessionState state) {
    final q = state.current;
    if (q == null || state.finished || state.awaitingNext) return state;
    final explanation =
        q.explanation ?? 'उत्तर: ${q.acceptedAnswers.join(' / ')}';
    return PracticeSessionState(
      questions: state.questions,
      index: state.index,
      attempts: state.attempts,
      currentVerdictText: explanation,
      currentRetryCount: state.currentRetryCount,
      currentVerdict: 'revealed',
      awaitingNext: true,
      finished: false,
    );
  }

  /// Advances past the current question (records the finalized
  /// attempt — the mastery evidence, §29).
  PracticeSessionState advance(PracticeSessionState state) {
    final q = state.current;
    if (q == null || state.finished || !state.awaitingNext) return state;
    final verdict = state.currentVerdict ?? 'incorrect';
    final attempts = [
      ...state.attempts,
      PracticeAttempt(
        questionId: q.id,
        topicId: q.topicId,
        verdict: verdict,
        retries: state.currentRetryCount,
        attemptedAtIso: DateTime.now().toIso8601String(),
      ),
    ];
    final nextIndex = state.index + 1;
    final finished = nextIndex >= state.questions.length;
    return PracticeSessionState(
      questions: state.questions,
      index: finished ? state.index : nextIndex,
      attempts: attempts,
      currentVerdictText: null,
      currentRetryCount: 0,
      currentVerdict: null,
      awaitingNext: false,
      finished: finished,
    );
  }

  PracticeSessionState _absorb(
    PracticeSessionState state,
    PracticeQuestion q,
    EvaluationResult result,
  ) {
    final canRetry = state.currentRetryCount < maxRetries;
    final correct = result.verdict == EvaluationVerdict.correct;

    if (correct) {
      // Final: feedback shown, awaiting the student's "next" tap.
      return PracticeSessionState(
        questions: state.questions,
        index: state.index,
        attempts: state.attempts,
        currentVerdictText: result.feedback,
        currentRetryCount: state.currentRetryCount,
        currentVerdict: 'correct',
        awaitingNext: true,
        finished: false,
      );
    }

    if (canRetry) {
      // §28: specific feedback + ONE invited retry.
      return PracticeSessionState(
        questions: state.questions,
        index: state.index,
        attempts: state.attempts,
        currentVerdictText: result.feedback,
        currentRetryCount: state.currentRetryCount + 1,
        currentVerdict: result.verdict.name,
        awaitingNext: false,
        finished: false,
      );
    }

    // Budget spent → final verdict, explanation revealed.
    final closing =
        '${result.feedback} ${q.explanation ?? ''}'.trim();
    return PracticeSessionState(
      questions: state.questions,
      index: state.index,
      attempts: state.attempts,
      currentVerdictText: closing.isEmpty ? result.feedback : closing,
      currentRetryCount: state.currentRetryCount,
      currentVerdict: switch (result.verdict) {
        EvaluationVerdict.partiallyCorrect => 'partiallyCorrect',
        EvaluationVerdict.uncertain => 'incorrect',
        _ => 'incorrect',
      },
      awaitingNext: true,
      finished: false,
    );
  }

  /// The mastery update batch the provider applies to the learner
  /// profile (§29 connection): correct/partial ⇒ true, else false.
  /// 'revealed' counts as not-correct (honest evidence, §29).
  static Map<String, bool> masteryUpdates(PracticeSessionState state) {
    final updates = <String, bool>{};
    for (final a in state.attempts) {
      final correct =
          a.verdict == 'correct' || a.verdict == 'partiallyCorrect';
      updates[a.topicId] = correct;
    }
    return updates;
  }

  /// §28-style closing summary (constructive; no percentages, §30).
  static String summary(PracticeSessionState state) {
    final total = state.attempts.length;
    if (total == 0) return 'आज कोई प्रश्न हल नहीं हुआ — कल फिर शुरू करें।';
    final good = state.correctCount;
    if (good == total) {
      return 'सभी $total प्रश्न अच्छे से हुए — अब कठिन दिशा में बढ़ेंगे।';
    }
    if (good >= total / 2) {
      return '$total में से $good अच्छे रहे — गलतियों को दोहराव में '
          'पक्का करेंगे।';
    }
    return 'आज कुछ कठिन रहा — कोई बात नहीं। कल वही विषय हल्के तरीके से '
        'दोहराएँगे।';
  }
}
