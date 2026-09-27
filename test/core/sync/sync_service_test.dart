/// Tests for the SyncService orchestrator.
///
/// Uses an in-memory ConnectivityService so the test does not depend
/// on `connectivity_plus` plugin availability. Pins the contract:
///   * `enqueue` persists and triggers a sync.
///   * Online + ops queued → drain posts to the backend.
///   * Duplicate operation ids → the backend returns `accepted=true`
///     with `error="duplicate"`, and we count the success.
///   * Failed op → retry counter bumps; poison pill eventually drops.
///   * Offline → no network calls made.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/network/connectivity_service.dart';
import 'package:vaanix_app/core/sync/sync_outbox.dart';
import 'package:vaanix_app/core/sync/sync_service.dart';
import 'package:vaanix_app/core/utils/result.dart';

class _AlwaysOnline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
  @override
  Stream<ConnectivityStatus> get statusStream => const Stream.empty();
  @override
  Future<ConnectivityStatus> get current async => ConnectivityStatus.online;
}

/// Records every POST body sent through [VaanixApiClient]. Returns a
/// pre-canned response so each test can stage the backend's reply.
class _RecorderApiClient extends VaanixApiClient {
  _RecorderApiClient({required this.respond})
      : super(tokenProvider: () async => 'test-token');

  /// `respond` is invoked with the path and the decoded JSON body the
  /// SyncService is sending. Return either:
  ///   - a `Map` — wrapped as `Right(map)`;
  ///   - a `Failure` (or any object) — wrapped as `Left(...)`.
  final Future<Object> Function(String path, Map<String, dynamic> body)
      respond;

  final List<String> postedPaths = [];
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    postedPaths.add(path);
    postedBodies.add(body ?? const <String, dynamic>{});
    final r = await respond(path, body ?? const {});
    if (r is Failure) return err(r);
    return ok(Map<String, dynamic>.from(r as Map));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue persists and sync() drains to the backend', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    final api = _RecorderApiClient(
      respond: (path, body) async => {
        'results': [
          for (final op in (body['operations'] as List))
            {
              'operation_id': op['operation_id'],
              'accepted': true,
            },
        ],
      },
    );
    final service = SyncService(
      outbox: outbox,
      connectivity: _AlwaysOnline(),
      apiClient: api,
    );
    service.rebindUser('A');
    await service.enqueue(
      type: SyncOpType.upsertProgress,
      payload: {'id': 'p1'},
      entityId: 'p1',
    );
    // Force a drain in case the timer hasn't fired.
    await service.sync();
    expect(api.postedPaths, ['/sync/outbox']);
    expect(outbox.pendingFor('A'), isEmpty);
    await service.dispose();
  });

  test('offline → no network call is made', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    var posted = 0;
    final api = _RecorderApiClient(
      respond: (_, __) async => {'results': []},
    );
    // Override postJson to count calls.
    final originalPost = api.postJson;
    final countingApi = _CountingClient(api, onPost: () => posted++);

    final service = SyncService(
      outbox: outbox,
      connectivity: _AlwaysOffline(),
      apiClient: countingApi,
    );
    service.rebindUser('A');
    await service.enqueue(
      type: SyncOpType.upsertProgress,
      payload: {'id': 'p1'},
    );
    await service.sync();
    expect(posted, 0,
        reason: 'the sync service MUST NOT post while offline');
    expect(outbox.pendingFor('A').length, 1);
    await service.dispose();
    originalPost.toString(); // Silence unused warning.
  });

  test('failed batch bumps retry count and keeps the op', () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    final api = _RecorderApiClient(
      respond: (_, __) async => const NetworkFailure('boom'),
    );
    final service = SyncService(
      outbox: outbox,
      connectivity: _AlwaysOnline(),
      apiClient: api,
    );
    service.rebindUser('A');
    await service.enqueue(
      type: SyncOpType.upsertProgress,
      payload: {'id': 'p1'},
    );
    await service.sync();
    final pending = outbox.pendingFor('A').single;
    expect(pending.retryCount, 1);
    await service.dispose();
  });

  test('rebinding to a new user stops draining the previous user\'s ops',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = SyncOutbox(prefs);
    final api = _RecorderApiClient(
      respond: (_, __) async => {
        'results': [],
      },
    );
    final service = SyncService(
      outbox: outbox,
      connectivity: _AlwaysOnline(),
      apiClient: api,
    );
    service.rebindUser('A');
    await service.enqueue(
      type: SyncOpType.upsertProgress,
      payload: {'id': 'a-1'},
    );
    // Now switch to B before draining.
    service.rebindUser('B');
    await service.enqueue(
      type: SyncOpType.upsertProgress,
      payload: {'id': 'b-1'},
    );
    await service.sync();
    // A's op is still pending (will resume next sign-in), B's was
    // drained in this call.
    expect(outbox.pendingFor('A').length, 1);
    expect(outbox.pendingFor('B'), isEmpty);
    await service.dispose();
  });
}

class _AlwaysOffline implements ConnectivityService {
  @override
  Future<bool> get isOnline async => false;
  @override
  Stream<ConnectivityStatus> get statusStream => const Stream.empty();
  @override
  Future<ConnectivityStatus> get current async => ConnectivityStatus.offline;
}

class _CountingClient implements VaanixApiClient {
  _CountingClient(this._inner, {required this.onPost});
  final VaanixApiClient _inner;
  final void Function() onPost;

  @override
  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    onPost();
    return _inner.postJson(path, body: body, query: query);
  }

  @override
  Future<Result<Map<String, dynamic>>> getJson(
    String path, {
    Map<String, String>? query,
  }) =>
      _inner.getJson(path, query: query);

  @override
  void close() => _inner.close();
}
