/// VaaniX Audio — provider wiring.
///
/// Single import surface for the audio feature:
///
/// ```dart
/// import 'package:vaanix_app/core/audio/audio_providers.dart';
/// ```
///
/// ## Lifetime
///
/// `audioServiceProvider` is a `Provider` (not `autoDispose`) on purpose.
/// Pronunciation clips are short, but a learner tapping play across two
/// screens should not have the engine torn down and rebuilt in between —
/// that would drop a playing clip mid-word. The container (not the widget
/// tree) owns the engine's lifetime.
///
/// ## Testing
///
/// Override `audioServiceProvider` with `fakeAudioServiceProvider` in a
/// test to run without a platform channel. See
/// `test/support/fake_audio_service.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_service.dart';
import 'package:vaanix_app/core/audio/audio_source_resolver.dart';
import 'package:vaanix_app/core/audio/just_audio_engine.dart';
import 'package:vaanix_app/core/network/connectivity_service.dart';

/// Source validation, wired to the app's real connectivity signal so a
/// remote clip is never promised while offline.
final audioSourceResolverProvider = Provider<AudioSourceResolver>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return AudioSourceResolver(
    isOnline: () => connectivity.isOnline,
  );
});

/// The single [AudioService] for the whole app.
///
/// Every screen reads this; nobody constructs an engine directly.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = JustAudioEngine(
    resolver: ref.watch(audioSourceResolverProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive playback state. Rebuilds on every state transition, so a
/// waveform can bind progress without polling.
final audioPlaybackStateProvider = StreamProvider<AudioPlaybackState>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.state;
});

/// Convenience accessor for code that only needs the latest snapshot
/// (e.g. deciding which icon to paint on first frame).
final audioCurrentStateProvider = Provider<AudioPlaybackState>((ref) {
  return ref.watch(audioServiceProvider).current;
});
