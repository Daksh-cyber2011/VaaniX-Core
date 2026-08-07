/// VaaniX Achievements — Local Repository
///
/// Persists unlocked achievement IDs + unlock timestamps in SharedPreferences.
/// Uses the generic getString/setString from ILocalStorageService.
///
/// Storage format: JSON map { achievementId: { "unlockedAt": ISO-8601 } }
/// under key 'ai_achievements_unlocked'.

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/achievements/domain/achievement.dart';

class AchievementRepository {
  AchievementRepository(this._storage);

  final ILocalStorageService _storage;

  static const String _key = 'achievements_unlocked';

  /// Returns a map of achievementId → unlock timestamp for all unlocked
  /// achievements.
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

  /// Mark [achievementId] as unlocked at [now]. Returns the updated map.
  Future<Result<Map<String, DateTime>>> unlock(
    String achievementId, {
    DateTime? now,
  }) {
    return guardAsync(() async {
      final current = await getUnlocked().then(
        (r) => r.fold((_) => <String, DateTime>{}, (v) => v),
      );
      if (current.containsKey(achievementId)) return current;

      final updated = {...current, achievementId: now ?? DateTime.now()};
      final json = updated.map((k, v) => MapEntry(k, {'unlockedAt': v.toIso8601String()}));
      await _storage.setString(_key, jsonEncode(json));
      return updated;
    });
  }

  /// Clear all unlocked achievements (used by Settings → reset).
  Future<Result<void>> clear() {
    return guardAsync(() async {
      await _storage.setString(_key, '{}');
    });
  }
}
