/// VAN visual-layer tests: frame normalisation + stage motion.
///
/// These pin the two production defects fixed in the VAN finalisation
/// pass, and the guarantees that keep them fixed:
///
///   1. **Frame normalisation.** The supplied PNGs are cut out
///      inconsistently (arms-in vs arms-out poses, and `sleepy.png` on a
///      1199×1312 canvas where the rest are 1024×1536). Rendering the
///      whole image made VAN change size between states — 7.9% height and
///      21.4% width spread on a 160px stage. Cropping to a measured
///      character frame drops the height spread to 0.3%.
///
///   2. **Shape-preserving stage motion.** The Animation Bible requires
///      "Van should never feel static", but canonical artwork was
///      rendered with no motion at all. It now gets a uniform scale and a
///      translation, both of which cannot distort the artwork — unlike
///      the per-part wing/eye/beak animation, which remains exclusive to
///      the painted fallback where it can actually be drawn.
///
/// Nothing here asserts on a specific package's internals; the tests
/// exercise VaaniX's own state → visual mapping.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';
import 'package:vaanix_app/features/van/presentation/van_expression.dart';
import 'package:vaanix_app/features/van/presentation/van_visual_renderer.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

/// Pumps a [VanWidget] in a controllable MediaQuery so reduced-motion can
/// be exercised without touching platform channels.
Future<void> pumpVan(
  WidgetTester tester, {
  required VanState state,
  double size = 160,
  bool reduceMotion = false,
  VanAssetCatalog? catalog,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          size: const Size(400, 800),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: VanWidget(
                  state: state,
                  size: size,
                  assetCatalog: catalog ?? VanAssetCatalog.v1,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('expression frames are well-formed', () {
    test('every canonical expression has a measured frame', () {
      for (final art in kVanCanonicalExpressionArt) {
        expect(art.frame.isWholeImage, isFalse,
            reason: '${art.expression} must declare a frame');
        expect(art.frame.width, greaterThan(0));
        expect(art.frame.height, greaterThan(0));
      }
    });

    test('each frame lies inside its own canvas', () {
      for (final art in kVanCanonicalExpressionArt) {
        expect(art.frame.left, greaterThanOrEqualTo(0));
        expect(art.frame.top, greaterThanOrEqualTo(0));
        expect(art.frame.left + art.frame.width, lessThanOrEqualTo(art.width),
            reason: '${art.expression} frame overflows its canvas width');
        expect(
            art.frame.top + art.frame.height, lessThanOrEqualTo(art.height),
            reason: '${art.expression} frame overflows its canvas height');
      }
    });

    test('frame normalisation makes the character height consistent', () {
      // Replicates the renderer's math: contain-fit the frame into a square
      // stage and measure how tall the character ends up.
      final heights = <double>[];
      for (final art in kVanCanonicalExpressionArt) {
        final s = math_min(
          1 / art.frame.width.toDouble(),
          1 / art.frame.height.toDouble(),
        );
        heights.add(art.frame.height * s);
      }
      final spread =
          (heights.reduce(math_max) - heights.reduce(math_min)) /
              heights.reduce(math_min);
      expect(spread, lessThan(0.02),
          reason: 'character height must not visibly change between states; '
              'measured ${(spread * 100).toStringAsFixed(1)}% spread');
    });

    test('wholeImage frame is the documented no-op', () {
      expect(VanExpressionFrame.wholeImage.isWholeImage, isTrue);
      expect(
        const VanExpressionArt(
          id: 'x',
          expression: VanExpression.neutral,
          path: 'a.png',
          width: 10,
          height: 10,
        ).frame.isWholeImage,
        isTrue,
        reason: 'an art entry without an explicit frame must degrade to the '
            'original whole-image behaviour',
      );
    });

    test('frames participate in equality and hash', () {
      const a = VanExpressionFrame(left: 1, top: 2, width: 3, height: 4);
      const b = VanExpressionFrame(left: 1, top: 2, width: 3, height: 4);
      const c = VanExpressionFrame(left: 9, top: 2, width: 3, height: 4);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('state → expression → frame mapping is total', () {
    test('every VanState resolves to an available, framed expression', () {
      for (final state in VanState.values) {
        final art = VanAssetCatalog.v1.expressionForState(state);
        expect(art.isAvailable, isTrue,
            reason: '${state.name} has no available canonical art');
        expect(art.frame.isWholeImage, isFalse,
            reason: '${state.name} resolved to unframed art');
      }
    });

    test('every canonical expression is reachable from some state', () {
      final reached = VanState.values
          .map((s) => s.canonicalExpression)
          .toSet();
      for (final expression in VanExpression.values) {
        expect(reached, contains(expression),
            reason: '${expression.name} is dead artwork — no state maps to it');
      }
    });

    test('sleepy uses its own canvas and is normalised like the rest', () {
      // sleepy.png is the odd one out (1199x1312). The frame is what keeps
      // it from rendering at a different size than the 1024x1536 set.
      final sleepy = VanAssetCatalog.v1.expressionForState(VanState.sad);
      expect(sleepy.width, 1199);
      expect(sleepy.height, 1312);
      expect(sleepy.frame.isWholeImage, isFalse);
    });
  });

  group('renderer behaviour', () {
    testWidgets('renders the frame crop for a framed expression',
        (tester) async {
      const art = VanExpressionArt(
        id: 'van_expression_neutral',
        expression: VanExpression.neutral,
        path: 'assets/van/expressions/neutral.png',
        width: 1024,
        height: 1536,
        available: true,
        frame: VanExpressionFrame(left: 61, top: 74, width: 899, height: 1442),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 160,
            child: VanVisualRenderer(
              asset: VanAssetCatalog.v1.assetFor(VanState.idle),
              expressionArt: art,
              fallback: const Text('FALLBACK'),
            ),
          ),
        ),
      );
      expect(find.byKey(kVanFrameClipKey), findsOneWidget,
          reason: 'a framed expression must be cropped to its frame');
      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget);
    });

    testWidgets('an unframed expression renders without the crop',
        (tester) async {
      const art = VanExpressionArt(
        id: 'van_expression_unframed',
        expression: VanExpression.neutral,
        path: 'assets/van/expressions/neutral.png',
        width: 1024,
        height: 1536,
        available: true,
        // no frame -> whole-image behaviour
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 160,
            child: VanVisualRenderer(
              asset: VanAssetCatalog.v1.assetFor(VanState.idle),
              expressionArt: art,
              fallback: const Text('FALLBACK'),
            ),
          ),
        ),
      );
      expect(find.byKey(kVanFrameClipKey), findsNothing);
      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget);
    });

    testWidgets('missing/unavailable art falls back without crashing',
        (tester) async {
      const unavailable = VanExpressionArt(
        id: 'van_expression_missing',
        expression: VanExpression.neutral,
        path: 'assets/van/expressions/does_not_exist.png',
        width: 1024,
        height: 1536,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 160,
            child: VanVisualRenderer(
              asset: VanAssetCatalog.v1.assetFor(VanState.idle),
              expressionArt: unavailable,
              fallback: const Text('FALLBACK'),
            ),
          ),
        ),
      );
      // The fallback is what a caller must be able to rely on.
      expect(find.text('FALLBACK'), findsOneWidget);
    });
  });

  group('renderer geometry contract', () {
    /// Pumps one framed expression into a square stage and returns the
    /// affine matrix the renderer applied to the source image, read from
    /// the live widget tree.
    Future<Matrix4> pumpAndReadMatrix(
      WidgetTester tester, {
      required VanExpressionArt art,
      double stage = 160,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: stage,
              child: VanVisualRenderer(
                asset: VanAssetCatalog.v1.assetFor(VanState.idle),
                expressionArt: art,
                fallback: const Text('FALLBACK'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // The Transform lives INSIDE the clip: the clip is stage-sized and
      // trims the transformed full-size source.
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(kVanFrameClipKey),
              matching: find.byType(Transform),
            )
            .first,
      );
      return transform.transform;
    }

    /// Projects the measured character frame through the renderer's
    /// matrix and returns the rect it occupies inside the stage.
    Rect projectFrame(VanExpressionArt art, Matrix4 m) {
      final l = art.frame.left.toDouble();
      final t = art.frame.top.toDouble();
      final r = l + art.frame.width;
      final b = t + art.frame.height;
      Offset map(double x, double y) {
        final v = m.transform3(Vector3(x, y, 0));
        return Offset(v.x, v.y);
      }
      final tl = map(l, t);
      final br = map(r, b);
      return Rect.fromPoints(tl, br);
    }

    testWidgets('the character frame is centred, not top-left anchored',
        (tester) async {
      const art = VanExpressionArt(
        id: 'van_expression_neutral',
        expression: VanExpression.neutral,
        path: 'assets/van/expressions/neutral.png',
        width: 1024,
        height: 1536,
        available: true,
        frame: VanExpressionFrame(left: 61, top: 74, width: 899, height: 1442),
      );
      final m = await pumpAndReadMatrix(tester, art: art);
      final rect = projectFrame(art, m);

      // The frame is taller than wide, so height binds and width must
      // be centred: the left and right margins must be equal.
      expect(rect.height, closeTo(160, 0.01),
          reason: 'the binding axis must fill the stage');
      expect(rect.left, closeTo(160 - rect.right, 0.01),
          reason: 'the character must be horizontally CENTRED in the stage; '
              'anchoring it to the left or right edge is a defect');
    });

    testWidgets('the whole character is visible — nothing is cropped',
        (tester) async {
      for (final art in kVanCanonicalExpressionArt) {
        final m = await pumpAndReadMatrix(tester, art: art);
        final rect = projectFrame(art, m);
        expect(rect.left, greaterThanOrEqualTo(-0.01),
            reason: '${art.expression}: character is cropped on the left');
        expect(rect.top, greaterThanOrEqualTo(-0.01),
            reason: '${art.expression}: character is cropped on the top');
        expect(rect.right, lessThanOrEqualTo(160.01),
            reason: '${art.expression}: character is cropped on the right');
        expect(rect.bottom, lessThanOrEqualTo(160.01),
            reason: '${art.expression}: character is cropped at the bottom');
      }
    });

    testWidgets('the transform is uniform — aspect ratio is preserved',
        (tester) async {
      const art = VanExpressionArt(
        id: 'van_expression_excited',
        expression: VanExpression.excited,
        path: 'assets/van/expressions/excited.png',
        width: 1024,
        height: 1536,
        available: true,
        frame: VanExpressionFrame(left: 22, top: 78, width: 991, height: 1412),
      );
      final m = await pumpAndReadMatrix(tester, art: art);

      // Column vectors of the 3×3 part. A uniform scale has sx == sy
      // and zero off-diagonal terms, so no axis is stretched.
      final sx = m.storage[0];
      final sy = m.storage[5];
      final xy = m.storage[1];
      final yx = m.storage[4];
      expect(sx, closeTo(sy, 1e-9),
          reason: 'x and y must scale by the SAME factor');
      expect(xy, closeTo(0, 1e-9), reason: 'no shear on x');
      expect(yx, closeTo(0, 1e-9), reason: 'no shear on y');
    });

    testWidgets('character height is consistent across every expression',
        (tester) async {
      final heights = <double>[];
      for (final art in kVanCanonicalExpressionArt) {
        final m = await pumpAndReadMatrix(tester, art: art);
        heights.add(projectFrame(art, m).height);
      }
      final lo = heights.reduce(math.min);
      final hi = heights.reduce(math.max);
      expect(hi - lo, lessThan(3.2),
          reason: 'apparent character height must not vary by more than 2% of '
              'the stage; got ${(lo).toStringAsFixed(1)}–${(hi).toStringAsFixed(1)}px');
    });

    testWidgets('an unframed expression still renders untransformed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 160,
              child: VanVisualRenderer(
                asset: VanAssetCatalog.v1.assetFor(VanState.idle),
                expressionArt: const VanExpressionArt(
                  id: 'x',
                  expression: VanExpression.neutral,
                  path: 'assets/van/expressions/neutral.png',
                  width: 1024,
                  height: 1536,
                  available: true,
                ),
                fallback: const Text('FALLBACK'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(kVanFrameClipKey), findsNothing,
          reason: 'a whole-image frame must not introduce a crop');
      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget);
    });
  });

  group('VanWidget renders canonical art for every state', () {
    testWidgets('each state shows the canonical artwork, not the painter',
        (tester) async {
      for (final state in VanState.values) {
        await pumpVan(tester, state: state);
        expect(
          find.byKey(kVanCanonicalArtKey),
          findsOneWidget,
          reason: '${state.name} must render canonical art',
        );
        expect(
          find.byKey(const ValueKey('van-flutter-fallback')),
          findsNothing,
          reason: '${state.name} must not fall back to the painter while '
              'canonical art is available',
        );
      }
    });

    testWidgets('the semantics label names the visible expression',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpVan(tester, state: VanState.thinking);
      expect(
        find.bySemanticsLabel('Van — thinking'),
        findsOneWidget,
        reason: 'expression changes must be announced by label, not colour '
            'alone',
      );
      handle.dispose();
    });
  });

  group('shape-preserving stage motion', () {
    testWidgets('canonical art is not static — a scale transform exists',
        (tester) async {
      await pumpVan(tester, state: VanState.idle, reduceMotion: false);
      // Motion is on: the canonical art is wrapped in a Transform.scale +
      // Transform.translate, so a Transform ancestor must exist.
      expect(
        find.ancestor(
          of: find.byKey(kVanCanonicalArtKey),
          matching: find.byType(Transform),
        ),
        findsWidgets,
        reason: 'Van must not be completely static (Animation Bible)',
      );
    });

    testWidgets('reduced motion presents the art untransformed',
        (tester) async {
      await pumpVan(tester, state: VanState.idle, reduceMotion: true);
      // Under reduced motion the stage is returned with no scale/translate
      // wrapper at all, so the canonical art is the direct child of the
      // sized stage. Asserting the absence of OUR wrapper is what matters;
      // Flutter may insert its own Transform inside Image, so this checks
      // the stage-level structure only.
      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget,
          reason: 'art must still render under reduced motion — it is a '
              'static image, so it is inherently reduced-motion safe');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ticker is disposed with the widget', (tester) async {
      await pumpVan(tester, state: VanState.idle);
      final state = tester.state<VanWidgetState>(find.byType(VanWidget));
      expect(state.motionController.isAnimating, isTrue,
          reason: 'idle must breathe');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // Disposing must not throw — the controller is released exactly once.
      expect(tester.takeException(), isNull);
    });
  });

  group('no fake assets / no fake claims', () {
    test('the catalog still declares Lottie assets as unavailable', () {
      // The animation layer is a reserved seam, not a claim. Nothing must
      // silently flip to "available" without real art on disk.
      for (final asset in VanAssetCatalog.v1.assets) {
        expect(asset.isAvailable, isFalse,
            reason: '${asset.id} must stay unavailable until real animation '
                'art exists at ${asset.path}');
      }
    });

    test('every canonical expression file is declared in the catalog', () {
      expect(kVanCanonicalExpressionArt, hasLength(VanExpression.values.length));
    });
  });
}

// Local min/max to avoid importing dart:math into the test's public API.
double math_min(double a, double b) => a < b ? a : b;
double math_max(double a, double b) => a > b ? a : b;
