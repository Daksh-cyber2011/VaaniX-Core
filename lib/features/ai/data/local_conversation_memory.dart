/// VaaniX AI — Local Conversation Memory
///
/// SharedPreferences-backed implementation of [ConversationMemory].
/// Conversations are stored as JSON-encoded lists of [AiMessage] maps
/// under keys `ai_conversation_<conversationId>`.
///
/// This enables conversations to survive app restarts. In a future
/// milestone, a Supabase-backed memory can replace this for cross-device
/// sync.
///
/// Bounded retention (Phase 4 — defect #12):
///   - Per-conversation transcripts are capped at
///     [AppConstants.maxAiTranscriptMessages]; the newest messages are kept.
///   - Conversation KEYS are pruned to the newest
///     [AppConstants.maxStoredAiConversations] (by the `conv_<millis>`
///     timestamp embedded in generated ids); older transcripts are removed.
///   - [clear] removes the storage key entirely instead of leaving an
///     empty-list zombie behind.
library;

import 'dart:convert';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_memory.dart';

class LocalConversationMemory implements ConversationMemory {
  LocalConversationMemory(this._storage);

  final ILocalStorageService _storage;

  String _key(String conversationId) =>
      '${AppConstants.aiConversationKeyPrefix}$conversationId';

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
      var next = [...current, message];
      // Bounded transcript: keep the newest messages when the cap is
      // exceeded (an old conversation can never grow without bound).
      if (next.length > AppConstants.maxAiTranscriptMessages) {
        next = next
            .sublist(next.length - AppConstants.maxAiTranscriptMessages);
      }
      await _storage.setAiConversation(
        conversationId,
        jsonEncode(next.map((m) => m.toJson()).toList()),
      );
      await _pruneOldConversations(keepId: conversationId);
    });
  }

  @override
  Future<Result<void>> save({
    required String conversationId,
    required List<AiMessage> messages,
  }) {
    return guardAsync(() async {
      var bounded = messages;
      if (bounded.length > AppConstants.maxAiTranscriptMessages) {
        bounded = bounded
            .sublist(bounded.length - AppConstants.maxAiTranscriptMessages);
      }
      await _storage.setAiConversation(
        conversationId,
        jsonEncode(bounded.map((m) => m.toJson()).toList()),
      );
      await _pruneOldConversations(keepId: conversationId);
    });
  }

  @override
  Future<Result<void>> clear(String conversationId) {
    return guardAsync(() async {
      // Remove the key entirely. Writing '[]' (the previous behavior) left
      // an ever-growing pile of empty zombie keys behind every "new chat".
      await _storage.remove(_key(conversationId));
    });
  }

  @override
  Future<Result<void>> clearAll() {
    return guardAsync(() async {
      await _storage.clearAiConversations();
    });
  }

  /// Retention policy: keep at most [AppConstants.maxStoredAiConversations]
  /// conversation keys in storage. [keepId] (the conversation being written)
  /// is never pruned; of the others, the ones with the NEWEST `conv_<millis>`
  /// timestamp survive. Ids that don't carry a parseable timestamp (e.g. the
  /// legacy `'default'`) sort oldest and go first.
  Future<void> _pruneOldConversations({required String keepId}) async {
    const prefix = AppConstants.aiConversationKeyPrefix;
    final otherIds = <String>[];
    for (final key in _storage.keys) {
      if (!key.startsWith(prefix)) continue;
      final id = key.substring(prefix.length);
      if (id == keepId) continue;
      otherIds.add(id);
    }
    const allowance = AppConstants.maxStoredAiConversations - 1;
    if (otherIds.length <= allowance) return;

    int timestamp(String id) {
      final match = RegExp(r'^conv_(\d+)$').firstMatch(id);
      return match == null ? -1 : int.tryParse(match.group(1)!) ?? -1;
    }

    otherIds.sort((a, b) => timestamp(a).compareTo(timestamp(b)));
    final doomed = otherIds.take(otherIds.length - allowance);
    for (final id in doomed) {
      await _storage.remove(_key(id));
    }
  }
}
