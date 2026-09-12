/// Learn Mode 2.0 — Learner Profile (M1 Architecture Spine)
///
/// The slow-changing INTENT side of the learner model (Master Brief §10):
/// who the learner wants to become — goal, desired level, pace. The
/// fast-changing evidence side lives in [LearningState] (mastery map,
/// review queue, recent performance).
///
/// Master Brief §10 field list → M1 mapping:
/// - language                    → [LearnerProfile.language]
/// - current estimated level     → [LearnerProfile.currentLevel] (diagnostic, M3)
/// - desired level               → [LearnerProfile.desiredLevel]
/// - learning goal               → [LearnerProfile.goal]
/// - strengths / weaknesses /
///   mastery map / review queue /
///   recent performance          → LearningState (spine/learning_state.dart)
/// - learning pace               → [LearnerProfile.pace]
/// - session history             → LearningSession records (M6)
/// - preferred practice style    → [LearnerProfile.practiceStyle]
/// - completed milestones        → [LearnerProfile.completedMilestones]
/// - current path                → [LearnerProfile.currentPath]
/// - last activity               → [LearnerProfile.lastActivity]
/// - confidence indicators       → LearningState dimension confidence (M3)
///
/// No sensitive information is stored (Master Brief §10) — learning data
/// only. M2 wires persistence (`learn_profile_<lang>` namespace); M1 ships
/// the validated model with JSON round-trip so storage is a drop-in.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';

/// What the learner wants to achieve (Master Brief §28 options).
enum LearningGoal {
  general('General learning'),
  conversation('Conversation'),
  reading('Reading'),
  writing('Writing'),
  travel('Travel'),
  school('School / basic literacy'),
  culture('Cultural understanding'),
  mastery('Advanced mastery');

  const LearningGoal(this.label);

  /// Human-readable label for UI pickers (M2).
  final String label;

