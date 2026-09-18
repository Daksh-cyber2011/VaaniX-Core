/// Token Usage Retention Tests (Phase 4 regression — audit defect #12)
///
/// TokenUsageTracker persisted one JSON entry per calendar day forever,
/// with no pruning — a long-lived install would grow `ai_token_usage`
/// without bound. It's now capped to
/// [AppConstants.maxTokenUsageHistoryDays] entries, oldest dropped first,
/// pruned on every write (and self-healing if a larger map is ever
/// loaded from an older install).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const usageKey = 'ai_token_usage';

  Future<(ProviderContainer, TokenUsageTracker)> makeTracker({
    Map<String, Object> initialStorage = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialStorage);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final tracker =
        TokenUsageTracker(container.read(localStorageServiceProvider));
    return (container, tracker);
  }

  Map<String, dynamic> seedDays(int count) {
    final map = <String, dynamic>{};
    final base = DateTime(2020, 1, 1);
    for (var i = 0; i < count; i++) {
      final d = base.add(Duration(days: i));
      final key = '${d.year.toString().padLeft(4, '0')}'
          '-${d.month.toString().padLeft(2, '0')}'
          '-${d.day.toString().padLeft(2, '0')}';
      map[key] = {
        'requestCount': 1,
        'promptTokens': 10,
        'completionTokens': 10,
        'totalTokens': 20,
      };
    }
    return map;
  }

  test('recordUsage prunes a pre-existing oversized map down to the window',
      () async {
    final seeded = seedDays(AppConstants.maxTokenUsageHistoryDays + 15);
    final (container, tracker) = await makeTracker(
      initialStorage: {usageKey: jsonEncode(seeded)},
    );
    addTearDown(container.dispose);

    await tracker.recordUsage(promptTokens: 5, completionTokens: 5);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(usageKey);
    final stored = jsonDecode(raw!) as Map<String, dynamic>;

    expect(
      stored.length,
      lessThanOrEqualTo(AppConstants.maxTokenUsageHistoryDays + 1),
      reason: 'today (newly added) plus the retained window, never the '
          'full pre-existing 15-over-cap map',
    );
  });

  test(
      'recordUsage never lets the map exceed the retention window '
      'across many days of use', () async {
    final (container, tracker) = await makeTracker();
    addTearDown(container.dispose);

    // Simulate far more days of usage than the retention window by
    // seeding storage directly between "days" (recordUsage always keys
    // off DateTime.now(), so we seed history and only exercise today's
    // write path, which is what actually runs the prune).
    final seeded = seedDays(AppConstants.maxTokenUsageHistoryDays * 3);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(usageKey, jsonEncode(seeded));

    await tracker.recordUsage(promptTokens: 1, completionTokens: 1);

    final raw = prefs.getString(usageKey);
    final stored = jsonDecode(raw!) as Map<String, dynamic>;
    expect(stored.length,
        lessThanOrEqualTo(AppConstants.maxTokenUsageHistoryDays + 1));
  });

  test('pruning drops the OLDEST day keys, not the newest', () async {
    final seeded = seedDays(AppConstants.maxTokenUsageHistoryDays + 5);
    final oldestKeys = (seeded.keys.toList()..sort()).take(5).toList();

    final (container, tracker) = await makeTracker(
      initialStorage: {usageKey: jsonEncode(seeded)},
    );
    addTearDown(container.dispose);

    await tracker.recordUsage(promptTokens: 1, completionTokens: 1);

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(usageKey)!) as Map<String, dynamic>;

    for (final key in oldestKeys) {
      expect(stored.containsKey(key), isFalse,
          reason: '$key is one of the oldest entries and must be pruned');
    }
  });

  test('clear() still empties the map entirely', () async {
    final seeded = seedDays(10);
    final (container, tracker) = await makeTracker(
      initialStorage: {usageKey: jsonEncode(seeded)},
    );
    addTearDown(container.dispose);

    await tracker.clear();

    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(usageKey)!) as Map<String, dynamic>;
    expect(stored, isEmpty);
  });
}
