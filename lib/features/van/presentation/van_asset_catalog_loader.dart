/// Loads the VAN animation catalog from its single JSON source.
///
/// `assets/van/metadata/van_assets.json` is the authoritative catalog: it is
/// what art directors and the asset pipeline edit. The Dart list in
/// [VanAssetCatalog.v1] remains ONLY as a byte-for-byte fallback for
/// malformed/missing assets (same pattern as the curriculum loader), and a
/// parity test pins the two together so they cannot drift.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';

/// Bundle path of the catalog metadata (declared in pubspec assets).
const String kVanAssetsMetadataPath = 'assets/van/metadata/van_assets.json';

/// Pure, testable parser: raw catalog JSON -> [VanAssetCatalog].
///
/// Throws [FormatException]/[TypeError] on structurally invalid input — the
/// async loader is responsible for falling back to the Dart contract.
VanAssetCatalog parseVanAssetCatalogJson(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final dimensions = map['dimensions'] as Map<String, dynamic>?;
  final width = (dimensions?['width'] as num?)?.toInt() ?? 512;
  final height = (dimensions?['height'] as num?)?.toInt() ?? 512;
  final entries = map['assets'] as List<dynamic>? ?? const [];
  final assets = entries
      .map((e) {
        final m = e as Map<String, dynamic>;
        return VanVisualAsset(
          id: m['id'] as String,
          state: VanState.values.byName(m['state'] as String),
          format: (m['format'] as String?) == 'flutter'
              ? VanAssetFormat.flutter
              : VanAssetFormat.lottie,
          path: m['path'] as String?,
          available: (m['available'] as bool?) ?? false,
          loop: (m['loop'] as bool?) ?? false,
          width: width,
          height: height,
        );
      })
      .toList(growable: false);
  return VanAssetCatalog(assets);
}

/// Loads the catalog from the bundled JSON metadata.
///
/// Any failure (asset missing from an unusual bundle, malformed JSON) falls
/// back to the Dart [VanAssetCatalog.v1] contract so VAN keeps rendering.
Future<VanAssetCatalog> loadVanAssetCatalog({
  String path = kVanAssetsMetadataPath,
}) async {
  try {
    final raw = await rootBundle.loadString(path);
    return parseVanAssetCatalogJson(raw);
  } catch (_) {
    return VanAssetCatalog.v1;
  }
}

/// Resolved VAN asset catalog. The first successful read wins for the
/// lifetime of the container; [VanWidget] falls back to the Dart contract
/// while the future is pending or when no provider scope exists (tests).
final vanAssetCatalogProvider = FutureProvider<VanAssetCatalog>(
  (ref) => loadVanAssetCatalog(),
  name: 'vanAssetCatalogProvider',
);

@visibleForTesting
bool vanVisualAssetsMatch(VanVisualAsset a, VanVisualAsset b) {
  return a.id == b.id &&
      a.state == b.state &&
      a.format == b.format &&
      a.path == b.path &&
      a.available == b.available &&
      a.loop == b.loop &&
      a.width == b.width &&
      a.height == b.height;
}
