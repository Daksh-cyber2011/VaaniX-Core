/// Bootstrap failure surface.
///
/// When a required startup dependency fails (today `SharedPreferences`), the
/// app used to be left on a blank platform launch screen: the exception
/// escaped to the zone guard before `runApp` ran. These tests pin the
/// replacement contract — a rendered error state, a retry that actually
/// re-runs the startup sequence, and no double-fire while one is in flight.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/app/bootstrap/bootstrap_failure_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders an error state with a retry action', (tester) async {
    await tester.pumpWidget(
      BootstrapFailureApp(onRetry: () async {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('VaaniX could not start'), findsOneWidget);
    expect(find.byKey(const Key('bootstrap-retry')), findsOneWidget);
  });

  testWidgets('retry re-runs the startup sequence', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      BootstrapFailureApp(onRetry: () async => attempts++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 1);
  });

  testWidgets('a second tap while retrying does not start a second attempt',
      (tester) async {
    var attempts = 0;
    final gate = Completer<void>();
    await tester.pumpWidget(
      BootstrapFailureApp(onRetry: () async {
        attempts++;
        await gate.future;
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bootstrap-retry')));
    await tester.pump();

    // While the attempt is in flight the button is replaced by a spinner, so
    // the only way to double-fire would be a queued second call.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('bootstrap-retry')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(attempts, 1);

    // The failed attempt restores the retry affordance.
    expect(find.byKey(const Key('bootstrap-retry')), findsOneWidget);
  });
}
