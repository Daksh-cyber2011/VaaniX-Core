/// Exam Mode 2.0 — Exam Scope Repository (M2)
///
/// Offline-first persistence for the student's exam scope, following the
/// LocalProgressRepository pattern: JSON-encoded under dedicated keys in
/// [ILocalStorageService] (SharedPreferences-backed).
///
/// Stored shape (single key, versioned):
/// ```json
/// {
///   "version": 1,
///   "activeTrackId": "cbse_10_sanskrit",
///   "scopes": {
///     "cbse_10_sanskrit": { "selectedUnitIds": [...], "revision": 3, ... }
///   }
/// }
/// ```
///
/// One active track at a time (V1: the student prepares one course); scope
/// per track is retained so switching back preserves the earlier selection
/// ("edit selections later", master plan §6).
///
/// Corruption policy: corrupt JSON degrades to an empty store (same
/// philosophy as the quiz-attempt history) — never a crash.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

import 'package:vaanix_app/features/exam/domain/exam_scope.dart';

class ExamScopeStore {
  ExamScopeStore(
      {String? activeTrackId, required Map<String, ExamScopeSelection> scopes})
      : _activeTrackId = activeTrackId,
        _scopes = scopes;

  final String? _activeTrackId;
  final Map<String, ExamScopeSelection> _scopes;

  String? get activeTrackId => _activeTrackId;
  Map<String, ExamScopeSelection> get scopes => Map.unmodifiable(_scopes);
}

class ExamScopeRepository {
  ExamScopeRepository(this._storage);

  static const String storageKey = 'exam_scope_v1';

  final ILocalStorageService _storage;

  /// Loads the store; degrades to empty on corrupt/missing JSON.
  Future<ExamScopeStore> load() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return ExamScopeStore(activeTrackId: null, scopes: {});
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final scopesJson =
          (json['scopes'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final scopes = <String, ExamScopeSelection>{};
      scopesJson.forEach((trackId, value) {
        try {
          scopes[trackId] = ExamScopeSelection.fromJson(
              (value as Map<String, dynamic>).cast<String, dynamic>());
        } catch (_) {
          // A single corrupt track entry must not take down the store.
        }
      });
      return ExamScopeStore(
        activeTrackId: json['activeTrackId'] as String?,
        scopes: scopes,
      );
    } catch (e) {
      debugPrint('[ExamScopeRepository] corrupt store, resetting: $e');
      return ExamScopeStore(activeTrackId: null, scopes: {});
    }
  }

  /// Saves the full store (write-through; small payloads).
  Future<void> _save(ExamScopeStore store) async {
    final json = {
      'version': 1,
      'activeTrackId': store.activeTrackId,
      'scopes': {
        for (final e in store.scopes.entries) e.key: e.value.toJson(),
      },
    };
    await _storage.setString(storageKey, jsonEncode(json));
  }

  /// Reads one track's selection (empty when absent).
  Future<ExamScopeSelection> loadSelection(String trackId) async {
    final store = await load();
    return store.scopes[trackId] ?? ExamScopeSelection.empty(trackId);
  }

  /// Persists [selection] for its track and marks that track active.
  Future<void> saveSelection(ExamScopeSelection selection) async {
    final store = await load();
    final scopes = {...store.scopes};
    scopes[selection.trackId] = selection;
    await _save(ExamScopeStore(
      activeTrackId: selection.trackId,
      scopes: scopes,
    ));
  }

  /// Clears one track's selection while keeping it active (explicit
  /// "clear all" persistence).
  Future<void> clearSelection(String trackId) async {
    final store = await load();
    final scopes = {...store.scopes};
    scopes[trackId] = ExamScopeSelection.empty(trackId);
    await _save(ExamScopeStore(activeTrackId: trackId, scopes: scopes));
  }

  /// The active track id, or null when nothing was ever saved.
  Future<String?> activeTrackId() async => (await load()).activeTrackId;

  /// Data-integrity pass: prunes stored selections against the current
  /// syllabus views (drops ids that no longer exist). Runs at load time in
  /// the provider so stale data can never leak into the UI.
  Future<ExamScopeStore> loadAndPrune(
      Map<String, ExamScopeView> viewsByTrack) async {
    final store = await load();
    var changed = false;
    final scopes = <String, ExamScopeSelection>{};
    store.scopes.forEach((trackId, selection) {
      final view = viewsByTrack[trackId];
      if (view == null) {
        scopes[trackId] = selection;
        return;
      }
      final pruned = selection.pruneTo(view);
      if (!identical(pruned, selection)) changed = true;
      scopes[trackId] = pruned;
    });
    final result =
        ExamScopeStore(activeTrackId: store.activeTrackId, scopes: scopes);
    if (changed) await _save(result);
    return result;
  }

  /// Test/teardown hook.
  @visibleForTesting
  Future<void> reset() async {
    await _storage.remove(storageKey);
  }
}
