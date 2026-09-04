/// VaaniX Analytics — Typed Events
///
/// The V1 analytics seam: a closed vocabulary of typed event names with an
/// optional, size-bounded payload. Events describe WHAT happened in product
/// terms (lessonCompleted, aiRequestFailed) — never screen plumbing.
///
/// Design rules (V1 §5):
///   - TYPED: event names live in [AnalyticsEventName]; ad-hoc strings are
///     impossible at call sites.
///   - BOUNDED: payloads are flat string/int/bool maps capped at
///     [maxPayloadEntries] with [maxPayloadValueLength] values.
///   - FIRE-AND-FORGET: logging must never throw, await, or block UI.
///   - NO REAL PROVIDER: production logs go to [NoopAnalyticsClient] unless
///     a client is injected. The abstraction ships; no third-party SDK does.
library;

import 'package:flutter/foundation.dart';

/// Product-level event vocabulary (V1 ships these 17).
enum AnalyticsEventName {
  /// Cold start of the app finished.
  appOpened,

  /// Onboarding flow fully completed.
  onboardingCompleted,

  /// A lesson was opened.
  lessonStarted,

  /// A lesson was completed (XP awarded).
  lessonCompleted,

  /// An exercise attempt was graded.
  exerciseCompleted,

  /// A chapter exam attempt began.
  examStarted,

  /// A chapter exam attempt finished with a score.
  examCompleted,

  /// The learner tapped the adaptive next-action CTA.
  nextActionSelected,

  /// First AI message of a conversation was sent.
  aiConversationStarted,

  /// An AI user message was dispatched.
  aiMessageSent,

  /// An AI request completed successfully.
  aiRequestSucceeded,

  /// An AI request failed (offline, quota, safety...).
  aiRequestFailed,

  /// An achievement was unlocked.
  achievementUnlocked,

  /// The day streak extended.
  streakExtended,

  /// Theme mode changed (light / dark / system).
  themeChanged,

  /// A settings value changed (goal, class, companion name...).
  settingsChanged,

  /// A recoverable app error was surfaced to the user.
  appErrorRecovered;

  /// Stable string id used by future real providers.
  String get id => name;
}

/// Maximum entries in one event payload.
const int maxPayloadEntries = 8;

/// Maximum length of a single payload string value.
const int maxPayloadValueLength = 120;

/// One analytics occurrence: a typed name plus a small, flat payload.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.payload = const <String, Object>{}]);

  final AnalyticsEventName name;

  /// Flat, bounded payload (ids and counts — never free text or PII).
  final Map<String, Object> payload;

  /// Builds a bounded event: drops extra payload entries and truncates
  /// over-long string values so a bad call site can never balloon data.
  factory AnalyticsEvent.bounded(
    AnalyticsEventName name,
    Map<String, Object> payload,
  ) {
    if (payload.length <= maxPayloadEntries) {
      return AnalyticsEvent(name, _clampValues(payload));
    }
    return AnalyticsEvent(
      name,
      _clampValues(
        Map.fromEntries(payload.entries.take(maxPayloadEntries)),
      ),
    );
  }

  static Map<String, Object> _clampValues(Map<String, Object> payload) {
    return payload.map((key, value) {
      if (value is String && value.length > maxPayloadValueLength) {
        return MapEntry(key, value.substring(0, maxPayloadValueLength));
      }
      return MapEntry(key, value);
    });
  }

  @override
  String toString() =>
      'AnalyticsEvent(${name.id}, ${payload.isEmpty ? '' : payload})';
}
