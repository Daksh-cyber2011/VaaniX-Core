/// VaaniX Connectivity Service
///
/// Provides reactive awareness of network availability so repositories can
/// short-circuit calls (returning [NetworkFailure]) and the UI can show
/// offline banners.
///
/// Uses the OS-level connectivity stream from the `connectivity_plus` package
/// — declared in pubspec so it is a hard dependency. If at any point the
/// dependency is removed, this service is the only place to change.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of connectivity state.
enum ConnectivityStatus {
  online,
  offline,
}

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  /// Emits the current status and every subsequent change.
  ///
  /// A result of [ConnectivityResult.none] (or only location/usb-tethered
  /// transport with no actual route) is treated as offline.
  Stream<ConnectivityStatus> get statusStream {
    return _connectivity.onConnectivityChanged.map(_reduce);
  }

  /// Current status, fetched once.
  Future<ConnectivityStatus> get current async {
    final results = await _connectivity.checkConnectivity();
    return _reduce(results);
  }

  /// True when there is at least one active transport.
  Future<bool> get isOnline async => (await current) == ConnectivityStatus.online;

  ConnectivityStatus _reduce(List<ConnectivityResult> results) {
    final online = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.bluetooth ||
          r == ConnectivityResult.tethering,
    );
    return online ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }
}

/// Riverpod wiring.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(Connectivity()),
);

/// Reactive connectivity status for UI consumption.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>(
  (ref) => ref.watch(connectivityProvider).statusStream,
);

/// Convenience synchronous accessor (online/offline). Defaults to true
/// before the first event arrives to avoid false-positive offline banners.
final isOnlineProvider = Provider<bool>((ref) {
  final asyncValue = ref.watch(connectivityStatusProvider);
  return asyncValue.maybeWhen(
    data: (status) => status == ConnectivityStatus.online,
    orElse: () => true,
  );
});
