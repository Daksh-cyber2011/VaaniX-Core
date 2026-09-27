/// VaaniX V1 Design System â€” Audio Cadence Waveform Player
///
/// Waveform player for:
/// - Pronunciation Lab micro-doses
/// - Conversational cadence & honorific agreement listening
/// - Interactive applied drills
///
/// ## Real playback, not decoration
///
/// This widget used to run a `AnimationController` that swung the bars
/// back and forth with no audio attached â€” the play button toggled a
/// boolean and the waveform pretended to play. That is gone.
///
/// Playback now goes through [AudioService], so:
///   * the play/pause icon reflects the engine's actual state;
///   * the painted bars are the **real** playhead from the engine's
///     position stream, not a sine wave;
///   * the duration label is the **real** duration once the engine
///     reports one, falling back to [durationLabel] only while unknown;
///   * dragging the waveform seeks.
///
/// When [source] is null â€” no audio is configured for this item â€” the
/// play button does not fake anything. It logs and leaves the player
/// idle, because a learner must never be shown "playing" for a clip that
/// does not exist.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/audio/audio_models.dart';
import 'package:vaanix_app/core/audio/audio_providers.dart';
import 'package:vaanix_app/core/audio/audio_service.dart';
import 'package:vaanix_app/core/logging/logger.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';

class AudioCadenceWaveform extends ConsumerStatefulWidget {
  const AudioCadenceWaveform({
    super.key,
    this.phrase,
    this.transliteration,
    this.durationLabel = '0:03',
    this.accentColor,
    this.onPlayStateChanged,
    this.source,
  });

  final String? phrase;
  final String? transliteration;

  /// Fallback label shown until the engine reports a real duration.
  final String durationLabel;
  final Color? accentColor;
  final ValueChanged<bool>? onPlayStateChanged;

  /// The audio to play. `null` means no audio exists for this item â€” the
  /// widget will not pretend otherwise.
  final AudioSource? source;

  @override
  ConsumerState<AudioCadenceWaveform> createState() =>
      _AudioCadenceWaveformState();
}
class _AudioCadenceWaveformState extends ConsumerState<AudioCadenceWaveform> {
  /// Local speed mirror so the chip repaints immediately, before the
  /// engine has acknowledged the change.
  double _speed = 1.0;

  /// Guards against a second tap racing an in-flight `play()`. The engine
  /// already serialises its own commands; this stops the UI from
  /// double-queuing the same intent.
  bool _commandInFlight = false;

  static const _barHeights = [
    0.35,
    0.65,
    0.95,
    0.50,
    0.80,
    1.0,
    0.70,
    0.45,
    0.85,
    0.60,
    0.40,
    0.75,
    0.90,
    0.55,
    0.30
  ];

  /// The current playback snapshot, or null before the first frame.
  ///
  /// Null means "we have not started anything", which is why the play
  /// button is enabled and the bars are drawn dim.
  AudioPlaybackState? _state;

  @override
  void dispose() {
    // Deliberately does NOT stop audio here. The engine is owned by the
    // ProviderContainer, not by this widget, so navigating away mid-word
    // should not cut a pronunciation clip short. Callers that want the
    // clip to end on navigation should call
    // `ref.read(audioServiceProvider).stop()` explicitly.
    super.dispose();
  }

  Future<void> _handlePlayTap(AudioSource? source) async {
    final service = ref.read(audioServiceProvider);
    final current = _state ?? service.current;
    HapticFeedback.lightImpact();

    // No real source configured â€” do not fake a play. Surface it as a
    // genuine unavailable state instead of animating bars for nothing.
    if (source == null) {
      widget.onPlayStateChanged?.call(false);
      _showUnavailable(service);
      return;
    }

    if (_commandInFlight) return;
    setState(() => _commandInFlight = true);
    try {
      switch (current.status) {
        case AudioPlaybackStatus.playing:
          await service.pause();
          widget.onPlayStateChanged?.call(false);
        case AudioPlaybackStatus.paused:
          await service.resume();
          widget.onPlayStateChanged?.call(true);
        case AudioPlaybackStatus.completed:
          // Replay from the top.
          await service.play(AudioPlayRequest(
            source: source,
            ducking: AudioDuckingPolicy.duckOthers,
            startAt: Duration.zero,
          ));
          widget.onPlayStateChanged?.call(true);
        case AudioPlaybackStatus.idle:
        case AudioPlaybackStatus.loading:
        case AudioPlaybackStatus.error:
          await service.play(AudioPlayRequest(
            source: source,
            ducking: AudioDuckingPolicy.duckOthers,
          ));
          widget.onPlayStateChanged?.call(true);
      }
    } finally {
      if (mounted) setState(() => _commandInFlight = false);
    }
  }

