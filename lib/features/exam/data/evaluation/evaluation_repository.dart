/// Exam Mode 2.0 — Evaluation Repository (M7)
///
/// Bounded, offline-first log of recent answer evaluations (§47 error
/// intelligence feeds the M8 weak-area engine later). Persists only
/// compact verdict records — never raw photo bytes (privacy: photos
/// are transient inputs, §41 data safety).
///
/// Bound: the last [maxRecords] per track (§56: no unbounded
/// history).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

class EvaluationRecord {
  const EvaluationRecord({
    required this.questionId,
    required this.topicId,
    required this.kind,
    required this.verdict,
    required this.atIso,
  });

  final String questionId;
  final String topicId;

  /// 'typed' | 'photo'.
  final String kind;

  /// 'correct' | 'partiallyCorrect' | 'incorrect' | 'uncertain'.
  final String verdict;
  final String atIso;

  factory EvaluationRecord.fromJson(Map<String, dynamic> json) =>
      EvaluationRecord(
        questionId: json['questionId'] as String? ?? '',
        topicId: json['topicId'] as String? ?? '',
        kind: json['kind'] as String? ?? 'typed',
        verdict: json['verdict'] as String? ?? '',
        atIso: json['atIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'topicId': topicId,
        'kind': kind,
        'verdict': verdict,
        'atIso': atIso,
      };
}

class EvaluationRepository {
  EvaluationRepository(this._storage);

  static const String storageKey = 'exam_evaluations_v1';
  static const int maxRecords = 200;

  final ILocalStorageService _storage;

  Future<Map<String, List<EvaluationRecord>>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final perTrack =
          (json['records'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final out = <String, List<EvaluationRecord>>{};
      perTrack.forEach((trackId, value) {
        try {
          out[trackId] = (value as List<dynamic>)
              .map((e) => EvaluationRecord.fromJson(
                  (e as Map<String, dynamic>).cast<String, dynamic>()))
              .toList();
        } catch (_) {
          // Corrupt entry set — skip (§41).
        }
      });
      return out;
    } catch (e) {
      debugPrint('[EvaluationRepository] corrupt store: $e');
      return {};
    }
  }

  Future<void> record({
    required String trackId,
    required String questionId,
    required String topicId,
    required String kind,
    required String verdict,
  }) async {
    final all = await loadAll();
    final list = [...(all[trackId] ?? const [])];
    list.add(EvaluationRecord(
      questionId: questionId,
      topicId: topicId,
      kind: kind,
      verdict: verdict,
      atIso: DateTime.now().toIso8601String(),
    ));
    // §56 bound: keep the newest [maxRecords].
    final bounded =
        list.length > maxRecords ? list.sublist(list.length - maxRecords) : list;
    all[trackId] = bounded;
    await _storage.setString(storageKey, jsonEncode({
      'version': 1,
      'records': {
        for (final e in all.entries) e.key: [for (final r in e.value) r.toJson()],
      },
    }));
  }

  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
