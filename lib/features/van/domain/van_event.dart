/// Typed lifecycle events that can trigger a Van reaction.
library;

import 'package:flutter/foundation.dart';

/// Events are intentionally domain-oriented so features do not depend on a
/// particular Van widget or animation implementation.
enum VanEventType {
  appOpened,
  lessonStarted,
  lessonCompleted,
  quizStarted,
  quizAnswerCorrect,
  quizAnswerWrong,
  quizCompleted,
  perfectScore,
  aiThinking,
  aiResponseStarted,
  aiResponseFinished,
  userMessageReceived,

  /// Reserved. Intentionally NOT dispatched in V1: no genuine idle detector
  /// exists in the app, and dispatching a synthetic "user is idle" event
  /// would fabricate companion behavior the product has not designed. The
  /// resolver keeps its settle-only semantics so a future detector (for
  /// example a chat-screen inactivity nudge) can adopt it without a
  /// contract change. Decision recorded in the Phase 3 changelog.
  userIdle,
  achievementUnlocked,
  streakExtended,
  onboardingCompleted,
  errorOccurred,
  companionTapped,
}

@immutable
class VanEvent {
  const VanEvent(
    this.type, {
    this.message,
    this.payload = const {},
    this.displayDuration,
  });

  final VanEventType type;

  /// Optional short copy for Van's speech bubble. Content remains owned by
  /// the calling feature, never by the VAN state machine.
  final String? message;

  /// Future-safe structured context, such as a lesson or achievement id.
  final Map<String, Object?> payload;

  /// Optional display hint that overrides the state's default reaction
  /// duration for this single dispatch. Used by the chat controller so the
  /// speaking reaction lasts as long as the reply genuinely needs to be
  /// read, instead of hard-cutting at the state's default duration.
  final Duration? displayDuration;
}
