/// VaaniX App-wide Constants
///
/// Central location for all app-wide string constants, route names,
/// asset paths, and configuration keys.
/// Do NOT put secrets here — use the .env file.

abstract final class AppConstants {
  // ============================================================
  // APP INFO
  // ============================================================

  static const String appName = 'VaaniX';
  static const String appVersion = '1.0.0';

  /// Internal code name for the AI companion — never change
  static const String companionCodeName = 'duck';

  /// Default public name shown to users
  static const String companionDefaultName = 'Van';

  // ============================================================
  // ENVIRONMENT
  // ============================================================

  static const String envFilePath = 'assets/env/.env';
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';
  static const String apiBaseUrlKey = 'API_BASE_URL';
  static const String appEnvKey = 'APP_ENV';
  static const String sentryDsnKey = 'SENTRY_DSN';

  // ============================================================
  // STORAGE KEYS (SharedPreferences)
  // ============================================================

  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyUserCompanionName = 'companion_name';
  static const String keyPersonalityMode = 'personality_mode';
  static const String keyDailyGoalMinutes = 'daily_goal_minutes';
  static const String keyCurrentStreak = 'current_streak';
  static const String keyLastActiveDate = 'last_active_date';
  static const String keySelectedClass = 'selected_class';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'app_language';
  static const String keyXpTotal = 'xp_total';
  static const String keyCompletedLessonIds = 'completed_lesson_ids';
  static const String keyCompletedQuizIds = 'completed_quiz_ids';

  // ============================================================
  // ONBOARDING
  // ============================================================

  /// Number of onboarding screens (from PRD Section 8.1)
  static const int onboardingScreenCount = 7;

  // ============================================================
  // DAILY GOAL OPTIONS (minutes, from PRD Section 8.1)
  // ============================================================

  static const List<int> dailyGoalOptions = [5, 10, 15, 20];
  static const int defaultDailyGoalMinutes = 10;

  // ============================================================
  // CBSE CLASS OPTIONS (from PRD Section 4)
  // ============================================================

  static const List<int> supportedClasses = [6, 7, 8, 9, 10];

  // ============================================================
  // VAN ANIMATION TIMING (milliseconds)
  // From PRD Section 6.4 — Animation System
  // ============================================================

  static const int vanIdleCycleDurationMs = 3500; // 3–4s breathing
  static const int vanTalkingDurationMs = 500;    // natural lip-sync
  static const int vanCelebrationDurationMs = 800;
  static const int vanThinkingDurationMs = 600;
  static const int vanErrorDurationMs = 300;
  static const int vanSuccessDurationMs = 800;

  /// Cooldown between idle state changes (ms)
  static const int vanIdleCooldownMs = 30000; // 30 seconds

  // ============================================================
  // API ENDPOINTS
  // ============================================================

  static const String healthEndpoint = '/health';
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';

  // ============================================================
  // NETWORK
  // ============================================================

  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 15000;
  static const int sendTimeoutMs = 10000;

  // ============================================================
  // ASSET PATHS
  // ============================================================

  static const String imagesPath = 'assets/images/';
  static const String animationsPath = 'assets/animations/';
  static const String iconsPath = 'assets/icons/';

  /// Van animation asset names (Lottie .json files)
  static const String vanIdleAnimation = 'assets/animations/van_idle.json';
  static const String vanHappyAnimation = 'assets/animations/van_happy.json';
  static const String vanThinkingAnimation = 'assets/animations/van_thinking.json';
  static const String vanCelebrationAnimation = 'assets/animations/van_celebration.json';
  static const String vanSadAnimation = 'assets/animations/van_sad.json';
  static const String vanFocusAnimation = 'assets/animations/van_focus.json';
}
