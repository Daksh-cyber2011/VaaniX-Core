/// VaaniX Progress Meter
///
/// The branded linear progress bar: rounded track, soft tinted background,
/// animated fill. Use for lesson progress, exam progress and mastery rows.
/// Never pair it with an unnamed percentage - always give [semanticLabel].
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';

class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.semanticLabel,
    this.animate = true,
  });

  /// Progress from 0.0 to 1.0. Values are clamped.
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final String? semanticLabel;

  /// Set false for static contexts (print, tests).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(0.0, 1.0);
    final trackColor =
        backgroundColor ?? theme.colorScheme.primary.withOpacity(0.12);

    final bar = Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            color: color ?? theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, animatedValue, _) {
                return Container(
                  height: height,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(height),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: animatedValue,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color ?? theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(height),
                      ),
                    ),
                  ),
                );
              },
            )
          : bar,
    );
  }
}
