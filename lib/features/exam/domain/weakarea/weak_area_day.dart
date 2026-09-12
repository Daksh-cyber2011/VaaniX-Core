/// Exam Mode 2.0 — Weak-Area Recovery Day (M8, master plan §22)
///
/// §22 makes the recovery day a CORE FEATURE with strict rules:
///   "VaaniX may deliberately reserve a day/session for weak-area
///    recovery… Do not make every day weak-area day. The system
///    decides frequency based on evidence. A student performing well
///    might get occasional recovery. A struggling student might get
///    recovery more frequently."
///
/// Encoded decision rules:
///  * evidence tier from the weak-area report:
///      struggling (any needsAttention finding)  → recovery at most
///        every 3rd study day;
///      steady (focus findings / overdue revision) → every 5th;
///      solid (only watch / fresh due items)      → at most every 7th;
///  * HARD CAPS regardless of tier: never two recovery days in a
///    row, never a recovery day on a track with NO evidence at all
///    (fresh tracks keep the §13 sequence, no fake "recovery");
///  * the chosen day is the earliest window day that satisfies the
///    gap rule — so the plan is explainable (§50): the decision ships
///    a rationale sentence, not a mystery;
///  * the recovery day's STRUCTURE (§22): weak concept recap → short
///    explanation → targeted practice → mistakes retry → mastery
///    check — materialized as [RecoveryDayBlueprint] phases.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';

/// How often the system offers a recovery day (§22 frequency tiers).
enum RecoveryFrequency { none, occasional, frequent }

RecoveryFrequency recoveryFrequencyFromName(String? name) => switch (name) {
      'occasional' => RecoveryFrequency.occasional,
      'frequent' => RecoveryFrequency.frequent,
      _ => RecoveryFrequency.none,
    };

/// The engine's decision for the current 7-day window.
class WeakAreaDayDecision extends Equatable {
  const WeakAreaDayDecision({
    required this.shouldRecover,
    required this.frequency,
    required this.dayIndex,
    required this.focusTopicId,
    required this.rationale,
  });

  final bool shouldRecover;
  final RecoveryFrequency frequency;

  /// Window day (0-based) reserved for recovery; −1 when not reserved.
  final int dayIndex;

  /// The topic the recovery day works on (top finding, §22 example:
  /// "Grammar Recovery Day").
  final String focusTopicId;

  /// §50-style explainable rationale (§30-clean).
  final String rationale;

  @override
  List<Object?> get props => [shouldRecover, frequency, dayIndex, focusTopicId];
}

/// One phase of the recovery day structure (§22 list, in order).
enum RecoveryPhase { recap, mistakeRetry, targetedPractice, recheck }

RecoveryPhase? recoveryPhaseFromName(String? name) => switch (name) {
      'mistakeRetry' => RecoveryPhase.mistakeRetry,
      'targetedPractice' => RecoveryPhase.targetedPractice,
      'recheck' => RecoveryPhase.recheck,
      _ => RecoveryPhase.recap,
    };

extension RecoveryPhaseX on RecoveryPhase {
  /// Student-facing phase label (§22 flow, §28 tone).
  String get label => switch (this) {
        RecoveryPhase.recap => 'छोटा concept दोहराव',
        RecoveryPhase.mistakeRetry => 'पुरानी गलतियाँ फिर से',
        RecoveryPhase.targetedPractice => 'लक्षित अभ्यास',
        RecoveryPhase.recheck => 'mastery जाँच',
      };
}

/// The recovery day's blueprint (topic + phases with minutes). The
/// planner converts this into budget-validated tasks; the session
/// engine executes the phases.
class RecoveryDayBlueprint extends Equatable {
  const RecoveryDayBlueprint({
    required this.topicId,
    required this.topicTitle,
    required this.phases,
    required this.rationale,
  });

  final String topicId;
  final String topicTitle;
  final List<RecoveryPhase> phases;
  final String rationale;

  int get totalMinutes =>
      phases.length * 10; // ~10 focused minutes per phase (§9-friendly).

  @override
  List<Object?> get props => [topicId, phases];
}

/// Deterministic recovery-day decision engine (§22).
class WeakAreaDayEngine {
  const WeakAreaDayEngine._();

  /// Frequency tiers (study-day gaps between recovery days).
  static const Map<RecoveryFrequency, int> frequencyGapDays = {
    RecoveryFrequency.frequent: 3,
    RecoveryFrequency.occasional: 5,
    RecoveryFrequency.none: 7,
  };

