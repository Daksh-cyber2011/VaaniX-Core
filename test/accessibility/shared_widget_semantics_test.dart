/// Accessibility regression tests — shared widget + remaining-screen parity.
///
/// Pins the Phase 2 completion pass:
///   - PrimaryButton keeps its accessible name while loading and the
///     spinner announces itself (the label was previously REPLACED).
///   - VaaniXLoadingIndicator announces its message.
///   - StatTile / VaaniXCard advertise the button trait when tappable,
///     and stay inert when not tappable.
///   - SectionHeader's action button keeps a 48dp touch target.
///   - Gemini retry classifier: transient errors retry, permanent ones
///     (bad key, quota, safety block) never do.
library;

import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show InvalidApiKey, ServerException;

import 'package:vaanix_app/features/ai/data/gemini_model_adapter.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/section_header.dart';
import 'package:vaanix_app/shared/widgets/stat_tile.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrimaryButton loading semantics', () {
    testWidgets('keeps its label visible while loading', (tester) async {
      await tester.pumpWidget(_app(const PrimaryButton(
        label: 'Save',
        onPressed: null,
        isLoading: true,
      )));
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('spinner is labelled when loading', (tester) async {
      await tester.pumpWidget(_app(const PrimaryButton(
        label: 'Save',
        onPressed: null,
        isLoading: true,
      )));
      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);
      final data = tester.firstWidget(spinner) as CircularProgressIndicator;
      expect(data.semanticsLabel, 'Loading');
    });

    testWidgets('non-loading button shows only the label', (tester) async {
      await tester.pumpWidget(_app(const PrimaryButton(
        label: 'Save',
        onPressed: null,
      )));
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('VaaniXLoadingIndicator', () {
    testWidgets('spinner carries the message as its semantics label',
        (tester) async {
      await tester
          .pumpWidget(_app(const VaaniXLoadingIndicator(message: 'Preparing')));
      final data = tester.firstWidget(find.byType(CircularProgressIndicator))
          as CircularProgressIndicator;
      expect(data.semanticsLabel, 'Preparing');
    });

    testWidgets('falls back to a generic label without a message',
        (tester) async {
      await tester.pumpWidget(_app(const VaaniXLoadingIndicator()));
      final data = tester.firstWidget(find.byType(CircularProgressIndicator))
          as CircularProgressIndicator;
      expect(data.semanticsLabel, 'Loading');
    });
  });

  group('SectionHeader touch target', () {
    testWidgets('action button tap-target floor is 48dp', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(SectionHeader(
        title: 'Section',
        actionLabel: 'See all',
        onActionTap: () {},
      )));
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final style = button.style!;
      expect(style.minimumSize!.resolve({})!.height, 48);
      handle.dispose();
    });
  });

  group('Tappable container button trait', () {
    testWidgets('StatTile exposes a button semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(StatTile(
        icon: Icons.local_fire_department,
        value: '3',
        label: 'day streak',
        onTap: () {},
      )));
      final node = tester.getSemantics(find.byType(StatTile));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('VaaniXCard exposes a button node when tappable',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(VaaniXCard(
        onTap: () {},
        child: const Text('Card content'),
      )));
      final node = tester.getSemantics(find.text('Card content'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('VaaniXCard is inert (no button node) when onTap is null',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const VaaniXCard(
        child: Text('Static card'),
      )));
      final node = tester.getSemantics(find.text('Static card'));
      expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
      handle.dispose();
    });
  });

  group('Gemini retry classifier', () {
    test('timeouts and network drops are transient', () {
      expect(
        GeminiModelAdapter.isTransientAiError(
          TimeoutException('Gemini completion timed out'),
        ),
        isTrue,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          const SocketException('Connection reset by peer'),
        ),
        isTrue,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('[500] Internal error'),
        ),
        isTrue,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('The model is overloaded. Please try again later.'),
        ),
        isTrue,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('Service unavailable (503)'),
        ),
        isTrue,
      );
    });

    test('invalid keys and configuration errors are permanent', () {
      expect(
        GeminiModelAdapter.isTransientAiError(
          InvalidApiKey('API key not valid. Please pass a valid API key.'),
        ),
        isFalse,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('API key not valid'),
        ),
        isFalse,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          Exception('User location is not supported for the API use.'),
        ),
        isFalse,
      );
    });

    test('rate limits and quota errors are NEVER retried', () {
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('[429] Resource has been exhausted'),
        ),
        isFalse,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          Exception('Rate limit exceeded: 429'),
        ),
        isFalse,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          Exception('Resource_exhausted: quota exceeded'),
        ),
        isFalse,
      );
    });

    test('safety blocks and malformed requests are permanent', () {
      expect(
        GeminiModelAdapter.isTransientAiError(
          ServerException('Request blocked by safety settings'),
        ),
        isFalse,
      );
      expect(
        GeminiModelAdapter.isTransientAiError(
          StateError('Gemini API key not configured'),
        ),
        isFalse,
      );
    });
  });
}
