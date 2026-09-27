/// Tests for the SyncOutbox queue.
///
/// Pins:
///   * Enqueue persists operations.
///   * Same operationId enqueued twice is deduped.
///   * markFailed bumps retry count, drops after a bounded cap.
///   * Per-user partitioning — User A's queue is invisible to User B.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/sync/sync_outbox.dart';

SyncOperation _op(String id, String userId, {SyncOpType type = SyncOpType.upsertProgress}) {
  return SyncOperation(
    operationId: id,
    userId: userId,
    type: type,
    entityId: 'p1',
    payload: const {'id': 'p1'},
    createdAt: DateTime(2026, 9, 26),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue persists and pendingFor returns the op', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-1', 'A'));
    final pending = outbox.pendingFor('A');
    expect(pending.length, 1);
    expect(pending.first.operationId, 'op-1');
  });

  test('enqueue is idempotent by operationId', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-1', 'A'));
    await outbox.enqueue(_op('op-1', 'A'));
    expect(outbox.pendingFor('A').length, 1);
  });

  test('per-user partitioning — B cannot see A\'s ops', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-a', 'A'));
    await outbox.enqueue(_op('op-b', 'B'));
    expect(outbox.pendingFor('A').length, 1);
    expect(outbox.pendingFor('B').length, 1);
    expect(outbox.pendingFor('A').first.operationId, 'op-a');
    expect(outbox.pendingFor('B').first.operationId, 'op-b');
  });

  test('remove() drops a successful op from the queue', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-1', 'A'));
    await outbox.remove('A', 'op-1');
    expect(outbox.pendingFor('A'), isEmpty);
  });

  test('markFailed bumps retry count', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-1', 'A'));
    await outbox.markFailed('A', 'op-1', 'boom');
    final after = outbox.pendingFor('A').single;
    expect(after.retryCount, 1);
    expect(after.lastError, 'boom');
  });

  test('markFailed drops a poison-pill op past the retry cap', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-1', 'A'));
    for (var i = 0; i < 12; i++) {
      await outbox.markFailed('A', 'op-1', 'boom');
    }
    expect(outbox.pendingFor('A'), isEmpty,
        reason: 'a poisoned op MUST be dropped so the queue can drain');
  });

  test('clear() removes all ops for the named user', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    await outbox.enqueue(_op('op-a', 'A'));
    await outbox.enqueue(_op('op-b', 'B'));
    await outbox.clear('A');
    expect(outbox.pendingFor('A'), isEmpty);
    expect(outbox.pendingFor('B').length, 1);
  });

  test('newOperationId is unique across calls', () {
    final a = SyncOutbox.newOperationId();
    final b = SyncOutbox.newOperationId();
    expect(a, isNot(b));
    expect(a, startsWith('op-'));
  });
}
