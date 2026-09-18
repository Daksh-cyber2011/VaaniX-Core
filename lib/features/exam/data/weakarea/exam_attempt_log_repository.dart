/// Exam Mode 2.0 — Attempt Log Repository (M8, §21/§12/§56)
///
/// The per-question FINAL attempt log — the raw evidence §21 pattern
/// detection needs. The M6 loop already persisted AGGREGATE mastery
/// (per-topic correct/attempt EWMA); M8 additionally needs the
/// QUESTION-level history (which questions were wrong, with what
/// verdict, after how many retries) to:
///   * detect error PATTERNS (§47/§21 — patterns, not counts);
///   * re-serve previously-wrong questions in recovery/revision
///     sessions (§22 "mistakes → retry", §23 "previously wrong
///     questions").
///
/// Persistence: one versioned JSON document per track (§12 "Do NOT
/// store everything only in UI state"), corrupt data degrades to
/// empty — never a crash (§41). Bounded: the newest [maxEntries] per
/// track (§56 no unbounded history). Batched writes (one write per
/// finished session, not per tap — §18 efficiency).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';

class ExamAttemptLogRepository {
  ExamAttemptLogRepository(this._storage);

  static const String storageKey = 'exam_attempt_log_v1';

  /// §56 bound — comfortably above the longest session; enough
  /// rolling history for patterns without unbounded growth.
  static const int maxEntries = 300;

  final ILocalStorageService _storage;

  Future<Map<String, List<ErrorEvidence>>> loadAll() async {
    final raw = _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final perTrack =
          (json['entries'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final out = <String, List<ErrorEvidence>>{};
      perTrack.forEach((trackId, value) {
        try {
          out[trackId] = (value as List<dynamic>)
              .map((e) => ErrorEvidence.fromJson(
                  (e as Map<String, dynamic>).cast<String, dynamic>()))
              .toList();
        } catch (_) {
          // Corrupt entry set — skip (§41).
        }
      });
      return out;
    } catch (e) {
      debugPrint('[ExamAttemptLogRepository] corrupt store: $e');
      return {};
    }
  }

  Future<List<ErrorEvidence>> load(String trackId) async =>
      (await loadAll())[trackId] ?? const [];

  /// Appends a FINISHED session's attempts in ONE write (batched,
  /// §18). Verdict normalization happens at the caller (the M6 loop's
  /// verdict vocabulary is the contract).
  Future<void> recordSession({
    required String trackId,
    required List<ErrorEvidence> attempts,
  }) async {
    if (attempts.isEmpty) return;
    // Defensive: never absorb foreign-track or empty ids — and never
    // create an empty entry for a track with nothing real to store.
    final filtered = attempts
        .where((a) => a.questionId.isNotEmpty && a.topicId.isNotEmpty)
        .toList();
    final all = await loadAll();
    final list = <ErrorEvidence>[...(all[trackId] ?? const [])];
    if (filtered.isEmpty && list.isEmpty) return;
    list.addAll(filtered);
    final bounded = list.length > maxEntries
        ? list.sublist(list.length - maxEntries)
        : list;
    all[trackId] = bounded;
    await _storage.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'entries': {
            for (final e in all.entries)
              e.key: [for (final r in e.value) r.toJson()],
          },
        }));
  }

  /// The wrong-question ids per topic (for mistake-retry phase and
  /// §23 review mix) from the rolling window.
  static Map<String, Set<String>> wrongQuestionIdsByTopic(
      List<ErrorEvidence> entries) {
    final out = <String, Set<String>>{};
    for (final e in entries) {
      if (!e.isWrong) continue;
      out.putIfAbsent(e.topicId, () => {}).add(e.questionId);
    }
    return out;
  }

  /// Production teardown: drops the stored question-level attempt log for every track.
  ///
  /// Settings -> "Reset all progress" promises that exam history is cleared,
  /// so a production entry point is required; [reset] is `@visibleForTesting`
  /// and must never be called from production code. [reset] delegates here so
  /// both paths share one implementation.
  Future<void> clear() async {
    await _storage.remove(storageKey);
  }

  @visibleForTesting
  Future<void> reset() => clear();
}
