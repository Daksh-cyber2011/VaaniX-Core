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

  /// Plans are rolling 7-day windows — anything older has served its
  /// purpose and rebuilds fresh.
  static const Duration maxAge = Duration(days: 7);

  final ILocalStorageService _storage;

  Future<Map<String, ExamPlan>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final plansJson =
          (json['plans'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final plans = <String, ExamPlan>{};
      plansJson.forEach((trackId, value) {
        try {
          plans[trackId] =
              ExamPlan.fromJson((value as Map<String, dynamic>).cast<String, dynamic>());
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

  Future<ExamPlan?> load(String trackId) async =>
      (await loadAll())[trackId];

  Future<void> save(ExamPlan plan, {bool markCached = false}) async {
    final all = await loadAll();
    final stored = markCached
        ? ExamPlan.fromJson({...plan.toJson(), 'source': 'cached'})
        : plan;
    all[plan.trackId] = stored;
    await _storage.setString(storageKey, jsonEncode({
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

  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
