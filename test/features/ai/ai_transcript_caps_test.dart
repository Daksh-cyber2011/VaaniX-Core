/// Phase 4: bounded AI memory — transcript caps, conversation pruning and
/// honest key removal (defect #12).
///
/// Before this phase the AI transcripts grew without bound on disk
/// (`ai_conversation_*` keys accumulated forever — every "New chat" left a
/// zombie key, and transcripts never shrank). These tests pin the retention
/// contract of [LocalConversationMemory].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/ai/data/local_conversation_memory.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';

AiMessage _user(int i) => AiMessage.user(id: 'u$i', content: 'm$i');
AiMessage _assistant(int i) => AiMessage.assistant(id: 'a$i', content: 'r$i');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late LocalConversationMemory memory;

  setUp(() async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    memory = LocalConversationMemory(container.read(localStorageServiceProvider));
  });

  tearDown(() => container.dispose());

  Set<String> aiKeys() => container
      .read(localStorageServiceProvider)
      .keys
      .where((k) => k.startsWith(AppConstants.aiConversationKeyPrefix))
      .toSet();

  test('appends beyond the transcript cap keep only the newest messages',
      () async {
    const id = 'conv_1';
    for (var i = 0; i < AppConstants.maxAiTranscriptMessages + 25; i++) {
      await memory.append(conversationId: id, message: _user(i));
      await memory.append(conversationId: id, message: _assistant(i));
    }

    final stored = await memory.load(id);
    final messages = stored.fold((_) => <AiMessage>[], (v) => v);
    expect(messages.length, AppConstants.maxAiTranscriptMessages,
        reason: 'the transcript is hard-capped on disk');
    expect(messages.last.content, 'r${AppConstants.maxAiTranscriptMessages + 24}',
        reason: 'the NEWEST messages are the ones kept');
    expect(messages.first.id, 'u75',
        reason: 'the oldest messages were the ones dropped (sliding window)');
  });

  test('clear removes the storage key instead of leaving a zombie', () async {
    const id = 'conv_42';
    await memory.append(conversationId: id, message: _user(1));
    expect(aiKeys(), contains('${AppConstants.aiConversationKeyPrefix}$id'));

    await memory.clear(id);

    expect(aiKeys(), isEmpty,
        reason: "clear must remove the key, not store an empty '[]' list");
    final reloaded = await memory.load(id);
    expect(reloaded.fold((_) => <AiMessage>[], (v) => v), isEmpty);
  });

  test('old conversations are pruned, keeping the newest cap of them',
      () async {
    // Write into 8 conversations with increasing timestamps. The cap keeps
    // the newest [maxStoredAiConversations] keys overall.
    final ids = List.generate(8, (i) => 'conv_${1700000000000 + i}');
    for (final id in ids) {
      await memory.append(conversationId: id, message: _user(1));
    }

    final remaining = aiKeys()
        .map((k) => k.substring(AppConstants.aiConversationKeyPrefix.length))
        .toSet();
    expect(remaining.length, AppConstants.maxStoredAiConversations);
    expect(
      remaining,
      ids.skip(8 - AppConstants.maxStoredAiConversations).toSet(),
      reason: 'the oldest conversations are removed, newest survive',
    );
  });

  test('the conversation being written is never pruned', () async {
    // Fill storage with newer conversations than the current one.
    const current = 'conv_1690000000000';
    final newer = List.generate(
        AppConstants.maxStoredAiConversations + 2,
        (i) => 'conv_${1700000000000 + i}');
    for (final id in newer) {
      await memory.append(conversationId: id, message: _user(1));
    }

    // The current conversation is older than all of the above, yet a write
    // to it must succeed and keep its data.
    await memory.append(conversationId: current, message: _user(99));

    final stored = await memory.load(current);
    expect(stored.fold((_) => <AiMessage>[], (v) => v).single.content, 'm99');
  });

  test('ids without a timestamp sort oldest and are pruned first', () async {
    // The legacy 'default' conversation has no conv_<millis> suffix.
    await memory.append(conversationId: 'default', message: _user(1));
    final newer = List.generate(AppConstants.maxStoredAiConversations,
        (i) => 'conv_${1700000000000 + i}');
    for (final id in newer) {
      await memory.append(conversationId: id, message: _user(1));
    }
    // One more conversation forces a prune; 'default' must go first.
    await memory.append(conversationId: 'conv_1800000000000', message: _user(1));

    final remaining = aiKeys()
        .map((k) => k.substring(AppConstants.aiConversationKeyPrefix.length))
        .toSet();
    expect(remaining, isNot(contains('default')),
        reason: 'legacy timestamp-less ids are the oldest by definition');
    expect(remaining.length, AppConstants.maxStoredAiConversations);
  });
}
