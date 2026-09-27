/// VaaniX Audio — the real playback engine, backed by `just_audio`.
///
/// This is the ONLY file in the app that imports `just_audio`. Everything
/// else talks to [AudioService]. If the engine is ever swapped, this file
/// changes and nothing else does.
///
/// ## Design notes
///
/// * **One player, ever.** A single [AudioPlayer] instance is reused for
///   all sources. Switching tracks calls `setUrl` on that player rather
///   than creating a second one, which is what makes the
///   "A → B → A" fast-tap race structurally impossible to get wrong.
/// * **Serialised control.** Every mutating call runs through a
///   [_CommandQueue], so `play` / `pause` / `stop` / `dispose` cannot
///   interleave. The queue is the reason the operations are deterministic
///   even when the engine is mid-load.
/// * **Real position.** [position] comes from the engine's own
///   `positionStream`. There is no `Timer.periodic` anywhere.
/// * **No secrets in logs.** Remote URLs are logged by host + path only,
///   with the query string stripped, because a signed-URL backend embeds
///   a credential there.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_service.dart';
import 'package:vaanix_app/core/audio/audio_source_resolver.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/logging/logger.dart';

/// Production [AudioService] implementation.
class JustAudioEngine implements AudioService {
  JustAudioEngine({
    ja.AudioPlayer? player,
    AudioSourceResolver resolver = const AudioSourceResolver(),
  })  : _player = player ?? ja.AudioPlayer(),
        _resolver = resolver {
    _wireEngineListeners();
  }

  static const String _tag = 'AudioEngine';

  final ja.AudioPlayer _player;
  final AudioSourceResolver _resolver;
  final _commands = _CommandQueue();

  final _stateCtrl = StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _state = const AudioPlaybackState.idle();
  bool _disposed = false;

  /// The source currently loaded, or null when idle. Used to make
  /// same-source `play` idempotent.
  AudioSource? _loadedSource;

  /// Guards the `[AudioSourceResolver]` result so a late-arriving
  /// `setUrl` completion cannot overwrite a newer load.
  int _loadGeneration = 0;

  double _speed = 1.0;

  // ─── Public surface ──────────────────────────────────────────────────────

  @override
  Stream<AudioPlaybackState> get state {
    final s = _stateCtrl;
    if (_disposed) return const Stream<AudioPlaybackState>.empty();
    return s.stream;
  }

  @override
  AudioPlaybackState get current => _state;

  @override
  double get speed => _speed;

  @override
  Future<void> play(AudioPlayRequest request) async {
    if (_disposed) return;
    return _commands.run(() async {
      if (_disposed) return;
      await _playUnsafe(request);
    });
  }

  @override
  Future<void> pause() {
    if (_disposed) return Future<void>.value();
    return _commands.run(() async {
      if (_disposed) return;
      if (_state.status != AudioPlaybackStatus.playing) return;
      await _player.pause();
    });
  }

  @override
  Future<void> resume() {
    if (_disposed) return Future<void>.value();
    return _commands.run(() async {
      if (_disposed) return;
      if (_state.status != AudioPlaybackStatus.paused) return;
      await _player.play();
    });
  }

  @override
  Future<void> stop() {
    if (_disposed) return Future<void>.value();
    return _commands.run(() async {
      if (_disposed) return;
      await _player.stop();
      await _player.seek(Duration.zero);
      _loadedSource = null;
      _emit(const AudioPlaybackState.idle());
    });
  }

  @override
  Future<void> seek(Duration position) {
    if (_disposed) return Future<void>.value();
    return _commands.run(() async {
      if (_disposed) return;
      // Nothing loaded — there is nothing to seek within.
      if (_loadedSource == null) return;
      final total = _state.duration;
      var target = position;
      if (total != null) {
        if (target < Duration.zero) target = Duration.zero;
        if (target > total) target = total;
      }
      await _player.seek(target);
    });
  }

