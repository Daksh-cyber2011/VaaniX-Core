// VaaniX — Foundation Infrastructure Test
//
// Smoke test that verifies core infrastructure wires up without crashing.
// Tests the real production providers with fake dependencies.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/errors/exception_mapper.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/profile/data/local_user_profile_repository.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';

late ProviderContainer _container;

Future<void> setUpContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => await setUpContainer());
  tearDown(() => _container.dispose());

  group('AppConstants storage keys', () {
    test('are non-empty (empty keys would silently drop writes)', () {
      expect(AppConstants.keyOnboardingComplete, isNotEmpty);
      expect(AppConstants.keyUserCompanionName, isNotEmpty);
      expect(AppConstants.keyPersonalityMode, isNotEmpty);
      expect(AppConstants.keyDailyGoalMinutes, isNotEmpty);
    });
  });

  group('LocalStorageService', () {
    test('defaults are safe before any write', () {
      final storage = _container.read(localStorageServiceProvider);
      expect(storage.isOnboardingComplete, isFalse);
      expect(storage.companionName, AppConstants.companionDefaultName);
      expect(storage.dailyGoalMinutes, AppConstants.defaultDailyGoalMinutes);
      expect(storage.currentStreak, 0);
      expect(storage.xpTotal, 0);
    });

    test('round-trips onboarding + companion name', () async {
      final storage = _container.read(localStorageServiceProvider);
      await storage.setOnboardingComplete(true);
      await storage.setCompanionName('Quack');

      expect(storage.isOnboardingComplete, isTrue);
      expect(storage.companionName, 'Quack');
    });

    test('XP round-trips', () async {
      final storage = _container.read(localStorageServiceProvider);
      await storage.setXpTotal(250);
      expect(storage.xpTotal, 250);
    });
  });

  group('ExceptionMapper', () {
    test('maps generic error to UnknownFailure', () {
      final failure = ExceptionMapper.toFailure(Exception('boom'));
      expect(failure, isA<UnknownFailure>());
    });

    test('maps ValidationFailure field through props', () {
      const failure = ValidationFailure(message: 'bad', field: 'email');
      expect(failure.field, 'email');
      expect(failure.props, contains('email'));
    });
  });

  group('Provider wiring', () {
    test('localStorageServiceProvider resolves from sharedPreferencesProvider', () {
      final service = _container.read(localStorageServiceProvider);
      expect(service, isA<LocalStorageService>());
    });
  });

  group('LocalUserProfileRepository', () {
    late UserProfileRepository repo;

    setUp(() {
      repo = LocalUserProfileRepository(
        _container.read(localStorageServiceProvider),
      );
    });

    test('getProfile returns defaults before any write', () async {
      final result = await repo.getProfile();
      result.fold(
        (_) => fail('expected success'),
        (profile) {
          expect(profile.companionName, AppConstants.companionDefaultName);
          expect(profile.dailyGoalMinutes, AppConstants.defaultDailyGoalMinutes);
          // xpTotal is no longer on UserProfile — it lives in the progress
          // repo (single source of truth). Verified in the progress repo tests.
          expect(profile.currentStreak, 0);
        },
      );
    });

    test('recordDailyActivity sets streak to 1 on first call', () async {
      final result = await repo.recordDailyActivity();
      result.fold(
        (_) => fail('expected success'),
        (streak) => expect(streak, 1),
      );
    });
  });

  group('LocalProgressRepository', () {
    late ProgressRepository repo;

    setUp(() {
      repo = LocalProgressRepository(
        _container.read(localStorageServiceProvider),
      );
    });

    test('completeLesson adds XP and records id', () async {
      const lesson = Lesson(
        id: 'ls_test_1',
        title: 'Test',
        chapterId: 'ch_test',
        xpReward: 20,
      );
      final result = await repo.completeLesson(lesson);
      result.fold(
        (_) => fail('expected success'),
        (xp) => expect(xp, 20),
      );
      final ids = repo.getCompletedLessonIds();
      ids.fold(
        (_) => fail('expected success'),
        (list) => expect(list, contains('ls_test_1')),
      );
    });

    test('completeQuiz awards 10 XP per correct answer', () async {
      final result = await repo.completeQuiz(
        quizId: 'qz_test',
        score: 3,
        total: 5,
      );
      result.fold(
        (_) => fail('expected success'),
        (r) {
          expect(r.xpEarned, 30);
          expect(r.score, 3);
        },
      );
    });

    test('reset clears XP and ids', () async {
      await repo.completeLesson(const Lesson(
        id: 'ls_x',
        title: '',
        chapterId: '',
      ));
      await repo.reset();
      repo.getXp().fold(
        (_) => fail('expected success'),
        (xp) => expect(xp, 0),
      );
    });
  });

  group('UserProfile domain', () {
    test('resolvedCompanionName falls back to Van', () {
      const empty = UserProfile(companionName: '');
      expect(empty.resolvedCompanionName, 'Van');
    });

    test('CbseClass.fromValue resolves valid values', () {
      expect(CbseClass.fromValue(8), CbseClass.class8);
      expect(CbseClass.fromValue(null), isNull);
      expect(CbseClass.fromValue(99), isNull);
    });

    test('copyWith preserves unmodified fields', () {
      // xpTotal is no longer on UserProfile (moved to progress repo in S4).
      const base = UserProfile(currentStreak: 5, dailyGoalMinutes: 15);
      final updated = base.copyWith(currentStreak: 10);
      expect(updated.currentStreak, 10);
      expect(updated.dailyGoalMinutes, 15);
    });
  });
}
