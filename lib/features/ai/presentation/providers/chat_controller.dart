/// VaaniX AI — Chat Controller
///
/// Riverpod Notifier that manages the chat conversation state. The UI calls
/// [sendMessage] to send a user message and receive Van's reply. The
/// controller:
///   1. Builds a [LearnerContext] from the user's profile (learner display
///      name, companion name, streak, XP, personality mode, CBSE class).
///   2. Creates or reuses a [ConversationContext] with a stable conversationId.
///   3. Dispatches the turn through [ConversationPipeline]: when the active
///      [AiConfig] allows streaming (`enableStreaming`), the reply is streamed
///      and rendered incrementally; otherwise the complete-turn path is used.
///      Either way the pipeline handles persona prompt, memory loading, AI
///      generation, safety filtering, and persistence.
///   4. Updates state with the new messages.
///
/// Conversations persist across app restarts via [LocalConversationMemory].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/learning_context_provider.dart';
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

  /// The full message list (user + assistant), oldest → newest. While a
  /// streaming reply is in flight, the last assistant message holds the
  /// text accumulated so far.
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

  bool _disposed = false;

  /// Completion signal for Van's speaking reaction (Phase 3): fires
  /// [VanEventType.aiResponseFinished] once the reply's reading window has
  /// elapsed, instead of the speaking state silently hard-cutting at its
  /// default duration. Cancelled on every new turn, failure, reset.
  Timer? _vanSpeakingTimer;

  /// Load any existing conversation from memory on startup.
  Future<void> _loadExistingConversation() async {
    final memory = _ref.read(conversationMemoryProvider);
    final result = await memory.load(state.conversationId);
    if (_disposed || !mounted) return;
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
      // Phase 4: the learner's real name (Settings → Your Name) reaches the
      // persona and the offline tutor. Empty until the learner sets one.
      displayName: profile.resolvedDisplayName,
      companionName: profile.resolvedCompanionName,
      cbseClassLabel: profile.cbseClass?.label,
      currentStreak: profile.currentStreak,
      xpTotal: _ref.read(xpTotalProvider),
      personalityMode: profile.personalityMode?.name ?? '',
      topic: 'Sanskrit',
    );
  }

  /// Reading window for Van's speaking reaction after a reply: the state's
  /// base cadence plus a small per-word extension (first word included in
  /// the base), bounded so an essay-long reply can never pin Van in
  /// speaking indefinitely. Short replies keep the exact pre-Phase-3
  /// cadence.
  @visibleForTesting
  static Duration speakingWindowFor(String? reply) {
    final words = reply == null || reply.trim().isEmpty
        ? 0
        : reply.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    const maxExtra =
        AppConstants.vanAiSpeakingMaxMs - AppConstants.vanAiSpeakingBaseMs;
    final extra = ((words - 1) * AppConstants.vanAiSpeakingPerWordMs)
        .clamp(0, maxExtra < 0 ? 0 : maxExtra);
    return Duration(milliseconds: AppConstants.vanAiSpeakingBaseMs + extra);
  }

  /// Send a user message and receive Van's reply.
  ///
  /// Routes through the streaming pipeline when the active config allows it
  /// ([AiConfig.enableStreaming]); the complete-turn path remains the
  /// fallback and the contract pinned by the controller tests.
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

    // Analytics: conversation start on the very first message, then the
    // generic send event for every dispatch.
    _ref.log(const AnalyticsEvent(AnalyticsEventName.aiMessageSent));
    if (state.messages.isEmpty) {
      _ref.log(const AnalyticsEvent(AnalyticsEventName.aiConversationStarted));
    }

    // Optimistically add the user message to the UI.
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      clearError: true,
    );
    final van = _ref.read(vanControllerProvider.notifier);
    _vanSpeakingTimer?.cancel();
    van.dispatch(const VanEvent(VanEventType.userMessageReceived));
    van.dispatch(const VanEvent(VanEventType.aiThinking));

    // Build the conversation context, stamped with the learner's REAL
    // curriculum state (V1 §4): learningContextProvider → context →
    // learningContextFragment → prompt pipeline → model adapters.
    final learner = _buildLearnerContext(profile);
    final learningContext = _ref.read(learningContextProvider);
    final context = ConversationContext(
      conversationId: state.conversationId,
      learner: learner,
      messages: state.messages,
      learningContext: learningContext,
    );

    // Resolve the achievement checker and safety filter before the await so
    // no provider read happens after a possible container disposal.
    final checker = _ref.read(achievementCheckerProvider);
    final safetyFilter = _ref.read(safetyFilterProvider);

    if (config.enableStreaming) {
      await _sendStreaming(
        pipeline: pipeline,
        context: context,
        userMessage: userMessage,
        config: config,
        van: van,
        checker: checker,
        safetyFilter: safetyFilter,
      );
    } else {
      await _sendComplete(
        pipeline: pipeline,
        context: context,
        userMessage: userMessage,
        config: config,
        van: van,
        checker: checker,
      );
    }
  }

  // ─── Complete-turn path ───────────────────────────────────────────────────

  /// The pre-Phase-4 turn: one request, one full reply.
  Future<void> _sendComplete({
    required ConversationPipeline pipeline,
    required ConversationContext context,
    required AiMessage userMessage,
    required AiConfig config,
    required VanController van,
    required AchievementChecker checker,
  }) async {
    // Send via the pipeline (handles persona, memory, AI, safety, persistence).
    final result = await pipeline.send(
      context: context,
      userMessage: userMessage,
      config: config,
    );

    // Both branches are async and MUST be awaited: dartz's Either.fold
    // otherwise discards the returned future, letting this method return
    // while the achievement check is still running (and racing container
    // disposal).
    await result.fold(
      (failure) async {
        if (_disposed || !mounted) return;
        await _failTurn(failure.message, van);
      },
      (updatedContext) async {
        if (_disposed || !mounted) return;
        // The updated context includes the assistant's reply appended.
        final reply = updatedContext.messages.isEmpty
            ? null
            : updatedContext.messages.last.content;
        await _succeedTurn(
          messages: updatedContext.messages,
          fullText: reply ?? '',
          van: van,
          checker: checker,
        );
      },
    );
  }

  // ─── Streaming path (Phase 4) ─────────────────────────────────────────────

  /// Streams Van's reply and renders deltas incrementally.
  ///
  /// Semantics:
  ///   - Each content delta updates the trailing assistant message in place,
  ///     so the bubble grows while Van "speaks".
  ///   - On success the assembled reply drives the exact same Van speaking
  ///     lifecycle + achievement check + usage-chip refresh as the complete
  ///     path.
  ///   - On failure the partial bubble is dropped (the pipeline persists
  ///     nothing on failure, so UI and memory stay consistent) and the error
  ///     surfaces exactly like a failed complete turn.
  ///   - A stream that closes with no content is treated as a failure —
  ///     "no reply" is never shown as a successful empty bubble.
  ///   - A final safety re-check on the ASSEMBLED text mirrors the pipeline's
  ///     own moderation: if the full text would not have been persisted, the
  ///     partial content is withdrawn rather than left dangling on screen.
  Future<void> _sendStreaming({
    required ConversationPipeline pipeline,
    required ConversationContext context,
    required AiMessage userMessage,
    required AiConfig config,
    required VanController van,
    required AchievementChecker checker,
    required SafetyFilter safetyFilter,
  }) async {
    final streamingId = 'stream_${DateTime.now().millisecondsSinceEpoch}';
    final buffer = StringBuffer();
    Failure? streamFailure;

    // Insert or grow the trailing partial assistant bubble.
    void upsertPartial(String content) {
      if (_disposed || !mounted) return;
      final messages = [...state.messages];
      final partial = AiMessage.assistant(
        id: streamingId,
        content: content,
        createdAt: DateTime.now().toUtc(),
      );
      final index = messages.indexWhere((m) => m.id == streamingId);
      if (index == -1) {
        messages.add(partial);
      } else {
        messages[index] = partial;
      }
      state = state.copyWith(messages: messages);
    }

    void dropPartial() {
      if (_disposed || !mounted) return;
      final messages = [...state.messages]
        ..removeWhere((m) => m.id == streamingId);
      state = state.copyWith(messages: messages);
    }

    try {
      await for (final result
          in pipeline.stream(context: context, userMessage: userMessage, config: config)) {
        if (_disposed || !mounted) return; // cancels the subscription
        result.fold(
          (failure) {
            // First failure wins; the partial (never persisted by the
            // pipeline) is withdrawn immediately.
            streamFailure ??= failure;
            dropPartial();
          },
          (delta) {
            if (streamFailure != null) return;
            if (delta.done) return; // content already accumulated
            buffer.write(delta.content);
            upsertPartial(buffer.toString());
          },
        );
      }
    } catch (e) {
      // Defensive: an adapter that throws instead of yielding an error.
      streamFailure ??= AiServiceFailure(e.toString());
      dropPartial();
    }

    if (_disposed || !mounted) return;

    final fullText = buffer.toString();
    final failure = streamFailure;
    if (failure != null) {
      await _failTurn(failure.message, van);
      return;
    }
    if (fullText.isEmpty) {
      // The stream ended without any content — never render success.
      dropPartial();
      await _failTurn(
        'Van couldn\'t come up with a reply. Please try again.',
        van,
      );
      return;
    }
    if (!safetyFilter.isOutputSafe(fullText)) {
      // Mirror ConversationPipelineImpl.stream: an unsafe assembled reply is
      // not persisted, so the UI must not keep it either.
      dropPartial();
      await _failTurn(const AiContentFilterFailure().message, van);
      return;
    }

    await _succeedTurn(
      messages: null, // the assembled partial bubble is already in state
      fullText: fullText,
      van: van,
      checker: checker,
    );
  }

  // ─── Shared turn finalization ─────────────────────────────────────────────

  /// Marks a turn failed: keep the optimistic user message, surface the
  /// error, and send Van to the error reaction. Never schedules a speaking
  /// completion signal.
  Future<void> _failTurn(String message, VanController van) async {
    _vanSpeakingTimer?.cancel();
    _ref.log(const AnalyticsEvent(AnalyticsEventName.aiRequestFailed));
    state = state.copyWith(
      isSending: false,
      error: message,
    );
    van.dispatch(const VanEvent(
      VanEventType.errorOccurred,
      message: 'I couldn\'t connect right now. Let\'s try again soon.',
    ));
  }

  /// Marks a turn successful: writes the final messages into state (when
  /// provided by the complete path; the streaming path's assembled bubble
  /// is already in state), drives Van's reading-window speaking lifecycle,
  /// refreshes the usage chip, and runs the achievement check.
  Future<void> _succeedTurn({
    required List<AiMessage>? messages,
    required String fullText,
    required VanController van,
    required AchievementChecker checker,
  }) async {
    _ref.log(const AnalyticsEvent(AnalyticsEventName.aiRequestSucceeded));
    state = state.copyWith(
      messages: messages,
      isSending: false,
      clearError: true,
    );

    // Phase 4: the usage chip reads [dailyUsageProvider]; invalidating it
    // after every successful turn keeps the remaining-quota count honest
    // (previously the chip was computed once and went stale).
    _ref.invalidate(dailyUsageProvider);

    // Phase 3: the speaking reaction lasts exactly as long as the reply
    // needs to be read (displayDuration), and its genuine completion is
    // signalled with aiResponseFinished instead of relying on the
    // state's fallback timer alone.
    final window = speakingWindowFor(fullText);
    van.dispatch(VanEvent(
      VanEventType.aiResponseStarted,
      message: fullText,
      displayDuration: window,
    ));
    _vanSpeakingTimer?.cancel();
    _vanSpeakingTimer = Timer(window, () {
      if (_disposed || !mounted) return;
      van.dispatch(const VanEvent(VanEventType.aiResponseFinished));
    });

    // ── Achievement check ──────────────────────────────────────
    // After the first successful chat message, check for the
    // 'van_friend' achievement.
    await checker.checkAchievements(didChatWithVan: true);
  }

  /// Start a new conversation (clears current messages + memory).
  Future<void> startNewConversation() async {
    // Never reset while a reply is in flight - the late response would
    // clobber the fresh conversation.
    if (state.isSending) return;
    final memory = _ref.read(conversationMemoryProvider);
    await memory.clear(state.conversationId);
    if (_disposed || !mounted) return;

    // Generate a new conversation ID.
    final newId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    state = ChatState(conversationId: newId);
    _vanSpeakingTimer?.cancel();
    _ref.read(vanControllerProvider.notifier).settle();
  }

  /// Clear the error state.
  void clearError() {
    _ref.log(const AnalyticsEvent(AnalyticsEventName.appErrorRecovered));
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _vanSpeakingTimer?.cancel();
    super.dispose();
  }
}

/// The chat controller provider.
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref);
});
