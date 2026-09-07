/// Default VAN visual renderer with a safe Lottie-to-Flutter fallback path.
///
/// Rendering precedence (see `docs/VAN/Implementation.md`):
///   1. An available Lottie animation asset (future canonical animations).
///   2. The canonical static expression artwork (the supplied VAN art set).
///   3. The Flutter fallback painter supplied by [VanWidget].
///
/// The canonical artwork is displayed EXACTLY as supplied: [BoxFit.contain]
/// preserves the original proportions (no stretching, squashing, or crop)
/// and the PNG transparency is preserved.
library;

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';
import 'package:vaanix_app/features/van/presentation/van_expression.dart';

/// Key of the canonical artwork visual. Tests assert on this to prove the
/// canonical art (not the fallback painter) is on screen.
const ValueKey<String> kVanCanonicalArtKey = ValueKey<String>('van-canonical-art');

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
      return Image.asset(
        art.path,
        key: kVanCanonicalArtKey,
        // Contain-fit: the artwork keeps its exact supplied proportions
        // inside the widget's square stage. Transparency is preserved.
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // Switching expressions never flashes blank between decodes.
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return fallback;
  }
}
