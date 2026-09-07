/// Canonical VAN expression artwork integration tests.
///
/// Proves the production pipeline
///   VAN EVENT → STATE RESOLVER → VanState → VISUAL ASSET SELECTION
///             → CANONICAL VAN EXPRESSION → VanWidget
/// end-to-end for the supplied (canonical, unmodified) art set:
///
///   1. every canonical expression can be resolved from the catalog;
///   2. every VanState maps to the intended canonical expression;
///   3. every wired production event lands on available canonical art;
///   4. missing assets trigger the fallback safely (no crash, no broken
///      image widget reaching the screen);
///   5. the widget renders the canonical art instead of the fallback
///      painter when the art is available — including under reduced motion;
///   6. accessibility: the semantics label names the visible expression.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

VanAssetCatalog _catalogWith(List<VanExpressionArt> expressions) =>
    VanAssetCatalog(const <VanVisualAsset>[], expressions: expressions);

/// The canonical art set with exactly one expression pointed at a missing
/// file, to exercise the safe-fallback path deterministically.
VanAssetCatalog catalogWithMissingAsset() {
  const broken = VanExpressionArt(
    id: 'van_expression_thinking_broken',
    expression: VanExpression.thinking,
    path: 'assets/van/expressions/definitely_missing.png',
    width: 100,
    height: 100,
    available: true,
  );
  return _catalogWith(
    kVanCanonicalExpressionArt
        .map((art) => art.expression == VanExpression.thinking ? broken : art)
        .toList(growable: false),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canonical expression resolution (catalog API)', () {
    test('every canonical expression resolves to available art', () {
      for (final expression in VanExpression.values) {
        final art = VanAssetCatalog.v1.expressionFor(expression);
        expect(art.isAvailable, isTrue,
            reason: '${expression.name} must resolve to the supplied artwork');
        expect(art.expression, expression);
        expect(art.path, 'assets/van/expressions/${expression.name}.png');
        expect(art.width, greaterThan(0));
        expect(art.height, greaterThan(0));
      }
    });

    test('every canonical expression PNG exists in the bundle', () {
      for (final expression in VanExpression.values) {
        final art = VanAssetCatalog.v1.expressionFor(expression);
        expect(File(art.path).existsSync(), isTrue,
            reason: '${art.path} must exist for ${expression.name}');
      }
    });

    test('the placeholder catalog resolves nothing (art-free hosts)', () {
      for (final expression in VanExpression.values) {
        expect(VanAssetCatalog.placeholder.expressionFor(expression)
            .isAvailable, isFalse);
      }
      for (final state in VanState.values) {
        expect(VanAssetCatalog.placeholder.staticArtForState(state), isNull);
      }
    });

    test('expressionForState is deterministic across calls', () {
      for (final state in VanState.values) {
        final a = VanAssetCatalog.v1.expressionForState(state);
        final b = VanAssetCatalog.v1.expressionForState(state);
        expect(a, equals(b), reason: '${state.name} must resolve stably');
      }
    });
  });

  group('VanState → canonical expression mapping', () {
    const expected = <VanState, VanExpression>{
      VanState.idle: VanExpression.neutral,
      VanState.happy: VanExpression.happy,
      VanState.thinking: VanExpression.thinking,
      VanState.focus: VanExpression.thinking,
      VanState.caring: VanExpression.motivating,
      VanState.surprised: VanExpression.excited,
      VanState.sad: VanExpression.sleepy,
      VanState.funny: VanExpression.happy,
      VanState.achievement: VanExpression.achievement,
      VanState.speaking: VanExpression.motivating,
      VanState.error: VanExpression.confused,
    };

    test('every state maps to the intended canonical expression', () {
      for (final state in VanState.values) {
        expect(state.canonicalExpression, expected[state],
            reason: '${state.name} must map to '
                '${expected[state]!.name}, got '
                '${state.canonicalExpression.name}');
      }
    });

    test('no supplied artwork is unreachable', () {
      final reachable = VanState.values
          .map((s) => s.canonicalExpression)
          .toSet();
      expect(reachable, VanExpression.values.toSet(),
          reason: 'all eight canonical expressions must be reachable from '
              'the state vocabulary');
    });

    test('static art selection honours animation-first precedence', () {
      // The reserved Lottie entries are unavailable, so canonical static art
      // is the production visual for every state today.
      for (final state in VanState.values) {
        expect(VanAssetCatalog.v1.staticArtForState(state), isNotNull,
            reason: '${state.name} must select canonical static art while '
                'the animation layer is still pending');
      }
    });
  });

  group('production event pipeline → canonical art', () {
    test('every wired event resolves to available canonical art', () {
      const wiredEvents = <VanEventType>[
        VanEventType.appOpened,
        VanEventType.lessonStarted,
        VanEventType.lessonCompleted,
        VanEventType.quizStarted,
        VanEventType.quizAnswerCorrect,
        VanEventType.quizAnswerWrong,
        VanEventType.quizCompleted,
        VanEventType.perfectScore,
        VanEventType.aiThinking,
        VanEventType.aiResponseStarted,
        VanEventType.aiResponseFinished,
        VanEventType.userMessageReceived,
        VanEventType.userIdle,
        VanEventType.achievementUnlocked,
        VanEventType.streakExtended,
        VanEventType.onboardingCompleted,
        VanEventType.errorOccurred,
        VanEventType.companionTapped,
      ];

      final expectedExpression = <VanEventType, VanExpression>{
        VanEventType.appOpened: VanExpression.happy,
        VanEventType.lessonStarted: VanExpression.happy,
        VanEventType.lessonCompleted: VanExpression.achievement,
        VanEventType.quizStarted: VanExpression.thinking,
        VanEventType.quizAnswerCorrect: VanExpression.happy,
        VanEventType.quizAnswerWrong: VanExpression.motivating,
        VanEventType.quizCompleted: VanExpression.achievement,
        VanEventType.perfectScore: VanExpression.achievement,
        VanEventType.aiThinking: VanExpression.thinking,
        VanEventType.aiResponseStarted: VanExpression.motivating,
        VanEventType.aiResponseFinished: VanExpression.neutral,
        VanEventType.userMessageReceived: VanExpression.thinking,
        VanEventType.userIdle: VanExpression.neutral,
        VanEventType.achievementUnlocked: VanExpression.achievement,
        VanEventType.streakExtended: VanExpression.excited,
        VanEventType.onboardingCompleted: VanExpression.happy,
        VanEventType.errorOccurred: VanExpression.confused,
        VanEventType.companionTapped: VanExpression.happy,
      };

      for (final type in wiredEvents) {
        final reaction = VanReactionResolver.resolve(VanEvent(type));
        final art = VanAssetCatalog.v1
            .expressionForState(reaction.state);
        expect(art.isAvailable, isTrue,
            reason: '$type → ${reaction.state.name} must land on available '
                'canonical artwork');
        expect(art.expression, expectedExpression[type],
            reason: '$type must present the ${expectedExpression[type]!.name} '
                'expression, got ${art.expression.name}');
      }
    });
  });

  group('VanWidget renders the canonical artwork', () {
    testWidgets('available art replaces the fallback painter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: VanWidget(
                  state: VanState.thinking,
                  size: 120,
                  assetCatalog: VanAssetCatalog.v1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey('van-flutter-fallback')),
        findsNothing,
        reason: 'the fallback painter must not render while canonical art '
            'is available',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing expression asset falls back safely, no crash',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: VanWidget(
                  state: VanState.thinking,
                  size: 120,
                  assetCatalog: catalogWithMissingAsset(),
                ),
              ),
            ),
          ),
        ),
      );
      // One pump is enough: the missing-asset failure surfaces at the first
      // build and the errorBuilder swaps in the fallback painter.
      await tester.pump();

      expect(
        find.byKey(const ValueKey('van-flutter-fallback')),
        findsOneWidget,
        reason: 'an unavailable canonical asset must fall back to the '
            'deterministic Flutter painter',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion still shows the static canonical art '
        '(motionless by definition)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: VanWidget(
                    state: VanState.achievement,
                    size: 120,
                    assetCatalog: VanAssetCatalog.v1,
                    visualBuilder: (context, asset, fallback) =>
                        const SizedBox(key: ValueKey('external-visual')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(kVanCanonicalArtKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey('external-visual')),
        findsNothing,
        reason: 'reduced motion bypasses animated builders — static art is '
            'the accessible presentation',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics label names the visible expression', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: VanWidget(
                  state: VanState.thinking,
                  size: 120,
                  assetCatalog: VanAssetCatalog.v1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Van — thinking'),
        findsOneWidget,
        reason: 'expression changes must be exposed to accessibility '
            'systems, not communicated by artwork alone',
      );
      handle.dispose();
    });

    testWidgets('an explicit semanticLabel override wins', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: VanWidget(
                  state: VanState.surprised,
                  size: 120,
                  semanticLabel: 'Van says hello',
                  assetCatalog: VanAssetCatalog.v1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Van says hello'), findsOneWidget);
      handle.dispose();
    });
  });
}
