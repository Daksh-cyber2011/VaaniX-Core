/// VaaniX V1 Design System — Audio Cadence Waveform Player
///
/// Visual audio waveform player for:
/// - Pronunciation Lab micro-doses
/// - Conversational cadence & honorific agreement listening
/// - Interactive applied drills
///
/// Features animated equalizer bars, play/pause toggle, and speed multiplier.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';

class AudioCadenceWaveform extends StatefulWidget {
  const AudioCadenceWaveform({
    super.key,
    this.phrase,
    this.transliteration,
    this.durationLabel = '0:03',
    this.accentColor,
    this.onPlayStateChanged,
  });

  final String? phrase;
  final String? transliteration;
  final String durationLabel;
  final Color? accentColor;
  final ValueChanged<bool>? onPlayStateChanged;

  @override
  State<AudioCadenceWaveform> createState() => _AudioCadenceWaveformState();
}

class _AudioCadenceWaveformState extends State<AudioCadenceWaveform>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _speed = 1.0;
  late final AnimationController _waveController;

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

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _waveController.repeat(reverse: true);
      } else {
        _waveController.stop();
      }
    });
    widget.onPlayStateChanged?.call(_isPlaying);
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.25;
      } else if (_speed == 1.25) {
        _speed = 1.5;
      } else {
        _speed = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.accentColor ??
        (isDark
            ? VaaniXColors.examCyanAccent
            : VaaniXColors.learnPrimaryViolet);

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
                onTap: _togglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Animated Waveform Bars
              Expanded(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_barHeights.length, (i) {
                          final baseHeight = _barHeights[i];
                          final animOffset = math.sin(
                              (_waveController.value * math.pi * 2) +
                                  (i * 0.4));
                          final dynamicScale = _isPlaying
                              ? (baseHeight + (animOffset * 0.25))
                                  .clamp(0.2, 1.0)
                              : baseHeight * 0.5;

                          return Container(
                            width: 3.5,
                            height: 28 * dynamicScale,
                            decoration: BoxDecoration(
                              color: _isPlaying
                                  ? primary
                                  : primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Duration Label
              Text(
                widget.durationLabel,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
  }
}
