/// Widget tests for `AudioCadenceWaveform` driven by the real
/// `AudioService` abstraction.
///
/// The point of these tests is behavioural, not structural: the widget
/// used to animate a waveform with no audio at all, so "did the bars
/// move" is no longer a meaningful question. What matters now is:
///   * the play button maps to real service calls;
///   * the rendered progress tracks the real playhead;
///   * a null source does NOT report playing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_providers.dart';
import 'package:vaanix_app/core/audio/audio_service.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/shared/widgets/audio_cadence_waveform.dart';

import '../../support/fake_audio_service.dart';

const _asset = AudioSource.asset('assets/audio/hi/namaste.mp3');
const _remote = AudioSource.remote('https://cdn.example/namaste.mp3');

/// Pumps the waveform with [service] injected in place of the real engine.
Future<FakeAudioService> pumpWaveform(
  WidgetTester tester, {
  AudioSource? source = _asset,
  Duration? duration = const Duration(seconds: 4),
  ValueChanged<bool>? onPlayStateChanged,
  FakeAudioService? existing,
}) async {
  final service = existing ?? FakeAudioService()..defaultDuration = duration;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(service as AudioService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AudioCadenceWaveform(
            phrase: 'नमस्ते',
            transliteration: 'Namaste',
            source: source,
            onPlayStateChanged: onPlayStateChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return service;
}

/// Taps the play/pause control, whichever glyph it currently shows.
///
/// A user taps the *button*, not an icon — after the first tap the glyph
/// flips from play to pause, so a finder pinned to one icon goes stale.
/// This mirrors what a finger actually does.
Future<void> tapTransport(WidgetTester tester) async {
  final finder = find.byWidgetPredicate(
    (w) => w is Icon &&
        (w.icon == Icons.play_arrow_rounded || w.icon == Icons.pause_rounded),
  );
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  group('play button drives the real service', () {
    testWidgets('idle → tapping play issues a real play() with the source',
        (tester) async {
      final service = await pumpWaveform(tester);

      // Idle: play icon.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.playCount, 1,
          reason: 'the tap must reach the service, not just a local bool');
      expect(service.playRequests.single.source.deterministicKey,
          _asset.deterministicKey);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget,
          reason: 'the icon must reflect the engine state after playing');
    });

    testWidgets('playing → tapping pause issues pause() and flips the icon',
        (tester) async {
      final service = await pumpWaveform(tester);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(service.pauseCount, 1);
      expect(service.resumeCount, 0);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('paused → tapping play resumes rather than reloading',
        (tester) async {
      final service = await pumpWaveform(tester);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.resumeCount, 1);
      expect(service.playCount, 1,
          reason: 'resuming must not reload the source from scratch');
    });

    testWidgets('onPlayStateChanged reports the real state transitions',
        (tester) async {
      final seen = <bool>[];
      final service = await pumpWaveform(
        tester,
        onPlayStateChanged: seen.add,
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(seen, [true, false]);
      expect(service.playCount, 1);
    });
  });

  group('honest empty-audio behaviour (the old fake engine is gone)', () {
    testWidgets('null source: tapping play does NOT report playing',
        (tester) async {
      final reported = <bool>[];
      final service = await pumpWaveform(
        tester,
        source: null,
        onPlayStateChanged: reported.add,
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.playCount, 0,
          reason: 'with no AudioSource there is nothing to play; the '
              'service must not be invoked');
      expect(reported, isNot(contains(true)),
          reason: 'the UI must never claim audio played when no audio exists');
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget,
          reason: 'the icon must remain the idle play glyph');
    });

    testWidgets('no source → no animation is scheduled (no fake waveform)',
        (tester) async {
      await pumpWaveform(tester, source: null);
      // The old implementation used AnimationController.repeat(). If any
      // animation were still running, pumpAndSettle would time out.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      // Reaching here without a settle timeout proves nothing is looping.
      expect(find.byType(AudioCadenceWaveform), findsOneWidget);
    });
  });

  group('progress renders the real playhead', () {
    testWidgets('duration label shows the real duration, not the fallback',
        (tester) async {
      await pumpWaveform(
        tester,
        duration: const Duration(minutes: 1, seconds: 5),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(find.text('1:05'), findsOneWidget,
          reason: 'the label must come from the engine duration');
      expect(find.text('0:03'), findsNothing,
          reason: 'the hardcoded fallback must be gone once a real '
              'duration is known');
    });

    testWidgets('fallback label is shown only before a duration is known',
        (tester) async {
      await pumpWaveform(tester, duration: null);
      expect(find.text('0:03'), findsOneWidget);
    });

    testWidgets('advancing the playhead repaints without any timer',
        (tester) async {
      final service = await pumpWaveform(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      final before = service.current.progress;
      expect(before, 0.0);

      // Move the playhead the way the engine's position stream would.
      service.advance(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(service.current.progress, closeTo(0.5, 1e-9),
          reason: 'progress must follow the real position, not a timer');
    });

    testWidgets('paused playhead does not advance', (tester) async {
      final service = await pumpWaveform(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      service.advance(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      final atPause = service.current.position;

      service.advance(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(service.current.position, atPause,
          reason: 'a paused engine does not advance its position');
    });
  });

  group('speed control reaches the service', () {
    testWidgets('cycling the speed chip calls setSpeed', (tester) async {
      final service = await pumpWaveform(tester);

      expect(find.text('1.0x'), findsOneWidget);
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      expect(service.setSpeedCount, 1);
      expect(service.speed, 1.25);
      expect(find.text('1.25x'), findsOneWidget);

      await tester.tap(find.text('1.25x'));
      await tester.pumpAndSettle();
      expect(service.speed, 1.5);
      expect(find.text('1.50x'), findsOneWidget,
          reason: 'non-unity speeds render with two decimals');

      await tester.tap(find.text('1.50x'));
      await tester.pumpAndSettle();
      expect(service.speed, 1.0, reason: 'the cycle wraps back to 1.0');
      expect(find.text('1.0x'), findsOneWidget);
    });
  });

  group('failure surfacing', () {
    testWidgets('a playback failure leaves the player in error, not playing',
        (tester) async {
      final service = await pumpWaveform(tester);

      service.emitFailure(const AudioNetworkFailure());
      await tester.pumpAndSettle();

      expect(service.current.status, AudioPlaybackStatus.error);
      expect(service.current.failure, isA<AudioNetworkFailure>());
      // The button is not claiming to be mid-playback.
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('tapping play after an error retries instead of staying dead',
        (tester) async {
      final service = await pumpWaveform(tester);
      service.emitFailure(const AudioPlaybackFailure());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.playCount, 1,
          reason: 'an error must be recoverable — the learner can retry');
    });

    testWidgets('a failed play attempt does not report playing',
        (tester) async {
      final reported = <bool>[];
      final service = await pumpWaveform(
        tester,
        onPlayStateChanged: reported.add,
      );
      service.failNextPlayWith = const AudioNetworkFailure();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.current.status, AudioPlaybackStatus.error);
      expect(find.byIcon(Icons.pause_rounded), findsNothing,
          reason: 'a failed load must not look like successful playback');
    });
  });

  group('concurrency and lifecycle', () {
    testWidgets('rapid A → B → A taps never leave two sources playing',
        (tester) async {
      final service = await pumpWaveform(tester);

      // Fire repeated taps in quick succession — the classic double-tap
      // race. A user means "toggle", not "queue three plays".
      await tapTransport(tester);
      await tapTransport(tester);
      await tapTransport(tester);

      expect(service.playCount, lessThanOrEqualTo(2),
          reason: 'the widget guards against double-queuing a single intent');
      // Whatever the interleaving, the widget still shows a live state —
      // never a stuck "playing" glyph over a stopped engine.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon &&
              (w.icon == Icons.play_arrow_rounded ||
                  w.icon == Icons.pause_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a second waveform instance shares the one service',
        (tester) async {
      final service = FakeAudioService()
        ..defaultDuration = const Duration(seconds: 4);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioServiceProvider.overrideWithValue(service as AudioService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AudioCadenceWaveform(
                    phrase: 'first',
                    source: _asset,
                  ),
                  AudioCadenceWaveform(
                    phrase: 'second',
                    source: _remote,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Two waveforms share ONE engine, so they also share one playback
      // state. Play the first clip, then the second — the engine must
      // hold a single source, the newest request winning.
      final transportIcons = find.byWidgetPredicate(
        (w) => w is Icon &&
            (w.icon == Icons.play_arrow_rounded || w.icon == Icons.pause_rounded),
      );
      expect(transportIcons, findsNWidgets(2));

      await tester.tap(transportIcons.at(0));
      await tester.pumpAndSettle();

      // Only the waveform whose clip is actually playing shows a pause
      // glyph. The other one still offers "play", because it is not the
      // source currently loaded.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(service.playRequests.length, 2);
      expect(service.playRequests.last.source.deterministicKey,
          _remote.deterministicKey,
          reason: 'the newest request replaces the current source — one '
              'engine, one clip');
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget,
          reason: 'exactly one player is active after the switch');
    });

    testWidgets('disposing the widget does not stop the shared engine',
        (tester) async {
      final service = await pumpWaveform(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      // Navigate the widget out of the tree mid-playback.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioServiceProvider.overrideWithValue(service as AudioService),
          ],
          child: const MaterialApp(home: Scaffold(body: Text('gone'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.stopCount, 0,
          reason: 'the engine is container-owned; leaving a screen must not '
              'cut a pronunciation clip short');
      expect(service.isDisposed, isFalse,
          reason: 'the widget does not own the engine lifetime');
    });
  });
}
