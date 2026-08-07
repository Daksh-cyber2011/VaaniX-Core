/// VaaniX AI — Message Models
///
/// Core domain types representing a single turn in a conversation between
/// the learner and the AI companion (Van). These are model-agnostic and
/// streaming-agnostic: every [ModelAdapter] must accept and emit them.
///
/// Layer rule: `domain` defines the contract; `data` (model adapters) and
/// `presentation` consume it. Domain never imports either.

import 'package:equatable/equatable.dart';

/// Who authored a message in the conversation.
enum AiRole {
  /// System / instruction prompt (sets Van's persona, rules, context).
  system,

  /// The learner.
  user,

  /// Van (the AI assistant).
  assistant,

  /// A tool/function call result injected into the transcript.
  tool,
}

/// A single message in a conversation transcript.
class AiMessage extends Equatable {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.metadata = const {},
  });

  /// Stable unique id (uuid or sequence).
  final String id;

  final AiRole role;

  /// The textual content. For streaming deltas this holds the accumulated
  /// text so far; for completed messages it is the final text.
  final String content;

  /// When the message was created (UTC). Null for transient/streaming.
  final DateTime? createdAt;

  /// Free-form adapter metadata (model id, token counts, finish reason).
  /// Kept untyped so adapters can attach provider-specific data without
  /// forcing every model into the same shape.
  final Map<String, dynamic> metadata;

  /// Convenience constructor for a user message.
  factory AiMessage.user({
    required String id,
    required String content,
    DateTime? createdAt,
  }) =>
      AiMessage(
        id: id,
        role: AiRole.user,
        content: content,
        createdAt: createdAt,
      );

  /// Convenience constructor for an assistant message.
  factory AiMessage.assistant({
    required String id,
    required String content,
    DateTime? createdAt,
    Map<String, dynamic> metadata = const {},
  }) =>
      AiMessage(
        id: id,
        role: AiRole.assistant,
        content: content,
        createdAt: createdAt,
        metadata: metadata,
      );

  /// Convenience constructor for a system instruction.
  factory AiMessage.system({
    required String id,
    required String content,
  }) =>
      AiMessage(
        id: id,
        role: AiRole.system,
        content: content,
      );

  AiMessage copyWith({
    String? id,
    AiRole? role,
    String? content,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) =>
      AiMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata ?? this.metadata,
      );

  /// Deserialize from JSON (for loading persisted conversation history).
  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      role: AiRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Serialize to JSON (for persisting conversation history).
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt?.toIso8601String(),
        'metadata': metadata,
      };

  @override
  List<Object?> get props => [id, role, content, createdAt, metadata];
}

/// A single streamed token/chunk emitted by a [ModelAdapter].
///
/// Streaming adapters emit these as the response is generated. Non-streaming
/// adapters can wrap the full response in a single delta.
class AiStreamDelta extends Equatable {
  const AiStreamDelta({
    required this.content,
    this.done = false,
    this.metadata = const {},
  });

  /// The incremental text since the previous delta (may be a single token).
  final String content;

  /// True once the stream has finished producing the response.
  final bool done;

  /// Optional per-delta metadata (e.g. usage stats on the final chunk).
  final Map<String, dynamic> metadata;

  @override
  List<Object?> get props => [content, done];
}

/// Usage / token accounting for a completed generation.
class AiUsage extends Equatable {
  const AiUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  AiUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) =>
      AiUsage(
        promptTokens: promptTokens ?? this.promptTokens,
        completionTokens: completionTokens ?? this.completionTokens,
        totalTokens: totalTokens ?? this.totalTokens,
      );

  @override
  List<Object?> get props => [promptTokens, completionTokens, totalTokens];
}
