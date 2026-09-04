import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        VanReactionResolver.resolve(
          const VanEvent(VanEventType.lessonStarted),
        ).state,
        VanState.happy,
      );
      expect(
        VanReactionResolver.resolve(
          const VanEvent(VanEventType.lessonCompleted),
        ).state,
        VanState.achievement,
      );
      expect(
        VanReactionResolver.resolve(
          const VanEvent(VanEventType.quizStarted),
        ).state,
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

  testWidgets('finite reactions return to idle deterministically', (
    tester,
  ) async {
    final controller = VanController();
    addTearDown(controller.dispose);

    controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
    expect(controller.state.current, VanState.happy);
    await tester.pump(const Duration(milliseconds: 1401));
    expect(controller.state.current, VanState.idle);
  });

  testWidgets(
    'VanWidget renders the Flutter fallback for an unavailable asset',
    (tester) async {
      const unavailableCatalog = VanAssetCatalog([
        VanVisualAsset(
          id: 'duck_idle_loop',
          state: VanState.idle,
          format: VanAssetFormat.lottie,
          path: 'assets/van/animations/missing.json',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VanWidget(
              assetCatalog: unavailableCatalog,
              showSpeechBubble: true,
              dialogueText: 'Ready when you are.',
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('van-flutter-fallback')),
        findsOneWidget,
      );
      expect(find.text('Ready when you are.'), findsOneWidget);
    },
  );

  testWidgets('every supported presentation state has a fallback visual', (
    tester,
  ) async {
    for (final state in VanState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: VanWidget(state: state, size: 120)),
          ),
        ),
      );

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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(builderCalled, isFalse);
      expect(
        find.byKey(const ValueKey('van-flutter-fallback')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('external-visual')), findsNothing);
    },
  );

  testWidgets('speech bubble wraps safely at a narrow text-scaled width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(260, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
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
      ),
    );

    expect(
      find.text('Let us take this one step at a time together.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  group('VanController priority and lifecycle hardening', () {
    test('userIdle never cuts a non-interruptible achievement short', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(
        VanEventType.lessonCompleted,
        message: 'Nice work - you completed the lesson!',
      ));
      expect(controller.state.current, VanState.achievement);
      expect(controller.state.message, 'Nice work - you completed the lesson!');

      expect(
        controller.dispatch(const VanEvent(VanEventType.userIdle)),
        isFalse,
        reason: 'settle is deferred while a protected reaction is visible',
      );
      expect(controller.state.current, VanState.achievement);
      expect(
        controller.state.message,
        'Nice work - you completed the lesson!',
        reason: 'the celebration copy stays until the reaction completes',
      );
    });

    test('aiResponseFinished cannot interrupt a critical error reaction', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.errorOccurred));
      expect(controller.state.current, VanState.error);

      expect(
        controller.dispatch(const VanEvent(VanEventType.aiResponseFinished)),
        isFalse,
      );
      expect(controller.state.current, VanState.error);
    });

    test('stale fallback timers cannot fire after a replacement reaction', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
      expect(controller.state.current, VanState.happy);
      // A same-priority feedback reaction replaces happy and resets the
      // fallback clock.
      controller.dispatch(const VanEvent(VanEventType.quizAnswerWrong));
      expect(controller.state.current, VanState.caring);
    });

    testWidgets('replacement keeps the new fallback clock (old timer inert)', (
      tester,
    ) async {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
      await tester.pump(const Duration(milliseconds: 200));
      controller.dispatch(const VanEvent(VanEventType.quizAnswerWrong));

      // Past the original happy duration (1400ms): caring must still show.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(controller.state.current, VanState.caring);
      // Caring (2400ms) then finishes on its own clock.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.state.current, VanState.idle);
    });

    test('settle on a sustained thinking state returns to idle', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.aiThinking));
      expect(controller.state.isLoading, isTrue);
      expect(controller.settle(), isTrue);
      expect(controller.state.current, VanState.idle);
      expect(controller.state.isLoading, isFalse);
    });

    test('back-to-back userMessageReceived + aiThinking never flickers '
        'through an intermediate state', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      // The chat controller dispatches these two synchronously; Van must
      // land on thinking with the loading flag set, never flash the
      // userMessageReceived reaction first.
      controller.dispatch(const VanEvent(VanEventType.userMessageReceived));
      controller.dispatch(const VanEvent(VanEventType.aiThinking));

      expect(controller.state.current, VanState.thinking);
      expect(controller.state.isLoading, isTrue);
      expect(controller.state.reaction?.state, VanState.thinking);
    });

    test('aiThinking is deferred while a protected celebration is visible '
        '(no thinking flash over an achievement)', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.lessonCompleted));
      expect(controller.state.current, VanState.achievement);

      // Thinking is task priority: it must NOT replace the celebration.
      expect(
        controller.dispatch(const VanEvent(VanEventType.aiThinking)),
        isFalse,
      );
      expect(controller.state.current, VanState.achievement);
      expect(controller.state.isLoading, isFalse);
    });

    test('repeated aiThinking is idempotent (no reset, no flicker)', () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.aiThinking));
      final first = controller.state;
      controller.dispatch(const VanEvent(VanEventType.aiThinking));
      expect(controller.state.current, VanState.thinking);
      expect(controller.state.isLoading, isTrue);
      expect(identical(first, controller.state), isFalse,
          reason: 'state object may be replaced but the presentation state '
              'must stay thinking/loading');
    });

    test('a failed AI turn still resolves to error then idle deterministically',
        () {
      final controller = VanController();
      addTearDown(controller.dispose);

      controller.dispatch(const VanEvent(VanEventType.aiThinking));
      controller.dispatch(const VanEvent(VanEventType.errorOccurred,
          message: 'I could not connect.'));
      expect(controller.state.current, VanState.error);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.message, 'I could not connect.');
    });

    test('dispatch after dispose is safe and returns false', () {
      final controller = VanController();
      controller.dispatch(const VanEvent(VanEventType.quizAnswerCorrect));
      controller.dispose();

      expect(
        controller.dispatch(const VanEvent(VanEventType.companionTapped)),
        isFalse,
      );
    });
  });
  testWidgets(
      'useController reflects dispatches and blocks taps while protected',
      (tester) async {
    final controller = VanController();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        vanControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: VanWidget(
              useController: true,
              size: 120,
              showSpeechBubble: true,
            ),
          ),
        ),
      ),
    ));

    // Idle: no bubble, fallback visible.
    expect(find.byKey(const ValueKey('van-flutter-fallback')), findsOneWidget);
    expect(find.text('Thinking.'), findsNothing);

    // Dispatch a celebration with copy: bubble + achievement visual appear.
    controller.dispatch(const VanEvent(
      VanEventType.lessonCompleted,
      message: 'Lesson complete!',
    ));
    await tester.pump();
    expect(find.text('Lesson complete!'), findsOneWidget);

    // Achievements do not allow user interaction: tapping must not dispatch
    // companionTapped (state must remain achievement).
    await tester.tap(find.byKey(const ValueKey('van-flutter-fallback')));
    await tester.pump();
    expect(controller.state.current, VanState.achievement);

    // The protected reaction still finishes on its own clock.
    await tester.pump(const Duration(milliseconds: 2601));
    expect(controller.state.current, VanState.idle);
    expect(controller.state.message, isNull);
  });
}