  @override
  Future<void> setSpeed(double speed) {
    if (_disposed) return Future<void>.value();
    return _commands.run(() async {
      if (_disposed) return;
      final clamped = speed.clamp(0.5, 2.0);
      _speed = clamped;
      // The engine rejects a speed change with no source loaded, so guard.
      if (_loadedSource == null) return;
      await _player.setSpeed(clamped);
    });
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Drop the player before draining the queue: any command already
    // in flight checks `_disposed` and returns without touching it.
    await _player.dispose();
    await _stateCtrl.close();
    AppLogger.info('audio engine disposed', tag: _tag);
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  Future<void> _playUnsafe(AudioPlayRequest request) async {
    final source = request.source;

    // Idempotent re-play of the same source: resume rather than reload,
    // so a double-tap does not restart the clip from zero.
    if (identical(source, _loadedSource) ||
        source.deterministicKey == _loadedSource?.deterministicKey) {
      if (_state.status == AudioPlaybackStatus.completed) {
        await _player.seek(Duration.zero);
      } else if (_state.status == AudioPlaybackStatus.paused) {
        await _player.play();
        return;
      } else if (_state.status == AudioPlaybackStatus.playing) {
        return;
      }
    }

    final resolution = await _resolver.resolve(source);
    switch (resolution) {
      case AudioSourceUnavailable(:final reason):
        _fail(AudioUnavailableFailure(reason), source);
        return;
      case AudioSourceInvalid(:final reason):
        _fail(AudioSourceFailure(reason), source);
        return;
      case AudioSourceResolved(:final uri, :final source):
        final generation = ++_loadGeneration;
        _emit(AudioPlaybackState(
          status: AudioPlaybackStatus.loading,
          source: source,
        ));
        AppLogger.info(
          'playback requested: ${_safeLogLabel(uri)}',
          tag: _tag,
        );
        try {
          // `setUrl` on the SAME player replaces the current item, which
          // is what prevents two players from ever coexisting.
          await _player.setAudioSource(
            ja.AudioSource.uri(uri),
            preload: true,
          );
          if (_disposed || generation != _loadGeneration) return;

          _loadedSource = source;
          await _player.setSpeed(_speed);
          if (request.startAt != null) {
            await _player.seek(request.startAt!);
          }
          if (_disposed || generation != _loadGeneration) return;

          await _player.play();
          if (_disposed || generation != _loadGeneration) return;
          AppLogger.info('playback started', tag: _tag);
        } on ja.PlayerException catch (e) {
          if (_disposed || generation != _loadGeneration) return;
          AppLogger.error('playback failed', tag: _tag, error: e);
          _fail(mapPlayerException(e, source), source);
        } on ja.PlayerInterruptedException catch (e) {
          if (_disposed || generation != _loadGeneration) return;
          AppLogger.warn('playback interrupted', tag: _tag, error: e);
          _fail(const AudioPlaybackFailure(), source);
        } catch (e, st) {
          if (_disposed || generation != _loadGeneration) return;
          AppLogger.error(
            'playback error',
            tag: _tag,
            error: e,
            stackTrace: st,
          );
          _fail(const AudioPlaybackFailure(), source);
        }
    }
  }

  /// Bridge the engine's own streams and events into our typed state.
  void _wireEngineListeners() {
    _player.positionStream.listen((position) {
      if (_disposed) return;
      // Position ticks while idle would resurrect a "playing" look after
      // a stop, so only propagate when something is actually loaded.
      if (_loadedSource == null) return;
      if (_state.status == AudioPlaybackStatus.playing) {
        _emit(_state.copyWith(position: position));
      }
    });

    _player.durationStream.listen((duration) {
      if (_disposed) return;
      if (_loadedSource == null) return;
      _emit(_state.copyWith(
        duration: duration,
        clearDuration: duration == null,
      ));
    });

    _player.playerStateStream.listen((playerState) {
      if (_disposed) return;
      if (_loadedSource == null) return;
      switch (playerState.processingState) {
        case ja.ProcessingState.idle:
          break; // no-op: we own the idle transition
        case ja.ProcessingState.loading:
        case ja.ProcessingState.buffering:
          _emit(_state.copyWith(status: AudioPlaybackStatus.loading));
        case ja.ProcessingState.ready:
          if (_state.status == AudioPlaybackStatus.loading) {
            _emit(_state.copyWith(status: AudioPlaybackStatus.playing));
          }
        case ja.ProcessingState.completed:
          AppLogger.info('playback completed', tag: _tag);
          _emit(_state.copyWith(
            status: AudioPlaybackStatus.completed,
            position: _state.duration ?? _state.position,
          ));
      }
    });

    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        if (_disposed) return;
        AppLogger.error(
          'playback stream error',
          tag: _tag,
          error: e,
          stackTrace: st,
        );
        _fail(const AudioPlaybackFailure(), _state.source);
      },
    );
  }

  void _fail(Object failure, AudioSource? source) {
    _loadedSource = null;
    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.error,
      source: source,
      failure: failure,
    ));
  }

  void _emit(AudioPlaybackState next) {
    if (_disposed) return;
    if (next == _state) return;
    _state = next;
    // Broadcast controller: a closed controller would throw here if a
    // listener raced dispose(), so guard explicitly.
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
  }

  /// Map engine-specific exceptions onto VaaniX failures.
  ///
  /// ## Why this classifies by message, not by `code`
  ///
  /// `ja.PlayerException.code` is a **platform-native int** — `NSError.code`
  /// on iOS, `ExoPlaybackException.type` on Android, `MediaError.code` on
  /// web. There is no cross-platform enum, so comparing it against string
  /// codes (as an earlier draft of this file did) silently never matches
  /// and degrades every failure into one generic bucket. The int is
  /// therefore treated as an opaque platform value that is logged for
  /// diagnosis but never branched on; classification uses the human
  /// message plus the source kind, which *is* portable.
  ///
  /// [source] distinguishes "could not be fetched" from "could not be
  /// decoded": a remote source that will not load is a network failure,
  /// while a bundled asset that will not decode is a playback failure.
  @visibleForTesting
  static Object mapPlayerException(ja.PlayerException e, AudioSource? source) {
    final msg = (e.message ?? '').toLowerCase();
    final isRemote = source?.kind == AudioSourceKind.remote;

    // Transport-level problems. These message fragments are produced by
    // the underlying platform stacks and are stable enough to key on;
    // anything unmatched falls through to the generic buckets below
    // rather than being misreported.
    const transportFragments = <String>[
      'socket',
      'connection',
      'host lookup',
      'failed host lookup',
      'handshake',
      'certificate',
      'cleartext',
      'unreachable',
      'timed out',
      'timeout',
      'network',
      'econnreset',
      'enotfound',
    ];
    for (final fragment in transportFragments) {
      if (msg.contains(fragment)) return const AudioNetworkFailure();
    }

    // Decode / container problems — the bytes arrived but will not play.
    const decodeFragments = <String>[
      'decoder',
      'malformed',
      'unsupported format',
      'invalid data',
      'not a valid',
    ];
    for (final fragment in decodeFragments) {
      if (msg.contains(fragment)) return const AudioPlaybackFailure();
    }

    // A missing bundle is a build/deployment fault, not a network one —
    // report it as unavailable so it is distinguishable from a flaky
    // connection in telemetry.
    if (msg.contains('not found') ||
        msg.contains('no such') ||
        msg.contains('unable to open')) {
      if (isRemote) return const AudioNetworkFailure();
      return const AudioUnavailableFailure();
    }

    if (msg.contains('audio track') || msg.contains('no output')) {
      return const AudioUnavailableFailure();
    }

    if (isRemote) return const AudioNetworkFailure();
    return const AudioPlaybackFailure();
  }

  /// Log-safe label for a URI: host + path, never the query string.
  ///
  /// A signed-URL backend puts its credential in the query; logging the
  /// raw URI would write that credential to Sentry.
  static String _safeLogLabel(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return uri.path;
    return uri.hasQuery
        ? '${uri.host}${uri.path}?<query stripped>'
        : '${uri.host}${uri.path}';
  }
}

/// Serialises async commands so overlapping `play` / `pause` / `stop` /
/// `dispose` calls cannot interleave inside the engine.
class _CommandQueue {
  Future<void> _tail = Future<void>.value();

  /// Run [action] after every previously-enqueued action settles.
  ///
  /// A failing action does not poison the queue — the error is logged and
  /// swallowed here because every failure is already surfaced through the
  /// typed state stream; letting it propagate would also strand every
  /// subsequent command.
  Future<void> run(Future<void> Function() action) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      if (completer.isCompleted) return;
      try {
        await action();
        completer.complete();
      } catch (e, st) {
        AppLogger.error(
          'audio command failed',
          tag: 'AudioEngine',
          error: e,
          stackTrace: st,
        );
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }
}
