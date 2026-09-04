/// VaaniX Analytics — Client Contract + Default Noop Implementation
///
/// [AnalyticsClient] is the seam future providers (Firebase, PostHog,
/// Matomo...) plug into. V1 deliberately ships NO real provider: the
/// production default is [NoopAnalyticsClient], which discards events.
///
/// Contract rules for ANY implementation:
///   - log() must never throw, never block, and never await long work.
///   - Events arrive bounded ([AnalyticsEvent.bounded]).
///   - Client state must survive being called before init — a Noop-like
///     fallback is always acceptable.
library;

import 'package:flutter/foundation.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';

/// Destination for typed product events.
abstract class AnalyticsClient {
  /// Records [event]. Fire-and-forget: implementors must swallow errors.
  void log(AnalyticsEvent event);
}

/// The production default: discard everything, cost nothing.
///
/// Keeps the app privacy-clean by default while every product flow still
/// emits typed events through the seam — flipping a provider override is
/// the only change a real provider needs later.
class NoopAnalyticsClient implements AnalyticsClient {
  const NoopAnalyticsClient();

  @override
  void log(AnalyticsEvent event) {
    // Intentionally a no-op. In debug builds the event is still visible to
    // the debug observer wired in analytics_provider.dart.
  }
}

/// Debug-only observer: prints events in dev builds so the seam is verifiable
/// during development without shipping any provider.
class DebugPrintAnalyticsClient implements AnalyticsClient {
  const DebugPrintAnalyticsClient();

  @override
  void log(AnalyticsEvent event) {
    debugPrint('[analytics] ${event.name.id} ${event.payload}');
  }
}
