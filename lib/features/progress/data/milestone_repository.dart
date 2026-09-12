/// Learning Milestones — Local Repository (Milestone 7)
///
/// Persists unlocked learning-milestone IDs + unlock timestamps in
/// SharedPreferences via the generic getString/setString seam (same
/// pattern as [AchievementRepository]).
///
/// Storage format: JSON map { milestoneId: { "unlockedAt": ISO-8601 } }
/// under key 'learning_milestones_unlocked'.
library;

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';

class MilestoneRepository {
  MilestoneRepository(this._storage);

  final ILocalStorageService _storage;

  static const String _key = 'learning_milestones_unlocked';

  /// Map of milestoneId → unlock timestamp for all unlocked milestones.
  /// Corrupt JSON is treated as an empty map rather than crashing.
  Future<Result<Map<String, DateTime>>> getUnlocked() {
    return guardAsync(() async {
      final raw = _storage.getString(_key);
      if (raw == null || raw.isEmpty) return <String, DateTime>{};
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return json.map((k, v) {
          final map = v as Map<String, dynamic>;
          final ts = DateTime.tryParse(map['unlockedAt'] as String? ?? '');
          return MapEntry(k, ts ?? DateTime.now());
        });
      } catch (_) {
        return <String, DateTime>{};
      }
    });
  }

  /// Mark [milestoneId] as unlocked at [now]. Idempotent: re-unlocking a
  /// known milestone returns the existing map unchanged. Returns the
  /// updated map.
  Future<Result<Map<String, DateTime>>> unlock(
    String milestoneId, {
    DateTime? now,
  }) {
    return guardAsync(() async {
      final current = await getUnlocked().then(
        (r) => r.fold((_) => <String, DateTime>{}, (v) => v),
      );
      if (current.containsKey(milestoneId)) return current;

      final updated = {...current, milestoneId: now ?? DateTime.now()};
      final json = updated
          .map((k, v) => MapEntry(k, {'unlockedAt': v.toIso8601String()}));
      await _storage.setString(_key, jsonEncode(json));
      return updated;
    });
  }

  /// Clear all unlocked milestones (used by Settings → reset, so a full
  /// reset lets milestones re-earn with their bonus XP).
  Future<Result<void>> clear() {
    return guardAsync(() async {
      await _storage.setString(_key, '{}');
    });
  }
}
