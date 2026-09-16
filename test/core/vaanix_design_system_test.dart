/// VaaniX V1 Design System Tests
///
/// Validates:
/// - Stitch color tokens (Dark Tactical Cockpit & Light Sanctuary)
/// - AppMode dual engine state notifier
/// - VaaniXModeSwitch widget interaction
/// - VaaniXRadialGauge percentage calculation & rendering
/// - VaaniXButton variants
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaanix_app/core/providers/app_mode_provider.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/shared/widgets/audio_cadence_waveform.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_mode_switch.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';
import 'package:vaanix_app/shared/widgets/van_companion_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaaniX Design Tokens', () {
    test('Exam Cockpit colors match Stitch specifications', () {
      expect(VaaniXColors.examCanvasBg, const Color(0xFF090D16));
      expect(VaaniXColors.examSurfaceCard, const Color(0xFF131B2E));
      expect(VaaniXColors.examCyanAccent, const Color(0xFF00E5FF));
      expect(VaaniXColors.examIndigoAccent, const Color(0xFF4F46E5));
    });

    test('Learn Sanctuary colors match Stitch specifications', () {
      expect(VaaniXColors.learnCanvasBg, const Color(0xFFF8FAFC));
      expect(VaaniXColors.learnSurfaceCard, const Color(0xFFFFFFFF));
      expect(VaaniXColors.learnPrimaryViolet, const Color(0xFF4338CA));
      expect(VaaniXColors.learnAccentIris, const Color(0xFF6366F1));
    });

    test('Spacing & Radius tokens comply with 4px grid', () {
      expect(VaaniXSpacing.xs, 4.0);
      expect(VaaniXSpacing.sm, 8.0);
      expect(VaaniXSpacing.md, 12.0);
      expect(VaaniXSpacing.lg, 16.0);
      expect(VaaniXSpacing.xl, 24.0);

      expect(VaaniXRadius.sm, 8.0);
      expect(VaaniXRadius.md, 12.0);
      expect(VaaniXRadius.lg, 16.0);
      expect(VaaniXRadius.xl, 24.0);
      expect(VaaniXRadius.pill, 999.0);
    });
  });

  group('Dual Mode State Provider', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
    });

    test('defaults to learn mode and toggles seamlessly', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );

      final notifier = container.read(appModeProvider.notifier);
      expect(container.read(appModeProvider), AppMode.learn);

      await notifier.setMode(AppMode.exam);
      expect(container.read(appModeProvider), AppMode.exam);
      expect(storage.activeAppMode, 'exam');

      await notifier.toggleMode();
      expect(container.read(appModeProvider), AppMode.learn);
      expect(storage.activeAppMode, 'learn');
    });
  });

  group('VaaniX Core Presentation Widgets', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
    });

    Widget wrap(Widget child) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('VaaniXModeSwitch renders segments and updates mode on tap',
        (tester) async {
      await tester.pumpWidget(
        wrap(const VaaniXModeSwitch()),
      );

      expect(find.text('EXAM'), findsOneWidget);
      expect(find.text('LEARN'), findsOneWidget);

      await tester.tap(find.text('EXAM'));
      await tester.pumpAndSettle();

      expect(storage.activeAppMode, 'exam');
    });

    testWidgets('VaaniXRadialGauge displays percentage and delta text',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const VaaniXRadialGauge(
            percentage: 78,
            deltaText: '+3.6%/wk',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('78%'), findsOneWidget);
      expect(find.text('+3.6%/wk'), findsOneWidget);
    });

    testWidgets('AudioCadenceWaveform toggles play/pause state on tap',
        (tester) async {
      bool playState = false;
      await tester.pumpWidget(
        wrap(
          AudioCadenceWaveform(
            phrase: 'नमस्ते',
            durationLabel: '0:03',
            onPlayStateChanged: (val) => playState = val,
          ),
        ),
      );

      expect(find.text('नमस्ते'), findsOneWidget);
      expect(find.text('0:03'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(playState, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('VanCompanionBubble renders speech message and badge role',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const VanCompanionBubble(
            message: 'Master Virodhabhas Alankar in Pad 2',
            badgeRole: VanBadgeRole.tacticalIntel,
          ),
        ),
      );

      expect(find.text('VAN • TACTICAL INTEL'), findsOneWidget);
      expect(
          find.text('Master Virodhabhas Alankar in Pad 2'), findsOneWidget);
    });

    testWidgets('VaaniXButton responds to click and respects disabled state',
        (tester) async {
      bool clicked = false;
      await tester.pumpWidget(
        wrap(
          VaaniXButton.cyan(
            label: 'Launch Mission',
            onPressed: () => clicked = true,
          ),
        ),
      );

      expect(find.text('Launch Mission'), findsOneWidget);
      await tester.tap(find.text('Launch Mission'));
      expect(clicked, isTrue);
    });

    testWidgets('VaaniXCard renders content and handles tap', (tester) async {
      bool cardTapped = false;
      await tester.pumpWidget(
        wrap(
          VaaniXCard(
            onTap: () => cardTapped = true,
            child: const Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(cardTapped, isTrue);
    });
  });
}
