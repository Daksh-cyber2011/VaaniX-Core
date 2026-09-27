/// VAN asset catalog parity: the bundled JSON metadata is the single source
/// of truth; the Dart `VanAssetCatalog.v1` list is only a fallback contract.
/// This test pins the two together so they cannot drift silently.
///
/// Since schemaVersion 3 the catalog also carries the canonical STATIC
/// expression artwork (`expressions`), pinned against
/// `kVanCanonicalExpressionArt` the same way.
///
/// schemaVersion 4 adds a measured `frame` per expression — the character's
/// non-transparent bounding box — so VAN renders at a consistent size
/// across states. Frames are pinned in parity too, and a metric test
/// fails if the apparent character height ever drifts by more than 2%.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

    test('catalog JSON is structurally valid metadata (schemaVersion 4)',
        () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // schemaVersion 4 adds the measured per-expression `frame` rectangle
      // used to normalise VAN's apparent size across expressions. The
      // version was bumped because the field is load-bearing, not
      // cosmetic: without it VAN visibly changes height and width
      // between states (7.9% / 21.4% spread on a 160px stage).
      expect(map['schemaVersion'], 4);
      expect(map['characterId'], AppConstants.companionCodeName);
      expect(map['publicName'], AppConstants.companionDefaultName);
    });

    test('every expression declares a frame inside its own canvas', () {
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expressions = (map['expressions'] as List).cast<Map<String, dynamic>>();
      for (final e in expressions) {
        final frame = e['frame'];
        expect(frame, isNotNull,
            reason: '${e['expression']} must declare a frame so VAN renders '
                'at a consistent size');
        final f = (frame as Map).cast<String, dynamic>();
        final w = (e['width'] as num).toInt();
        final h = (e['height'] as num).toInt();
        final left = (f['left'] as num).toInt();
        final top = (f['top'] as num).toInt();
        final fw = (f['width'] as num).toInt();
        final fh = (f['height'] as num).toInt();
        expect(fw, greaterThan(0), reason: '${e['expression']} frame width');
        expect(fh, greaterThan(0), reason: '${e['expression']} frame height');
        expect(left, greaterThanOrEqualTo(0));
        expect(top, greaterThanOrEqualTo(0));
        expect(left + fw, lessThanOrEqualTo(w),
            reason: '${e['expression']} frame must stay inside its canvas');
        expect(top + fh, lessThanOrEqualTo(h),
            reason: '${e['expression']} frame must stay inside its canvas');
      }
    });

    test('normalised frames give VAN a consistent height across expressions',
        () {
      // The point of the frame: under contain-fit every expression must
      // present the character at (near) the same stage height. This is the
      // metric that regressed before the fix (0.872 -> 0.941 of the stage).
      final raw =
          File('assets/van/metadata/van_assets.json').readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expressions = (map['expressions'] as List).cast<Map<String, dynamic>>();

      final heights = <double>[];
      for (final e in expressions) {
        final f = (e['frame'] as Map).cast<String, dynamic>();
        final fw = (f['width'] as num).toDouble();
        final fh = (f['height'] as num).toDouble();
        // contain-fit of the frame into a square stage:
        //   scale = min(1/fw, 1/fh);  character height = frameH * scale
        final scale = math.min(1 / fw, 1 / fh);
        heights.add(fh * scale);
      }
      final spread = (heights.reduce(math.max) - heights.reduce(math.min)) /
          heights.reduce(math.min);
      expect(spread, lessThan(0.02),
          reason: 'character height must be consistent within 2% across '
              'expressions; measured $spread');
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
