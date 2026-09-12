/// Exam Mode 2.0 — Weak-Area State Repository (M8, §12/§22/§23/§56)
///
/// Persistence for the M8 state that must survive restarts (§12):
///  * recovery-day history (when the last weak-area day was, how
///    many the student has had — the §22 frequency evidence);
///  * per-topic revision ladder state (§23 interval position, last
///    review, due date — the forgetting-curve memory);
///  * the bounded recheck outcome log (§56).
///
/// Same pattern as the other M3-M7 repositories: one versioned JSON
/// document, per-track map, corrupt entries degrade — never crash
/// (§41), defensive parsing (§57).
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/remediation_engine.dart';

/// Per-track weak-area state (§12 persisted, never UI-only).
class WeakAreaState extends Equatable {
  const WeakAreaState({
    required this.trackId,
    this.lastRecoveryDayIso = '',
    this.recoveryDayCount = 0,
    this.revision = const {},
    this.recheckOutcomes = const [],
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String trackId;

  /// When the last weak-area recovery day/session ran (§22 gap rule).
  final String lastRecoveryDayIso;

  /// How many recovery days the student has had (cumulative, honest
  /// history for frequency decisions).
  final int recoveryDayCount;

  /// topicId → revision ladder state (§23).
  final Map<String, RevisionItem> revision;

  /// Bounded recheck outcome log (newest last).
  final List<RecheckOutcomeRecord> recheckOutcomes;

  final int schemaVersion;

  static WeakAreaState empty(String trackId) =>
      WeakAreaState(trackId: trackId);

  WeakAreaState withRecoveryCompleted(DateTime now) => WeakAreaState(
        trackId: trackId,
        lastRecoveryDayIso: now.toIso8601String(),
        recoveryDayCount: recoveryDayCount + 1,
        revision: revision,
        recheckOutcomes: recheckOutcomes,
        schemaVersion: schemaVersion,
      );

  WeakAreaState withRevision(Map<String, RevisionItem> next) => WeakAreaState(
        trackId: trackId,
        lastRecoveryDayIso: lastRecoveryDayIso,
        recoveryDayCount: recoveryDayCount,
        revision: next,
        recheckOutcomes: recheckOutcomes,
        schemaVersion: schemaVersion,
      );

  WeakAreaState withRecheckOutcome(RecheckOutcomeRecord record) {
    final bounded = [...recheckOutcomes, record];
    const cap = 100; // §56.
    return WeakAreaState(
      trackId: trackId,
      lastRecoveryDayIso: lastRecoveryDayIso,
      recoveryDayCount: recoveryDayCount,
      revision: revision,
      recheckOutcomes:
          bounded.length > cap ? bounded.sublist(bounded.length - cap) : bounded,
      schemaVersion: schemaVersion,
    );
  }

  factory WeakAreaState.fromJson(Map<String, dynamic> json) {
    final revisionJson =
        (json['revision'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final revision = <String, RevisionItem>{};
    revisionJson.forEach((topicId, value) {
      try {
        revision[topicId] = RevisionItem.fromJson(
            (value as Map<String, dynamic>).cast<String, dynamic>());
      } catch (_) {
        // Corrupt single entry — skip (§41).
      }
    });
    final outcomes = <RecheckOutcomeRecord>[];
    for (final o in (json['recheckOutcomes'] as List<dynamic>? ?? [])) {
      try {
        outcomes.add(RecheckOutcomeRecord.fromJson(
            (o as Map<String, dynamic>).cast<String, dynamic>()));
      } catch (_) {
        // Corrupt single entry — skip (§41).
      }
    }
    return WeakAreaState(
      trackId: json['trackId'] as String? ?? '',
      lastRecoveryDayIso: json['lastRecoveryDayIso'] as String? ?? '',
      recoveryDayCount: (json['recoveryDayCount'] as num?)?.toInt() ?? 0,
      revision: revision,
      recheckOutcomes: outcomes,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'trackId': trackId,
        'lastRecoveryDayIso': lastRecoveryDayIso,
        'recoveryDayCount': recoveryDayCount,
        'revision': {
          for (final e in revision.entries) e.key: e.value.toJson(),
        },
        'recheckOutcomes': [
          for (final o in recheckOutcomes) o.toJson(),
        ],
      };

  @override
  List<Object?> get props =>
      [trackId, lastRecoveryDayIso, recoveryDayCount, revision, recheckOutcomes];
}

/// One §22 mastery-recheck outcome (bounded log).
class RecheckOutcomeRecord extends Equatable {
  const RecheckOutcomeRecord({
    required this.topicId,
    required this.outcome,
    required this.atIso,
  });

  final String topicId;
  final RemediationOutcome outcome;
  final String atIso;

  factory RecheckOutcomeRecord.fromJson(Map<String, dynamic> json) =>
      RecheckOutcomeRecord(
        topicId: json['topicId'] as String? ?? '',
        outcome: remediationOutcomeFromName(json['outcome'] as String?),
        atIso: json['atIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'outcome': outcome.name,
        'atIso': atIso,
      };

  @override
  List<Object?> get props => [topicId, outcome, atIso];
}

class WeakAreaRepository {
  WeakAreaRepository(this._storage);

  static const String storageKey = 'exam_weak_area_v1';

  final ILocalStorageService _storage;

  Future<Map<String, WeakAreaState>> loadAll() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final statesJson =
          (json['states'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final states = <String, WeakAreaState>{};
      statesJson.forEach((trackId, value) {
        try {
          states[trackId] = WeakAreaState.fromJson(
              (value as Map<String, dynamic>).cast<String, dynamic>());
        } catch (_) {
          // Corrupt single entry — skip (§41).
        }
      });
      return states;
    } catch (e) {
      debugPrint('[WeakAreaRepository] corrupt store: $e');
      return {};
    }
  }

  Future<WeakAreaState> load(String trackId) async =>
      (await loadAll())[trackId] ?? WeakAreaState.empty(trackId);

  Future<void> save(WeakAreaState state) async {
    final all = await loadAll();
    all[state.trackId] = state;
    await _storage.setString(storageKey, jsonEncode({
      'version': 1,
      'states': {
        for (final e in all.entries) e.key: e.value.toJson(),
      },
    }));
  }

  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
