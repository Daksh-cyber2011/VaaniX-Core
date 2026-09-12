/// Exam Mode 2.0 — Exam Learner Profile Repository (M4)
///
/// Offline-first persistence for the per-track learner exam profile
/// (§12 "This must be persistent. Do NOT store everything only in UI
/// state"), following the ExamScopeRepository/ExamProfileRepository
/// pattern: one versioned JSON document, per-track map, corrupt data
/// degrades to empty — never a crash (§41).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';

class ExamLearnerProfileRepository {
  ExamLearnerProfileRepository(this._storage);

  static const String storageKey = 'exam_learner_v1';

  final ILocalStorageService _storage;

  Future<Map<String, ExamLearnerProfile>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final profilesJson =
          (json['profiles'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final profiles = <String, ExamLearnerProfile>{};
      profilesJson.forEach((trackId, value) {
        try {
          profiles[trackId] = ExamLearnerProfile.fromJson(
              (value as Map<String, dynamic>).cast<String, dynamic>());
        } catch (_) {
          // Corrupt single entry — skip (§41).
        }
      });
      return profiles;
    } catch (e) {
      debugPrint('[ExamLearnerProfileRepository] corrupt store: $e');
      return {};
    }
  }

  Future<ExamLearnerProfile> load(String trackId) async =>
      (await loadAll())[trackId] ?? ExamLearnerProfile.empty(trackId);

  Future<void> save(ExamLearnerProfile profile) async {
    final all = await loadAll();
    all[profile.trackId] = profile;
    await _storage.setString(storageKey, jsonEncode({
      'version': 1,
      'profiles': {
        for (final e in all.entries) e.key: e.value.toJson(),
      },
    }));
  }

  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
