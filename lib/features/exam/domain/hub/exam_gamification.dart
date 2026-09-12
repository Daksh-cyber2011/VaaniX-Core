/// Exam Mode 2.0 — Session Gamification Domain (M10)
///
/// Pure, deterministic rules that turn a FINISHED exam-mode session
/// (diagnostic / practice / recovery / revision / PYQ / mock) into the
/// app-wide gamification the Nest already speaks: XP, streak evidence
/// and honest celebration copy.
///
/// Design rules (master plan §M10 + the honesty standard):
///  * XP is earned ONLY from finalized, persisted evidence — the same
///    attempts the mastery/§21 engines already recorded. A session that
///    crashed before persisting awards nothing.
///  * The XP formula is deterministic and bounded per session: no
///    inflation, no random bonuses, no "engagement" multipliers.
///  * One finished session can award XP exactly ONCE: the award is
///    keyed by a fingerprint of (kind, track, questions, verdicts), so
///    re-rendering or re-opening the finish screen never re-awards.
///  * Copy is honest: the outcome line reports exactly what happened
///    (XP earned, streak state, real unlocks) — never a fabricated
///    "achievement" or a synthetic celebration.
///
/// Pure Dart — no Flutter, no Riverpod, no I/O.
library;

/// Which exam-mode session finished. Drives the XP rates and the
/// plan-day completion mapping (a finished [recovery] or [revision]
/// session marks the day's weakArea/review tasks done).
enum ExamSessionKind {
  diagnostic,
  practice,
  recovery,
  revision,
  pyq,
  mock,
}

ExamSessionKind? examSessionKindFromName(String? name) => switch (name) {
      'diagnostic' => ExamSessionKind.diagnostic,
      'practice' => ExamSessionKind.practice,
      'recovery' => ExamSessionKind.recovery,
      'revision' => ExamSessionKind.revision,
      'pyq' => ExamSessionKind.pyq,
      'mock' => ExamSessionKind.mock,
      _ => null,
    };

/// XP rules per session kind. Values are deliberately small: exam-mode
/// sessions are short (§9 budgets), and the Nest's level curve needs
/// 100·level XP — a typical practice session (6-8 questions) should
/// move the bar, not jump three levels.
const Map<ExamSessionKind, int> _xpPerCorrect = {
  ExamSessionKind.diagnostic: 3,
  ExamSessionKind.practice: 2,
  ExamSessionKind.recovery: 2,
  ExamSessionKind.revision: 2,
  ExamSessionKind.pyq: 3,
  ExamSessionKind.mock: 4,
};

const Map<ExamSessionKind, int> _completionBonus = {
  ExamSessionKind.diagnostic: 5,
  ExamSessionKind.practice: 3,
  ExamSessionKind.recovery: 8,
  ExamSessionKind.revision: 4,
  ExamSessionKind.pyq: 4,
  ExamSessionKind.mock: 15,
};

/// Upper bound on XP a single session may award. Mocks run long, so
/// their bound is higher; everything else caps at a practice-sized
/// honest reward. Guards against corrupt verdict counts ever minting
/// thousands of XP (§57 defensive data).
const Map<ExamSessionKind, int> _sessionXpCap = {
  ExamSessionKind.diagnostic: 60,
  ExamSessionKind.practice: 40,
  ExamSessionKind.recovery: 40,
  ExamSessionKind.revision: 40,
  ExamSessionKind.pyq: 60,
  ExamSessionKind.mock: 120,
};

/// Deterministic XP computation for one finished session.
///
/// [correctCount] / [totalCount] come from the FINALIZED attempts
/// (verdict correct; partial/revealed count as not-correct — the same
/// honesty as §29 mastery). A perfect run on a real-sized session
/// earns a small bonus; "perfect" on a 1-question session does not
/// (that would reward clicking one button).
class ExamSessionXp {
  const ExamSessionXp._();

  /// XP for the correct answers of a session.
  static int correctXp(ExamSessionKind kind, int correctCount) =>
      _xpPerCorrect[kind]! * correctCount;

  /// Flat bonus for finishing the session at all.
  static int completionBonus(ExamSessionKind kind) => _completionBonus[kind]!;

  /// True when the run deserves the perfect-session bonus: everything
  /// correct AND at least 5 questions (a real demonstration).
  static bool deservesPerfectBonus(int correctCount, int totalCount) =>
      totalCount >= 5 && correctCount == totalCount;

