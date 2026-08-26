/// Chat Controller Lifecycle/Race Tests
///
/// Verifies the controller survives disposal while a send is in flight
/// (no provider mutation after dispose), surfaces failures without
/// leaving isSending stuck, and blocks conversation resets during sends.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_controller.dart';

class _FakePipeline implements ConversationPipeline {
  _FakePipeline(this._send);

  final Future<Result<ConversationContext>> Function() _send;

  @override
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) {
    return _send();
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) {
    return const Stream.empty();
  }
}

Future<ProviderContainer> makeContainer(
  Future<Result<ConversationContext>> Function() send,
) async {
  dotenv.testLoad();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      conversationPipelineProvider.overrideWithValue(_FakePipeline(send)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disposing the container mid-send is safe (no mutation after dispose)',
      () async {
    final container = await makeContainer(
      () => Future.delayed(
        const Duration(milliseconds: 100),
        () => ok(
          ConversationContext(
            conversationId: 'default',
            learner: const LearnerContext(),
            messages: [
              AiMessage.user(id: 'u1', content: 'hi'),
              AiMessage.assistant(id: 'a1', content: 'namaste'),
            ],
          ),
        ),
      ),
    );
    final controller = container.read(chatControllerProvider.notifier);

    final send = controller.sendMessage('hi');
    // Dispose while the pipeline result is still pending.
    container.dispose();
    await send;
    // Reaching here without a FlutterError proves the mounted guard works.
  });

  test('a failed send clears isSending and records the error', () async {
    final container = await makeContainer(
      () async => err(const AiServiceFailure('offline test failure')),
    );
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);

    await controller.sendMessage('hello');

    expect(controller.state.isSending, isFalse);
    expect(controller.state.error, 'offline test failure');
    expect(controller.state.messages.length, 1,
        reason: 'the optimistic user message stays, no reply is fabricated');
  });

  test('a successful send appends the assistant reply', () async {
    final container = await makeContainer(
      () async => ok(
        ConversationContext(
          conversationId: 'default',
          learner: const LearnerContext(),
          messages: [
            AiMessage.user(id: 'u1', content: 'hi'),
            AiMessage.assistant(id: 'a1', content: 'Namaste!'),
          ],
        ),
      ),
    );
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);

    await controller.sendMessage('hi');

    expect(controller.state.isSending, isFalse);
    expect(controller.state.error, isNull);
    expect(controller.state.messages.last.content, 'Namaste!');
  });

  test('startNewConversation is ignored while a send is in flight', () async {
    final container = await makeContainer(
      () => Future.delayed(
        const Duration(milliseconds: 100),
        () => ok(
          ConversationContext(
            conversationId: 'default',
            learner: const LearnerContext(),
            messages: [
              AiMessage.user(id: 'u1', content: 'hi'),
              AiMessage.assistant(id: 'a1', content: 'namaste'),
            ],
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);

    final send = controller.sendMessage('hi');
    await controller.startNewConversation();
    expect(controller.state.conversationId, 'default',
        reason: 'reset must not fire while a reply is pending');
    await send;
  });
}
