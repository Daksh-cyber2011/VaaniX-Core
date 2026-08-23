/// Replaceable VAN animation asset contract.
library;

import 'package:flutter/foundation.dart';

import 'package:vaanix_app/features/van/domain/van_state.dart';

enum VanAssetFormat { flutter, lottie }

@immutable
class VanVisualAsset {
  const VanVisualAsset({
    required this.id,
    required this.state,
    required this.format,
    this.path,
    this.loop = false,
    this.width = 512,
    this.height = 512,
  });

  final String id;
  final VanState state;
  final VanAssetFormat format;
  final String? path;
  final bool loop;
  final int width;
  final int height;

  bool get isAvailable => path != null && path!.isNotEmpty;
}

/// An injected catalog lets final art arrive without changing [VanWidget].
@immutable
class VanAssetCatalog {
  const VanAssetCatalog(this.assets);

  final List<VanVisualAsset> assets;

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

  /// V1 ships no artwork yet. Flutter motion is therefore the intentional,
  /// accessible fallback rather than a missing-asset error.
  static const placeholder = VanAssetCatalog(<VanVisualAsset>[]);
}
