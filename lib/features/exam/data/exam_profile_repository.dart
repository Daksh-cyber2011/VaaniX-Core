/// Exam Mode 2.0 — Exam Profile Repository (M3)
///
/// Offline-first persistence for the student's exam profile, following
/// the ExamScopeRepository pattern: one versioned JSON document under a
/// dedicated key in [ILocalStorageService], one profile PER TRACK so
/// switching courses preserves earlier answers ("allow editing",
/// master plan §8/§12).
///
/// Stored shape:
/// ```json
/// {
///   "version": 1,
///   "profiles": {
///     "cbse_10_sanskrit": { "dailyStudyMinutes": 45, ... }
///   }
/// }
/// ```
///
/// Safety:
///  * corrupt JSON degrades to an empty store — never a crash;
///  * a single corrupt profile entry is skipped, not fatal;
///  * invalid profiles (failed [ExamProfile.validate]) are never saved
///    — the caller gets `false` back instead of persisted garbage.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';

class ExamProfileRepository {
  ExamProfileRepository(this._storage);

  static const String storageKey = 'exam_profile_v1';

  final ILocalStorageService _storage;

  /// Loads all persisted profiles; empty map when nothing/corrupt.
  Future<Map<String, ExamProfile>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final profilesJson = (json['profiles'] as Map<String, dynamic>?)
              ?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final profiles = <String, ExamProfile>{};
      profilesJson.forEach((trackId, value) {
        try {
          profiles[trackId] = ExamProfile.fromJson(
              (value as Map<String, dynamic>).cast<String, dynamic>());
        } catch (_) {
          // One corrupt entry must not take down the store (§41).
        }
      });
      return profiles;
    } catch (e) {
      debugPrint('[ExamProfileRepository] corrupt store, resetting: $e');
      return {};
    }
  }

  /// One track's profile, or null when never set.
  Future<ExamProfile?> load(String trackId) async => (await loadAll())[trackId];

  /// Persists [profile]. Refuses invalid profiles (returns false) so the
  /// store can only ever contain planning-grade data.
  Future<bool> save(ExamProfile profile) async {
    if (!profile.isValid) return false;
    final all = await loadAll();
    all[profile.trackId] = profile;
    await _saveAll(all);
    return true;
  }

  Future<void> _saveAll(Map<String, ExamProfile> profiles) async {
    final json = {
      'version': 1,
      'profiles': {
        for (final e in profiles.entries) e.key: e.value.toJson(),
      },
    };
    await _storage.setString(storageKey, jsonEncode(json));
  }

  /// Removes one track's profile (course isolation teardown).
  Future<void> remove(String trackId) async {
    final all = await loadAll();
    if (all.remove(trackId) == null) return;
    await _saveAll(all);
  }

  /// Test/teardown hook.
  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
