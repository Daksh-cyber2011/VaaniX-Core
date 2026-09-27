/// VaaniX Audio — source validation and normalisation.
///
/// Separating this from the engine means "can this source even be
/// played?" is answerable without touching `just_audio`, and it is
/// unit-testable on its own.
///
/// The resolver also enforces the offline rule: a remote source is never
/// silently promised as playable when the device has no network. It
/// reports [AudioSourceResolved] only when the bytes are reachable, and
/// otherwise returns a typed answer the UI can render honestly.
library;

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/logging/logger.dart';

/// Validates and normalises an [AudioSource] into a loadable [Uri].
class AudioSourceResolver {
  const AudioSourceResolver({this.isOnline});
  static const String _tag = 'AudioSource';

  /// Optional connectivity probe. `null` means "assume online" — the
  /// caller has no connectivity signal, so we do not block playback on a
  /// guess.
  final Future<bool> Function()? isOnline;

  /// Hosts we refuse to load. Local addresses can reach a developer
  /// machine or a private subnet; for a shipped learner build these are
  /// never legitimate audio origins, and allowing them would let a
  /// server-provided URL probe the user's LAN.
  static const Set<String> _blockedHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
    '10.0.2.2', // Android emulator alias for the host machine
  };

  /// Resolve [source] to something the engine can load.
  ///
  /// Async because a remote source consults the connectivity probe before
  /// committing to being playable.
  Future<AudioSourceResolution> resolve(AudioSource source) async {
    switch (source.kind) {
      case AudioSourceKind.tts:
        return const AudioSourceUnavailable(
          'Text-to-speech is not available in this build.',
        );

      case AudioSourceKind.asset:
        return _resolveAsset(source);

      case AudioSourceKind.remote:
        return _resolveRemote(source);
    }
  }

  AudioSourceResolution _resolveAsset(AudioSource source) {
    final path = source.assetPath;
    if (path == null || path.trim().isEmpty) {
      return const AudioSourceInvalid('Asset path is empty.');
    }
    final trimmed = path.trim();
    if (!trimmed.startsWith('assets/')) {
      return AudioSourceInvalid(
        'Asset path must be under "assets/", got "$trimmed".',
      );
    }
    return AudioSourceResolved(Uri.parse(trimmed), source);
  }

  Future<AudioSourceResolution> _resolveRemote(AudioSource source) async {
    final raw = source.url;
    if (raw == null || raw.trim().isEmpty) {
      return const AudioSourceInvalid('Remote URL is empty.');
    }
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      return const AudioSourceInvalid('Remote URL is malformed.');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return AudioSourceInvalid(
        'Unsupported URL scheme "${uri.scheme}". '
        'Use https (or http for local development).',
      );
    }
    if (uri.host.isEmpty) {
      return const AudioSourceInvalid('Remote URL has no host.');
    }
    if (_blockedHosts.contains(uri.host.toLowerCase())) {
      AppLogger.warn('blocked audio host: ${uri.host}', tag: _tag);
      return AudioSourceInvalid(
        'Refusing to load audio from "${uri.host}".',
      );
    }

    // Offline honesty: a remote source with no network is an explicit
    // unavailable answer, never a promise that fails later.
    final probe = isOnline;
    if (probe != null) {
      final online = await probe();
      if (!online) {
        return const AudioSourceInvalid(
          'This audio needs a connection and is not cached for offline use.',
        );
      }
    }

    return AudioSourceResolved(uri, source);
  }
}
