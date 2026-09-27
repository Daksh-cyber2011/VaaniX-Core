/// Default VAN visual renderer with a safe Lottie-to-Flutter fallback path.
///
/// Rendering precedence (see `docs/VAN/Implementation.md`):
///   1. An available Lottie animation asset (future canonical animations).
///   2. The canonical static expression artwork (the supplied VAN art set),
///      cropped to its measured character frame so VAN presents at a
///      consistent size and position across every expression.
///   3. The Flutter fallback painter supplied by [VanWidget].
///
/// ## Frame normalisation
///
/// The supplied PNGs are cut out inconsistently — `excited.png` has its
/// arms spread while `motivating.png` has them tucked, and `sleepy.png`
/// arrived on a 1199×1312 canvas where the other seven are 1024×1536.
/// A plain contain-fit over the *whole image* therefore makes VAN
/// visibly change size and height between states (measured: 7.9% height
/// spread, 21.4% width spread on a 160px stage).
///
/// Cropping to each asset's measured character frame first removes that
/// inconsistency: height spread drops to 0.3% and every expression fills
/// the stage identically. Pixels inside the frame are untouched, so the
/// artwork is still displayed exactly as supplied — only the dead
/// transparent margin around it is trimmed. See [VanExpressionFrame].
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';
import 'package:vaanix_app/features/van/presentation/van_expression.dart';

/// Key of the canonical artwork visual. Tests assert on this to prove the
/// canonical art (not the fallback painter) is on screen.
const ValueKey<String> kVanCanonicalArtKey =
    ValueKey<String>('van-canonical-art');

/// Key of the frame-normalisation crop, so tests can assert that the
/// per-expression crop seam is present (and deliberately absent when an
/// expression has no measured frame).
const ValueKey<String> kVanFrameClipKey =
    ValueKey<String>('van-expression-frame');

class VanVisualRenderer extends StatelessWidget {
  const VanVisualRenderer({
    super.key,
    required this.asset,
    required this.fallback,
    this.expressionArt,
  });

  /// Animation-layer asset for the current state (Lottie seam, unchanged).
  final VanVisualAsset asset;

  /// Canonical static artwork for the current state, when the catalog
  /// provides it and no animation supersedes it.
  final VanExpressionArt? expressionArt;

  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (asset.format == VanAssetFormat.lottie && asset.isAvailable) {
      return Lottie.asset(
        asset.path!,
        repeat: asset.loop,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    final art = expressionArt;
    if (art != null && art.isAvailable) {
      // On a load failure the errorBuilder below swaps the rendered output
      // to the deterministic Flutter fallback painter — the app never shows
      // a broken image and never crashes.
      return _FramedExpressionImage(art: art, fallback: fallback);
    }

    return fallback;
  }
}

/// Renders one canonical expression, cropped to its character frame.
///
/// The crop is a uniform scale plus a translation inside a `ClipRect`
/// — the standard image-crop idiom. It is uniform, so the artwork's
/// proportions are never changed; only the transparent margin around
/// the character is trimmed away.
class _FramedExpressionImage extends StatelessWidget {
  const _FramedExpressionImage({required this.art, required this.fallback});

  final VanExpressionArt art;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final frame = art.frame;
    if (frame.isWholeImage) {
      // No measurement available — behave exactly as before.
      return _plainImage();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageW = constraints.maxWidth;
        final stageH = constraints.maxHeight;
        if (stageW <= 0 || stageH <= 0) {
          return _plainImage();
        }
        // Uniform scale that makes the CHARACTER box fit the stage
        // (contain semantics: the whole character is always visible).
        final scale = math.min(
          stageW / frame.width,
          stageH / frame.height,
        );
        return ClipRect(
          key: kVanFrameClipKey,
          child: Transform.scale(
            scale: scale,
            // Inner: shift so the frame's top-left lands on the origin.
            child: Transform.translate(
              offset: Offset(-frame.left.toDouble(), -frame.top.toDouble()),
              child: _plainImage(),
            ),
          ),
        );
      },
    );
  }

  /// The untransformed source image, at natural pixel size.
  ///
  /// [BoxFit.none] is deliberate inside the frame path: the surrounding
  /// uniform scale already sizes the character to the stage, and `none`
  /// guarantees no second, independent fit can distort it.
  Widget _plainImage() => Image.asset(
        art.path,
        key: kVanCanonicalArtKey,
        fit: art.frame.isWholeImage ? BoxFit.contain : BoxFit.none,
        filterQuality: FilterQuality.medium,
        // Switching expressions never flashes blank between decodes.
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
}
