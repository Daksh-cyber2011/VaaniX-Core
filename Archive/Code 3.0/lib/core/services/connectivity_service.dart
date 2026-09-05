/// VaaniX Connectivity Service
///
/// Wraps the `connectivity_plus` package to expose a reactive boolean
/// stream of online/offline state plus a one-shot synchronous-ish check.
///
/// Providers subscribe to [onConnectivityChanged] to drive the global
/// [connectivityProvider]; repositories can call [isOnline] before
/// attempting a network operation.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'logger_service.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Emits `true` whenever the device has at least one usable transport
  /// (wifi / mobile / ethernet / vpn / bluetooth), `false` for none.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
  }

  /// Current connectivity state. Returns `true` if any transport is up.
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } on Exception catch (e, st) {
      AppLogger.w('Connectivity check failed — assuming offline', e, st);
      return false;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Releases the stream subscription. Safe to call multiple times.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
