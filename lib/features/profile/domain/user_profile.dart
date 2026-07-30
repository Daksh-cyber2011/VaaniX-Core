/// User Profile — Domain Layer
///
/// Central domain model for a learner's profile and learning state.
/// Combines onboarding-derived preferences with progress data (XP, streak).
///
/// This is the single source of truth consumed by Home, Settings, Progress,
/// and Learn features. It is persisted locally (offline-first) and synced to
/// Supabase when a session is available.

import 'package:equatable/equatable.dart';

/// How Van communicates with the learner.
enum PersonalityMode {
  /// Energetic, celebratory — most encouraging.
  cheerleader,

  /// Patient, soft, steady — good for anxious learners.
  calm,

  /// Playful, humor-forward — duck puns, casual tone.
  fun;

  String get label => switch (this) {
        PersonalityMode.cheerleader => 'Cheerleader',
        PersonalityMode.calm => 'Calm',
        PersonalityMode.fun => 'Fun',
      };

  String get emoji => switch (this) {
        PersonalityMode.cheerleader => '🎉',
        PersonalityMode.calm => '🌿',
        PersonalityMode.fun => '🦆',
      };
}

/// The learner's CBSE class (6–10).
enum CbseClass {
  class6,
  class7,
  class8,
  class9,
  class10;

  int get value => index + 6;

  String get label => 'Class $value';

  static CbseClass? fromValue(int? v) {
    if (v == null) return null;
    for (final c in CbseClass.values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

/// Immutable snapshot of the learner's full profile.
class UserProfile extends Equatable {
  const UserProfile({
    this.id,
    this.companionName = 'Van',
    this.personalityMode,
    this.cbseClass,
    this.dailyGoalMinutes = 10,
    this.xpTotal = 0,
    this.currentStreak = 0,
    this.lastActiveDate,
    this.isAnonymous = true,
  });

  /// Supabase user id (null while anonymous / offline).
  final String? id;

  /// The name the learner gave to Van.
  final String companionName;

  /// Van's personality mode selected during onboarding.
  final PersonalityMode? personalityMode;

  /// The learner's CBSE class.
  final CbseClass? cbseClass;

  /// Daily learning goal in minutes.
  final int dailyGoalMinutes;

  /// Total XP earned across all lessons and quizzes.
  final int xpTotal;

  /// Current consecutive-day streak.
  final int currentStreak;

  /// ISO-8601 date string of the last active day (UTC midnight).
  final String? lastActiveDate;

  /// True when the learner has not signed in (data is local-only).
  final bool isAnonymous;

  /// A profile with safe defaults, used before onboarding completes.
  static const UserProfile empty = UserProfile();

  /// Companion name with fallback to 'Van' when blank.
  String get resolvedCompanionName =>
      companionName.trim().isEmpty ? 'Van' : companionName.trim();

  UserProfile copyWith({
    String? id,
    String? companionName,
    PersonalityMode? personalityMode,
    CbseClass? cbseClass,
    int? dailyGoalMinutes,
    int? xpTotal,
    int? currentStreak,
    String? lastActiveDate,
    bool? isAnonymous,
  }) {
    return UserProfile(
      id: id ?? this.id,
      companionName: companionName ?? this.companionName,
      personalityMode: personalityMode ?? this.personalityMode,
      cbseClass: cbseClass ?? this.cbseClass,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      xpTotal: xpTotal ?? this.xpTotal,
      currentStreak: currentStreak ?? this.currentStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  @override
  List<Object?> get props => [
        id,
        companionName,
        personalityMode,
        cbseClass,
        dailyGoalMinutes,
        xpTotal,
        currentStreak,
        lastActiveDate,
        isAnonymous,
      ];
}
