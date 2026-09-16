/// VaaniX V1 Design System — Radial Gauge
///
/// High-performance canvas-based circular indicator for:
/// - Readiness score (e.g. 78% with +3.6%/wk trend indicator)
/// - Daily commitment progress (e.g. 76% / 16 of 20 min)
/// - Chapter mastery progress
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';

class VaaniXRadialGauge extends StatefulWidget {
  const VaaniXRadialGauge({
    super.key,
    required this.percentage,
    this.size = 90.0,
    this.strokeWidth = 8.0,
    this.primaryColor,
    this.trackColor,
    this.title,
    this.subtitle,
    this.deltaText,
    this.showPercentage = true,
  });

  final double percentage; // 0.0 to 100.0
  final double size;
  final double strokeWidth;
  final Color? primaryColor;
  final Color? trackColor;
  final String? title;
  final String? subtitle;
  final String? deltaText;
  final bool showPercentage;

  @override
  State<VaaniXRadialGauge> createState() => _VaaniXRadialGaugeState();
}

class _VaaniXRadialGaugeState extends State<VaaniXRadialGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.percentage.clamp(0.0, 100.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant VaaniXRadialGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = Tween<double>(
        begin: oldWidget.percentage.clamp(0.0, 100.0),
        end: widget.percentage.clamp(0.0, 100.0),
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.primaryColor ??
        (isDark
            ? VaaniXColors.examCyanAccent
            : VaaniXColors.learnPrimaryViolet);
    final bgTrack = widget.trackColor ??
        (isDark
            ? VaaniXColors.examSurfaceElevated
            : VaaniXColors.learnBorder.withValues(alpha: 0.6));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RadialPainter(
                  percentage: _animation.value,
                  strokeWidth: widget.strokeWidth,
                  color: activeColor,
                  trackColor: bgTrack,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showPercentage)
                    Text(
                      '${_animation.value.toInt()}%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: widget.size * 0.26,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? VaaniXColors.textPrimaryDark
                            : VaaniXColors.textPrimaryLight,
                      ),
                    ),
                  if (widget.deltaText != null)
                    Text(
                      widget.deltaText!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: widget.size * 0.12,
                        fontWeight: FontWeight.w600,
                        color: VaaniXColors.telemetryEmerald,
                      ),
                    ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: widget.size * 0.11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? VaaniXColors.textSecondaryDark
                            : VaaniXColors.textSecondaryLight,
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

class _RadialPainter extends CustomPainter {
  const _RadialPainter({
    required this.percentage,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double percentage;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final sweepAngle = (percentage / 100.0) * 2 * math.pi;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
