/// VAN's responsive companion widget and approved-art fallback renderer.
///
/// The state and event contracts live in `features/van`; this widget only
/// turns a presentation state into a visual. Until approved source animation
/// files arrive, [_VanFallbackPainter] provides a deliberately polished 2D
/// vector fallback rather than a missing asset or generic icon.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/features/van/domain/van_event.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_controller.dart';
import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';
import 'package:vaanix_app/features/van/presentation/van_visual_renderer.dart';

export 'package:vaanix_app/features/van/domain/van_state.dart';

class VanWidget extends StatefulWidget {
  const VanWidget({
    super.key,
    this.state = VanState.idle,
    this.size = 160.0,
    this.onTap,
    this.onLongPress,
    this.showSpeechBubble = false,
    this.dialogueText,
    this.isLoading = false,
    this.useController = false,
    this.assetCatalog = VanAssetCatalog.v1,
    this.visualBuilder,
    this.semanticLabel,
  });

  final VanState state;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showSpeechBubble;
  final String? dialogueText;
  final bool isLoading;

  /// Renders the global event-driven presentation instead of [state].
  final bool useController;
  final VanAssetCatalog assetCatalog;
  final VanVisualBuilder? visualBuilder;
  final String? semanticLabel;

  @override
  State<VanWidget> createState() => _VanWidgetState();
}

