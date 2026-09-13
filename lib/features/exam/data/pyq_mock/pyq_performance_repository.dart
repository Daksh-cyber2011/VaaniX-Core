/// Exam Mode 2.0 — PYQ Performance + Mock Results Repositories (M9)
///
/// §12: performance evidence never lives only in UI state.
/// §21: pyqPerformance + mockPerformance are tracked student data.
/// §41: mock results are CRITICAL state — this repository writes
/// only what the deterministic engine produced (AI never scores).
/// §56: bounded history. §57: schema version. §41: corrupt data
/// degrades, never crashes.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

/// Per-track PYQ performance (§21 pyqPerformance).
class PyqPerformanceRepository {
  PyqPerformanceRepository(this._storage);

  static const String storageKey = 'exam_pyq_performance_v1';

  /// §56 bound — per track, one merged record per topic.
  static const int maxTopics = 60;

  final ILocalStorageService _storage;

  Future<Map<String, Map<String, PyqTopicPerformance>>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final perTrack =
          (json['tracks'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final out = <String, Map<String, PyqTopicPerformance>>{};
      perTrack.forEach((trackId, value) {
        try {
          final topics = <String, PyqTopicPerformance>{};
          for (final e in (value as Map<String, dynamic>)
              .cast<String, dynamic>()
              .entries) {
            try {
              topics[e.key] = PyqTopicPerformance.fromJson(
                  (e.value as Map<String, dynamic>).cast<String, dynamic>());
            } catch (_) {
              // Corrupt single topic — skip (§41).
            }
          }
          out[trackId] = topics;
        } catch (_) {
          // Corrupt track entry — skip (§41).
        }
      });
      return out;
    } catch (e) {
      debugPrint('[PyqPerformanceRepository] corrupt store: $e');
      return {};
    }
  }

  Future<Map<String, PyqTopicPerformance>> load(String trackId) async =>
      (await loadAll())[trackId] ?? const {};

  /// Merges a finished session's per-topic outcomes into the store
  /// (batched — one write per finished session, §18).
  Future<void> mergeSession({
    required String trackId,
    required List<PyqTopicPerformance> outcomes,
  }) async {
    if (outcomes.isEmpty) return;
    final all = await loadAll();
    final topics = {...(all[trackId] ?? const {})};
    for (final o in outcomes) {
      if (o.topicId.isEmpty) continue;
      final current = topics[o.topicId];
      topics[o.topicId] = current == null ? o : current.merge(o);
    }
    // §56 bound: keep the topics with the most evidence.
    // Keep equal-evidence topics in their established insertion order.
    // `List.sort` is not stable, so add the position as an explicit
    // deterministic tie-breaker.
    final indexed = topics.values.indexed.toList()
      ..sort((a, b) {
        final evidence = b.$2.attempted.compareTo(a.$2.attempted);
        return evidence != 0 ? evidence : a.$1.compareTo(b.$1);
      });
    final kept = {
      for (final entry in indexed.take(maxTopics)) entry.$2.topicId: entry.$2,
    };
    all[trackId] = kept;
    await _storage.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'tracks': {
            for (final e in all.entries)
              e.key: {for (final t in e.value.entries) t.key: t.value.toJson()},
          },
        }));
  }

  @visibleForTesting
  Future<void> reset() async => _storage.remove(storageKey);
}

/// Per-track mock results log (§21 mockPerformance, §41 critical).
class MockResultRepository {
  MockResultRepository(this._storage);

  static const String storageKey = 'exam_mock_results_v1';

  /// §56 bound — newest kept.
  static const int maxResults = 40;

  final ILocalStorageService _storage;

  Future<Map<String, List<MockResult>>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final perTrack =
          (json['tracks'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final out = <String, List<MockResult>>{};
      perTrack.forEach((trackId, value) {
        try {
          out[trackId] = (value as List<dynamic>)
              .map((e) => MockResult.fromJson(
                  (e as Map<String, dynamic>).cast<String, dynamic>()))
              .toList();
        } catch (_) {
          // Corrupt entry set — skip (§41).
        }
      });
      return out;
    } catch (e) {
      debugPrint('[MockResultRepository] corrupt store: $e');
      return {};
    }
  }

  Future<List<MockResult>> load(String trackId) async =>
      (await loadAll())[trackId] ?? const [];

  /// Appends one finished mock (deterministic result only, §41).
  Future<void> record(MockResult result) async {
    if (result.totalAttempted == 0) return;
    final all = await loadAll();
    final list = <MockResult>[...(all[result.trackId] ?? const [])];
    list.add(result);
    final bounded = list.length > maxResults
        ? list.sublist(list.length - maxResults)
        : list;
    all[result.trackId] = bounded;
    await _storage.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'tracks': {
            for (final e in all.entries)
              e.key: [for (final r in e.value) r.toJson()],
          },
        }));
  }

  @visibleForTesting
  Future<void> reset() async => _storage.remove(storageKey);
}
