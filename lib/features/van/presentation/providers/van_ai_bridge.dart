/// VAN ↔ AI routing bridge.
///
/// Maps an [AiLifecycleStage] (the abstract lifecycle of any AI request
/// that travels through the central AI gateway) onto the existing
/// [VanEvent] vocabulary so VAN can react without ever importing the AI
/// gateway, the Gemini adapter, or the Groq adapter.
///
/// The bridge is intentionally a pure function: the caller (typically
/// [ChatController], or any future feature that calls AI) observes an
/// AI lifecycle stage and dispatches a single [VanEvent] derived from
/// the mapper below. VAN continues to be the only component that owns
/// the visual state machine; this file only translates between two
/// domain vocabularies.
///
/// Provider-agnostic by construction: the bridge never inspects which
/// adapter answered the request (Gemini / Groq / offline), so swapping
/// the configured provider never requires touching this file.
library;

import 'package:vaanix_app/features/van/domain/van_event.dart';

/// The five lifecycle stages an AI request can occupy.
///
/// Distinct from `AiMessage.role` / streaming-state because VAN does
/// not need to know about message bodies — only about the abstract
/// shape of "the AI is being talked to right now".
enum AiLifecycleStage {
  /// A user message has just been submitted; AI processing is queued.
  userSubmitted,

  /// The adapter is actively preparing a response (network in-flight,
  /// model inference, etc.).
  thinking,

  /// The adapter has emitted visible response content (a streaming
  /// delta or a non-streaming completion). VAN should present the
  /// "speaking" state while this lasts.
  responding,

  /// The adapter has finished emitting content and the AI is no longer
  /// active. VAN returns to its idle state.
  idle,

  /// The adapter signalled an error or a fallback (rate limit, network
  /// failure, content filter, missing key, etc.). VAN renders its
  /// existing error reaction.
  error,
}

/// Resolve a single [AiLifecycleStage] into the existing [VanEvent] the
/// VAN controller already knows how to present.
///
/// This is the SINGLE place in the codebase where an AI lifecycle stage
/// is mapped to a VAN event. Tests assert the mapping exhaustively so
/// adding a new provider or a new lifecycle stage cannot silently
/// detach the VAN reaction chain.
///
/// `displayDuration` may be supplied to stretch the speaking reaction
/// for the length of an actual response; it is forwarded as-is and is
/// respected by the existing VAN controller for non-protected reactions.
VanEvent vanEventForStage(
  AiLifecycleStage stage, {
  String? message,
  Duration? displayDuration,
  Map<String, Object?> payload = const {},
}) {
  final type = switch (stage) {
    AiLifecycleStage.userSubmitted => VanEventType.userMessageReceived,
    AiLifecycleStage.thinking => VanEventType.aiThinking,
    AiLifecycleStage.responding => VanEventType.aiResponseStarted,
    AiLifecycleStage.idle => VanEventType.aiResponseFinished,
    AiLifecycleStage.error => VanEventType.errorOccurred,
  };
  return VanEvent(
    type,
    message: message,
    payload: payload,
    displayDuration: displayDuration,
  );
}