  /// Total session award, bounded by the kind's cap.
  static int total({
    required ExamSessionKind kind,
    required int correctCount,
    required int totalCount,
  }) {
    if (totalCount <= 0 || correctCount < 0) return 0;
    final base = correctXp(kind, correctCount) + completionBonus(kind);
    final withPerfect = deservesPerfectBonus(correctCount, totalCount)
        ? base + 5
        : base;
    return withPerfect.clamp(0, _sessionXpCap[kind]!);
  }

  /// The maximum award this kind can ever give (for UI honesty lines).
  static int capOf(ExamSessionKind kind) => _sessionXpCap[kind]!;
}

/// One finished session, described ONLY by persisted evidence.
class ExamSessionRecord {
  const ExamSessionRecord({
    required this.kind,
    required this.trackId,
    required this.correctCount,
    required this.totalCount,
    required this.questionFingerprint,
    required this.finishedAt,
  });

  final ExamSessionKind kind;
  final String trackId;
  final int correctCount;
  final int totalCount;

  /// Stable fingerprint of the question set + final verdicts (built by
  /// the calling controller from the session state). Equal fingerprints
  /// ⇒ the same session; the XP ledger uses this for once-ever awards.
  final String questionFingerprint;

  /// When the session finished (used for the day-key).
  final DateTime finishedAt;

  /// yyyy-mm-dd day key (local date — streaks and plan days are local
  /// calendar concepts).
  String get dayKey {
    final y = finishedAt.year.toString().padLeft(4, '0');
    final m = finishedAt.month.toString().padLeft(2, '0');
    final d = finishedAt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Once-ever award source id for the progress repository's bonus
  /// ledger (awardBonusXp is idempotent per source id).
  String get xpSourceId =>
      'exam_xp_${kind.name}_${trackId}_$questionFingerprint';

  /// XP this session awards (bounded, deterministic).
  int get award => ExamSessionXp.total(
        kind: kind,
        correctCount: correctCount,
        totalCount: totalCount,
      );

  /// Plan task type this session counts as "done" for the day. A
  /// diagnostic is setup work, not a plan task — it marks nothing.
  /// Recovery marks weakArea (its primary purpose); revision marks
  /// review. Both keep their own kind for the completion map.
  String? get planTaskTypeName => switch (kind) {
        ExamSessionKind.diagnostic => null,
        ExamSessionKind.practice => 'practice',
        ExamSessionKind.recovery => 'weakArea',
        ExamSessionKind.revision => 'review',
        ExamSessionKind.pyq => 'pyq',
        ExamSessionKind.mock => 'mock',
      };
}

/// The honest outcome of running a finished session through the
/// gamification service — what actually happened, nothing invented:
///  * [xpAwarded] — XP newly awarded (0 when the ledger already paid
///    this session, or when the award itself failed).
///  * [streakExtended] — today's activity genuinely extended the
///    streak (same-day repeats report false).
///  * [newAchievements] / [newMilestones] — titles of REAL unlocks
///    from the shared checkers (usually empty — the exam-mode content
///    does not fabricate curriculum achievements).
class ExamSessionOutcome {
  const ExamSessionOutcome({
    required this.trackId,
    required this.kind,
    required this.xpAwarded,
    required this.streakExtended,
    required this.currentStreak,
    required this.newAchievements,
    required this.newMilestones,
  });

  final String trackId;
  final ExamSessionKind kind;
  final int xpAwarded;
  final bool streakExtended;
  final int currentStreak;
  final List<String> newAchievements;
  final List<String> newMilestones;

  /// Honest single line for the finish screens' XP strip. Reports only
  /// what happened; an all-zero outcome stays silent (empty string).
  String get headline {
    final parts = <String>[];
    if (xpAwarded > 0) parts.add('+$xpAwarded XP');
    if (streakExtended && currentStreak > 0) {
      parts.add('$currentStreak-day streak');
    }
    if (newAchievements.isNotEmpty) {
      parts.add('${newAchievements.length} achievement'
          '${newAchievements.length > 1 ? 's' : ''}');
    }
    if (newMilestones.isNotEmpty) {
      parts.add('${newMilestones.length} milestone'
          '${newMilestones.length > 1 ? 's' : ''}');
    }
    return parts.join(' · ');
  }
}
