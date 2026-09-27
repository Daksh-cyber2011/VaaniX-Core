/// Sync infrastructure providers — single import surface for the sync
/// outbox + sync service. Exposes the [SyncService] and its status
/// stream.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/api/vaanix_api_client.dart';
import 'package:vaanix_app/core/network/connectivity_service.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/sync/sync_outbox.dart';
import 'package:vaanix_app/core/sync/sync_service.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';

/// Outbox queue, persisted to the same SharedPreferences instance the
/// rest of the app uses.
final syncOutboxProvider = Provider<SyncOutbox>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncOutbox(prefs);
});

/// HTTP client for the VaaniX backend. The [BearerTokenProvider]
/// pulls the live token from the auth repository so the backend can
/// always identify the caller.
final vaanixApiClientProvider = Provider<VaanixApiClient>((ref) {
  final tokenProvider = () async {
    final session = ref.read(latestAuthSessionProvider);
    return session.accessToken;
  };
  final client = VaanixApiClient(tokenProvider: tokenProvider);
  ref.onDispose(client.close);
  return client;
});

/// Process-wide sync orchestrator. Starts listening for connectivity
/// changes on first read; rebinds to the current user whenever auth
/// state changes; tears down cleanly when the container disposes.
final syncServiceProvider = Provider<SyncService>((ref) {
  final outbox = ref.watch(syncOutboxProvider);
  final connectivity = ref.watch(connectivityProvider);
  final api = ref.watch(vaanixApiClientProvider);
  final service = SyncService(
    outbox: outbox,
    connectivity: connectivity,
    apiClient: api,
  );
  service.start();

  // Rebind whenever the auth user changes. The previous user's
  // pending operations are NOT drained — they remain in storage and
  // will resume when that user signs back in on this device.
  ref.listen(latestAuthSessionProvider, (_, next) {
    service.rebindUser(next.user?.id);
  });
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive accessor for the sync status stream.
final syncStatusStreamProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncServiceProvider).statusStream,
);
