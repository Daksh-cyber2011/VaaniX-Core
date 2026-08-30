/// VaaniX Achievements — Domain Model
///
/// Defines the [Achievement] value object and [AchievementCategory] enum.
/// Achievements are milestones that unlock when the learner reaches a
/// threshold (lessons completed, quizzes passed, streak maintained, XP
/// earned, or special actions like chatting with Van).

import 'package:equatable/equatable.dart';

/// Category for grouping achievements in the UI.
enum AchievementCategory {
  lessons,
  quizzes,
  streak,
  xp,
  special;

  String get label => switch (this) {
        AchievementCategory.lessons => 'Lessons',
        AchievementCategory.quizzes => 'Quizzes',
        AchievementCategory.streak => 'Streak',
        AchievementCategory.xp => 'XP',
        AchievementCategory.special => 'Special',
      };

  String get emoji => switch (this) {
        AchievementCategory.lessons => '📚',
        AchievementCategory.quizzes => '🎯',
        AchievementCategory.streak => '🔥',
        AchievementCategory.xp => '⭐',
        AchievementCategory.special => '🏅',
      };
}

/// A single achievement definition. Immutable.
///
/// [isUnlocked] is NOT stored here — it's computed by the provider from
/// the learner's current progress data. This model only describes the
/// achievement itself (what it is, what threshold unlocks it, what reward
/// it gives).
class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.iconName,
    required this.xpReward,
    required this.threshold,
  });

  /// Stable unique identifier (e.g. 'first_lesson').
  final String id;

  /// Short title shown on the badge card.
  final String title;

  /// 1-2 sentence description of what the learner did to earn it.
  final String description;

  /// Category for grouping + filtering.
  final AchievementCategory category;

  /// Material icon name (mapped to IconData in the UI).
  final String iconName;

  /// Bonus XP awarded on unlock (0 for achievements that are just badges).
  final int xpReward;

  /// The numeric threshold the learner must reach to unlock this achievement.
  /// Interpretation depends on [category]:
  ///   - lessons: number of lessons completed
  ///   - quizzes: number of quizzes completed
  ///   - streak: number of consecutive days
  ///   - xp: total XP earned
  ///   - special: 1 = do the action once (e.g. chat with Van)
  final int threshold;

  @override
  List<Object?> get props =>
      [id, title, description, category, iconName, xpReward, threshold];
}

/// A snapshot of the learner's current progress toward an achievement.
/// Computed by the provider by comparing [Achievement.threshold] against
/// live progress data.
class AchievementProgress extends Equatable {
  const AchievementProgress({
    required this.achievement,
    required this.current,
    required this.isUnlocked,
    required this.unlockedAt,
  });

  final Achievement achievement;

  /// Current value (e.g. 3 lessons completed, 50 XP earned).
  final int current;

  /// True when [current] >= [achievement.threshold].
  final bool isUnlocked;

  /// When the achievement was unlocked (null if not yet unlocked).
  /// Persisted by the repository so it survives app restarts.
  final DateTime? unlockedAt;

  /// Progress fraction 0.0 – 1.0.
  double get fraction {
    if (achievement.threshold == 0) return isUnlocked ? 1.0 : 0.0;
    return (current / achievement.threshold).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [achievement, current, isUnlocked, unlockedAt];
}
