/// Exam Mode 2.0 — Targeted Remediation Engine (M8, §22/§23/§29)
///
/// Builds and judges the weak-area recovery session:
///
///   §22 recovery day focuses specifically on:
///     weak concept → short explanation → targeted practice →
///     mistakes → retry → mastery check.
///
/// Phase structure over the GROUNDED question pool (§60 — every
/// question comes from the official syllabus; nothing invented):
///   1. mistakeRetry  — the topic's previously-wrong questions first
///                      (mistake re-encounter, §23);
///   2. targetedPractice — fresh questions on the SAME topic;
///   3. recheck       — 2 held-aside FRESH questions (never previously
///                      wrong, never asked earlier in this session) —
///                      the honest mastery check (§29): recovery is
///                      CONFIRMED only when the recheck is clean.
///
/// Mastery recheck verdict (§22 "mastery check", §29 evidence):
///   recovered       — every recheck question correct;
///   stillNeedsWork  — any recheck miss. No partial credit, no
///                     percentage — the finding honestly stays open.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';

/// The remediation session's outcome (§22 mastery check).
enum RemediationOutcome { notRun, recovered, stillNeedsWork }

RemediationOutcome remediationOutcomeFromName(String? name) =>
    switch (name) {
      'recovered' => RemediationOutcome.recovered,
      'stillNeedsWork' => RemediationOutcome.stillNeedsWork,
      _ => RemediationOutcome.notRun,
    };

/// The §22 recovery-day concept recap (short explanation — trusted
/// syllabus data only, §15/§60: official section, official title,
/// official sub-topics).
class RemediationRecap extends Equatable {
  const RemediationRecap({
    required this.topicTitle,
    required this.sectionTitle,
    required this.subtopics,
  });

  final String topicTitle;
  final String sectionTitle;
  final List<String> subtopics;

  /// §28-style short recap text (grounded, no invention).
  String get recapText {
    final points = subtopics.take(4).map((s) => '• $s').join('\n');
    return '«$topicTitle» ($sectionTitle) के मुख्य बिंदु:\n'
        '${points.isEmpty ? '• आधिकारिक पाठ्यक्रम के अनुसार यह इकाई।' : points}';
  }

  @override
  List<Object?> get props => [topicTitle, sectionTitle, subtopics];
}

/// The full remediation session plan for one weak topic.
class RemediationPlan extends Equatable {
  const RemediationPlan({
    required this.topicId,
    required this.recap,
    required this.mistakeRetryQuestions,
    required this.targetedQuestions,
    required this.recheckQuestions,
  });

  final String topicId;
  final RemediationRecap recap;

  /// Phase 2: previously-wrong questions (mistake re-encounter).
  final List<PracticeQuestion> mistakeRetryQuestions;

  /// Phase 3: fresh targeted practice.
  final List<PracticeQuestion> targetedQuestions;

  /// Phase 4: mastery recheck (§22) — held-aside FRESH questions.
  final List<PracticeQuestion> recheckQuestions;

  int get totalQuestions =>
      mistakeRetryQuestions.length +
      targetedQuestions.length +
      recheckQuestions.length;

  /// The main-loop question order (mistake retry first — §22/§23).
  List<PracticeQuestion> get mainQuestions =>
      [...mistakeRetryQuestions, ...targetedQuestions];

  bool get isViable =>
      recheckQuestions.isNotEmpty && mainQuestions.isNotEmpty;

  @override
  List<Object?> get props => [topicId, mistakeRetryQuestions,
      targetedQuestions, recheckQuestions];
}

/// Deterministic remediation builder + recheck judge.
class RemediationEngine {
  const RemediationEngine._();

  /// §22 "mastery check" size — two clean answers confirm recovery.
  static const int recheckSize = 2;

  /// Max mistake-retries per recovery session (bounded, §18 spirit).
  static const int maxMistakeRetries = 3;

  /// Splits the grounded per-topic pool into the §22 phases.
  ///
  /// [previouslyWrongQuestionIds] come from the persisted attempt log
  /// (topics' wrong answers). Questions NOT in that set are FRESH —
  /// the recheck reserves [recheckSize] of them so the mastery check
  /// is never a question the student just saw (§23 "revision should
  /// not be identical to the original lesson").
  static RemediationPlan build({
    required String topicId,
    required RemediationRecap recap,
    required List<PracticeQuestion> topicPool,
    required Set<String> previouslyWrongQuestionIds,
  }) {
    final wrong = topicPool
        .where((q) => previouslyWrongQuestionIds.contains(q.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final mistakeRetry = wrong.take(maxMistakeRetries).toList();

    final fresh = topicPool
        .where((q) => !previouslyWrongQuestionIds.contains(q.id))
        .toList()
      ..sort((a, b) => a.difficultyTier.compareTo(b.difficultyTier));

    // Reserve the recheck first (FRESH questions only — honest
    // mastery check), prefer tier 2 (application-grade).
    final recheck = <PracticeQuestion>[];
    final recheckPool = <PracticeQuestion>[];
    for (final q in fresh) {
      if (q.difficultyTier == 2 && recheck.length < recheckSize) {
        recheck.add(q);
      } else {
        recheckPool.add(q);
      }
    }
    // Pool too thin for tier-2 only → top up from any fresh tier.
    for (var i = 0; i < recheckPool.length && recheck.length < recheckSize;
        i++) {
      final q = recheckPool[i];
      recheck.add(q);
      recheckPool.removeAt(i);
      i--;
    }

    return RemediationPlan(
      topicId: topicId,
      recap: recap,
      mistakeRetryQuestions: mistakeRetry,
      targetedQuestions: recheckPool,
      recheckQuestions: recheck,
    );
  }

  /// Judges the §22 mastery check from the recheck session's finalized
  /// attempts (verdict strings as recorded by the M6 engine).
  ///
  /// recovered ⇔ every recheck attempt is correct/partiallyCorrect
  /// AND at least [recheckSize] attempts exist. Anything else is
  /// honestly stillNeedsWork — no curve, no percentage.
  static RemediationOutcome judgeRecheck({
    required List<({String questionId, String verdict})> recheckAttempts,
  }) {
    if (recheckAttempts.length < recheckSize) {
      return RemediationOutcome.stillNeedsWork;
    }
    final allGood = recheckAttempts.every((a) =>
        a.verdict == 'correct' || a.verdict == 'partiallyCorrect');
    return allGood
        ? RemediationOutcome.recovered
        : RemediationOutcome.stillNeedsWork;
  }

  /// §28-style closing line for the outcome (no percentages, §30).
  static String outcomeSummary(RemediationOutcome outcome) => switch (outcome) {
        RemediationOutcome.recovered =>
          'अच्छा — mastery जाँच साफ़ हो गई। अब इस विषय का दोहराव थोड़ा '
              'लंबा अंतराल पर रखेंगे।',
        RemediationOutcome.stillNeedsWork => 'अभी पूरी तरह पक्का नहीं हुआ — '
            'कोई बात नहीं, अगली recovery में फिर छूएँगे। कम-से-कम आगे बढ़ते रहें।',
        RemediationOutcome.notRun => 'mastery जाँच अभी शुरू नहीं हुई।',
      };
}
