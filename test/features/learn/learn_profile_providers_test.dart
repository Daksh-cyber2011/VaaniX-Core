/// Learner Profile Providers — M2 wiring tests.
///
/// Proves the full production chain: persisted SharedPreferences seed →
/// repository → per-language profile notifier → active-profile provider.
/// Pins persist-first semantics, idempotent no-op saves, per-language
/// isolation, and the configured/prompt-flag behaviour.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unset profile falls back to safe defaults', () async {
    final container = await _container(prefs: {
      'learn_language': 'hindi',
    });
    addTearDown(container.dispose);

    final profile = container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.language, LearnLanguage.hindi);
    expect(profile.goal, LearningGoal.general);
    expect(profile.desiredLevel, DesiredLevel.beginner);
    expect(profile.currentLevel, isNull); // never fabricated
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isFalse,
    );
  });

  test('persisted profile loads back through the notifier', () async {
    // Seed exactly what the repository writes.
    final stored = LearnerProfile.initial(LearnLanguage.hindi).copyWith(
      goal: LearningGoal.reading,
      desiredLevel: DesiredLevel.advanced,
      dailyGoalMinutes: 30,
    );
    final container = await _container(prefs: {
      'learn_language': 'hindi',
      'learn_profile_hi': _encoded(stored),
    });
    addTearDown(container.dispose);

    final profile = container.read(learnerProfileProvider(LearnLanguage.hindi));
    expect(profile.goal, LearningGoal.reading);
    expect(profile.desiredLevel, DesiredLevel.advanced);
    expect(profile.dailyGoalMinutes, 30);
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isTrue,
    );
  });

  test('update persists FIRST then publishes (and flips the configured flag)',
      () async {
    final container = await _container(prefs: {
      'learn_language': 'hindi',
    });
    addTearDown(container.dispose);

    await container
        .read(learnerProfileProvider(LearnLanguage.hindi).notifier)
        .setGoal(LearningGoal.travel);

    // State reflects it...
    expect(
      container.read(learnerProfileProvider(LearnLanguage.hindi)).goal,
      LearningGoal.travel,
    );
    // ...storage holds it (a fresh repo over the same prefs sees it)...
    final reread = container
        .read(learnProfileRepositoryProvider)
        .getProfile(LearnLanguage.hindi);
    expect(reread!.goal, LearningGoal.travel);
    // ...and the Learn-screen prompt condition flips to "configured".
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isTrue,
    );
  });

  test('idempotent update is a no-op (no storage churn)', () async {
    final container = await _container(prefs: {
      'learn_language': 'hindi',
      'learn_profile_hi': _encoded(
        LearnerProfile.initial(LearnLanguage.hindi)
            .copyWith(goal: LearningGoal.travel),
      ),
    });
    addTearDown(container.dispose);

    final notifier =
        container.read(learnerProfileProvider(LearnLanguage.hindi).notifier);
    final before = container.read(learnerProfileProvider(LearnLanguage.hindi));

    await notifier.setGoal(LearningGoal.travel); // same value

    expect(container.read(learnerProfileProvider(LearnLanguage.hindi)),
        same(before));
  });

  test('profiles are isolated per language', () async {
    final container = await _container(prefs: {
      'learn_language': 'hindi',
    });
    addTearDown(container.dispose);

    await container
        .read(learnerProfileProvider(LearnLanguage.hindi).notifier)
        .setGoal(LearningGoal.mastery);

    // Hindi is configured; Urdu is not and keeps defaults.
    expect(
      container.read(learnerProfileProvider(LearnLanguage.hindi)).goal,
      LearningGoal.mastery,
    );
    expect(
      container.read(learnerProfileProvider(LearnLanguage.urdu)).goal,
      LearningGoal.general,
    );
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.urdu)),
      isFalse,
    );
  });

  test('active profile is null without a selection and follows the selection',
      () async {
    final container = await _container(prefs: {});
    addTearDown(container.dispose);

    expect(container.read(activeLearnerProfileProvider), isNull);

    await container
        .read(selectedLearnLanguageProvider.notifier)
        .select(LearnLanguage.tamil);

    final active = container.read(activeLearnerProfileProvider);
    expect(active, isNotNull);
    expect(active!.language, LearnLanguage.tamil);
  });

  test('resetToDefaults clears storage and the configured flag', () async {
    final container = await _container(prefs: {
      'learn_language': 'hindi',
      'learn_profile_hi': _encoded(
        LearnerProfile.initial(LearnLanguage.hindi)
            .copyWith(goal: LearningGoal.mastery),
      ),
    });
    addTearDown(container.dispose);

    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isTrue,
    );

    await container
        .read(learnerProfileProvider(LearnLanguage.hindi).notifier)
        .resetToDefaults();

    expect(
      container.read(learnerProfileProvider(LearnLanguage.hindi)).goal,
      LearningGoal.general,
    );
    expect(
      container.read(learnerProfileConfiguredProvider(LearnLanguage.hindi)),
      isFalse,
    );
  });
}

/// JSON-encodes a profile exactly the way the repository stores it.
String _encoded(LearnerProfile profile) => jsonEncode(profile.toJson());
