/// VAN asset catalog parity: the bundled JSON metadata is the single source
/// of truth; the Dart `VanAssetCatalog.v1` list is only a fallback contract.
/// This test pins the two together so they cannot drift silently.
///
/// Since schemaVersion 3 the catalog also carries the canonical STATIC
/// expression artwork (`expressions`), pinned against
/// `kVanCanonicalExpressionArt` the same way.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/features/van/van.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('van_assets.json ↔ Dart catalog parity', () {
    test('every JSON entry maps 1:1 onto the Dart v1 contract', () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final catalog = parseVanAssetCatalogJson(raw);

      expect(catalog.assets, hasLength(VanAssetCatalog.v1.assets.length),
          reason: 'the fallback contract must track the JSON catalog size');

      for (var i = 0; i < catalog.assets.length; i++) {
        final fromJson = catalog.assets[i];
        final fromDart = VanAssetCatalog.v1.assets[i];
        expect(
          vanVisualAssetsMatch(fromJson, fromDart),
          isTrue,
          reason: 'JSON entry #${i + 1} (${fromJson.id}) drifted from the '
              'Dart fallback contract (${fromDart.id})',
        );
      }
    });

    test('the catalog covers every presentation state exactly once', () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final catalog = parseVanAssetCatalogJson(raw);

      final jsonStates = catalog.assets.map((a) => a.state).toSet();
      expect(jsonStates, VanState.values.toSet(),
          reason: 'every VanState needs a declared visual (fallback or art)');
      expect(catalog.assets.length, VanState.values.length,
          reason: 'one declared visual per state, no duplicates');
    });

    test('every canonical expression maps 1:1 onto the Dart contract', () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final catalog = parseVanAssetCatalogJson(raw);

      expect(
        catalog.expressions,
        hasLength(kVanCanonicalExpressionArt.length),
        reason: 'the JSON expression set must track the Dart expression set',
      );
      for (var i = 0; i < catalog.expressions.length; i++) {
        expect(
          vanExpressionArtMatch(
              catalog.expressions[i], kVanCanonicalExpressionArt[i]),
          isTrue,
          reason: 'JSON expression #${i + 1} '
              '(${catalog.expressions[i].id}) drifted from the Dart contract '
              '(${kVanCanonicalExpressionArt[i].id})',
        );
      }

      final jsonExpressions =
          catalog.expressions.map((e) => e.expression).toSet();
      expect(jsonExpressions, VanExpression.values.toSet(),
          reason: 'all eight canonical expressions must be declared, '
              'each exactly once');
    });

    test('every canonical expression PNG exists at its declared path', () {
      // Asset-integrity guard: a renamed or deleted canonical file would
      // otherwise only surface as a runtime fallback, never as a failure.
      for (final art in kVanCanonicalExpressionArt) {
        expect(
          File(art.path).existsSync(),
          isTrue,
          reason: '${art.path} is declared by the catalog but missing on disk',
        );
      }
    });

    test('catalog JSON is structurally valid metadata (schemaVersion 3)', () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expect(map['schemaVersion'], 3);
      expect(map['characterId'], AppConstants.companionCodeName);
      expect(map['publicName'], AppConstants.companionDefaultName);
    });

    test('loader falls back to the Dart contract when the asset is missing',
        () async {
      final catalog = await loadVanAssetCatalog(
        path: 'assets/van/animations/definitely_missing_catalog.json',
      );
      expect(catalog.assets, hasLength(VanAssetCatalog.v1.assets.length));
      expect(
        vanVisualAssetsMatch(
          catalog.assets.first,
          VanAssetCatalog.v1.assets.first,
        ),
        isTrue,
      );
      // The Dart fallback contract still carries the canonical expressions.
      expect(catalog.expressions, hasLength(kVanCanonicalExpressionArt.length));
    });

    test('the real bundled asset loads through rootBundle', () async {
      // In `flutter test` the declared pubspec assets are served by the test
      // asset bundle; if a future harness changes that, the loader's
      // fallback (tested above) keeps production green — this test simply
      // documents the happy path.
      final raw = await rootBundle.loadString(kVanAssetsMetadataPath);
      final catalog = parseVanAssetCatalogJson(raw);
      expect(catalog.assets, isNotEmpty);
      expect(catalog.expressions, isNotEmpty);
    });
  });
}
