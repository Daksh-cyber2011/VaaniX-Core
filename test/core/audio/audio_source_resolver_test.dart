/// Audio source resolution + playback-state model tests.
///
/// Pure Dart — no platform channel, no engine. These pin the two pieces
/// of logic that decide whether a clip is *allowed* to play and what the
/// UI renders, independently of `just_audio`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_source_resolver.dart';
import 'package:vaanix_app/core/errors/failures.dart';

void main() {
  group('AudioSource — determinism', () {
    test('asset key is derived from the path', () {
      const a = AudioSource.asset('assets/audio/hi/a.mp3');
      expect(a.deterministicKey, 'asset:assets/audio/hi/a.mp3');
    });

    test('same input yields the same key (cache-safe)', () {
      const a = AudioSource.asset('assets/audio/hi/a.mp3');
      const b = AudioSource.asset('assets/audio/hi/a.mp3');
      expect(a.deterministicKey, b.deterministicKey);
    });

    test('explicit cacheKey overrides the derived key', () {
      const a = AudioSource.asset('assets/audio/x.mp3', cacheKey: 'greeting-1');
      expect(a.deterministicKey, 'greeting-1');
    });

    test('empty explicit cacheKey falls back to the derived key', () {
      const a = AudioSource.asset('assets/audio/x.mp3', cacheKey: '');
      expect(a.deterministicKey, 'asset:assets/audio/x.mp3');
    });

    test('only assets are offline-capable', () {
      expect(
        const AudioSource.asset('assets/a.mp3').isOfflineCapable,
        isTrue,
      );
      expect(
        const AudioSource.remote('https://cdn.example/a.mp3').isOfflineCapable,
        isFalse,
      );
      expect(const AudioSource.tts('namaste').isOfflineCapable, isFalse);
    });
  });

  group('AudioSourceResolver — assets', () {
    const resolver = AudioSourceResolver();

    test('resolves a well-formed asset path', () async {
      const src = AudioSource.asset('assets/audio/hi/a.mp3');
      final result = await resolver.resolve(src);
      expect(result, isA<AudioSourceResolved>());
      expect((result as AudioSourceResolved).uri.path,
          'assets/audio/hi/a.mp3');
    });

    test('rejects an empty path', () async {
      final result = await resolver.resolve(const AudioSource.asset(''));
      expect(result, isA<AudioSourceInvalid>());
    });

    test('rejects a path outside assets/', () async {
      final result =
          await resolver.resolve(const AudioSource.asset('../etc/passwd'));
      expect(result, isA<AudioSourceInvalid>());
      expect(
        (result as AudioSourceInvalid).reason,
        contains('assets/'),
      );
    });

    test('assets need no connectivity probe', () async {
      // Probe always says offline; a bundled asset must still resolve.
      const offlineResolver = AudioSourceResolver(isOnline: _alwaysOffline);
      final result = await offlineResolver
          .resolve(const AudioSource.asset('assets/audio/a.mp3'));
      expect(result, isA<AudioSourceResolved>(),
          reason: 'a bundled asset is offline-capable and must not be '
              'blocked by a connectivity check');
    });
  });

  group('AudioSourceResolver — remote', () {
    test('resolves a valid https URL when online', () async {
      const resolver = AudioSourceResolver(isOnline: _alwaysOnline);
      final result = await resolver
          .resolve(const AudioSource.remote('https://cdn.example/a.mp3'));
      expect(result, isA<AudioSourceResolved>());
    });

    test('refuses remote audio while offline (honest unavailable)', () async {
      const resolver = AudioSourceResolver(isOnline: _alwaysOffline);
      final result = await resolver
          .resolve(const AudioSource.remote('https://cdn.example/a.mp3'));
      expect(result, isA<AudioSourceInvalid>());
      expect(
        (result as AudioSourceInvalid).reason,
        contains('offline'),
        reason: 'the message must tell the truth: not cached, needs network',
      );
    });

    test('rejects an unsupported scheme', () async {
      const resolver = AudioSourceResolver();
      final result = await resolver
          .resolve(const AudioSource.remote('ftp://example.com/a.mp3'));
      expect(result, isA<AudioSourceInvalid>());
      expect((result as AudioSourceInvalid).reason, contains('scheme'));
    });

    test('rejects a malformed URL', () async {
      const resolver = AudioSourceResolver();
      final result = await resolver.resolve(const AudioSource.remote('http://'));
      expect(result, isA<AudioSourceInvalid>());
    });

    test('rejects an empty URL', () async {
      const resolver = AudioSourceResolver();
      final result = await resolver.resolve(const AudioSource.remote('  '));
      expect(result, isA<AudioSourceInvalid>());
    });

    test('blocks localhost / LAN targets (SSRF hardening)', () async {
      const resolver = AudioSourceResolver();
      for (final url in [
        'https://localhost/a.mp3',
        'https://127.0.0.1/a.mp3',
        'https://10.0.2.2/a.mp3',
      ]) {
        final result = await resolver.resolve(AudioSource.remote(url));
        expect(result, isA<AudioSourceInvalid>(), reason: 'must block $url');
      }
    });
  });

  group('AudioSourceResolver — TTS', () {
    test('reports unavailable rather than pretending to speak', () async {
      const resolver = AudioSourceResolver();
      final result = await resolver.resolve(const AudioSource.tts('namaste'));
      expect(result, isA<AudioSourceUnavailable>(),
          reason: 'VaaniX ships no TTS engine; the resolver must say so '
              'instead of silently no-oping or pretending to speak');
    });
  });

  group('AudioPlaybackState', () {
    test('idle has zero position and no duration', () {
      const s = AudioPlaybackState.idle();
      expect(s.status, AudioPlaybackStatus.idle);
      expect(s.position, Duration.zero);
      expect(s.duration, isNull);
      expect(s.progress, isNull);
    });

    test('progress is null when duration is unknown', () {
      const s = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration(seconds: 2),
      );
      expect(s.progress, isNull,
          reason: 'an unknown duration must not produce a fake ratio');
    });

    test('progress is the real position ratio', () {
      const s = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration(milliseconds: 2500),
        duration: Duration(seconds: 10),
      );
      expect(s.progress, closeTo(0.25, 1e-9));
    });

    test('progress clamps to 0..1', () {
      const s = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration(seconds: 30),
        duration: Duration(seconds: 10),
      );
      expect(s.progress, 1.0);
    });

    test('zero duration yields null progress, not a division by zero', () {
      const s = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration.zero,
        duration: Duration.zero,
      );
      expect(s.progress, isNull);
    });

    test('status helpers reflect the enum', () {
      const playing = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
      );
      const paused = AudioPlaybackState(
        status: AudioPlaybackStatus.paused,
      );
      const loading = AudioPlaybackState(
        status: AudioPlaybackStatus.loading,
      );
      expect(playing.isPlaying, isTrue);
      expect(playing.isPaused, isFalse);
      expect(paused.isPaused, isTrue);
      expect(loading.isBusy, isTrue);
    });

    test('equality ignores nothing — two identical snapshots compare equal',
        () {
      const a = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration(seconds: 1),
        duration: Duration(seconds: 4),
      );
      const b = AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        position: Duration(seconds: 1),
        duration: Duration(seconds: 4),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('audio failures are canonical VaaniX failures', () {
    test('each audio failure carries a distinct stable code', () {
      expect(const AudioSourceFailure().code, 'AUDIO_SOURCE');
      expect(const AudioNetworkFailure().code, 'AUDIO_NETWORK');
      expect(const AudioOfflineFailure().code, 'AUDIO_OFFLINE');
      expect(const AudioPlaybackFailure().code, 'AUDIO_PLAYBACK');
      expect(const AudioUnavailableFailure().code, 'AUDIO_UNAVAILABLE');
    });

    test('audio failures are all Failure instances', () {
      const all = <Failure>[
        AudioSourceFailure(),
        AudioNetworkFailure(),
        AudioOfflineFailure(),
        AudioPlaybackFailure(),
        AudioUnavailableFailure(),
      ];
      for (final f in all) {
        expect(f, isA<Failure>());
        expect(f.code, isNotEmpty);
      }
    });
  });
}

Future<bool> _alwaysOnline() async => true;
Future<bool> _alwaysOffline() async => false;
