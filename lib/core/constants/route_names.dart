/// VaaniX Route Name Constants
///
/// All route paths and names are centralized here.
/// Use [name] constants for programmatic navigation to avoid typos.
library;

abstract final class RouteNames {
  // Paths
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String learn = '/learn';
  static const String learnLanguageSelection = '/learn/language';
  static const String learnProfile = '/learn/profile';
  static const String learnDiagnostic = '/learn/diagnostic';
  static const String learnSmartPractice = '/learn/smart';
  static const String learnSession = '/learn/session';
  static const String lessonContent = '/learn/lesson/:lessonId';
  static const String lessonPractice = '/learn/lesson/:lessonId/practice';
  static const String exam = '/exam';
  static const String examSetup = '/exam/setup';
  static const String examScope = '/exam/setup/scope/:trackId';
  static const String examScopeSummary = '/exam/setup/summary/:trackId';
  static const String examProfile = '/exam/profile/:trackId';
  static const String examDiagnostic = '/exam/diagnostic/:trackId';
  static const String examPlan = '/exam/plan/:trackId';
  static const String examHub = '/exam/hub/:trackId';
  static const String examStudy = '/exam/study/:trackId/:topicId';
  static const String examPractice = '/exam/practice/:trackId';
  static const String examWeakArea = '/exam/weakarea/:trackId';
  static const String examPyq = '/exam/pyq/:trackId';
  static const String examMock = '/exam/mock/:trackId';
  static const String progress = '/progress';
  static const String vanProfile = '/van';
  static const String chat = '/chat';
  static const String achievements = '/achievements';
  static const String settings = '/settings';
  static const String learnHome = '/learn/home';
  static const String examCockpit = '/exam/cockpit';
  static const String interactiveDrill = '/practice/drill';
  static const String chapterStudy = '/syllabus/chapter';
  static const String profileTray = '/profile/tray';

  // Named route identifiers (for GoRouter.of(context).goNamed())
  static const String splashName = 'splash';
  static const String onboardingName = 'onboarding';
  static const String authName = 'auth';
  static const String homeName = 'home';
  static const String learnName = 'learn';
  static const String learnLanguageSelectionName = 'learn-language';
  static const String learnProfileName = 'learn-profile';
  static const String learnDiagnosticName = 'learn-diagnostic';
  static const String learnSmartPracticeName = 'learn-smart-practice';
  static const String learnSessionName = 'learn-session';
  static const String lessonContentName = 'lesson-content';
  static const String lessonPracticeName = 'lesson-exercise';
  static const String examName = 'exam';
  static const String examSetupName = 'exam-setup';
  static const String examScopeName = 'exam-scope';
  static const String examScopeSummaryName = 'exam-scope-summary';
  static const String examProfileName = 'exam-profile';
  static const String examDiagnosticName = 'exam-diagnostic';
  static const String examPlanName = 'exam-plan';
  static const String examHubName = 'exam-hub';
  static const String examStudyName = 'exam-study';
  static const String examPracticeName = 'exam-practice';
  static const String examWeakAreaName = 'exam-weak-area';
  static const String examPyqName = 'exam-pyq';
  static const String examMockName = 'exam-mock';
  static const String progressName = 'progress';
  static const String vanProfileName = 'van-profile';
  static const String chatName = 'chat';
  static const String achievementsName = 'achievements';
  static const String settingsName = 'settings';
  static const String learnHomeName = 'learn-home';
  static const String examCockpitName = 'exam-cockpit';
  static const String interactiveDrillName = 'interactive-drill';
  static const String chapterStudyName = 'chapter-study';
  static const String profileTrayName = 'profile-tray';
}
