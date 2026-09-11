/// Daily Goal — pure domain tests (Milestone 7)
///
/// The date-key helpers and the honest minutes→XP mapping behind the
/// daily-goal loop, verified without Flutter, Riverpod or storage.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/progress/domain/daily_goal.dart';

void main() {
  group('dailyGoalDateKey', () {
    test('formats a local-midnight YYYY-MM-DD key', () {
      expect(dailyGoalDateKey(DateTime(2026, 9, 11)), '2026-09-11');
      expect(dailyGoalDateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dailyGoalDateKey(DateTime(1999, 12, 31)), '1999-12-31');
    });

    test('keys sort chronologically as strings', () {
      final keys = [
        dailyGoalDateKey(DateTime(2026, 9, 11)),
        dailyGoalDateKey(DateTime(2026, 9, 2)),
        dailyGoalDateKey(DateTime(2026, 10, 1)),
        dailyGoalDateKey(DateTime(2025, 1, 1)),
      ]..sort();
      expect(keys, [
        '2025-01-01',
        '2026-09-02',
        '2026-09-11',
        '2026-10-01',
      ]);
    });
  });

  group('dailyGoalXpTarget', () {
    test('maps the onboarding minutes to XP at 2 XP per minute', () {
      expect(dailyGoalXpTarget(5), 10);
      expect(dailyGoalXpTarget(10), 20);
      expect(dailyGoalXpTarget(15), 30);
      expect(dailyGoalXpTarget(20), 40);
    });

    test('degenerate goals never produce a negative target', () {
      expect(dailyGoalXpTarget(0), 0);
      expect(dailyGoalXpTarget(-5), 0);
    });
  });

  group('DailyGoalState', () {
    test('tracks remaining XP and met state below the target', () {
      const state = DailyGoalState(
        dateKey: '2026-09-11',
        xpEarnedToday: 8,
        goalMinutes: 10,
      );
      expect(state.xpTarget, 20);
      expect(state.isMet, isFalse);
      expect(state.xpRemaining, 12);
      expect(state.fraction, closeTo(0.4, 1e-9));
    });

    test('the goal is met at exactly the target (no off-by-one)', () {
      const state = DailyGoalState(
        dateKey: '2026-09-11',
        xpEarnedToday: 20,
        goalMinutes: 10,
      );
      expect(state.isMet, isTrue);
      expect(state.xpRemaining, 0);
      expect(state.fraction, 1.0);
    });

    test('overshooting clamps the fraction at 1.0', () {
      const state = DailyGoalState(
        dateKey: '2026-09-11',
        xpEarnedToday: 55,
        goalMinutes: 10,
      );
      expect(state.isMet, isTrue);
      expect(state.xpRemaining, 0);
      expect(state.fraction, 1.0);
    });

    test('a zero-minute goal is always met (nothing promised)', () {
      const state = DailyGoalState(
        dateKey: '2026-09-11',
        xpEarnedToday: 0,
        goalMinutes: 0,
      );
      expect(state.xpTarget, 0);
      expect(state.isMet, isTrue);
      expect(state.fraction, 1.0);
      expect(state.xpRemaining, 0);
    });
  });
}
