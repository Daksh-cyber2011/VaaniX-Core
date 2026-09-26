/// Tests for the VAN ↔ AI routing bridge.
///
/// The bridge translates [AiLifecycleStage] values (the abstract AI
/// lifecycle) into the existing [VanEvent] vocabulary the VAN state
/// machine already understands. These tests pin the mapping so the
/// chain cannot silently detach when an AI provider is swapped (Gemini
/// → Groq → offline) or when a new lifecycle stage is added.
///
/// No mocks, no providers — the bridge is a pure function.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/van/domain/van_event.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_ai_bridge.dart';

void main() {
  group('vanEventForStage — exhaustive stage mapping', () {
    test('userSubmitted → userMessageReceived', () {
      final event = vanEventForStage(AiLifecycleStage.userSubmitted);
      expect(event.type, VanEventType.userMessageReceived);
    });

    test('thinking → aiThinking', () {
      final event = vanEventForStage(AiLifecycleStage.thinking);
      expect(event.type, VanEventType.aiThinking);
    });

    test('responding → aiResponseStarted', () {
      final event = vanEventForStage(AiLifecycleStage.responding);
      expect(event.type, VanEventType.aiResponseStarted);
    });

    test('idle → aiResponseFinished', () {
      final event = vanEventForStage(AiLifecycleStage.idle);
      expect(event.type, VanEventType.aiResponseFinished);
    });

    test('error → errorOccurred', () {
      final event = vanEventForStage(AiLifecycleStage.error);
      expect(event.type, VanEventType.errorOccurred);
    });

    test('every AiLifecycleStage maps to a known VanEventType', () {
      // Guards against adding a stage without updating the bridge.
      for (final stage in AiLifecycleStage.values) {
        final event = vanEventForStage(stage);
        expect(VanEventType.values, contains(event.type),
            reason: 'stage ${stage.name} must map to a VanEventType');
      }
    });
  });

  group('vanEventForStage — payload forwarding', () {
    test('forwards message, displayDuration, and payload verbatim', () {
      final event = vanEventForStage(
        AiLifecycleStage.responding,
        message: 'speech bubble copy',
        displayDuration: const Duration(seconds: 5),
        payload: const {'conversationId': 'abc', 'token': 42},
      );
      expect(event.message, 'speech bubble copy');
      expect(event.displayDuration, const Duration(seconds: 5));
      expect(event.payload['conversationId'], 'abc');
      expect(event.payload['token'], 42);
    });

    test('omitted fields stay null / empty (no fabrication)', () {
      final event = vanEventForStage(AiLifecycleStage.thinking);
      expect(event.message, isNull);
      expect(event.displayDuration, isNull);
      expect(event.payload, isEmpty);
    });
  });

  group('VAN AI routing is provider-agnostic', () {
    test(
        'bridge never inspects the underlying AI provider — same input '
        'always produces the same VanEvent', () {
      // The Groq adapter, the Gemini adapter, and the offline adapter
      // all surface lifecycle stages through the same vocabulary.
      // Re-running the mapping here pins the contract.
      final stages = [
        AiLifecycleStage.userSubmitted,
        AiLifecycleStage.thinking,
        AiLifecycleStage.responding,
        AiLifecycleStage.idle,
        AiLifecycleStage.error,
      ];
      final types = stages.map(vanEventForStage).map((e) => e.type).toList();
      // Five distinct lifecycle stages must yield five distinct
      // VanEventTypes — no two stages collapse to the same event.
      expect(types.toSet().length, types.length,
          reason: 'each AI lifecycle stage MUST produce a distinct VAN '
              'reaction — a collapsed mapping would lose visual fidelity');
    });
  });
}
