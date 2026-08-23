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
  });

  testWidgets('finite reactions return to idle deterministically', (tester) async {
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
}
