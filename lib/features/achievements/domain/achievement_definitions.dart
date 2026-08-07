/// VaaniX Achievements — Definitions
///
/// Static list of all 10 V1 achievements. Adding a new achievement is as
/// simple as appending to this list — the provider, checker, and UI all
/// react automatically.

import 'package:vaanix_app/features/achievements/domain/achievement.dart';

abstract final class AchievementDefinitions {
  static const List<Achievement> all = [
    // ─── Lessons ─────────────────────────────────────────────────────────
    Achievement(
      id: 'first_lesson',
      title: 'First Steps',
      description: 'Complete your first lesson',
      category: AchievementCategory.lessons,
      iconName: 'school',
      xpReward: 20,
      threshold: 1,
    ),
    Achievement(
      id: 'five_lessons',
      title: 'Dedicated Learner',
      description: 'Complete 5 lessons',
      category: AchievementCategory.lessons,
      iconName: 'menu_book',
      xpReward: 50,
      threshold: 5,
    ),
    Achievement(
      id: 'ten_lessons',
      title: 'Scholar',
      description: 'Complete 10 lessons',
      category: AchievementCategory.lessons,
      iconName: 'auto_stories',
      xpReward: 100,
      threshold: 10,
    ),

    // ─── Quizzes ─────────────────────────────────────────────────────────
    Achievement(
      id: 'first_quiz',
      title: 'Quiz Novice',
      description: 'Complete your first quiz',
      category: AchievementCategory.quizzes,
      iconName: 'quiz',
      xpReward: 20,
      threshold: 1,
    ),
    Achievement(
      id: 'perfect_quiz',
      title: 'Perfect Score',
      description: 'Get 100% on any quiz',
      category: AchievementCategory.quizzes,
      iconName: 'star',
      xpReward: 50,
      threshold: 100,
    ),

    // ─── Streak ──────────────────────────────────────────────────────────
    Achievement(
      id: 'three_day_streak',
      title: 'Consistent',
      description: 'Maintain a 3-day streak',
      category: AchievementCategory.streak,
      iconName: 'local_fire_department',
      xpReward: 30,
      threshold: 3,
    ),
    Achievement(
      id: 'seven_day_streak',
      title: 'Week Warrior',
      description: 'Maintain a 7-day streak',
      category: AchievementCategory.streak,
      iconName: 'whatshot',
      xpReward: 70,
      threshold: 7,
    ),

    // ─── XP ──────────────────────────────────────────────────────────────
    Achievement(
      id: '100_xp',
      title: 'Centurion',
      description: 'Earn 100 XP',
      category: AchievementCategory.xp,
      iconName: 'stars',
      xpReward: 0,
      threshold: 100,
    ),
    Achievement(
      id: '500_xp',
      title: 'XP Master',
      description: 'Earn 500 XP',
      category: AchievementCategory.xp,
      iconName: 'emoji_events',
      xpReward: 0,
      threshold: 500,
    ),

    // ─── Special ─────────────────────────────────────────────────────────
    Achievement(
      id: 'van_friend',
      title: "Van's Friend",
      description: 'Chat with Van for the first time',
      category: AchievementCategory.special,
      iconName: 'pets',
      xpReward: 10,
      threshold: 1,
    ),
  ];

  /// Lookup by id.
  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
