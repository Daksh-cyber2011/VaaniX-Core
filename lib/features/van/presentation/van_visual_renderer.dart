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
/// ## Geometry (verified against the Flutter SDK, not assumed)
///
/// Three things make the naive `Transform.scale` + `Transform.translate`
/// version wrong, so the mapping is computed explicitly instead:
///
///  1. **The image must escape the stage constraint.** `RenderImage`
///     sizes itself with
///     `constraints.constrainSizeAndAttemptToPreserveAspectRatio`, so
///     under the VAN stage's tight box it collapses to the stage size.
///  2. **`BoxFit.none` crops.** In this Flutter version
///     `applyBoxFit(BoxFit.none, …)` uses
///     `min(input, output)` per axis and then draws 1:1 — inside a
///     160 px stage it shows only the top-left 160×160 of a 1024×1536
///     image, which is transparent margin, not the character.
///  3. **`Transform.scale` / `Transform.translate` pivot about the
///     child centre** (their `alignment` defaults to
///     `Alignment.center`), not the frame origin.
///
/// So the child is laid out at its intrinsic pixel size via
/// [UnconstrainedBox] (giving `BoxFit.none` nothing to crop), and the
/// whole mapping is applied as ONE explicit affine matrix with
/// `alignment: null` so the pivot is the frame origin:
///
/// ```text
/// stage = scale * sourcePixels + (tx, ty)
/// scale = min(stageW / frameW, stageH / frameH)      // uniform = contain
/// tx    = (stageW - frameW * scale) / 2 - frameLeft * scale
/// ty    = (stageH - frameH * scale) / 2 - frameTop  * scale
/// ```
///
/// The `(stage - frame*scale) / 2` term is the explicit centring: the
/// character is presented centred in the stage on the non-binding axis,
/// never anchored top-left. `scale` is a single scalar applied to both
/// axes, so the artwork's aspect ratio is preserved exactly, and the
/// frame is the tight bounding box of non-transparent pixels, so no
/// character pixel is cropped.
class _FramedExpressionImage extends StatelessWidget {
  const _FramedExpressionImage({required this.art, required this.fallback});

  final VanExpressionArt art;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final frame = art.frame;
    if (frame.isWholeImage) {
      // No measurement available — behave exactly as before.
      return _image(fit: BoxFit.contain);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageW = constraints.maxWidth;
        final stageH = constraints.maxHeight;
        if (stageW <= 0 ||
            stageH <= 0 ||
            !stageW.isFinite ||
            !stageH.isFinite) {
          // Unbounded / zero stage — fall back to the plain contain fit
          // rather than dividing by zero.
          return _image(fit: BoxFit.contain);
        }

        final frameW = frame.width.toDouble();
        final frameH = frame.height.toDouble();
        // Uniform scale: the whole character is always visible
        // (contain semantics applied to the CHARACTER box).
        final scale = math.min(stageW / frameW, stageH / frameH);
        // Explicit centring on the non-binding axis, then remove the
        // frame's own origin. Composed into a single matrix.
        final tx = (stageW - frameW * scale) / 2 - frame.left * scale;
        final ty = (stageH - frameH * scale) / 2 - frame.top * scale;

        return ClipRect(
          key: kVanFrameClipKey,
          child: Transform(
            // `alignment: null` is required: with a non-null alignment
            // RenderTransform re-pivots the matrix about the child
            // centre, which would undo the frame-origin mapping.
            alignment: null,
            transform: Matrix4.identity()
              ..translate(tx, ty)
              ..scale(scale),
            child: _naturalSizeImage(),
          ),
        );
      },
    );
  }

  /// The source image at its intrinsic pixel size.
  ///
  /// [UnconstrainedBox] lets the child exceed the stage so
  /// `RenderImage` reports its real 1024×1536 (or 1199×1312) size and
  /// `BoxFit.none` has nothing to crop. `topLeft` keeps the image's
  /// origin aligned with the transform's origin.
  Widget _naturalSizeImage() => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: _image(fit: BoxFit.none),
      );

  Widget _image({required BoxFit fit}) => Image.asset(
        art.path,
        key: kVanCanonicalArtKey,
        fit: fit,
        filterQuality: FilterQuality.medium,
        // Switching expressions never flashes blank between decodes.
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
}
