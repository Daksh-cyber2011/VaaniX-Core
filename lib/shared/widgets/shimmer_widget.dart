/// VaaniX Shimmer Loading Widget
///
/// Provides skeleton/shimmer placeholders for content-heavy loading states.
/// The animated gradient sweeps left→right on a warm tinted base, matching
/// the VaaniX palette in both light and dark themes.
///
/// Usage:
///   - [VaaniXShimmer] wraps any widget tree with the shimmer animation.
///   - [ShimmerCard] is a pre-built content-card placeholder.
///   - [ShimmerListTile] is a pre-built list-row placeholder.
///   - [ShimmerText] is a pre-built text-line placeholder.
library;

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';

// ============================================================
// CORE SHIMMER WRAPPER
// ============================================================

/// Wraps [child] with a looping shimmer animation.
///
/// The shimmer colour is derived from the current theme so it always looks
/// intentional — not a grey blur on a branded surface.
class VaaniXShimmer extends StatefulWidget {
  const VaaniXShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// Set to [false] to instantly show [child] without shimmer (e.g. once data
  /// loads and you are doing an animated swap).
  final bool enabled;

  @override
  State<VaaniXShimmer> createState() => _VaaniXShimmerState();
}

class _VaaniXShimmerState extends State<VaaniXShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.shimmerDark : AppColors.shimmer;
    final highlight = isDark
        ? AppColors.surfaceVariantDark
        : Colors.white.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: _shimmer,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final gradientStart = _shimmer.value - 0.4;
            final gradientEnd = _shimmer.value + 0.4;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                gradientStart.clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                gradientEnd.clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

// ============================================================
// PRE-BUILT PLACEHOLDER COMPONENTS
// ============================================================

/// A rounded rectangle placeholder — use for text lines.
class ShimmerText extends StatelessWidget {
  const ShimmerText({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 7,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.shimmerDark : AppColors.shimmer;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A full card-shaped placeholder for content cards.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.height = 96,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.borderRadius = 20,
  });

  final double height;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final shimmerColor = isDark ? AppColors.shimmerDark : AppColors.shimmer;
    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 13,
                  width: double.infinity * 0.6,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: double.infinity * 0.4,
                  decoration: BoxDecoration(
                    color: shimmerColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal list-tile shaped placeholder.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({
    super.key,
    this.leading = true,
    this.trailing = false,
  });

  final bool leading;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.shimmerDark : AppColors.shimmer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leading) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  color: color,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 140,
                  color: color.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          if (trailing) ...[
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Convenience widget: wraps 3 [ShimmerCard]s in a [VaaniXShimmer] for
/// a standard content-list loading state.
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    super.key,
    this.count = 3,
    this.cardHeight = 80,
  });

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return VaaniXShimmer(
      child: Column(
        children: List.generate(
          count,
          (i) => ShimmerCard(height: cardHeight),
        ),
      ),
    );
  }
}