  void _showUnavailable(AudioService service) {
    // Prefer a real typed failure over an invented one.
    if (service.current.failure != null) return;
    AppLogger.warn(
      'waveform tapped with no audio source configured',
      tag: 'AudioCadenceWaveform',
    );
  }

  Future<void> _cycleSpeed() async {
    HapticFeedback.selectionClick();
    final next = switch (_speed) {
      1.0 => 1.25,
      1.25 => 1.5,
      _ => 1.0,
    };
    setState(() => _speed = next);
    await ref.read(audioServiceProvider).setSpeed(next);
  }

  /// `mm:ss` from a real duration, or the caller's label when the engine
  /// has not reported one yet (or the source is a live stream).
  String _durationText(AudioPlaybackState? state) {
    final total = state?.duration;
    if (total == null) return widget.durationLabel;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.accentColor ??
        (isDark
            ? VaaniXColors.examCyanAccent
            : VaaniXColors.learnPrimaryViolet);

    return StreamBuilder<AudioPlaybackState>(
      stream: ref.watch(audioServiceProvider).state,
      initialData: _state ?? ref.read(audioServiceProvider).current,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
        // Real playback progress. Null while the duration is unknown â€”
        // in that case the bars render flat rather than pretending to
        // advance.
        final progress = state?.progress;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? VaaniXColors.examSurfaceCard
                : VaaniXColors.learnSurfaceCard,
            borderRadius: VaaniXRadius.borderLg,
            border: Border.all(
              color: isDark ? VaaniXColors.examBorder : VaaniXColors.learnBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.phrase != null) ...[
                Row(
                  children: [
                    Text(
                      widget.phrase!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? VaaniXColors.textPrimaryDark
                            : VaaniXColors.textPrimaryLight,
                      ),
                    ),
                    if (widget.transliteration != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.transliteration!})',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? VaaniXColors.textTertiaryDark
                              : VaaniXColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: () => _handlePlayTap(widget.source),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Waveform bars driven by REAL playback position.
                  //
                  // Bars left of the playhead are fully painted; bars at
                  // or past it stay dim. When the duration is unknown
                  // there is no playhead to draw, so every bar renders
                  // dim â€” we never synthesise motion.
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) async {
                        final service = ref.read(audioServiceProvider);
                        final total = state?.duration;
                        if (total == null || total.inMilliseconds <= 0) return;
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final dx = details.localPosition.dx;
                        final fraction =
                            (dx / box.size.width).clamp(0.0, 1.0);
                        await service.seek(
                          Duration(
                            milliseconds:
                                (total.inMilliseconds * fraction).round(),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_barHeights.length, (i) {
                            final baseHeight = _barHeights[i];
                            // Fraction of the track already played,
                            // mapped onto this bar's slot.
                            final played = progress != null &&
                                (i / _barHeights.length) <= progress;
                            final scale = played ? baseHeight : baseHeight * 0.45;

                            return Container(
                              width: 3.5,
                              height: 28 * scale,
                              decoration: BoxDecoration(
                                color: played
                                    ? primary
                                    : primary.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Duration label â€” real once known.
                  Text(
                    _durationText(state),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? VaaniXColors.textSecondaryDark
                          : VaaniXColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Speed multiplier chip
                  GestureDetector(
                    onTap: _cycleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? VaaniXColors.examSurfaceElevated
                            : VaaniXColors.learnSurfaceElevated,
                        borderRadius: VaaniXRadius.borderPill,
                        border: Border.all(
                          color: isDark
                              ? VaaniXColors.examBorder
                              : VaaniXColors.learnBorder,
                        ),
                      ),
                      child: Text(
                        '${_speed.toStringAsFixed(_speed == 1.0 ? 1 : 2)}x',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
