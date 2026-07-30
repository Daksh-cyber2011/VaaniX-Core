/// Onboarding State — Domain Layer
///
/// Holds all data collected across the 7 onboarding screens.
/// Stored locally via SharedPreferences through [OnboardingRepository].
///
/// PRD Section 8.1

/// Which personality mode the user selected for Van.
/// Maps to the three communication modes from PRD Section 6.5.
enum PersonalityMode {
  cheerleader, // Energetic, celebratory — most encouraging
  calm,        // Patient, soft, steady — good for anxious learners
  fun,         // Playful, humor-forward — duck puns, casual
}

/// The user's CBSE class (6–10) as defined in PRD Section 4.
enum CbseClass {
  class6,
  class7,
  class8,
  class9,
  class10;

  /// Display label shown in UI
  String get label => 'Class ${index + 6}';

  /// Numeric value
  int get value => index + 6;

  static CbseClass fromValue(int v) =>
      CbseClass.values.firstWhere((c) => c.value == v,
          orElse: () => CbseClass.class9);
}

/// Immutable snapshot of state across all onboarding screens.
/// Updated step-by-step as user progresses.
class OnboardingState {
  const OnboardingState({
    this.currentPage = 0,
    this.companionName = '',
    this.personalityMode,
    this.selectedClass,
    this.dailyGoalMinutes = 10,
    this.isComplete = false,
  });

  /// Which page (0-indexed) is currently visible
  final int currentPage;

  /// Name the user gave to Van (default = 'Van')
  final String companionName;

  /// Personality mode selected in Page 2
  final PersonalityMode? personalityMode;

  /// CBSE class selected in Page 3
  final CbseClass? selectedClass;

  /// Daily learning goal in minutes (5/10/15/20)
  final int dailyGoalMinutes;

  /// True after the Nest Reveal page is completed
  final bool isComplete;

  /// Resolved companion name — falls back to 'Van' if blank
  String get resolvedName =>
      companionName.trim().isEmpty ? 'Van' : companionName.trim();

  OnboardingState copyWith({
    int? currentPage,
    String? companionName,
    PersonalityMode? personalityMode,
    CbseClass? selectedClass,
    int? dailyGoalMinutes,
    bool? isComplete,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      companionName: companionName ?? this.companionName,
      personalityMode: personalityMode ?? this.personalityMode,
      selectedClass: selectedClass ?? this.selectedClass,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          runtimeType == other.runtimeType &&
          currentPage == other.currentPage &&
          companionName == other.companionName &&
          personalityMode == other.personalityMode &&
          selectedClass == other.selectedClass &&
          dailyGoalMinutes == other.dailyGoalMinutes &&
          isComplete == other.isComplete;

  @override
  int get hashCode => Object.hash(
        currentPage,
        companionName,
        personalityMode,
        selectedClass,
        dailyGoalMinutes,
        isComplete,
      );
}
