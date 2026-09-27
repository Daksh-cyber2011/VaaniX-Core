/// Deterministic [AudioService] double for tests.
///
/// ## Why this exists
///
/// `JustAudioEngine` needs a real platform channel, which a `flutter_test`
/// run does not provide. Widget and integration tests still need to
/// exercise *real* playback state transitions — a mock that only records
/// "play() was called" would let a broken state machine pass.
///
/// So this fake models the actual lifecycle: a source loads, becomes
/// `playing`, advances a position on a controllable clock, completes, and
/// reports typed failures. Tests drive it explicitly rather than sleeping
/// on real audio.
///
/// ## Determinism
///
/// Time is injected. Call [advance] to move the playhead; nothing here
/// reads a wall clock, so a test can assert an exact position at any
/// point.
library;

import 'dart:async';

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_service.dart';

/// Scripted [AudioService] for tests.
class FakeAudioService implements AudioService {
  FakeAudioService({this.autoComplete = false});

  final _stateCtrl = StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _state = const AudioPlaybackState.idle();
  AudioSource? _loaded;
  bool _disposed = false;
  double _speed = 1.0;

  /// When true, [advance] to the end flips the state to `completed`
  /// automatically, like a real engine finishing a clip.
  final bool autoComplete;

  /// Resolver hook: return a failure to make the next `play` fail, or
  /// `null` to let it succeed.
  Object? failNextPlayWith;

  /// Optional duration reported when a source loads.
  Duration? defaultDuration;

  /// Every request passed to [play], in order. Lets a test assert that a
  /// fast A→B→A tap produced exactly the sources we expect.
  final List<AudioPlayRequest> playRequests = [];

  int seekCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  int setSpeedCount = 0;

  @override
  Stream<AudioPlaybackState> get state {
    if (_disposed) return const Stream<AudioPlaybackState>.empty();
    return _stateCtrl.stream;
  }

  @override
  AudioPlaybackState get current => _state;

  @override
  double get speed => _speed;

  @override
  Future<void> play(AudioPlayRequest request) async {
    if (_disposed) return;
    playCount++;
    playRequests.add(request);

    final injected = failNextPlayWith;
    if (injected != null) {
      failNextPlayWith = null;
      _loaded = null;
      _emit(AudioPlaybackState(
        status: AudioPlaybackStatus.error,
        source: request.source,
        failure: injected,
      ));
      return;
    }

    _loaded = request.source;
    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.loading,
      source: request.source,
    ));
    // A real engine's `setAudioSource` resolves with the duration, then
    // playback begins. Mirror that: loading → playing.
    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.playing,
      source: request.source,
      duration: defaultDuration,
      position: request.startAt ?? Duration.zero,
    ));
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    pauseCount++;
    if (_state.status != AudioPlaybackStatus.playing) return;
    _emit(_state.copyWith(status: AudioPlaybackStatus.paused));
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    resumeCount++;
    if (_state.status != AudioPlaybackStatus.paused) return;
    _emit(_state.copyWith(status: AudioPlaybackStatus.playing));
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    stopCount++;
    _loaded = null;
    _emit(const AudioPlaybackState.idle());
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    seekCount++;
    // Mirrors the real engine: seeking with nothing loaded is a no-op.
    if (_loaded == null) return;
    var target = position;
    final total = _state.duration;
    if (target < Duration.zero) target = Duration.zero;
    if (total != null && target > total) target = total;
    _emit(_state.copyWith(position: target));
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    setSpeedCount++;
    _speed = speed.clamp(0.5, 2.0);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    disposeCount++;
    _disposed = true;
    await _stateCtrl.close();
  }

  // ─── Test controls ───────────────────────────────────────────────────────

  /// Move the playhead forward by [delta] while playing.
  ///
  /// Only advances when the state is `playing`, exactly like a real
  /// engine whose position stream stops when paused.
  void advance(Duration delta) {
    if (_disposed) return;
    if (_state.status != AudioPlaybackStatus.playing) return;
    var next = _state.position + delta;
    final total = _state.duration;
    if (total != null && next >= total) {
      if (autoComplete) {
        _emit(_state.copyWith(
          status: AudioPlaybackStatus.completed,
          position: total,
        ));
        return;
      }
      next = total;
    }
    _emit(_state.copyWith(position: next));
  }

  /// Inject a failure without going through [play] — used to simulate an
  /// error arriving mid-playback.
  void emitFailure(Object failure) {
    if (_disposed) return;
    _loaded = null;
    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.error,
      source: _state.source,
      failure: failure,
    ));
  }

  bool get isDisposed => _disposed;

  void _emit(AudioPlaybackState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }
}

/// Provider-friendly factory for overriding `audioServiceProvider`.
///
/// ```dart
/// ProviderScope(
///   overrides: [fakeAudioServiceProvider()],
///   child: const MyTest(),
/// )
/// ```
FakeAudioService fakeAudioService({bool autoComplete = false}) =>
    FakeAudioService(autoComplete: autoComplete);
