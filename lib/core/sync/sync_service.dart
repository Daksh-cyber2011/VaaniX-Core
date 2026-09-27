/// Offline-first sync orchestrator.
///
/// Responsibilities:
///
/// 1.  Watch [ConnectivityService] — only attempt uploads when the
///     device is online. Avoid hammering Supabase when connectivity is
///     unavailable.
/// 2.  Drain the [SyncOutbox] for the current user, in FIFO order.
/// 3.  Send each batch through [VaanixApiClient.postJson] to
///     `/api/v1/sync/outbox`. The backend is idempotent, so a retry
///     that arrives twice is fine.
/// 4.  Honour bounded retries with exponential backoff (capped).
/// 5.  Emit a [SyncStatus] stream so the UI can render a banner.
///
/// The service intentionally does NOT block callers — `enqueue`
/// returns immediately, the upload happens asynchronously.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/core/network/connectivity_service.dart';
import 'package:vaanix_app/core/sync/sync_outbox.dart';

enum SyncState {
  /// Service is initialising.
  idle,

  /// Service is actively uploading operations for the user.
  syncing,

  /// Service is waiting for connectivity or for a new operation.
  waiting,

  /// Last attempt failed. The service will retry on the next trigger.
  failed,
}

@immutable
class SyncStatus {
  const SyncStatus({
    required this.state,
    required this.pending,
    this.lastError,
    this.lastSyncAt,
  });

  final SyncState state;
  final int pending;
  final String? lastError;
  final DateTime? lastSyncAt;
}

/// Wires the [SyncOutbox] + [ConnectivityService] + [VaanixApiClient]
/// together. One instance is owned by the providers layer and reused
/// for the app's lifetime.
class SyncService {
  SyncService({
    required SyncOutbox outbox,
    required ConnectivityService connectivity,
    required VaanixApiClient apiClient,
  })  : _outbox = outbox,
        _connectivity = connectivity,
        _api = apiClient;

  static const int _maxBatchSize = 25;
  static const Duration _baseBackoff = Duration(seconds: 2);
  static const Duration _maxBackoff = Duration(minutes: 5);

  final SyncOutbox _outbox;
  final ConnectivityService _connectivity;
  final VaanixApiClient _api;

  String? _currentUserId;
  StreamSubscription<ConnectivityStatus>? _connSub;
  Timer? _retryTimer;

  final StreamController<SyncStatus> _statusCtrl =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _last = const SyncStatus(state: SyncState.idle, pending: 0);

  Stream<SyncStatus> get statusStream => _statusCtrl.stream;
  SyncStatus get currentStatus => _last;

  /// Bind the service to a user. Pending operations belonging to the
  /// previous user are NOT drained — they remain queued for that
  /// user's next sign-in on this device.
  void rebindUser(String? userId) {
    final previous = _currentUserId;
    _currentUserId = userId;
    if (previous != userId) {
      _emit();
    }
  }

