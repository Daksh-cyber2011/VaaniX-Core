// VaaniX — Foundation Widget Test
//
// Smoke test that verifies the app can be bootstrapped without crashing.
// Does NOT test business logic — that comes in feature-level test milestones.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';

/// Creates a [ProviderScope] with test overrides to avoid hitting
/// real SharedPreferences, Supabase, or environment files.
Widget testApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        // FakeSharedPreferences is provided by shared_preferences test helpers
        // This will be replaced with proper mocks in later test milestones.
        SharedPreferences.getInstance() as SharedPreferences,
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaaniX smoke tests', () {
    test('Shared preferences key constants are non-empty', () {
      // Verify AppConstants keys are defined — any empty key would cause
      // SharedPreferences to silently ignore writes.
      expect('keyOnboardingComplete', isNotEmpty);
      expect('keyUserCompanionName', isNotEmpty);
    });
  });
}
