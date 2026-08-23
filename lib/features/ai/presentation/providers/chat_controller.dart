/// VaaniX AI — Chat Controller
///
/// Riverpod Notifier that manages the chat conversation state. The UI calls
/// [sendMessage] to send a user message and receive Van's reply. The
/// controller:
///   1. Builds a [LearnerContext] from the user's profile (companion name,
///      streak, XP, personality mode, CBSE class).
///   2. Creates or reuses a [ConversationContext] with a stable conversationId.
///   3. Calls [ConversationPipeline.send] which handles persona prompt,
///      memory loading, AI generation, safety filtering, and persistence.
///   4. Updates state with the new messages.
///
/// Conversations persist across app restarts via [LocalConversationMemory].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';

/// Immutable state for the chat screen.
class ChatState {
  const ChatState({
    this.conversationId = 'default',
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  /// Stable conversation ID. For V1 we use a single 'default' conversation.
  /// Future versions may support multiple named conversations.
  final String conversationId;

  /// The full message list (user + assistant), oldest → newest.
  final List<AiMessage> messages;

  /// True while waiting for Van's reply.
  final bool isSending;

  /// Error message from the last failed send, or null.
  final String? error;

  ChatState copyWith({
    String? conversationId,
    List<AiMessage>? messages,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages the chat conversation lifecycle.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState()) {
    _loadExistingConversation();
  }

  final Ref _ref;

  /// Load any existing conversation from memory on startup.
  Future<void> _loadExistingConversation() async {
    final memory = _ref.read(conversationMemoryProvider);
    final result = await memory.load(state.conversationId);
    result.fold(
      (_) {}, // keep empty on error
      (messages) {
        if (messages.isNotEmpty) {
          state = state.copyWith(messages: messages);
        }
      },
    );
  }

  /// Build a [LearnerContext] from the current user profile + progress.
  LearnerContext _buildLearnerContext(UserProfile profile) {
    return LearnerContext(
      displayName: '', // V1: no learner display name yet
      companionName: profile.resolvedCompanionName,
      cbseClassLabel: profile.cbseClass?.label,
      currentStreak: profile.currentStreak,
      xpTotal: _ref.read(xpTotalProvider),
      personalityMode: profile.personalityMode?.name ?? '',
      topic: 'Sanskrit',
    );
  }

  /// Send a user message and receive Van's reply.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final pipeline = _ref.read(conversationPipelineProvider);
    final config = _ref.read(defaultAiConfigProvider);
    final profile = _ref.read(userProfileProvider);

    // Create the user message.
    final userMessage = AiMessage.user(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: trimmed,
      createdAt: DateTime.now().toUtc(),
    );

    // Optimistically add the user message to the UI.
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      clearError: true,
    );
    final van = _ref.read(vanControllerProvider.notifier);
    van.dispatch(const VanEvent(VanEventType.userMessageReceived));
    van.dispatch(const VanEvent(VanEventType.aiThinking));

    // Build the conversation context.
    final learner = _buildLearnerContext(profile);
    final context = ConversationContext(
      conversationId: state.conversationId,
      learner: learner,
      messages: state.messages,
    );

    // Send via the pipeline (handles persona, memory, AI, safety, persistence).
    final result = await pipeline.send(
      context: context,
      userMessage: userMessage,
      config: config,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isSending: false,
          error: failure.message,
        );
        van.dispatch(VanEvent(
          VanEventType.errorOccurred,
          message: 'I couldn\'t connect right now. Let\'s try again soon.',
        ));
      },
      (updatedContext) async {
        // The updated context includes the assistant's reply appended.
        state = state.copyWith(
          messages: updatedContext.messages,
          isSending: false,
          clearError: true,
        );
        final reply = updatedContext.messages.isEmpty
            ? null
            : updatedContext.messages.last.content;
        van.dispatch(VanEvent(VanEventType.aiResponseStarted, message: reply));

        // ── Achievement check ──────────────────────────────────────
        // After the first successful chat message, check for the
        // 'van_friend' achievement.
        final checker = _ref.read(achievementCheckerProvider);
        await checker.checkAchievements(didChatWithVan: true);
      },
    );
  }

  /// Start a new conversation (clears current messages + memory).
  Future<void> startNewConversation() async {
    final memory = _ref.read(conversationMemoryProvider);
    await memory.clear(state.conversationId);

    // Generate a new conversation ID.
    final newId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    state = ChatState(conversationId: newId);
    _ref.read(vanControllerProvider.notifier).settle();
  }

  /// Clear the error state.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// The chat controller provider.
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});
