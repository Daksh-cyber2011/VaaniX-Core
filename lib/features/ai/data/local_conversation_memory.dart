/// VaaniX AI — Local Conversation Memory
///
/// SharedPreferences-backed implementation of [ConversationMemory].
/// Conversations are stored as JSON-encoded lists of [AiMessage] maps
/// under keys `ai_conversation_<conversationId>`.
///
/// This enables conversations to survive app restarts. In a future
/// milestone, a Supabase-backed memory can replace this for cross-device
/// sync.

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_memory.dart';

class LocalConversationMemory implements ConversationMemory {
  LocalConversationMemory(this._storage);

  final ILocalStorageService _storage;

  @override
  Future<Result<List<AiMessage>>> load(String conversationId) {
    return guardAsync(() async {
      final raw = _storage.getAiConversation(conversationId);
      if (raw == null || raw.isEmpty) return const <AiMessage>[];
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => AiMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Corrupt JSON — treat as empty rather than crashing.
        return const <AiMessage>[];
      }
    });
  }

  @override
  Future<Result<void>> append({
    required String conversationId,
    required AiMessage message,
  }) {
    return guardAsync(() async {
      final current = await load(conversationId).then(
        (r) => r.fold((_) => <AiMessage>[], (v) => v),
      );
      final next = [...current, message];
      await _storage.setAiConversation(
        conversationId,
        jsonEncode(next.map((m) => m.toJson()).toList()),
      );
    });
  }

  @override
  Future<Result<void>> save({
    required String conversationId,
    required List<AiMessage> messages,
  }) {
    return guardAsync(() async {
      await _storage.setAiConversation(
        conversationId,
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
    });
  }

  @override
  Future<Result<void>> clear(String conversationId) {
    return guardAsync(() async {
      await _storage.setAiConversation(conversationId, '[]');
    });
  }

  @override
  Future<Result<void>> clearAll() {
    return guardAsync(() async {
      // SharedPreferences doesn't expose prefix-search, so we clear by
      // iterating known keys. For V1 this is fine — conversations are
      // short-lived. A Production version would track conversation IDs
      // in a separate index key.
      await _storage.clearAiConversations();
    });
  }
}