  /// The decision for one rolling window.
  ///
  /// [dayCount] = study days in the window (plan days).
  /// [daysSinceLastRecovery] = null → never had one.
  /// [lastRecoveryDayIndex] = the previous window day that was a
  /// recovery day, when the last recovery happened THIS window.
  ///
  /// NOTE: the rationale intentionally stays TITLE-FREE — the
  /// decision layer has no syllabus access, so the resolved topic
  /// title is rendered by the UI/planner, never a raw topicId (§30
  /// honesty: no internal ids leak to students).
  static WeakAreaDayDecision decide({
    required WeakAreaReport report,
    required List<RevisionItem> revisionItems,
    required int dayCount,
    int? daysSinceLastRecovery,
    int? lastRecoveryDayIndex,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final focus = report.attentionFirst;
    final top = focus.isEmpty ? null : focus.first;

    // Tier 1 — struggling: any needs-attention finding (§22
    // "struggling student might get recovery more frequently").
    if (report.hasAttentionFinding && top != null) {
      return _decide(
        frequency: RecoveryFrequency.frequent,
        focus: top.topicId,
        dayCount: dayCount,
        daysSinceLastRecovery: daysSinceLastRecovery,
        lastRecoveryDayIndex: lastRecoveryDayIndex,
        rationale:
            'इस हफ़्ते का एक दिन कमज़ोर क्षेत्र की recovery पर रखा गया है — '
            'डायग्नोस्टिक और अभ्यास दोनों यही कह रहे हैं।',
      );
    }

    // Tier 2 — steady: focus-level findings OR revision overdue.
    final overdue = revisionItems
        .where((i) => i.bandOf(t) == RevisionRiskBand.overdue)
        .length;
    if ((focus.isNotEmpty && focus.first.severity == WeakSeverity.focus) ||
        overdue >= 2) {
      final focusId = focus.isNotEmpty
          ? focus.first.topicId
          : (revisionItems.isEmpty ? '' : revisionItems.first.topicId);
      return _decide(
        frequency: RecoveryFrequency.occasional,
        focus: focusId,
        dayCount: dayCount,
        daysSinceLastRecovery: daysSinceLastRecovery,
        lastRecoveryDayIndex: lastRecoveryDayIndex,
        rationale: overdue >= 2 && focus.isEmpty
            ? 'दो विषयों का दोहराव टल गया है — एक दिन हल्की recovery + '
                'दोहराव पर देंगे।'
            : 'इस हफ़्ते एक दिन recovery पर — धीरे-धीरे उस विषय को पक्का '
                'करेंगे।',
      );
    }

    // Tier 3 — solid: only watch findings / fresh due items → at most
    // once a week, and only when something is actually due.
    final dueSoon = revisionItems
        .where((i) => i.bandOf(t) != RevisionRiskBand.fresh)
        .toList();
    if (focus.isNotEmpty || dueSoon.isNotEmpty) {
      final focusId = focus.isNotEmpty
          ? focus.first.topicId
          : (dueSoon.isEmpty ? '' : dueSoon.first.topicId);
      return _decide(
        frequency: RecoveryFrequency.none,
        focus: focusId,
        dayCount: dayCount,
        daysSinceLastRecovery: daysSinceLastRecovery,
        lastRecoveryDayIndex: lastRecoveryDayIndex,
        rationale:
            'प्रगति ठीक है — बस एक हल्की recovery रखी गई है ताकि दोहराव '
            'छूटे नहीं।',
      );
    }

    // Tier 4 — nothing weak, nothing due: NO recovery day (§22 "Do
    // not make every day weak-area day").
    return const WeakAreaDayDecision(
      shouldRecover: false,
      frequency: RecoveryFrequency.none,
      dayIndex: -1,
      focusTopicId: '',
      rationale: 'अभी किसी recovery दिन की ज़रूरत नहीं — आपकी प्रगति '
          'संतुलित है।',
    );
  }

  static WeakAreaDayDecision _decide({
    required RecoveryFrequency frequency,
    required String focus,
    required int dayCount,
    required int? daysSinceLastRecovery,
    required int? lastRecoveryDayIndex,
    required String rationale,
  }) {
    // No evidence → never a recovery day (honest floor).
    if (focus.isEmpty || dayCount < 1) {
      return WeakAreaDayDecision(
        shouldRecover: false,
        frequency: RecoveryFrequency.none,
        dayIndex: -1,
        focusTopicId: '',
        rationale: 'अभी recovery के लिए पर्याप्त सबूत नहीं है।',
      );
    }

    // Gap rule: minimum study-days since the last recovery (§22
    // frequency by tier). Never had one → eligible from day 1.
    final gap = frequencyGapDays[frequency]!;
    final eligible = daysSinceLastRecovery == null ||
        daysSinceLastRecovery >= gap;

    // Hard cap: no back-to-back recovery days inside a window —
    // the candidate must be ≥ 2 days after the previous recovery
    // day of THIS window (§22 "Do not make every day weak-area day").
    var day = -1;
    if (eligible) {
      day = 1; // earliest candidate: window day 1 (day 0 keeps §13 flow)
      if (lastRecoveryDayIndex != null && day <= lastRecoveryDayIndex + 1) {
        day = lastRecoveryDayIndex + 2;
      }
      if (day >= dayCount) day = -1;
    }

    return WeakAreaDayDecision(
      shouldRecover: day >= 0,
      frequency: frequency,
      dayIndex: day,
      focusTopicId: focus,
      rationale: rationale,
    );
  }

  /// The §22 recovery-day structure for a topic.
  static RecoveryDayBlueprint blueprintFor(String topicId, String topicTitle,
      {String rationale = ''}) {
    return RecoveryDayBlueprint(
      topicId: topicId,
      topicTitle: topicTitle,
      phases: const [
        RecoveryPhase.recap,
        RecoveryPhase.mistakeRetry,
        RecoveryPhase.targetedPractice,
        RecoveryPhase.recheck,
      ],
      rationale: rationale,
    );
  }
}
