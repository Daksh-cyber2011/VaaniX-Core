/// Exam Mode 2.0 — Exam Hub Repository (M10, §12/§56/§57)
///
/// The small persisted state the exam-mode HOME needs on top of what
/// the other milestones already store:
///
///  * per-track DAY COMPLETIONS — which plan task types were actually
///    completed on which calendar day (a finished session of a kind
///    marks that kind's plan task done for that day; §20 freedom is
///    preserved — the plan stays a recommendation, this only records
///    what really happened);
///  * the SESSION XP LEDGER — which finished sessions already paid XP
///    (so re-rendered finish screens never re-celebrate, and the
///    once-ever awardBonusXp source ids are mirrored locally so the
///    hub can report "already counted" honestly).
///
/// Persistence: one versioned JSON document per concern, corrupt data
/// degrades to empty (§41/§57), day keys bounded (§56 — the rolling
/// window only ever needs a few weeks), track-isolated (§38).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

class ExamHubRepository {
  ExamHubRepository(this._storage);

  static const String _completionsKey = 'exam_hub_day_completions_v1';
  static const String _xpLedgerKey = 'exam_hub_xp_ledger_v1';

  /// §56 bound: day keys kept per track. The plan window is 7 days;
  /// 60 days comfortably covers a full exam-prep month plus replans.
  static const int maxDayKeys = 60;

  /// §56 bound: session ledger entries (once-ever XP fingerprints).
  static const int maxLedgerEntries = 300;

  final ILocalStorageService _storage;

  // ---- day completions ---------------------------------------------------

  /// The plan task-type names completed on [dayKey] for [trackId]
  /// ('practice', 'review', 'weakArea', 'pyq', 'mock'). Empty when
  /// nothing happened that day.
  Future<Set<String>> loadDayCompletions(String trackId, String dayKey) async {
    final doc = await _loadCompletionsDoc();
    final track = doc[trackId];
    if (track is! Map<String, dynamic>) return const <String>{};
    final day = track[dayKey];
    if (day is! List) return const <String>{};
    return day.whereType<String>().toSet();
  }

  /// Marks [taskTypeName] done on [dayKey] (idempotent union).
  Future<void> recordCompletion(
      String trackId, String dayKey, String taskTypeName) async {
    final doc = await _loadCompletionsDoc();
    final track = (doc[trackId] as Map<String, dynamic>? ?? {});
    final day =
        (track[dayKey] as List? ?? const []).whereType<String>().toList();
    if (!day.contains(taskTypeName)) {
      day.add(taskTypeName);
    }
    track[dayKey] = day;
    doc[trackId] = track;
    await _saveCompletionsDoc(_boundDayKeys(doc));
  }

  /// Drops the oldest day keys beyond [maxDayKeys] per track (§56).
  Map<String, dynamic> _boundDayKeys(Map<String, dynamic> doc) {
    final out = <String, dynamic>{};
    doc.forEach((trackId, value) {
      if (value is! Map) {
        return;
      }
      final casted = value.cast<String, dynamic>();
      final keys = casted.keys.toList()..sort();
      while (keys.length > maxDayKeys) {
        casted.remove(keys.removeAt(0));
      }
      out[trackId] = casted;
    });
    return out;
  }

  Future<Map<String, dynamic>> _loadCompletionsDoc() async {
    final raw = _storage.getString(_completionsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return json.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[ExamHubRepository] corrupt completions: $e');
      return {};
    }
  }

  Future<void> _saveCompletionsDoc(Map<String, dynamic> doc) async {
    await _storage.setString(_completionsKey, jsonEncode(doc));
  }

  // ---- session XP ledger ---------------------------------------------------

  /// True when [sessionKey] (the ExamSessionRecord fingerprint id)
  /// already paid its XP — the honest "already counted" check.
  Future<bool> isAwarded(String sessionKey) async {
    final ledger = await _loadLedger();
    return ledger.contains(sessionKey);
  }

  /// Marks [sessionKey] paid. Bounded to [maxLedgerEntries] (oldest
  /// dropped — the progress repository's own bonus-source ledger
  /// remains the ultimate idempotency authority, this is the fast,
  /// honest reporting mirror).
  Future<void> markAwarded(String sessionKey) async {
    final ledger = await _loadLedger();
    if (ledger.contains(sessionKey)) return;
    ledger.add(sessionKey);
    while (ledger.length > maxLedgerEntries) {
      ledger.removeAt(0);
    }
    await _storage.setString(_xpLedgerKey, jsonEncode(ledger));
  }

  Future<List<String>> _loadLedger() async {
    final raw = _storage.getString(_xpLedgerKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return <String>[];
      return json.whereType<String>().toList();
    } catch (e) {
      debugPrint('[ExamHubRepository] corrupt ledger: $e');
      return <String>[];
    }
  }

  // ---- teardown ----------------------------------------------------------

  /// Production teardown: drops the day-completion map and the once-ever XP
  /// ledger for every track.
  ///
  /// This store had no teardown hook at all, so Settings -> "Reset all
  /// progress" left exam day-completions behind (plan days still showed as
  /// done) and left the XP ledger behind, which would have suppressed the XP
  /// award for every session the learner re-did after the reset — the ledger
  /// is a once-ever fingerprint set, so a stale entry silently means "already
  /// paid".
  Future<void> clear() async {
    await _storage.remove(_completionsKey);
    await _storage.remove(_xpLedgerKey);
  }
}
