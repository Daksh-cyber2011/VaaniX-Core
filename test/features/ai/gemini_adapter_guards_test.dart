/// Gemini Adapter Guard Tests
///
/// Verifies the adapter never fabricates input, fails cleanly without a
/// user message, and maps timeouts to a typed failure. No API key or
/// network is required - every path exercised here fails BEFORE any SDK
/// call, so the tests are hermetic.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vaanix_app/core/errors/exception_mapper.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/ai/data/gemini_model_adapter.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

ConversationContext _contextWithMessages(List<AiMessage> messages) {
  return ConversationContext(
    conversationId: 'test_conv',
    learner: const LearnerContext(displayName: 'Test'),
    messages: messages,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => dotenv.testLoad());

  group('GeminiModelAdapter input guards', () {
    test('isAvailable is false when Gemini is unconfigured', () {
      expect(GeminiModelAdapter().isAvailable, isFalse);
    });

    test('complete fails cleanly when the context has no user message',
        () async {
      final result = await GeminiModelAdapter().complete(
        context: _contextWithMessages([
          AiMessage.assistant(id: 'a1', content: 'Hello!'),
        ]),
        config: const AiConfig(provider: AiProviderId.gemini),
      );

      expect(result.isLeft(), isTrue);
      expect(result.swap().getOrElse(() => const UnknownFailure()).code,
          'AI_SERVICE');
    });

    test('complete fails cleanly on an empty user message (no garbage sent)',
        () async {
      final result = await GeminiModelAdapter().complete(
        context: _contextWithMessages([
          AiMessage.user(id: 'u1', content: '   '),
        ]),
        config: const AiConfig(provider: AiProviderId.gemini),
      );

      expect(result.isLeft(), isTrue);
      expect(result.swap().getOrElse(() => const UnknownFailure()).code,
          'AI_SERVICE');
    });

    test('the no-user-message guard wins over the missing-key error', () async {
      // Without a key _getModel would throw StateError; the guard must run
      // first so the failure is the typed AI_SERVICE, not UNKNOWN.
      final result = await GeminiModelAdapter().complete(
        context: _contextWithMessages([]),
        config: const AiConfig(provider: AiProviderId.gemini),
      );

      expect(result.isLeft(), isTrue);
      expect(result.swap().getOrElse(() => const UnknownFailure()).code,
          'AI_SERVICE');
    });

    test('stream yields a typed error without a user message', () async {
      final deltas = await GeminiModelAdapter()
          .stream(
            context: _contextWithMessages([]),
            config: const AiConfig(provider: AiProviderId.gemini),
          )
          .toList();

      expect(deltas.length, 1);
      expect(deltas.single.isLeft(), isTrue);
      expect(deltas.single.swap().getOrElse(() => const UnknownFailure()).code,
          'AI_SERVICE');
    });
  });

  group('timeout mapping', () {
    test('ExceptionMapper maps dart:async TimeoutException to TimeoutFailure',
        () {
      final failure = ExceptionMapper.toFailure(
        TimeoutException('Gemini completion timed out'),
      );
      expect(failure, isA<TimeoutFailure>());
    });
  });
}
