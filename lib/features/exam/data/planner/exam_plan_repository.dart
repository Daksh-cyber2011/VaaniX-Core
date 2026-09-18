/// Exam Mode 2.0 — Exam Plan Repository (M5, §17 fallback chain)
///
/// Persistence for accepted plans (one per track). The cached plan is
/// the FIRST fallback when Gemini is unavailable (§17 hierarchy:
/// cached plan → deterministic planner). Staleness is structural: a
/// plan whose [scopeRevision] no longer matches the current scope
/// revision (§33 replanning trigger) or that is older than
/// [maxAgeDays] is reported stale and not served.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';

class ExamPlanRepository {
  ExamPlanRepository(this._storage);

  static const String storageKey = 'exam_plan_v1';
  static const String overrideStorageKey = 'exam_plan_overrides_v1';

  /// Plans are rolling 7-day windows — anything older has served its
  /// purpose and rebuilds fresh.
  static const Duration maxAge = Duration(days: 7);

  final ILocalStorageService _storage;

  Future<Map<String, ExamPlan>> loadAll() async {
    final raw = _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final plansJson =
          (json['plans'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final plans = <String, ExamPlan>{};
      plansJson.forEach((trackId, value) {
        try {
          plans[trackId] = ExamPlan.fromJson(
              (value as Map<String, dynamic>).cast<String, dynamic>());
        } catch (_) {
          // Corrupt entry — skip (§41).
        }
      });
      return plans;
    } catch (e) {
      debugPrint('[ExamPlanRepository] corrupt store: $e');
      return {};
    }
  }

  Future<ExamPlan?> load(String trackId) async => (await loadAll())[trackId];

  /// Topics a student explicitly chose over the recommended task. This is a
  /// bounded preference signal, not a replacement syllabus: callers still
  /// validate every id against the active scope before planning.
  Future<List<String>> loadStudentOverrideTopicIds(String trackId) async {
    final raw = _storage.getString(overrideStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final values = json[trackId] as List<dynamic>? ?? const [];
      return values
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .take(12)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Records one voluntary topic choice and keeps only recent distinct ids.
  /// The record is device-local and is used solely to improve the next plan.
  Future<void> recordStudentOverride({
    required String trackId,
    required String topicId,
  }) async {
    final raw = _storage.getString(overrideStorageKey);
    final all = <String, List<String>>{};
    try {
      final json = raw == null || raw.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      json.forEach((id, values) {
        if (values is List<dynamic>) {
          all[id] =
              values.whereType<String>().where((v) => v.isNotEmpty).toList();
        }
      });
    } catch (_) {
      // A corrupt preference store must not erase plans or block choice.
    }
    final next = <String>[
      topicId,
      ...?all[trackId]?.where((id) => id != topicId)
    ].take(12).toList(growable: false);
    all[trackId] = next;
    await _storage.setString(overrideStorageKey, jsonEncode(all));
  }

  Future<void> save(ExamPlan plan, {bool markCached = false}) async {
    final all = await loadAll();
    final stored = markCached
        ? ExamPlan.fromJson({...plan.toJson(), 'source': 'cached'})
        : plan;
    all[plan.trackId] = stored;
    await _storage.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'plans': {
            for (final e in all.entries) e.key: e.value.toJson(),
          },
        }));
  }

  /// The cached-plan fallback hop: serves the last accepted plan ONLY
  /// when it is fresh AND matches the current scope revision (§33);
  /// returns null (chain continues) otherwise.
  Future<ExamPlan?> loadUsableCached(String trackId, int scopeRevision) async {
    final plan = await load(trackId);
    if (plan == null || plan.days.isEmpty) return null;
    if (plan.scopeRevision != scopeRevision) return null;
    final created = DateTime.tryParse(plan.createdAtIso);
    if (created == null) return null;
    if (DateTime.now().difference(created) > maxAge) return null;
    return plan;
  }

  /// Production teardown: drops the stored study plans and their day overrides for every track.
  ///
  /// Settings -> "Reset all progress" promises that exam history is cleared,
  /// so a production entry point is required; [reset] is `@visibleForTesting`
  /// and must never be called from production code. [reset] delegates here so
  /// both paths share one implementation.
  Future<void> clear() async {
    await _storage.remove(storageKey);
    await _storage.remove(overrideStorageKey);
  }

  @visibleForTesting
  Future<void> reset() => clear();
}