class _VanWidgetState extends State<VanWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      duration:
          const Duration(milliseconds: AppConstants.vanIdleCycleDurationMs),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.useController) return _buildVan(context);
    return Consumer(
      builder: (context, ref, _) => _buildVan(
        context,
        presentation: ref.watch(vanControllerProvider),
        onDefaultTap: () => ref.read(vanControllerProvider.notifier).dispatch(
              const VanEvent(VanEventType.companionTapped),
            ),
      ),
    );
  }

  Widget _buildVan(
    BuildContext context, {
    VanPresentationState? presentation,
    VoidCallback? onDefaultTap,
  }) {
    final state = presentation?.current ?? widget.state;
    final dialogue = presentation?.message ?? widget.dialogueText;
    final loading = presentation?.isLoading ?? widget.isLoading;
    final asset = widget.assetCatalog.assetFor(state);
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final defaultTap =
        state.definition.allowsUserInteraction ? onDefaultTap : null;
    final hasBubble = widget.showSpeechBubble && (dialogue != null || loading);

    return Semantics(
      button: widget.onTap != null ||
          widget.onLongPress != null ||
          defaultTap != null,
      label: widget.semanticLabel ?? 'Van is ${state.definition.meaning}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap ?? defaultTap,
        onLongPress: widget.onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasBubble) _SpeechBubble(text: dialogue, isLoading: loading),
            if (hasBubble) const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _motionController,
              builder: (context, _) {
                final motion = _VanFallbackMotion.resolve(
                  state,
                  _motionController.value,
                  reducedMotion,
                );
                final fallback = RepaintBoundary(
                  key: const ValueKey('van-flutter-fallback'),
                  child: _VanFallbackBody(
                    size: widget.size,
                    state: state,
                    motion: motion,
                  ),
                );
                final visual = reducedMotion
                    ? fallback
                    : widget.visualBuilder?.call(context, asset, fallback) ??
                        VanVisualRenderer(asset: asset, fallback: fallback);
                return Transform.translate(
                  offset: Offset(0, motion.verticalOffset * widget.size),
                  child: Transform.rotate(
                    angle: motion.rotation,
                    child: Transform.scale(
                      scale: motion.scale,
                      child: SizedBox.square(
                          dimension: widget.size, child: visual),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _VanFallbackMotion {
  const _VanFallbackMotion({
    this.verticalOffset = 0,
    this.rotation = 0,
    this.scale = 1,
    this.wingAngle = 0,
    this.eyeOpenness = 1,
    this.pupilOffset = Offset.zero,
    this.beakHeightFactor = .14,
    this.showSparkles = false,
    this.wink = false,
    this.tuftLift = 0,
  });

  final double verticalOffset;
  final double rotation;
  final double scale;
  final double wingAngle;
  final double eyeOpenness;
  final Offset pupilOffset;
  final double beakHeightFactor;
  final bool showSparkles;
  final bool wink;
  final double tuftLift;

  /// The animation is phase-based rather than random, keeping screenshots,
  /// tests, and state changes predictable while still avoiding rigid motion.
  factory _VanFallbackMotion.resolve(
    VanState state,
    double progress,
    bool reducedMotion,
  ) {
    if (reducedMotion) {
      return _staticPoseFor(state);
    }
    final phase = progress * math.pi * 2;
    final slowWave = math.sin(phase);
    final quickWave = math.sin(phase * 2);
    final blink = _blinkAt(progress) ? .16 : 1.0;
    final idle = state == VanState.idle;
    return _VanFallbackMotion(
      verticalOffset: switch (state) {
        VanState.achievement => -math.max(0, slowWave) * .055,
        VanState.happy => -math.max(0, slowWave) * .018,
        _ => idle ? slowWave * .012 : 0,
      },
      scale: switch (state) {
        VanState.achievement => 1 + math.max(0, slowWave) * .055,
        VanState.surprised => 1.025,
        VanState.error => .99,
        _ => 1 + (idle ? slowWave.abs() * .014 : 0),
      },
      rotation: switch (state) {
        VanState.thinking => -.06 + slowWave * .012,
        VanState.caring => .045,
        VanState.sad => .055,
        VanState.funny => -.075 + slowWave * .035,
        VanState.error => quickWave * .035,
        _ => 0,
      },
      wingAngle: switch (state) {
        VanState.achievement => .62 + quickWave * .15,
        VanState.happy => .18 + math.max(0, quickWave) * .13,
        VanState.surprised => .34,
        VanState.speaking => .08 + quickWave * .1,
        VanState.caring => -.12,
        VanState.funny => .17,
        _ => idle ? slowWave * .035 : 0,
      },
      eyeOpenness: switch (state) {
        VanState.focus => .82,
        VanState.sad => .68,
        VanState.caring => .82,
        VanState.surprised => 1.16,
        _ => blink,
      },
      pupilOffset: switch (state) {
        VanState.thinking => const Offset(.17, -.20),
        VanState.focus => const Offset(0, .14),
        VanState.caring || VanState.sad => const Offset(-.06, .08),
        VanState.surprised => const Offset(0, -.08),
        _ => idle ? Offset(slowWave * .07, 0) : Offset.zero,
      },
      beakHeightFactor: switch (state) {
        VanState.speaking => .13 + (quickWave + 1) * .045,
        VanState.surprised => .27,
        VanState.achievement => .2,
        VanState.sad || VanState.caring => .1,
        _ => .14,
      },
      showSparkles:
          state == VanState.achievement || state == VanState.surprised,
      wink: state == VanState.funny,
      tuftLift: switch (state) {
        VanState.achievement || VanState.surprised => .12 + slowWave * .04,
        VanState.sad => -.06,
        _ => idle ? slowWave * .03 : 0,
      },
    );
  }

  static _VanFallbackMotion _staticPoseFor(VanState state) =>
      _VanFallbackMotion(
        rotation: switch (state) {
          VanState.thinking => -.06,
          VanState.caring => .045,
          VanState.sad => .055,
          VanState.funny => -.075,
          _ => 0,
        },
        wingAngle: switch (state) {
          VanState.achievement => .65,
          VanState.happy => .2,
          VanState.surprised => .34,
          VanState.caring => -.12,
          VanState.funny => .17,
          _ => 0,
        },
        eyeOpenness: switch (state) {
          VanState.focus => .82,
          VanState.sad => .68,
          VanState.caring => .82,
          VanState.surprised => 1.16,
          _ => 1,
        },
        pupilOffset: switch (state) {
          VanState.thinking => const Offset(.17, -.20),
          VanState.focus => const Offset(0, .14),
          VanState.caring || VanState.sad => const Offset(-.06, .08),
          VanState.surprised => const Offset(0, -.08),
          _ => Offset.zero,
        },
        beakHeightFactor: switch (state) {
          VanState.speaking => .19,
          VanState.surprised => .27,
          VanState.achievement => .2,
          VanState.sad || VanState.caring => .1,
          _ => .14,
        },
        showSparkles:
            state == VanState.achievement || state == VanState.surprised,
        wink: state == VanState.funny,
        tuftLift: switch (state) {
          VanState.achievement || VanState.surprised => .12,
          VanState.sad => -.06,
          _ => 0,
        },
      );

  static bool _blinkAt(double progress) {
    // Two brief, gentle blinks per 3.5-second breathing cycle.
    return (progress > .22 && progress < .255) ||
        (progress > .78 && progress < .805);
  }
}

class _VanFallbackBody extends StatelessWidget {
  const _VanFallbackBody({
    required this.size,
    required this.state,
    required this.motion,
  });

  final double size;
  final VanState state;
  final _VanFallbackMotion motion;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VanFallbackPainter(
        state: state,
        motion: motion,
        darkMode: Theme.of(context).brightness == Brightness.dark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// A flat, soft-vector VAN construction. It deliberately uses no heavy
/// outlines, emoji, or Material glyphs so it stays visually consistent until
/// final Lottie/vector art is approved and supplied through the asset catalog.
class _VanFallbackPainter extends CustomPainter {
  const _VanFallbackPainter({
    required this.state,
    required this.motion,
    required this.darkMode,
  });

  final VanState state;
  final _VanFallbackMotion motion;
  final bool darkMode;

  static const _feather = Color(0xFFF4C74A);
  static const _cream = Color(0xFFFFE7A3);
  static const _wing = Color(0xFFF8D76B);
  static const _eye = Color(0xFF263044);
  static const _hoodie = Color(0xFF3678D7);
  static const _hoodieShade = Color(0xFF2864BB);
  static const _beak = Color(0xFFF08B3E);
  static const _beakShade = Color(0xFFDD7130);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);

    if (motion.showSparkles) _paintSparkles(canvas, s);
    _paintFeet(canvas, s);
    _paintBodyAndWings(canvas, s);
    _paintHoodie(canvas, s);
    _paintHead(canvas, s);
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas, double s) {
    final paint = Paint()
      ..color = const Color(0xFFF5C447).withOpacity(.9);
    _diamond(canvas, Offset(.16 * s, .22 * s), .045 * s, paint);
    _diamond(canvas, Offset(.84 * s, .34 * s), .032 * s, paint);
    if (state == VanState.achievement) {
      _diamond(canvas, Offset(.76 * s, .12 * s), .022 * s, paint);
      _diamond(canvas, Offset(.25 * s, .44 * s), .018 * s, paint);
    }
  }

  void _paintFeet(Canvas canvas, double s) {
    final paint = Paint()..color = _beak;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(.40 * s, .86 * s), width: .17 * s, height: .075 * s),
        Radius.circular(.06 * s),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(.60 * s, .86 * s), width: .17 * s, height: .075 * s),
        Radius.circular(.06 * s),
      ),
      paint,
    );
  }

  void _paintBodyAndWings(Canvas canvas, double s) {
    final wingPaint = Paint()..color = _wing;
    _paintWing(canvas, Offset(.30 * s, .61 * s), -motion.wingAngle, false, s,
        wingPaint);
    _paintWing(
        canvas, Offset(.70 * s, .61 * s), motion.wingAngle, true, s, wingPaint);

    final body = Rect.fromCenter(
      center: Offset(.5 * s, .62 * s),
      width: .53 * s,
      height: .42 * s,
    );
    canvas.drawOval(body, Paint()..color = _feather);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(.5 * s, .68 * s),
        width: .31 * s,
        height: .22 * s,
      ),
      Paint()..color = _cream.withOpacity(.7),
    );
  }

  void _paintWing(Canvas canvas, Offset pivot, double angle, bool flip,
      double s, Paint paint) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(flip ? angle : -angle);
    final rect = Rect.fromCenter(
      center: Offset(flip ? .045 * s : -.045 * s, .015 * s),
      width: .20 * s,
      height: .27 * s,
    );
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  void _paintHoodie(Canvas canvas, double s) {
    final shell = RRect.fromRectAndCorners(
      Rect.fromLTWH(.245 * s, .59 * s, .51 * s, .22 * s),
      topLeft: Radius.circular(.13 * s),
      topRight: Radius.circular(.13 * s),
      bottomLeft: Radius.circular(.075 * s),
      bottomRight: Radius.circular(.075 * s),
    );
    canvas.drawRRect(shell, Paint()..color = _hoodie);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(.5 * s, .62 * s), width: .31 * s, height: .18 * s),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _hoodieShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = .028 * s,
    );
    final string = Paint()
      ..color = Colors.white.withOpacity(.85)
      ..strokeWidth = .012 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(.455 * s, .665 * s), Offset(.43 * s, .72 * s), string);
    canvas.drawLine(
        Offset(.545 * s, .665 * s), Offset(.57 * s, .72 * s), string);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(.40 * s, .735 * s, .20 * s, .045 * s),
        Radius.circular(.03 * s),
      ),
      Paint()..color = _hoodieShade.withOpacity(.65),
    );
    final logo = Paint()
      ..color = Colors.white.withOpacity(.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .012 * s
      ..strokeCap = StrokeCap.round;
    final mark = Path()
      ..moveTo(.485 * s, .69 * s)
      ..lineTo(.5 * s, .71 * s)
      ..lineTo(.515 * s, .69 * s);
    canvas.drawPath(mark, logo);
  }

  void _paintHead(Canvas canvas, double s) {
    _paintTuft(canvas, s);
    final head = Rect.fromCenter(
      center: Offset(.5 * s, .36 * s),
      width: .63 * s,
      height: .53 * s,
    );
    canvas.drawOval(head, Paint()..color = _feather);
    _paintEyes(canvas, s);
    _paintBeak(canvas, s);
  }

  void _paintTuft(Canvas canvas, double s) {
    final baseY = (.115 - motion.tuftLift) * s;
    final paint = Paint()..color = _feather;
    for (final tuft in <(double, double, double)>[
      (.45, -.06, -.36),
      (.50, -.11, 0),
      (.55, -.06, .36),
    ]) {
      canvas.save();
      canvas.translate(tuft.$1 * s, (baseY + tuft.$2 * s));
      canvas.rotate(tuft.$3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: .085 * s, height: .17 * s),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintEyes(Canvas canvas, double s) {
    final left = Offset(.395 * s, .335 * s);
    final right = Offset(.605 * s, .335 * s);
    if (state == VanState.happy || state == VanState.achievement) {
      _happyEye(canvas, left, s);
      _happyEye(canvas, right, s);
      return;
    }
    _eyeShape(canvas, left, s, motion.wink ? .12 : motion.eyeOpenness, false);
    _eyeShape(canvas, right, s, motion.eyeOpenness, true);
  }

  void _eyeShape(
      Canvas canvas, Offset center, double s, double openness, bool right) {
    final eyeWidth = .105 * s;
    final eyeHeight = .145 * s * openness;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight),
      Paint()..color = _eye,
    );
    if (openness < .25) return;
    final pupil = center +
        Offset(
          motion.pupilOffset.dx * eyeWidth * .35,
          motion.pupilOffset.dy * eyeHeight * .35,
        );
    canvas.drawCircle(
      pupil + Offset(right ? -.014 * s : .014 * s, -.026 * s),
      .018 * s,
      Paint()..color = Colors.white.withOpacity(.96),
    );
  }

  void _happyEye(Canvas canvas, Offset center, double s) {
    final paint = Paint()
      ..color = _eye
      ..style = PaintingStyle.stroke
      ..strokeWidth = .027 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: center, width: .115 * s, height: .08 * s),
      0,
      math.pi,
      false,
      paint,
    );
  }

  void _paintBeak(Canvas canvas, double s) {
    final center = Offset(.5 * s, .50 * s);
    final height = math.max(.065 * s, motion.beakHeightFactor * s);
    final top = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center - Offset(0, height * .19),
          width: .23 * s,
          height: height * .52),
      Radius.circular(height),
    );
    final bottom = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center + Offset(0, height * .20),
          width: .21 * s,
          height: height * .48),
      Radius.circular(height),
    );
    canvas.drawRRect(top, Paint()..color = _beak);
    canvas.drawRRect(bottom, Paint()..color = _beakShade);
    if (state == VanState.sad || state == VanState.caring) {
      final paint = Paint()
        ..color = _beakShade.withOpacity(.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .009 * s;
      canvas.drawArc(
        Rect.fromCenter(
            center: center + Offset(0, height * .08),
            width: .12 * s,
            height: .06 * s),
        math.pi,
        math.pi,
        false,
        paint,
      );
    }
  }

  void _diamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * .58, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * .58, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VanFallbackPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.motion != motion ||
      oldDelegate.darkMode != darkMode;
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.isLoading});

  final String? text;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final maxWidth = math.max(
      80.0,
      math.min(300.0, (media?.size.width ?? 300) - 32),
    );
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: isLoading,
      label: text ?? 'Van is thinking',
      child: CustomPaint(
        painter: _BubbleTailPainter(color: theme.colorScheme.surface),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: theme.colorScheme.outline.withOpacity(.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  text ?? 'Thinking…',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5 - 9, size.height - 1)
      ..lineTo(size.width * .5, size.height + 7)
      ..lineTo(size.width * .5 + 9, size.height - 1)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
