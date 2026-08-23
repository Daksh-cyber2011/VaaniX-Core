import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

void main() {
  group('VanController', () {
    test('starts idle without a reaction', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      expect(controller.state.current, VanState.idle);
      expect(controller.state.reaction, isNull);
    });

    test('maps AI lifecycle events to thinking, speaking, and idle', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.aiThinking));
      expect(controller.state.current, VanState.thinking);
      expect(controller.state.isLoading, isTrue);

      controller.dispatch(const VanEvent(VanEventType.aiResponseStarted));
      expect(controller.state.current, VanState.speaking);
      controller.dispatch(const VanEvent(VanEventType.aiResponseFinished));
      expect(controller.state.current, VanState.idle);
    });

    test('maps Learn and Exam lifecycle events to canonical states', () {
      expect(
        VanReactionResolver.resolve(const VanEvent(VanEventType.lessonStarted))
            .state,
        VanState.happy,
      );
      expect(
        VanReactionResolver.resolve(
          const VanEvent(VanEventType.lessonCompleted),
        ).state,
        VanState.achievement,
      );
      expect(
        VanReactionResolver.resolve(const VanEvent(VanEventType.quizStarted))
            .state,
        VanState.focus,
      );
      expect(
        VanReactionResolver.resolve(
          const VanEvent(VanEventType.quizAnswerWrong),
        ).state,
        VanState.caring,
      );
    });

    test('does not let a low priority interaction interrupt achievement', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      expect(
        controller.dispatch(const VanEvent(VanEventType.lessonCompleted)),
        isTrue,
      );
      expect(
        controller.dispatch(const VanEvent(VanEventType.companionTapped)),
        isFalse,
      );
      expect(controller.state.current, VanState.achievement);
    });

    test('allows a critical error to interrupt an achievement', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.lessonCompleted));
      expect(
        controller.dispatch(const VanEvent(VanEventType.errorOccurred)),
        isTrue,
      );
      expect(controller.state.current, VanState.error);
    });

    test('disposal cancels a pending fallback safely', () {
      final controller = VanController();
      controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
      expect(controller.state.current, VanState.happy);
      controller.dispose();
    });
  });

  testWidgets('finite reactions return to idle deterministically',
      (tester) async {
    final controller = VanController();
    addTearDown(controller.dispose);

    controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
    expect(controller.state.current, VanState.happy);
    await tester.pump(const Duration(milliseconds: 1401));
    expect(controller.state.current, VanState.idle);
  });

  testWidgets('VanWidget renders the Flutter fallback for an unavailable asset',
      (tester) async {
    const unavailableCatalog = VanAssetCatalog([
      VanVisualAsset(
        id: 'duck_idle_loop',
        state: VanState.idle,
        format: VanAssetFormat.lottie,
        path: 'assets/van/animations/missing.json',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VanWidget(
          assetCatalog: unavailableCatalog,
          showSpeechBubble: true,
          dialogueText: 'Ready when you are.',
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('van-flutter-fallback')), findsOneWidget);
    expect(find.text('Ready when you are.'), findsOneWidget);
  });

  testWidgets('every supported presentation state has a fallback visual',
      (tester) async {
    for (final state in VanState.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: VanWidget(state: state, size: 120))),
      ));

      expect(
        find.byKey(const ValueKey('van-flutter-fallback')),
        findsOneWidget,
        reason: '${state.name} should remain legible without final art assets',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'reduced motion keeps the accessible fallback over an asset builder',
      (tester) async {
    var builderCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: VanWidget(
            state: VanState.achievement,
            visualBuilder: (context, asset, fallback) {
              builderCalled = true;
              return const SizedBox(key: ValueKey('external-visual'));
            },
          ),
        ),
      ),
    ));

    expect(builderCalled, isFalse);
    expect(find.byKey(const ValueKey('van-flutter-fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('external-visual')), findsNothing);
  });

  testWidgets('speech bubble wraps safely at a narrow text-scaled width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(260, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(260, 500),
          textScaler: TextScaler.linear(1.5),
        ),
        child: Scaffold(
          body: Center(
            child: VanWidget(
              size: 100,
              showSpeechBubble: true,
              dialogueText: 'Let us take this one step at a time together.',
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Let us take this one step at a time together.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
