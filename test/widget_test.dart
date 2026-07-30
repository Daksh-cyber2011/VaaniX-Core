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
    });

    test('round-trips onboarding + companion name', () async {
      final storage = _container.read(localStorageServiceProvider);
      await storage.setOnboardingComplete(true);
      await storage.setCompanionName('Quack');

      expect(storage.isOnboardingComplete, isTrue);
      expect(storage.companionName, 'Quack');
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
}
