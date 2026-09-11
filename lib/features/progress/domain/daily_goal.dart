/// Daily Goal — Domain Layer (Milestone 7)
///
/// Pure helpers for the daily-goal gamification loop: the learner's
/// onboarding goal is expressed in MINUTES (5/10/15/20), while the app's
/// measurable learning currency is XP. This module defines the honest,
/// deterministic mapping between the two and the date-key helpers that
/// keep per-day counters rolling over at local midnight.
///
/// XP mapping: every 1 minute of the daily goal maps to
/// [kDailyGoalXpPerMinute] XP. At 2 XP/min the default 10-minute goal is
/// 20 XP — roughly one completed lesson plus a handful of correct quiz
/// answers, which matches the ~10 XP/lesson reward scale already shipped.
///
/// The mapping is intentionally XP (not raw minutes): XP only increases
/// through the progress repository's idempotent award paths (lesson
/// completion, exam scoring, bonus ledger), so a daily XP counter can
/// never be inflated by re-reading content.
library;

/// XP that satisfies one minute of the daily goal.
const int kDailyGoalXpPerMinute = 2;

/// Local-midnight date key ('YYYY-MM-DD') matching the profile
/// repository's lastActiveDate format, so daily counters, streak windows
/// and review-challenge claims all share ONE day boundary.
String dailyGoalDateKey(DateTime now) {
  return '${now.year.toString().padLeft(4, '0')}'
      '-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';
}

/// The XP target for a goal expressed in minutes.
int dailyGoalXpTarget(int dailyGoalMinutes) {
  if (dailyGoalMinutes <= 0) return 0;
  return dailyGoalMinutes * kDailyGoalXpPerMinute;
}

/// Immutable daily-goal snapshot for the UI.
class DailyGoalState {
  const DailyGoalState({
    required this.dateKey,
    required this.xpEarnedToday,
    required this.goalMinutes,
  });

  /// The day this snapshot belongs to ('YYYY-MM-DD', local).
  final String dateKey;

  /// XP earned today through real learning events.
  final int xpEarnedToday;

  /// The learner's daily goal in minutes (from their profile).
  final int goalMinutes;

  /// XP target derived from the goal minutes (never negative).
  int get xpTarget => dailyGoalXpTarget(goalMinutes);

  /// 0.0–1.0 progress towards today's goal (1.0 when already met or when
  /// the goal is configured to zero).
  double get fraction {
    if (xpTarget <= 0) return 1;
    return (xpEarnedToday / xpTarget).clamp(0.0, 1.0);
  }

  /// True when today's goal is met.
  bool get isMet => xpTarget <= 0 ? true : xpEarnedToday >= xpTarget;

  /// Remaining XP to reach the goal today (0 when met).
  int get xpRemaining {
    final remaining = xpTarget - xpEarnedToday;
    return remaining > 0 ? remaining : 0;
  }
}
