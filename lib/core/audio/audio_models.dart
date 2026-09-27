/// VaaniX Audio — source and playback-state domain models.
///
/// Pure Dart. No Flutter, no `just_audio`, no platform imports. This is
/// the vocabulary the rest of the app speaks; only
/// `JustAudioEngine` knows what an `AudioPlayer` is.
///
/// The two existing abstractions this file is built to preserve:
///
///   * `AudioSourceKind` mirrors the three *policies* already declared in
///     `VaanixAudioEvent` (`guideTts`, `referenceAudio`, `prerecorded`).
///     We keep that taxonomy rather than inventing a parallel one.
///   * Playback state uses the project's canonical `Failure` types so
///     errors flow into existing UI error handling untouched.
library;

/// Where the audio bytes come from.
///
/// The source is resolved to a concrete URI by [resolve] before it
/// reaches the engine, so consumers never hand-construct engine input.
enum AudioSourceKind {
  /// Text-to-speech produced by the platform (guide narration).
  ///
  /// NOTE: VaaniX does not currently ship a TTS engine. This kind is
  /// declared because [VaanixAudioEvent] already models the policy, and
  /// so a TTS-backed engine can be added later without changing the
  /// vocabulary. Passing it to [resolve] currently yields an
  /// [AudioSourceResolution.unavailable] rather than silently
  /// pretending to speak.
  tts,

  /// A file bundled in the APK (`assetPath`), e.g. `assets/audio/hi/a.mp3`.
  ///
  /// Always available offline — this is the only source that can be.
  asset,

  /// A remote file fetched over HTTPS/HTTP.
  ///
  /// [url] may carry a query string, so a signed-URL backend can serve
  /// authenticated audio without the engine ever seeing a credential.
  remote,
}

/// A single addressable piece of audio.
///
/// Construct with the named constructors rather than the raw constructor
/// so an [AudioSource] can never be built in an inconsistent state.
class AudioSource {
  /// A file bundled inside the app. Plays offline.
  const AudioSource.asset(this.assetPath, {this.cacheKey})
      : kind = AudioSourceKind.asset,
        url = null;

  /// A remote file. Requires network access and is *not* offline-capable
  /// unless the engine has cached it.
  const AudioSource.remote(this.url, {this.cacheKey})
      : kind = AudioSourceKind.remote,
        assetPath = null;

  /// Platform text-to-speech. Not yet backed by an engine in VaaniX.
  const AudioSource.tts(String text, {this.cacheKey})
      : kind = AudioSourceKind.tts,
        url = text,
        assetPath = null;

  final AudioSourceKind kind;

  /// Asset-relative path, set only when [kind] is [AudioSourceKind.asset].
  final String? assetPath;

  /// The remote URL, or the spoken text for [AudioSourceKind.tts].
  final String? url;

  /// Optional caller-supplied cache identity. When omitted the engine
  /// derives a deterministic key from the source itself.
  final String? cacheKey;

  /// True when this source can be played with no network at all.
  bool get isOfflineCapable => kind == AudioSourceKind.asset;

  /// Deterministic, non-secret cache key.
  ///
  /// The remote URL is included verbatim, which is safe for a local key
  /// but means callers must NOT pass a URL containing a query-string
  /// credential if they care about the key leaking to disk. See
  /// `docs/BUILD/Audio.md` §Caching.
  String get deterministicKey {
    final explicit = cacheKey;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return switch (kind) {
      AudioSourceKind.asset => 'asset:${assetPath ?? ''}',
      AudioSourceKind.remote => 'remote:${url ?? ''}',
      AudioSourceKind.tts => 'tts:${url ?? ''}',
    };
  }

  @override
  String toString() => 'AudioSource(${kind.name}, key: $deterministicKey)';
}

/// Outcome of validating/normalising a source before playback.
///
/// The point of this type is that an unsupported source is an explicit,
/// *typed* answer rather than a null that a caller might ignore and then
/// pretend succeeded.
sealed class AudioSourceResolution {
  const AudioSourceResolution();
}

