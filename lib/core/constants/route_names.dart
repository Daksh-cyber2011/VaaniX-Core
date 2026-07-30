/// VaaniX Route Name Constants
///
/// All route paths and names are centralized here.
/// Use [name] constants for programmatic navigation to avoid typos.

abstract final class RouteNames {
  // Paths
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String learn = '/learn';
  static const String exam = '/exam';
  static const String progress = '/progress';
  static const String vanProfile = '/van';
  static const String settings = '/settings';

  // Named route identifiers (for GoRouter.of(context).goNamed())
  static const String splashName = 'splash';
  static const String onboardingName = 'onboarding';
  static const String authName = 'auth';
  static const String homeName = 'home';
  static const String learnName = 'learn';
  static const String examName = 'exam';
  static const String progressName = 'progress';
  static const String vanProfileName = 'van-profile';
  static const String settingsName = 'settings';
}
