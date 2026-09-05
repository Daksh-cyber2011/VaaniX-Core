/// Phase 4: ChatController streaming path.
///
/// With `enableStreaming` (the production default) the controller consumes
/// [ConversationPipeline.stream] and renders deltas incrementally. These
/// tests pin the new contract:
///   - deltas grow the trailing assistant bubble in place
///   - success drives the same Van lifecycle + usage-chip refresh as the
///     complete path
///   - a failure (or an empty stream, or an unsafe assembled reply)
///     withdraws the partial bubble — the pipeline persists nothing on
///     failure, so UI and memory must agree
///   - `enableStreaming: false` still routes to send()
///   - disposing mid-stream is safe
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/van/van.dart';

/// Pipeline whose two paths are scripted independently and counted, so
/// tests can assert WHICH path the controller chose.
class _ScriptedPipeline implements ConversationPipeline {
  _ScriptedPipeline({this.sendReply, this.deltas});

  /// Reply returned by send() (defaults to a generic success).
  final String? sendReply;

  /// Deltas emitted by stream() (defaults to a single done delta).
  final List<Result<AiStreamDelta>>? deltas;

  int sendCalls = 0;
  int streamCalls = 0;
  ConversationContext? lastStreamContext;

  @override
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async {
    sendCalls++;
    return ok(context.append(AiMessage.assistant(
      id: 'a1',
      content: sendReply ?? 'complete reply',
    )));
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async* {
    streamCalls++;
    lastStreamContext = context;
    for (final delta in deltas ??
        [ok(const AiStreamDelta(content: '', done: true))]) {
      // A real microtask gap between events so the consumer processes each
      // delta separately (state snapshots are observable per delta).
      await Future<void>.delayed(Duration.zero);
      yield delta;
    }
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

/// Blocks every assembled output — mirrors a model that starts safe and
/// turns unsafe only once the full text is considered.
class _BlockAllFilter implements SafetyFilter {
  const _BlockAllFilter();

  @override
  String sanitizeInput(String userMessage) => userMessage;

  @override
  bool isOutputSafe(String assistantResponse) => false;

  @override
  String defensiveSystemPrompt() => 'defensive';
}

Future<ProviderContainer> _makeContainer({
  required _ScriptedPipeline pipeline,
  _RecordingVan? van,
  bool streaming = true,
  SafetyFilter? safetyFilter,
  Map<String, Object> seed = const {},
}) async {
  dotenv.testLoad();
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      conversationPipelineProvider.overrideWithValue(pipeline),
      defaultAiConfigProvider.overrideWithValue(
        AiConfig(provider: AiProviderId.offline, enableStreaming: streaming),
      ),
      if (van != null) vanControllerProvider.overrideWith((ref) => van),
      if (safetyFilter != null) safetyFilterProvider.overrideWithValue(safetyFilter),
    ],
  );
}

/// First touch constructs UserProfileNotifier (fire-and-forget load); pump
/// microtasks so a seeded profile (learner name) is visible to the chat.
Future<void> _settleProfile(ProviderContainer container) async {
  container.read(userProfileProvider);
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deltas grow the trailing bubble in place, ending with the full reply',
      () async {
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'Namaste')),
      ok(const AiStreamDelta(content: ' student!')),
      ok(const AiStreamDelta(content: '', done: true)),
    ]);
    final container = await _makeContainer(pipeline: pipeline);
    addTearDown(container.dispose);

    final snapshots = <ChatState>[];
    container.listen<ChatState>(chatControllerProvider, (_, next) {
      snapshots.add(next);
    });

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    final finalState = container.read(chatControllerProvider);
    expect(finalState.isSending, isFalse);
    expect(finalState.error, isNull);
    expect(finalState.messages, hasLength(2));
    expect(finalState.messages.last.role, AiRole.assistant);
    expect(finalState.messages.last.content, 'Namaste student!');

    // The partial bubble must have been observable mid-stream: a state
    // snapshot where the trailing assistant message held only 'Namaste'
    // while the turn was still in flight.
    final partialSnapshots = snapshots.where((s) =>
        s.messages.length == 2 &&
        s.messages.last.content == 'Namaste' &&
        s.isSending);
    expect(partialSnapshots, isNotEmpty,
        reason: 'streaming must render the reply incrementally');
  });

  test('a stream failure withdraws the partial and surfaces the error',
      () async {
    final van = _RecordingVan();
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'Namaste')),
      err(const AiServiceFailure('boom')),
    ]);
    final container = await _makeContainer(pipeline: pipeline, van: van);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    final state = container.read(chatControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.error, contains('boom'));
    expect(state.messages, hasLength(1),
        reason: 'the optimistic user message stays, the partial is dropped');
    expect(van.dispatched, contains(VanEventType.errorOccurred));
    expect(van.dispatched, isNot(contains(VanEventType.aiResponseStarted)),
        reason: 'a failed turn never starts the speaking lifecycle');
  });

  test('a stream that ends with no content is a failure, not a success',
      () async {
    final pipeline = _ScriptedPipeline(deltas: const []);
    final container = await _makeContainer(pipeline: pipeline);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    final state = container.read(chatControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.error, isNotNull);
    expect(state.messages, hasLength(1),
        reason: 'no empty success bubble is fabricated');
  });

  test('an unsafe ASSEMBLED reply is withdrawn like the pipeline does',
      () async {
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'looks ')),
      ok(const AiStreamDelta(content: 'unsafe')),
      ok(const AiStreamDelta(content: '', done: true)),
    ]);
    final container = await _makeContainer(
      pipeline: pipeline,
      safetyFilter: const _BlockAllFilter(),
    );
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    final state = container.read(chatControllerProvider);
    expect(state.isSending, isFalse);
    expect(state.error, 'The AI response was blocked by safety filters.');
    expect(state.messages, hasLength(1),
        reason:
            'the pipeline would not persist this text, so the UI drops it');
  });

  test('streaming success drives the full Van speaking lifecycle', () async {
    final van = _RecordingVan();
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'Namaste!')),
      ok(const AiStreamDelta(content: '', done: true)),
    ]);
    final container = await _makeContainer(pipeline: pipeline, van: van);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    expect(
      van.dispatched,
      containsAllInOrder(const [
        VanEventType.userMessageReceived,
        VanEventType.aiThinking,
        VanEventType.aiResponseStarted,
      ]),
    );
    expect(van.state.current, VanState.speaking);

    final window = ChatController.speakingWindowFor('Namaste!');
    await Future<void>.delayed(window + const Duration(milliseconds: 150));
    expect(van.dispatched, contains(VanEventType.aiResponseFinished));
    expect(van.state.current, VanState.idle);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('enableStreaming=false still routes through send()', () async {
    final pipeline = _ScriptedPipeline(sendReply: 'Namaste!');
    final container =
        await _makeContainer(pipeline: pipeline, streaming: false);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    expect(pipeline.sendCalls, 1);
    expect(pipeline.streamCalls, 0);
    final state = container.read(chatControllerProvider);
    expect(state.messages.last.content, 'Namaste!');
  });

  test('a successful streaming turn refreshes the daily usage provider',
      () async {
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'Here is your answer!')),
      ok(const AiStreamDelta(content: '', done: true)),
    ]);
    final container = await _makeContainer(pipeline: pipeline);
    addTearDown(container.dispose);

    final tracker = TokenUsageTracker(container.read(localStorageServiceProvider));

    // Prime the provider with the current (empty) usage.
    await container.read(dailyUsageProvider.future);
    expect((await container.read(dailyUsageProvider.future)).requestCount, 0);

    // Simulate the adapter recording quota consumption for the NEXT turn
    // (the fake pipeline cannot do it).
    await tracker.recordUsage(promptTokens: 12, completionTokens: 8);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    // The controller invalidates the provider on success, so the next read
    // re-computes from storage instead of returning the stale zeros.
    final usage = await container.read(dailyUsageProvider.future);
    expect(usage.requestCount, 1);
    expect(usage.totalTokens, 20);
  });

  test('the learner display name reaches the streaming context', () async {
    final pipeline = _ScriptedPipeline();
    final container = await _makeContainer(
      pipeline: pipeline,
      seed: {AppConstants.keyLearnerName: ' Arjun '},
    );
    addTearDown(container.dispose);
    await _settleProfile(container);

    await container.read(chatControllerProvider.notifier).sendMessage('hi');

    expect(pipeline.lastStreamContext, isNotNull);
    expect(pipeline.lastStreamContext!.learner.displayName, 'Arjun',
        reason: 'the profile display name is trimmed and personalized');
  });

  test('disposing the container mid-stream is safe', () async {
    final pipeline = _ScriptedPipeline(deltas: [
      ok(const AiStreamDelta(content: 'chunk 1')),
      ok(const AiStreamDelta(content: ' chunk 2')),
      ok(const AiStreamDelta(content: '', done: true)),
    ]);
    final container = await _makeContainer(pipeline: pipeline);
    final controller = container.read(chatControllerProvider.notifier);

    final send = controller.sendMessage('hi');
    // Dispose while deltas are still in flight.
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await send;
    // Reaching here without a FlutterError proves the mounted guards work.
  });
}