/// The source is playable. [uri] is what the engine loads.
class AudioSourceResolved extends AudioSourceResolution {
  const AudioSourceResolved(this.uri, this.source);
  final Uri uri;
  final AudioSource source;
}

/// The source is understood but this build cannot play it (e.g. TTS with
/// no TTS engine installed).
class AudioSourceUnavailable extends AudioSourceResolution {
  const AudioSourceUnavailable(this.reason);
  final String reason;
}

/// The source is malformed.
class AudioSourceInvalid extends AudioSourceResolution {
  const AudioSourceInvalid(this.reason);
  final String reason;
}

/// Lifecycle of a single playback attempt.
///
/// Deliberately *not* a copy of any engine enum: the engine maps its own
/// states into these, so swapping the engine cannot ripple into UI.
enum AudioPlaybackStatus {
  /// Nothing loaded, or fully released.
  idle,

  /// Source is being resolved / buffered.
  loading,

  /// Audio is advancing. [AudioPlaybackState.position] is live.
  playing,

  /// Loaded and positioned, but not advancing.
  paused,

  /// Reached the end of the track. Terminal until the next play/stop.
  completed,

  /// Playback failed. [AudioPlaybackState.failure] carries the reason.
  error,
}

/// An immutable snapshot of playback.
///
/// Emitted on [AudioService.state]. The position advances from the real
/// engine clock — there is no local timer anywhere in this pipeline.
class AudioPlaybackState {
  const AudioPlaybackState({
    required this.status,
    this.position = Duration.zero,
    this.duration,
    this.source,
    this.failure,
  });

  const AudioPlaybackState.idle()
      : status = AudioPlaybackStatus.idle,
        position = Duration.zero,
        duration = null,
        source = null,
        failure = null;

  final AudioPlaybackStatus status;

  /// Current playhead. Real engine time, not a simulated counter.
  final Duration position;

  /// Total length once known. `null` while still resolving, and for live
  /// streams that never report one.
  final Duration? duration;

  /// The source this state describes, or `null` when idle.
  final AudioSource? source;

  /// Set only when [status] is [AudioPlaybackStatus.error].
  final Object? failure;

  bool get isPlaying => status == AudioPlaybackStatus.playing;
  bool get isPaused => status == AudioPlaybackStatus.paused;
  bool get isBusy => status == AudioPlaybackStatus.loading;

  /// Progress in `0.0..1.0`, or `null` when the duration is unknown.
  /// The waveform uses this instead of a synthetic animation.
  double? get progress {
    final total = duration;
    if (total == null || total.inMilliseconds <= 0) return null;
    final ratio = position.inMilliseconds / total.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  AudioPlaybackState copyWith({
    AudioPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    AudioSource? source,
    Object? failure,
    bool clearFailure = false,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      source: source ?? this.source,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioPlaybackState &&
      other.status == status &&
      other.position == position &&
      other.duration == duration &&
      identical(other.source, source) &&
      identical(other.failure, failure);

  @override
  int get hashCode => Object.hash(status, position, duration, source, failure);

  @override
  String toString() => 'AudioPlaybackState(${status.name}, '
      'pos: ${position.inMilliseconds}ms, '
      'dur: ${duration?.inMilliseconds}ms, '
      'source: ${source?.deterministicKey ?? 'none'})';
}

/// How playback should behave relative to other audio in the app.
enum AudioDuckingPolicy {
  /// No special handling. Used for short SFX.
  normal,

  /// Lower other audio while this plays. Used for pronunciation clips so
  /// the learner hears the word clearly over background music.
  duckOthers,
}

/// A playback request.
///
/// Bundling the source and the policy means a caller cannot start a clip
/// and then race a separate `setDucking` call against it.
class AudioPlayRequest {
  const AudioPlayRequest({
    required this.source,
    this.ducking = AudioDuckingPolicy.normal,
    this.startAt,
  });

  final AudioSource source;
  final AudioDuckingPolicy ducking;

  /// Optional initial position, for resuming a lesson at a known offset.
  final Duration? startAt;

  @override
  String toString() => 'AudioPlayRequest($source, $ducking)';
}
