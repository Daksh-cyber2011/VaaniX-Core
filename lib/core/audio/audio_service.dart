/// VaaniX Audio — the provider-agnostic service contract.
///
/// ## The one rule
///
/// UI and Learn code depend on *this* interface, never on `just_audio`,
/// `audioplayers`, or any other engine package. The engine lives behind
/// [AudioService] and is swappable in exactly one place
/// (`audio_providers.dart`) without touching a single screen.
///
/// ## Concurrency contract
///
/// Implementations must guarantee all of the following, because learners
/// tap play fast and the UI must never end up with two players running:
///
///   1. `play()` for a different source while something is playing
///      replaces the current item — it does not layer on top of it.
///   2. `play()` for the *same* source while playing is idempotent.
///   3. Every method is safe to call after `dispose()`; it resolves
///      without throwing and performs no work.
///   4. No events are emitted after `dispose()`.
///   5. `play()` for an unsupportable source transitions to
///      [AudioPlaybackStatus.error] with a typed failure and does *not*
///      silently no-op — a lesson must never claim audio played when it
///      did not.
library;

import 'dart:async';

import 'package:vaanix_app/core/audio/audio_models.dart';

/// Real audio playback.
///
/// Obtained from `audioServiceProvider`. See
/// `lib/core/audio/just_audio_engine.dart` for the production
/// implementation and `test/support/fake_audio_engine.dart` for a
/// deterministic test double.
abstract interface class AudioService {
  /// Playback lifecycle snapshots. Broadcast: multiple listeners allowed.
  ///
  /// Emits an initial [AudioPlaybackState.idle] on subscribe.
  Stream<AudioPlaybackState> get state;

  /// The most recent snapshot, for late subscribers that want to render
  /// the correct button state on their first frame.
  AudioPlaybackState get current;

  /// Load and start [request], replacing whatever is currently playing.
  ///
  /// Returns when playback has *started* (not when it finishes). Throws
  /// nothing: failures are delivered through [state] as
  /// [AudioPlaybackStatus.error] with a typed [AudioPlaybackState.failure].
  /// [current] is updated synchronously, so a caller that never listens
  /// to [state] can still poll [current] and see the outcome.
  Future<void> play(AudioPlayRequest request);

  /// Pause, keeping the loaded source and position so [resume] can
  /// continue. No-op when idle or already paused.
  Future<void> pause();

  /// Continue from the paused position. No-op when not paused.
  Future<void> resume();

  /// Stop and release the loaded source, returning to
  /// [AudioPlaybackStatus.idle]. Position is discarded — use [seek] before
  /// a stop if the offset matters.
  Future<void> stop();

  /// Jump to [position] within the loaded source.
  ///
  /// Clamped to `0..duration`. A no-op when idle (nothing is loaded to
  /// seek within).
  Future<void> seek(Duration position);

  /// Playback speed multiplier. `1.0` is normal speed.
  ///
  /// Persists across [play] calls for the same source, which is what
  /// learners expect from the 0.75x / 1.0x / 1.25x control.
  Future<void> setSpeed(double speed);

  /// The speed currently applied.
  double get speed;

  /// Release the engine and every underlying resource.
  ///
  /// Idempotent. After this, [state] is closed and all other methods are
  /// safe no-ops.
  Future<void> dispose();
}
