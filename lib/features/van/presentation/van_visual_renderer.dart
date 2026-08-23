/// Default VAN visual renderer with a safe Lottie-to-Flutter fallback path.
library;

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';

class VanVisualRenderer extends StatelessWidget {
  const VanVisualRenderer({
    super.key,
    required this.asset,
    required this.fallback,
  });

  final VanVisualAsset asset;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (asset.format != VanAssetFormat.lottie || !asset.isAvailable) {
      return fallback;
    }

    return Lottie.asset(
      asset.path!,
      repeat: asset.loop,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
