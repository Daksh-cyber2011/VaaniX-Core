import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/van/presentation/van_asset_catalog.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

Widget _host({
  required VanState state,
  String dialogue = 'Hello from Van',
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: VanWidget(
          state: state,
          size: 120,
          assetCatalog: VanAssetCatalog.placeholder,
          showSpeechBubble: true,
          dialogueText: dialogue,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('speech-disabled state suppresses supplied dialogue',
      (tester) async {
    await tester.pumpWidget(_host(state: VanState.thinking));
    expect(find.text('Hello from Van'), findsNothing);
  });

  testWidgets('speech-enabled state renders supplied dialogue', (tester) async {
    await tester.pumpWidget(_host(state: VanState.idle));
    expect(find.text('Hello from Van'), findsOneWidget);
  });

  testWidgets('interaction-disabled state blocks explicit tap and long press',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(_host(
      state: VanState.focus,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    ));

    await tester.tap(find.byType(GestureDetector));
    await tester.longPress(find.byType(GestureDetector));
    expect(taps, 0);
    expect(longPresses, 0);
  });

  testWidgets('interaction-enabled state preserves explicit callbacks',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(_host(
      state: VanState.idle,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    ));

    await tester.tap(find.byType(GestureDetector));
    await tester.longPress(find.byType(GestureDetector));
    expect(taps, 1);
    expect(longPresses, 1);
  });
}
