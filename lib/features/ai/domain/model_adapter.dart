/// VaaniX AI — Model Adapter Contract
///
/// The single extension point for plugging a new LLM backend into VaaniX.
/// Each provider (Gemini, GLM, OpenAI, Claude, Groq, Kimi, …) gets one
/// implementation of [ModelAdapter]. The DI container resolves the active
/// adapter from [AiConfig.provider]; the rest of the app never knows which
/// provider is wired in.
///
/// Contract rules for adapters:
///   - Accept domain types only ([ConversationContext], [AiConfig]).
///   - Emit domain types only ([AiMessage], [AiStreamDelta], [AiUsage]).
///   - Never throw — return [Result] failures (use [guardAsync]).
///   - Translate provider errors via [ExceptionMapper].
///   - Map provider-specific auth/keys from environment, never from request
///     config (configs must stay secret-free).
library;

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';

/// A backend-agnostic LLM adapter.
abstract class ModelAdapter {
  /// Which provider this adapter fulfills requests for.
  AiProviderId get providerId;

  /// Human-readable label for diagnostics / settings UI.
  String get displayName;

  /// True when this adapter is ready to serve requests (e.g. an API key is
  /// configured). The offline adapter is always available; remote adapters
  /// return false until their credentials are present.
  bool get isAvailable;

  /// Generate a single, complete response for [context].
  ///
  /// Non-streaming path. Adapters that only stream should buffer internally
  /// and return the assembled message here.
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  });

  /// Stream response deltas as they are generated.
  ///
  /// The stream emits [AiStreamDelta]s and completes when generation finishes
  /// (the last delta carries `done: true`). Adapters that do not natively
  /// stream may emit a single delta with the full content.
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  });

  /// Release any resources (HTTP clients, isolates). Idempotent.
  void dispose();
}