  /// Listen for connectivity changes. Idempotent.
  void start() {
    _connSub ??= _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        unawaited(sync());
      }
    });
  }

  /// Stop listening. The outbox stays intact so a later `start()` can
  /// resume.
  Future<void> stop() async {
    await _connSub?.cancel();
    _connSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Enqueue an operation. The actual upload happens asynchronously;
  /// `enqueue` returns as soon as the op is persisted to local
  /// storage.
  Future<void> enqueue({
    required SyncOpType type,
    required Map<String, dynamic> payload,
    String? entityId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      // Guest / signed-out — operations are dropped. This is the
      // conservative choice: we do not want guest activity to leak
      // into the next signed-in user's queue.
      return;
    }
    final op = SyncOperation(
      operationId: SyncOutbox.newOperationId(),
      userId: userId,
      type: type,
      entityId: entityId,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await _outbox.enqueue(op);
    _emit();
    // Best-effort: try to drain right now. If offline, the
    // connectivity subscription will trigger the drain when we
    // reconnect.
    unawaited(sync());
  }

  /// Drain the outbox. Safe to call repeatedly.
  Future<void> sync() async {
    final userId = _currentUserId;
    if (userId == null) {
      _emit();
      return;
    }
    if (!await _connectivity.isOnline) {
      _emit();
      return;
    }
    final pending = _outbox.pendingFor(userId);
    if (pending.isEmpty) {
      _last = SyncStatus(
        state: SyncState.waiting,
        pending: 0,
        lastSyncAt: _last.lastSyncAt,
      );
      _emit();
      return;
    }

    _last = SyncStatus(
      state: SyncState.syncing,
      pending: pending.length,
      lastError: _last.lastError,
      lastSyncAt: _last.lastSyncAt,
    );
    _emit();

    // Process in small batches to keep memory + payload size bounded.
    var processed = 0;
    var failedAny = false;
    while (processed < pending.length) {
      final batch = pending.skip(processed).take(_maxBatchSize).toList();
      processed += batch.length;
      final result = await _api.postJson(
        '/sync/outbox',
        body: {
          'operations': [
            for (final op in batch)
              {
                'operation_id': op.operationId,
                'type': op.type.wire,
                'entity_id': op.entityId,
                'payload': op.payload,
                'created_at': op.createdAt.toIso8601String(),
              },
          ],
        },
      );
      final batchFailed = await _applyResult(userId, batch, result);
      failedAny = failedAny || batchFailed;
    }

    final remaining = _outbox.pendingFor(userId).length;
    _last = SyncStatus(
      state: failedAny ? SyncState.failed : SyncState.waiting,
      pending: remaining,
      lastError: failedAny ? _last.lastError : null,
      lastSyncAt: DateTime.now().toUtc(),
    );
    _emit();

    if (failedAny && remaining > 0) {
      _scheduleRetry();
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  /// Apply a batch result to the outbox. Returns `true` if any op
  /// failed (so the caller knows to schedule a retry).
  Future<bool> _applyResult(
    String userId,
    List<SyncOperation> batch,
    Result<Map<String, dynamic>> result,
  ) async {
    if (result.isLeft()) {
      // Whole-batch failure — bump retry count for every op in this
      // batch so a poison-pill doesn't loop forever.
      final failure = result.swap().getOrElse(() => throw StateError('x'));
      for (final op in batch) {
        await _outbox.markFailed(userId, op.operationId, failure.message);
      }
      _last = SyncStatus(
        state: SyncState.failed,
        pending: _outbox.pendingFor(userId).length,
        lastError: failure.message,
        lastSyncAt: _last.lastSyncAt,
      );
      return true;
    }
    final body = result.getOrElse(() => throw StateError('x'));
    final results = body['results'];
    var anyFailed = false;
    if (results is List) {
      for (final item in results) {
        if (item is! Map) continue;
        final opId = item['operation_id'];
        final accepted = item['accepted'];
        if (opId is! String) continue;
        if (accepted == true) {
          await _outbox.remove(userId, opId);
        } else {
          anyFailed = true;
          final error = item['error']?.toString() ?? 'unknown';
          await _outbox.markFailed(userId, opId, error);
        }
      }
    }
    return anyFailed;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    // Exponential backoff capped at _maxBackoff.
    final pending = _outbox.pendingFor(_currentUserId);
    final maxRetries = pending.fold<int>(
      0,
      (acc, op) => op.retryCount > acc ? op.retryCount : acc,
    );
    final delay = _baseBackoff * (1 << maxRetries.clamp(0, 8));
    final bounded = delay > _maxBackoff ? _maxBackoff : delay;
    _retryTimer = Timer(bounded, () => unawaited(sync()));
  }

  void _emit() {
    final pending =
        _outbox.pendingFor(_currentUserId).length;
    _last = SyncStatus(
      state: _last.state,
      pending: pending,
      lastError: _last.lastError,
      lastSyncAt: _last.lastSyncAt,
    );
    _statusCtrl.add(_last);
  }

  Future<void> dispose() async {
    await stop();
    await _statusCtrl.close();
  }
}
