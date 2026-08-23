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
  userIdle,
  achievementUnlocked,
  streakExtended,
  onboardingCompleted,
  errorOccurred,
  companionTapped,
}

@immutable
class VanEvent {
  const VanEvent(this.type, {this.message, this.payload = const {}});

  final VanEventType type;

  /// Optional short copy for Van's speech bubble. Content remains owned by
  /// the calling feature, never by the VAN state machine.
  final String? message;

  /// Future-safe structured context, such as a lesson or achievement id.
  final Map<String, Object?> payload;
}
