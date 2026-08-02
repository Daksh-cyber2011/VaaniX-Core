/// VaaniX AI — Conversation Memory Contract
///
/// Persists conversation transcripts so Van can recall prior interactions
/// across app restarts. Implementations may be local-first (SharedPreferences,
/// SQLite) or remote (Supabase) — the pipeline depends only on this contract.
///
/// Memory is keyed by conversation id. A single learner typically has one
/// active conversation per learning session; long-term recall (summaries,
/// vector embeddings) is a future concern layered on top of this interface.

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';

abstract class ConversationMemory {
  /// Load the full transcript for [conversationId], oldest → newest.
  /// Returns an empty list for a new/unknown conversation.
  Future<Result<List<AiMessage>>> load(String conversationId);

  /// Append a single message to [conversationId]'s transcript.
  Future<Result<void>> append({
    required String conversationId,
    required AiMessage message,
  });

  /// Replace the entire transcript for [conversationId].
  Future<Result<void>> save({
    required String conversationId,
    required List<AiMessage> messages,
  });

  /// Clear the transcript for [conversationId].
  Future<Result<void>> clear(String conversationId);

  /// Clear every stored conversation.
  Future<Result<void>> clearAll();
}
