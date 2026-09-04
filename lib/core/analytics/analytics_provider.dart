/// VaaniX Analytics — Riverpod Wiring
///
/// The single provider the app uses to log product events. Default:
/// NoopAnalyticsClient (release) / DebugPrintAnalyticsClient (debug) so the
/// seam is observable in development without shipping any third-party SDK.
///
/// Swapping in a real provider later is a one-line override in the
/// ProviderScope — no call-site changes anywhere.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';

/// The active analytics destination.
final analyticsClientProvider = Provider<AnalyticsClient>((ref) {
  return kDebugMode
      ? const DebugPrintAnalyticsClient()
      : const NoopAnalyticsClient();
});

/// One-shot `appOpened` emitter. Watches compute once per container
/// lifetime, so wiring `ref.watch(appOpenedEventProvider)` at the app root
/// logs exactly one appOpened per cold start — no widget-state guards.
final appOpenedEventProvider = Provider<void>((ref) {
  ref.log(const AnalyticsEvent(AnalyticsEventName.appOpened));
});

/// Convenience extension: `ref.log(AnalyticsEventName.appOpened)`.
extension AnalyticsRefX on Ref {
  void log(AnalyticsEvent event) {
    // Resolve through the provider each time so tests can swap clients.
    try {
      read(analyticsClientProvider).log(event);
    } catch (_) {
      // Analytics must never crash the app — swallow provider errors.
    }
  }
}

/// WidgetRef twin of [AnalyticsRefX] for use inside ConsumerWidgets.
extension AnalyticsWidgetRefX on WidgetRef {
  void log(AnalyticsEvent event) {
    try {
      read(analyticsClientProvider).log(event);
    } catch (_) {
      // Analytics must never crash the app.
    }
  }
}
