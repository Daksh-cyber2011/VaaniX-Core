/// Daily Activity Repository — Data Layer (Milestone 7)
///
/// Bounded per-day counters backing the daily-goal loop and the daily
/// review challenge:
///
///   - `daily_xp_<YYYY-MM-DD>`       → XP earned that day through REAL
///     learning events (lesson completion, exam scoring). Written by the
///     [recordDailyXp] hook, never by reads.
///   - `daily_review_claimed_<key>`  → '1' once the day's review challenge
///     bonus has been paid.
///
/// Storage is bounded: writes prune day-keys older than [retentionDays],
/// so the store cannot grow without bound across a long install (same
/// policy as the AI transcript caps).
library;

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/progress/domain/daily_goal.dart';

class DailyActivityRepository {
  DailyActivityRepository(this._storage);

  final ILocalStorageService _storage;

  /// Key prefixes (also used for pruning).
  static const String _xpPrefix = 'daily_xp_';
  static const String _claimedPrefix = 'daily_review_claimed_';

  /// How many past days of counters to retain.
  static const int retentionDays = 7;

  // ─── Daily XP ──────────────────────────────────────────────────────────

  /// XP already earned on [dateKey] (0 when none / corrupt).
  int xpOn(String dateKey) {
    final raw = _storage.getString('$_xpPrefix$dateKey');
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  /// Adds [amount] XP (amount > 0) to [dateKey]'s counter and prunes old
  /// day keys. Returns the new day total.
  Future<Result<int>> addXp(String dateKey, int amount) {
    return guardAsync(() async {
      if (amount <= 0) return xpOn(dateKey);
      final next = xpOn(dateKey) + amount;
      await _storage.setString('$_xpPrefix$dateKey', '$next');
      await _pruneOldDays();
      return next;
    });
  }

  // ─── Review-challenge claim ────────────────────────────────────────────

  /// True when the day's review bonus was already claimed.
  bool isReviewClaimed(String dateKey) =>
      _storage.getString('$_claimedPrefix$dateKey') == '1';

  /// Marks the day's review bonus as claimed. Returns true when THIS call
  /// performed the claim (false when it was already claimed) — the caller
  /// awards XP only on true, and the bonus ledger is idempotent anyway.
  Future<Result<bool>> claimReview(String dateKey) {
    return guardAsync(() async {
      if (isReviewClaimed(dateKey)) return false;
      await _storage.setString('$_claimedPrefix$dateKey', '1');
      await _pruneOldDays();
      return true;
    });
  }

  /// Clears every daily-XP counter and review-claim marker (used by
  /// Settings → reset, so a full restart also restarts the daily-goal and
  /// review-challenge loops from zero).
  Future<Result<void>> clear() {
    return guardAsync(() async {
      final doomed = <String>[];
      for (final key in _storage.keys) {
        if (key.startsWith(_xpPrefix) || key.startsWith(_claimedPrefix)) {
          doomed.add(key);
        }
      }
      for (final key in doomed) {
        await _storage.remove(key);
      }
    });
  }

  // ─── Pruning ───────────────────────────────────────────────────────────

  /// Removes day-keyed entries older than [retentionDays] days. Pure
  /// string-prefix scan over storage keys; tolerant of any key format.
  Future<void> _pruneOldDays() async {
    final cutoff = DateTime.now().subtract(const Duration(days: retentionDays));
    final cutoffKey = dailyGoalDateKey(cutoff);
    final doomed = <String>[];
    for (final key in _storage.keys) {
      if (key.startsWith(_xpPrefix)) {
        final day = key.substring(_xpPrefix.length);
        if (_isBefore(day, cutoffKey)) doomed.add(key);
      } else if (key.startsWith(_claimedPrefix)) {
        final day = key.substring(_claimedPrefix.length);
        if (_isBefore(day, cutoffKey)) doomed.add(key);
      }
    }
    for (final key in doomed) {
      await _storage.remove(key);
    }
  }

  /// Lexicographic day comparison — 'YYYY-MM-DD' sorts chronologically.
  bool _isBefore(String a, String b) => a.compareTo(b) < 0;
}
