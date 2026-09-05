// Onboarding Page-Index Persistence Tests — Phase 5
//
// A mid-onboarding app restart used to drop the learner back to page 0
// (audit row A: "Page index not persisted"). The notifier now hydrates
// the last page from storage, persists every move, clamps stale values
// against the page count, and clears the index when the flow completes.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/onboarding/data/onboarding_repository.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';

/// Flushes the fire-and-forget (unawaited) persistence writes so
/// assertions can observe them.
Future<void> flushAsyncWrites() => pumpEventQueue();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late OnboardingRepository repo;

  OnboardingNotifier buildNotifier() =>
      OnboardingNotifier(repo, const NoopAnalyticsClient());

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    repo = OnboardingRepository(storage);
  });

  group('fresh start', () {
    test('starts at page 0 when nothing was persisted', () {
      expect(buildNotifier().state.currentPage, 0);
      expect(storage.onboardingPage, isNull);
    });
  });

  group('persistence on page moves', () {
    test('nextPage writes the new index to storage', () async {
      final notifier = buildNotifier()..nextPage();
      await flushAsyncWrites();

      expect(notifier.state.currentPage, 1);
      expect(storage.onboardingPage, 1);
    });

    test('previousPage writes the new index to storage', () async {
      final notifier = buildNotifier()
        ..goToPage(3)
        ..previousPage();
      await flushAsyncWrites();

      expect(notifier.state.currentPage, 2);
      expect(storage.onboardingPage, 2);
    });

    test('goToPage clamps and persists the clamped value', () async {
      final notifier = buildNotifier()..goToPage(99);
      await flushAsyncWrites();

      expect(notifier.state.currentPage, AppConstants.onboardingScreenCount - 1);
      expect(storage.onboardingPage, AppConstants.onboardingScreenCount - 1);
    });

    test('nextPage cannot advance past the last page', () async {
      final notifier = buildNotifier()
        ..goToPage(AppConstants.onboardingScreenCount - 1)
        ..nextPage();
      await flushAsyncWrites();

      expect(notifier.state.currentPage, AppConstants.onboardingScreenCount - 1);
      expect(storage.onboardingPage, AppConstants.onboardingScreenCount - 1);
    });

    test('a no-op move does not rewrite storage', () async {
      final notifier = buildNotifier()..goToPage(0);
      await flushAsyncWrites();

      expect(notifier.state.currentPage, 0);
      expect(storage.onboardingPage, isNull,
          reason: 'page 0 == current page — nothing should be written');
    });
  });

  group('restart hydration', () {
    test('a mid-flow restart resumes on the persisted page', () async {
      final first = buildNotifier()
        ..nextPage() // page 1: personality
        ..nextPage() // page 2: subject
        ..nextPage(); // page 3: daily goal
      await flushAsyncWrites();
      expect(first.state.currentPage, 3);

      // Simulate an app restart: brand-new notifier over the same storage.
      final restarted = buildNotifier();
      expect(restarted.state.currentPage, 3);
    });

    test('a stored out-of-range index is clamped, not trusted', () async {
      await storage.setOnboardingPage(42);
      expect(buildNotifier().state.currentPage,
          AppConstants.onboardingScreenCount - 1);

      await storage.setOnboardingPage(-7);
      expect(buildNotifier().state.currentPage, 0);
    });

    test('a completed onboarding ignores the stored index', () async {
      await storage.setOnboardingPage(4);
      await storage.setOnboardingComplete(true);

      expect(buildNotifier().state.currentPage, 0,
          reason: 'the router bounces completed users away anyway — the '
              'notifier must not resurrect a stale page');
    });
  });

  group('completion', () {
    test('completing onboarding clears the stored index', () async {
      final notifier = buildNotifier()..nextPage();
      await flushAsyncWrites();
      expect(storage.onboardingPage, 1);

      await notifier.completeOnboarding();
      expect(notifier.state.isComplete, isTrue);
      expect(storage.onboardingPage, isNull,
          reason: 'no stale resume index may survive a completed flow');
      expect(storage.isOnboardingComplete, isTrue);
    });
  });

  group('page-count constant', () {
    test('AppConstants.onboardingScreenCount matches the real flow (6)',
        () {
      // Audit defect #17: the constant claimed 7 (the PRD's screen count
      // including the splash) while the actual PageView hosts 6 pages.
      expect(AppConstants.onboardingScreenCount, 6);
    });

    test('page moves keep working across all 6 pages', () {
      final notifier = buildNotifier();
      for (var i = 0; i < AppConstants.onboardingScreenCount - 1; i++) {
        notifier.nextPage();
      }
      expect(notifier.state.currentPage,
          AppConstants.onboardingScreenCount - 1);
      expect(notifier.state.isComplete, isFalse);
    });
  });
}
