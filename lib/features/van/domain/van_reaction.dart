/// Resolution from a domain event to a finite or sustained Van presentation.
library;

import 'package:flutter/foundation.dart';

import 'package:vaanix_app/features/van/domain/van_event.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';

@immutable
class VanReaction {
  const VanReaction({
    required this.event,
    required this.state,
    required this.priority,
    this.duration,
    this.fallbackState = VanState.idle,
    this.message,
  });

  final VanEventType event;
  final VanState state;
  final VanPriority priority;
  final Duration? duration;
  final VanState fallbackState;
  final String? message;
}

/// Maps product lifecycle events to Van's approved emotional vocabulary.
abstract final class VanReactionResolver {
  static VanReaction resolve(VanEvent event) {
    final state = switch (event.type) {
      VanEventType.appOpened => VanState.happy,
      VanEventType.lessonStarted => VanState.happy,
      VanEventType.lessonCompleted => VanState.achievement,
      VanEventType.quizStarted => VanState.focus,
      VanEventType.quizAnswerCorrect => VanState.happy,
      VanEventType.quizAnswerWrong => VanState.caring,
      VanEventType.quizCompleted => VanState.achievement,
      VanEventType.perfectScore => VanState.achievement,
      VanEventType.aiThinking => VanState.thinking,
      VanEventType.aiResponseStarted => VanState.speaking,
      VanEventType.aiResponseFinished => VanState.idle,
      VanEventType.userMessageReceived => VanState.thinking,
      VanEventType.userIdle => VanState.idle,
      VanEventType.achievementUnlocked => VanState.achievement,
      VanEventType.streakExtended => VanState.surprised,
      VanEventType.onboardingCompleted => VanState.happy,
      VanEventType.errorOccurred => VanState.error,
      VanEventType.companionTapped => VanState.funny,
    };
    final definition = state.definition;
    return VanReaction(
      event: event.type,
      state: state,
      priority: definition.priority,
      // A feature-provided display hint wins over the state default so the
      // caller can stretch (never used to shorten below its own hint) a
      // reaction for genuine content, e.g. reading-time for chat replies.
      duration: event.displayDuration ?? definition.defaultDuration,
      fallbackState: definition.fallbackState,
      message: event.message,
    );
  }
}
