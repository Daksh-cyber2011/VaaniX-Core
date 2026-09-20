/// VaaniX Audio — Event Taxonomy
///
/// Single source of truth for every audio cue the product can play.
/// Designed to be the contract between feature code (which dispatches
/// domain events) and the audio service (which resolves them to clips,
/// volume, and playback policy).
///
/// Naming convention: `<domain>.<outcome>` — easy to grep, easy to
/// audit, easy to map to a folder of SFX.
///
/// The set is deliberately CLOSED. If a new sound is needed, add it
/// here AND wire a resolver mapping. We never want audio code to call
/// a raw asset path directly — that would defeat the mute / volume /
/// accessibility / offline rules below.
library;

import 'package:flutter/foundation.dart';

/// The canonical VaaniX audio event taxonomy.
///
/// Every entry maps to one short SFX. The audio service can resolve
/// each event to a bundled clip (when present) or to silence (when
/// the asset is missing or audio is muted / disabled).
enum VaaniXAudioEvent {
  // ── User interaction ───────────────────────────────────────────────────
  tap,
  longPress,
  navigation,
  modalOpen,
  modalClose,

  // ── Answer feedback (Learn Mode + Exam Mode practice) ────────────────
  correct,
  incorrect,
  hint,
  streakExtended,

  // ── Reward + progress ─────────────────────────────────────────────────
  xpGained,
  achievementUnlocked,
  lessonComplete,
  sessionComplete,
  milestone,

  // ── Companion (VAN) ────────────────────────────────────────────────────
  vanIdle,
  vanHappy,
  vanCaring,
  vanThinking,
  vanCelebrate,
  vanSurprised,
  vanError,

  // ── System / connectivity ─────────────────────────────────────────────
  errorOccurred,
  offline,
  online,
}

/// Declarative playback policy. Attached to each event so the audio
/// service can apply consistent rules (no audio spam, no sound during
/// reduced-motion sessions, etc.).
@immutable
class VaaniXAudioPolicy {
  const VaaniXAudioPolicy({
    required this.maxConcurrent,
    required this.minIntervalMs,
    this.volume = 0.85,
  });

  /// How many times this event may play at once across the app.
  /// 1 = interrupt previous if a new one fires.
  final int maxConcurrent;

  /// Minimum gap between two plays of the SAME event (ms). Prevents
  /// audio spam when the user fires correct/incorrect rapidly.
  final int minIntervalMs;

  /// Per-event volume (0.0 .. 1.0). Defaults are conservative — VAN
  /// reactions are softer than reward sounds.
  final double volume;

  /// Default policy used by the service when a per-event override is
  /// not supplied.
  static const VaaniXAudioPolicy defaults = VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 60,
    volume: 0.85,
  );
}

/// Default per-event policy table. Edit here when adding a new event.
const Map<VaaniXAudioEvent, VaaniXAudioPolicy> kVaaniXAudioPolicies = {
  VaaniXAudioEvent.tap: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 40,
    volume: 0.55,
  ),
  VaaniXAudioEvent.correct: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 80,
    volume: 0.9,
  ),
  VaaniXAudioEvent.incorrect: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 80,
    volume: 0.75,
  ),
  VaaniXAudioEvent.xpGained: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 60,
    volume: 0.7,
  ),
  VaaniXAudioEvent.streakExtended: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 500,
    volume: 0.85,
  ),
  VaaniXAudioEvent.achievementUnlocked: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 1000,
    volume: 0.9,
  ),
  VaaniXAudioEvent.lessonComplete: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 1500,
    volume: 0.9,
  ),
  VaaniXAudioEvent.sessionComplete: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 2000,
    volume: 0.95,
  ),
  VaaniXAudioEvent.milestone: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 1500,
    volume: 0.9,
  ),
  VaaniXAudioEvent.vanHappy: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 200,
    volume: 0.7,
  ),
  VaaniXAudioEvent.vanCaring: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 200,
    volume: 0.7,
  ),
  VaaniXAudioEvent.vanThinking: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 250,
    volume: 0.55,
  ),
  VaaniXAudioEvent.vanCelebrate: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 800,
    volume: 0.85,
  ),
  VaaniXAudioEvent.vanSurprised: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 300,
    volume: 0.8,
  ),
  VaaniXAudioEvent.vanError: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 500,
    volume: 0.75,
  ),
  VaaniXAudioEvent.offline: VaaniXAudioPolicy(
    maxConcurrent: 1,
    minIntervalMs: 4000,
    volume: 0.6,
  ),
};
