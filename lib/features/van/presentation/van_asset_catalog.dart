/// Replaceable VAN animation asset contract.
library;

import 'package:flutter/widgets.dart';

import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/features/van/presentation/van_expression.dart';

enum VanAssetFormat { flutter, lottie }

/// Rendering boundary between VAN behavior and an asset technology. A caller
/// can supply a Lottie, Rive, SVG, or custom painter and return [fallback] if
/// the asset cannot load.
typedef VanVisualBuilder = Widget Function(
  BuildContext context,
  VanVisualAsset asset,
  Widget fallback,
);

@immutable
class VanVisualAsset {
  const VanVisualAsset({
    required this.id,
    required this.state,
    required this.format,
    this.path,
    this.available = false,
    this.loop = false,
    this.width = 512,
    this.height = 512,
  });

  final String id;
  final VanState state;
  final VanAssetFormat format;
  final String? path;
  final bool available;
  final bool loop;
  final int width;
  final int height;

  bool get isAvailable => available && path != null && path!.isNotEmpty;
}

/// An injected catalog lets final art arrive without changing [VanWidget].
@immutable
class VanAssetCatalog {
  const VanAssetCatalog(
    this.assets, {
    this.expressions = const <VanExpressionArt>[],
  });

  final List<VanVisualAsset> assets;

  /// Canonical static expression artwork (the supplied VAN art set). Empty
  /// only in the art-free [placeholder] catalog used by tests and custom
  /// hosts that want the pure Flutter fallback.
  final List<VanExpressionArt> expressions;

  VanVisualAsset assetFor(VanState state) {
    return assets.firstWhere(
      (asset) => asset.state == state,
      orElse: () => VanVisualAsset(
        id: 'duck_${state.name}_flutter_fallback',
        state: state,
        format: VanAssetFormat.flutter,
      ),
    );
  }

  /// Stable semantic access to one canonical expression artwork. Returns an
  /// unavailable placeholder when the expression is not in the catalog, so
  /// callers never deal with nulls or raw paths.
  VanExpressionArt expressionFor(VanExpression expression) {
    return expressions.firstWhere(
      (art) => art.expression == expression,
      orElse: () => VanExpressionArt(
        id: 'van_expression_${expression.name}_unavailable',
        expression: expression,
        path: 'assets/van/expressions/${expression.name}.png',
        width: 0,
        height: 0,
      ),
    );
  }

  /// Canonical artwork for the expression closest to [state].
  VanExpressionArt expressionForState(VanState state) =>
      expressionFor(state.canonicalExpression);

  /// Canonical STATIC art for [state], or null when a final animation asset
  /// already supersedes it (animation-first precedence — when genuine
  /// Lottie/Rive animation assets land later they win over the static art;
  /// until then the canonical expressions are the production visual).
  VanExpressionArt? staticArtForState(VanState state) {
    final animation = assetFor(state);
    if (animation.format == VanAssetFormat.lottie && animation.isAvailable) {
      return null;
    }
    final art = expressionForState(state);
    return art.isAvailable ? art : null;
  }

  /// No artwork at all: every visual resolves to the Flutter fallback
  /// painter. Used by tests and by hosts that explicitly want the vector
  /// character regardless of the bundled art.
  static const placeholder = VanAssetCatalog(<VanVisualAsset>[]);

  /// V1's reserved asset set. The Lottie animation entries remain
  /// unavailable until approved animation art is dropped at the declared
  /// path and explicitly marked available; the canonical STATIC expression
  /// artwork is integrated and available now.
  static const v1 = VanAssetCatalog(<VanVisualAsset>[
    VanVisualAsset(
        id: 'duck_idle_loop',
        state: VanState.idle,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_idle_loop.json',
        loop: true),
    VanVisualAsset(
        id: 'duck_happy_short',
        state: VanState.happy,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_happy_short.json'),
    VanVisualAsset(
        id: 'duck_thinking_loop',
        state: VanState.thinking,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_thinking_loop.json',
        loop: true),
    VanVisualAsset(
        id: 'duck_focus_loop',
        state: VanState.focus,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_focus_loop.json',
        loop: true),
    VanVisualAsset(
        id: 'duck_caring_short',
        state: VanState.caring,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_caring_short.json'),
    VanVisualAsset(
        id: 'duck_surprised_short',
        state: VanState.surprised,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_surprised_short.json'),
    VanVisualAsset(
        id: 'duck_sad_soft',
        state: VanState.sad,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_sad_soft.json'),
    VanVisualAsset(
        id: 'duck_funny_short',
        state: VanState.funny,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_funny_short.json'),
    VanVisualAsset(
        id: 'duck_achievement_celebrate',
        state: VanState.achievement,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_achievement_celebrate.json'),
    VanVisualAsset(
        id: 'duck_speaking_loop',
        state: VanState.speaking,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_speaking_loop.json',
        loop: true),
    VanVisualAsset(
        id: 'duck_error_soft',
        state: VanState.error,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/duck_error_soft.json'),
  ], expressions: kVanCanonicalExpressionArt);
}