  static LearningGoal? tryParse(String? name) {
    for (final g in values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

/// How far the learner wants to go (Master Brief §29).
///
/// These are VaaniX INTERNAL levels — never presented as formal CEFR
/// certification (Master Brief §29).
enum DesiredLevel {
  starter('Starter'),
  beginner('Beginner'),
  elementary('Elementary'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const DesiredLevel(this.label);

  /// Clearly-labelled internal level name (Master Brief §29).
  final String label;

  static DesiredLevel? tryParse(String? name) {
    for (final d in values) {
      if (d.name == name) return d;
    }
    return null;
  }
}

/// Preferred learning pace (drives planner session sizing, M4+).
enum LearningPace {
  gentle('A little each day'),
  steady('Regular practice'),
  intense('Intensive');

  const LearningPace(this.label);

  final String label;

  static LearningPace? tryParse(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Preferred practice style (Master Brief §10, optional).
enum PracticeStyle {
  mixed('A bit of everything'),
  visual('Seeing and reading'),
  listening('Listening and repeating'),
  speaking('Speaking and doing');

  const PracticeStyle(this.label);

  final String label;

  static PracticeStyle? tryParse(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// The learner's COARSE self-reported starting point (Master Brief §10 —
/// "I know almost nothing" / "I can read Hindi but struggle to speak").
///
/// This is deliberately NOT a level selection (Master Brief §11: the
/// diagnostic, not the learner, estimates the level) — it seeds the M3
/// diagnostic's starting difficulty and the planner's pre-diagnostic
/// default. Never shown back to the user as a level.
enum SelfReport {
  almostNothing('I know almost nothing'),
  recognizeScript("I can read the script, words are hard"),
  understandBasics('I understand some basics'),
  conversational('I can already chat a little');

  const SelfReport(this.label);

  /// First-person label shown on the profile picker tiles.
  final String label;

  /// Coarse internal-level hint derived from the report (0..4 scale).
  /// Used only to seed the M3 diagnostic and the pre-diagnostic planner
  /// default — never displayed as the learner's level.
  int get suggestedLevel => switch (this) {
        SelfReport.almostNothing => 0,
        SelfReport.recognizeScript => 1,
        SelfReport.understandBasics => 1,
        SelfReport.conversational => 2,
      };

  static SelfReport? tryParse(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// The learner's per-language profile (slow-changing intent).
class LearnerProfile extends Equatable {
  const LearnerProfile({
    required this.language,
    this.currentLevel,
    this.desiredLevel = DesiredLevel.beginner,
    this.goal = LearningGoal.general,
    this.pace = LearningPace.steady,
    this.practiceStyle = PracticeStyle.mixed,
    this.selfReport = SelfReport.almostNothing,
    this.dailyGoalMinutes = kDefaultDailyGoalMinutes,
    this.completedMilestones = const <String>[],
    this.currentPath = const <String>[],
    this.lastActivity,
    this.createdAt,
  });

  /// Default daily goal in minutes (flexible, non-punitive — Master Brief
  /// §58: consistency matters more than huge sessions).
  static const int kDefaultDailyGoalMinutes = 10;

  final LearnLanguage language;

  /// Internal 0..4 estimated level (diagnostic output, M3). `null` = not
  /// yet diagnosed; the planner must then treat the learner as a starter.
  final int? currentLevel;

  final DesiredLevel desiredLevel;
  final LearningGoal goal;
  final LearningPace pace;
  final PracticeStyle practiceStyle;

  /// Coarse self-reported starting point (M2). Seeds the M3 diagnostic
  /// difficulty and the pre-diagnostic planner default — never displayed
  /// as a level (Master Brief §11).
  final SelfReport selfReport;

  /// Daily goal in minutes; measured against REAL learning actions only
  /// (opening the app never counts — Master Brief §58).
  final int dailyGoalMinutes;

  /// Competency milestone ids already unlocked (M7 defines the catalogue).
  final List<String> completedMilestones;

  /// Concept ids on the learner's current personal path.
  final List<String> currentPath;

  final DateTime? lastActivity;
  final DateTime? createdAt;

  /// The safe starting profile for a brand-new learner of [language].
  factory LearnerProfile.initial(LearnLanguage language) => LearnerProfile(
        language: language,
        createdAt: DateTime.now(),
      );

  LearnerProfile copyWith({
    LearnLanguage? language,
    int? currentLevel,
    bool clearCurrentLevel = false,
    DesiredLevel? desiredLevel,
    LearningGoal? goal,
    LearningPace? pace,
    PracticeStyle? practiceStyle,
    SelfReport? selfReport,
    int? dailyGoalMinutes,
    List<String>? completedMilestones,
    List<String>? currentPath,
    DateTime? lastActivity,
    DateTime? createdAt,
  }) {
    return LearnerProfile(
      language: language ?? this.language,
      currentLevel:
          clearCurrentLevel ? null : (currentLevel ?? this.currentLevel),
      desiredLevel: desiredLevel ?? this.desiredLevel,
      goal: goal ?? this.goal,
      pace: pace ?? this.pace,
      practiceStyle: practiceStyle ?? this.practiceStyle,
      selfReport: selfReport ?? this.selfReport,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      completedMilestones: completedMilestones ?? this.completedMilestones,
      currentPath: currentPath ?? this.currentPath,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'currentLevel': currentLevel,
        'desiredLevel': desiredLevel.name,
        'goal': goal.name,
        'pace': pace.name,
        'practiceStyle': practiceStyle.name,
        'selfReport': selfReport.name,
        'dailyGoalMinutes': dailyGoalMinutes,
        'completedMilestones': completedMilestones,
        'currentPath': currentPath,
        'lastActivity': lastActivity?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  /// Defensive deserialization: unknown enum names fall back to defaults;
  /// out-of-range values are clamped. A corrupt store never crashes.
  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    final language = LearnLanguage.values.firstWhere(
      (l) => l.name == (json['language'] as String?),
      orElse: () => LearnLanguage.hindi,
    );
    final level = (json['currentLevel'] as num?)?.toInt();
    final minutes = (json['dailyGoalMinutes'] as num?)?.toInt() ??
        kDefaultDailyGoalMinutes;
    return LearnerProfile(
      language: language,
      currentLevel: level == null ? null : level.clamp(0, 4).toInt(),
      desiredLevel:
          DesiredLevel.tryParse(json['desiredLevel'] as String?) ??
              DesiredLevel.beginner,
      goal: LearningGoal.tryParse(json['goal'] as String?) ??
          LearningGoal.general,
      pace: LearningPace.tryParse(json['pace'] as String?) ??
          LearningPace.steady,
      practiceStyle:
          PracticeStyle.tryParse(json['practiceStyle'] as String?) ??
              PracticeStyle.mixed,
      selfReport: SelfReport.tryParse(json['selfReport'] as String?) ??
          SelfReport.almostNothing,
      dailyGoalMinutes: minutes.clamp(5, 120).toInt(),
      completedMilestones: (json['completedMilestones'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      currentPath: (json['currentPath'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        language,
        currentLevel,
        desiredLevel,
        goal,
        pace,
        practiceStyle,
        selfReport,
        dailyGoalMinutes,
        completedMilestones,
        currentPath,
        lastActivity,
        createdAt,
      ];
}
