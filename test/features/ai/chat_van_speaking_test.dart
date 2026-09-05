/// Phase 3: the chat flow drives Van's speaking reaction with a genuine
/// completion signal — the reply's reading window is passed as
/// `displayDuration` and `aiResponseFinished` is dispatched when it
/// elapses, instead of the speaking state silently hard-cutting at its
/// default fallback timer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/van/van.dart';

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

/// Records the event sequence while delegating to the real controller.
class _RecordingVan extends VanController {
  final dispatched = <VanEventType>[];

  @override
  bool dispatch(VanEvent event) {
    dispatched.add(event.type);
    return super.dispatch(event);
  }
}

Future<ProviderContainer> _makeContainer(
  Future<Result<ConversationContext>> Function() send,
  _RecordingVan van,
) async {
  dotenv.testLoad();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      conversationPipelineProvider.overrideWithValue(_FakePipeline(send)),
      vanControllerProvider.overrideWith((ref) => van),
    ],
  );
}

ConversationContext _okReply(String reply) => ConversationContext(
      conversationId: 'default',
      learner: const LearnerContext(),
      messages: [
        AiMessage.user(id: 'u1', content: 'hi'),
        AiMessage.assistant(id: 'a1', content: reply),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatController.speakingWindowFor', () {
    test('short replies keep the base cadence', () {
      expect(
        ChatController.speakingWindowFor('Namaste!'),
        const Duration(milliseconds: 2200),
      );
      expect(
        ChatController.speakingWindowFor(null),
        const Duration(milliseconds: 2200),
      );
    });

    test('longer replies get proportionally more reading time', () {
      final medium = List.filled(40, 'word').join(' ');
      final window = ChatController.speakingWindowFor(medium);
      expect(
        window.inMilliseconds,
        greaterThan(2200),
        reason: 'a 40-word reply must not hard-cut at the base duration',
      );
    });

    test('the window is capped so essays cannot pin Van in speaking', () {
      final essay = List.filled(500, 'word').join(' ');
      expect(
        ChatController.speakingWindowFor(essay),
        const Duration(milliseconds: 6000),
      );
    });
  });

  test('a successful send drives the full speaking lifecycle to idle',
      () async {
    final van = _RecordingVan();
    final container = await _makeContainer(() async => ok(_okReply('Namaste!')), van);
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);

    await controller.sendMessage('hi');

    expect(
      van.dispatched,
      containsAllInOrder(const [
        VanEventType.userMessageReceived,
        VanEventType.aiThinking,
        VanEventType.aiResponseStarted,
      ]),
    );
    expect(van.state.current, VanState.speaking,
        reason: 'the reply is on screen, Van speaks');

    // Wait out the reading window; aiResponseFinished must settle Van.
    final window = ChatController.speakingWindowFor('Namaste!');
    await Future<void>.delayed(window + const Duration(milliseconds: 150));
    expect(van.dispatched, contains(VanEventType.aiResponseFinished));
    expect(van.state.current, VanState.idle);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a failed send never schedules a completion signal', () async {
    final van = _RecordingVan();
    final container = await _makeContainer(
      () async => err(const AiServiceFailure('offline')),
      van,
    );
    addTearDown(container.dispose);
    final controller = container.read(chatControllerProvider.notifier);

    await controller.sendMessage('hello');

    expect(van.dispatched, contains(VanEventType.errorOccurred));
    expect(van.dispatched, isNot(contains(VanEventType.aiResponseStarted)));
  });
}
