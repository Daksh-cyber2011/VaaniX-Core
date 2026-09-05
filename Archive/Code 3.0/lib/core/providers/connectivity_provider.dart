/// VaaniX Connectivity & Network Providers
///
/// Exposes a reactive `isOnline` boolean derived from
/// [ConnectivityService.onConnectivityChanged]. Repositories and UI can
/// watch [isOnlineProvider] to react to network changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import 'app_providers.dart';

/// Reactive online/offline state.
/// Defaults to `true` until the first connectivity event lands.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  // Seed with an immediate check so consumers don't briefly assume offline.
  return service.onConnectivityChanged;
});
