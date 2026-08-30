/// VaaniX AI — Conversation Context
///
/// Bundles everything a request needs beyond the raw message: Van's persona,
/// learner context (name, class, streak), and the recent transcript. The
/// [ConversationPipeline] assembles this and hands it to the [AIService],
/// keeping adapter interfaces small and consistent across providers.
///
/// Conversation state (the rolling transcript) is owned here; memory
/// persistence is delegated to a [ConversationMemory] implementation.

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/ai/domain/ai_message.dart';

/// Snapshot of the learner passed into every prompt so Van can personalize
/// responses (e.g. "नमस्ते अर्जुन!"). Populated from the profile feature.
class LearnerContext extends Equatable {
  const LearnerContext({
    this.displayName = '',
    this.companionName = 'Van',
    this.cbseClassLabel,
    this.currentStreak = 0,
    this.xpTotal = 0,
    this.personalityMode = '',
    this.topic = '',
  });

  /// Display name of the learner.
  final String displayName;

  /// The name the learner gave Van.
  final String companionName;

  /// Human-readable CBSE class label (e.g. "Class 8"), or null if unset.
  final String? cbseClassLabel;

  final int currentStreak;
  final int xpTotal;

  /// Active personality mode label (e.g. "cheerleader"), for tone steering.
  final String personalityMode;

  /// Current learning topic / chapter title, when known.
  final String topic;

  /// Empty learner context — used before onboarding completes.
  static const LearnerContext empty = LearnerContext();

  @override
  List<Object?> get props => [
        displayName,
        companionName,
        cbseClassLabel,
        currentStreak,
        xpTotal,
        personalityMode,
        topic,
      ];
}

/// Immutable snapshot of a conversation at the moment a request is made.
class ConversationContext extends Equatable {
  const ConversationContext({
    required this.conversationId,
    required this.learner,
    required this.messages,
    this.personaPrompt = '',
  });

  /// Unique id of this conversation (used by memory adapters for storage keys).
  final String conversationId;

  /// Learner context snapshot.
  final LearnerContext learner;

  /// The ordered transcript of messages so far (oldest → newest).
  final List<AiMessage> messages;

  /// The resolved persona/instruction prompt for Van (overrides config.systemPrompt
  /// when non-empty). Built by the prompt pipeline from the personality mode.
  final String personaPrompt;

  /// A context with no prior messages — the start of a new conversation.
  factory ConversationContext.initial({
    required String conversationId,
    required LearnerContext learner,
    String personaPrompt = '',
  }) =>
      ConversationContext(
        conversationId: conversationId,
        learner: learner,
        messages: const [],
        personaPrompt: personaPrompt,
      );

  /// The most recent message, or null when the transcript is empty.
  AiMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Only the user + assistant messages (transcript shown to the model).
  List<AiMessage> get transcript => messages
      .where((m) => m.role == AiRole.user || m.role == AiRole.assistant)
      .toList(growable: false);

  /// Returns a new context with [message] appended to the transcript.
  ConversationContext append(AiMessage message) => ConversationContext(
        conversationId: conversationId,
        learner: learner,
        messages: [...messages, message],
        personaPrompt: personaPrompt,
      );

  /// Returns a new context with the persona prompt replaced.
  ConversationContext withPersona(String prompt) => ConversationContext(
        conversationId: conversationId,
        learner: learner,
        messages: messages,
        personaPrompt: prompt,
      );

  /// Returns a new context truncated to the most recent [keep] messages,
  /// used to stay within a provider's context window.
  ConversationContext truncated({int keep = 20}) {
    if (messages.length <= keep) return this;
    return ConversationContext(
      conversationId: conversationId,
      learner: learner,
      messages: messages.sublist(messages.length - keep),
      personaPrompt: personaPrompt,
    );
  }

  @override
  List<Object?> get props => [conversationId, learner, messages, personaPrompt];
}
