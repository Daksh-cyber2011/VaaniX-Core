/// Van motion ticker lifecycle: the breathing animation must pause whenever
/// Van is not visibly active — inside a disabled [TickerMode] subtree
/// (covered/offstage routes, hidden tab children) or while the app is
/// backgrounded — instead of ticking offscreen forever (Phase 3 repair).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/shared/widgets/van_widget.dart';

Widget _host({required bool tickerEnabled}) => ProviderScope(
      child: MaterialApp(
        home: TickerMode(
          enabled: tickerEnabled,
          child: const Scaffold(
            body: Center(child: VanWidget(size: 80)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('ticker pauses under a disabled TickerMode and resumes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tickerEnabled: false));
    await tester.pump();

    final state = tester.state<VanWidgetState>(find.byType(VanWidget));
    expect(
      state.motionController.isAnimating,
      isFalse,
      reason: 'an offscreen Van must not keep requesting frames',
    );

    // Rebuild with the subtree visible again: the same State resumes.
    await tester.pumpWidget(_host(tickerEnabled: true));
    expect(state.motionController.isAnimating, isTrue);
  });

  testWidgets('ticker pauses while the app is backgrounded and resumes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();

    final state = tester.state<VanWidgetState>(find.byType(VanWidget));
    expect(state.motionController.isAnimating, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
      state.motionController.isAnimating,
      isFalse,
      reason: 'a backgrounded app must not burn battery on Van motion',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(state.motionController.isAnimating, isTrue);
  });

  testWidgets('the hidden lifecycle state also pauses the ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();

    final state = tester.state<VanWidgetState>(find.byType(VanWidget));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(state.motionController.isAnimating, isFalse);

    // Leave the binding in a sane state for later tests.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}
