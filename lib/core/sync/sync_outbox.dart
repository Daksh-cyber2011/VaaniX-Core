/// Sync outbox — durable queue of pending mutations.
///
/// The Flutter client writes user state to local storage first (the
/// "local-first" model). Mutations are also enqueued here so they can
/// be replayed against the VaaniX backend once connectivity returns.
///
/// Every operation carries:
///   * `operationId` — a UUID generated client-side. The backend uses
///     this to deduplicate retries (see backend/app/idempotency.py).
///   * `userId` — the user the operation belongs to. A signed-out
///     outbox is wiped; a switch-user transition flushes the
///     previous user's pending operations before binding a new id.
///   * `type` — the operation type (see [SyncOpType]).
///   * `entityId` — the row this operation targets.
///   * `payload` — JSON body that the backend forwards to Supabase.
///   * `createdAt` / `retryCount` / `lastError` — retry bookkeeping.
///
/// The outbox persists to SharedPreferences under a single JSON
/// document, so the queue survives app restarts.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of operations the outbox knows how to send. Mirrors the
/// backend's `OutboxOperationType` enum.
enum SyncOpType {
  upsertProgress,
  upsertMastery,
  upsertCourseState,
  upsertLearnProfile,
}

extension SyncOpTypeWire on SyncOpType {
  String get wire {
    switch (this) {
      case SyncOpType.upsertProgress:
        return 'upsert_progress';
      case SyncOpType.upsertMastery:
        return 'upsert_mastery';
      case SyncOpType.upsertCourseState:
        return 'upsert_course_state';
      case SyncOpType.upsertLearnProfile:
        return 'upsert_learn_profile';
    }
  }

  static SyncOpType fromWire(String wire) {
    switch (wire) {
      case 'upsert_progress':
        return SyncOpType.upsertProgress;
      case 'upsert_mastery':
        return SyncOpType.upsertMastery;
      case 'upsert_course_state':
        return SyncOpType.upsertCourseState;
      case 'upsert_learn_profile':
        return SyncOpType.upsertLearnProfile;
    }
    throw ArgumentError('Unknown sync op type: $wire');
  }
}

/// A single pending mutation.
@immutable
class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.userId,
    required this.type,
    required this.payload,
    this.entityId,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  final String operationId;
  final String userId;
  final SyncOpType type;
  final String? entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  SyncOperation copyWith({
    int? retryCount,
    String? lastError,
  }) {
    return SyncOperation(
      operationId: operationId,
      userId: userId,
      type: type,
      entityId: entityId,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'userId': userId,
        'type': type.wire,
        'entityId': entityId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };

  static SyncOperation fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      operationId: json['operationId'] as String,
      userId: json['userId'] as String,
      type: SyncOpTypeWire.fromWire(json['type'] as String),
      entityId: json['entityId'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as int?) ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

/// The outbox queue, persisted to SharedPreferences.
class SyncOutbox {
  SyncOutbox(this._prefs, {String? storageKeyPrefix})
      : _keyPrefix = storageKeyPrefix ?? 'sync_outbox';

  static const int _maxRetryCount = 8;

  final SharedPreferences _prefs;
  final String _keyPrefix;

  String _userKey(String? userId) =>
      '$_keyPrefix:${userId ?? 'guest'}';

  /// Returns every pending operation for the given user, oldest first.
  /// The queue is owned per-user — operations for other users are not
  /// visible across sign-in / sign-out transitions.
  List<SyncOperation> pendingFor(String? userId) {
    final raw = _prefs.getString(_userKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded.cast<Map<String, dynamic>>())
          SyncOperation.fromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Enqueue a new operation. Idempotent by `operationId` — re-enqueuing
  /// the same id is a no-op.
  Future<void> enqueue(SyncOperation op) async {
    final list = pendingFor(op.userId);
    final without = [
      for (final existing in list)
        if (existing.operationId != op.operationId) existing,
    ];
    final next = [...without, op];
    await _save(op.userId, next);
  }

  /// Remove an operation (after a successful upload).
  Future<void> remove(String userId, String operationId) async {
    final list = pendingFor(userId);
    final next = [
      for (final op in list)
        if (op.operationId != operationId) op,
    ];
    await _save(userId, next);
  }

  /// Mark an operation as failed. The retry count is incremented
  /// (bounded — operations past [_maxRetryCount] are dropped so a
  /// poison-pill op cannot block the queue forever).
  Future<void> markFailed(String userId, String operationId, String error) async {
    final list = pendingFor(userId);
    final next = <SyncOperation>[];
    for (final op in list) {
      if (op.operationId == operationId) {
        final bumped = op.copyWith(
          retryCount: op.retryCount + 1,
          lastError: error,
        );
        if (bumped.retryCount > _maxRetryCount) {
          continue; // poison-pill: drop.
        }
        next.add(bumped);
      } else {
        next.add(op);
      }
    }
    await _save(userId, next);
  }

  /// Drop every operation for [userId]. Used on logout.
  Future<void> clear(String? userId) async {
    await _prefs.remove(_userKey(userId));
  }

  Future<void> _save(String userId, List<SyncOperation> ops) async {
    final encoded = jsonEncode([for (final op in ops) op.toJson()]);
    await _prefs.setString(_userKey(userId), encoded);
  }

  /// Generates a client-side operation id. Random + timestamp so it
  /// is unique even across offline sessions.
  static String newOperationId({Random? random}) {
    final r = random ?? Random.secure();
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final tail = r.nextInt(0xFFFFFFFF).toRadixString(36);
    return 'op-$ts-$tail';
  }
}
