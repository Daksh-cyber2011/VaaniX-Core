/// Canonical presentation states for Van.
///
/// The original nine states are retained for source compatibility. The two
/// operational states, [speaking] and [error], model AI and recoverable system
/// lifecycle feedback without overloading an emotional state.
library;

import 'package:flutter/foundation.dart';

/// Priority used by the controller when multiple reactions compete.
enum VanPriority { idle, task, interaction, feedback, achievement, critical }

/// The emotional or operational state Van should present.
enum VanState {
  idle,
  happy,
  thinking,
  focus,
  caring,
  surprised,
  sad,
  funny,
  achievement,
  speaking,
  error,
}

/// Declarative behavior attached to a [VanState].
@immutable
class VanStateDefinition {
  const VanStateDefinition({
    required this.id,
    required this.meaning,
    required this.priority,
    required this.defaultDuration,
    required this.interruptible,
    required this.fallbackState,
    required this.allowsSpeech,
    required this.allowsAiThinking,
    required this.allowsUserInteraction,
  });

  final String id;
  final String meaning;
  final VanPriority priority;
  final Duration? defaultDuration;
  final bool interruptible;
  final VanState fallbackState;
  final bool allowsSpeech;
  final bool allowsAiThinking;
  final bool allowsUserInteraction;
}

/// State metadata kept separate from the renderer so visual assets can change
/// without changing behavior.
extension VanStateDefinitionX on VanState {
  VanStateDefinition get definition => switch (this) {
        VanState.idle => const VanStateDefinition(
            id: 'idle',
            meaning: 'Relaxed, available companion.',
            priority: VanPriority.idle,
            defaultDuration: null,
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.happy => const VanStateDefinition(
            id: 'happy',
            meaning: 'Warm acknowledgement of progress.',
            priority: VanPriority.feedback,
            defaultDuration: Duration(milliseconds: 1400),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.thinking => const VanStateDefinition(
            id: 'thinking',
            meaning: 'Considering, processing, or waiting.',
            priority: VanPriority.task,
            defaultDuration: null,
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: false,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.focus => const VanStateDefinition(
            id: 'focus',
            meaning: 'Calm concentration during an assessment.',
            priority: VanPriority.task,
            defaultDuration: null,
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: false,
          ),
        VanState.caring => const VanStateDefinition(
            id: 'caring',
            meaning: 'Gentle support after difficulty.',
            priority: VanPriority.feedback,
            defaultDuration: Duration(milliseconds: 2400),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.surprised => const VanStateDefinition(
            id: 'surprised',
            meaning: 'Delighted surprise for a notable moment.',
            priority: VanPriority.achievement,
            defaultDuration: Duration(milliseconds: 1800),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: false,
            allowsUserInteraction: true,
          ),
        VanState.sad => const VanStateDefinition(
            id: 'sad',
            meaning: 'Mild concern; never shame or disappointment.',
            priority: VanPriority.feedback,
            defaultDuration: Duration(milliseconds: 1800),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.funny => const VanStateDefinition(
            id: 'funny',
            meaning: 'A brief, optional playful interaction.',
            priority: VanPriority.interaction,
            defaultDuration: Duration(milliseconds: 1200),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: true,
            allowsUserInteraction: true,
          ),
        VanState.achievement => const VanStateDefinition(
            id: 'achievement',
            meaning: 'Celebration of a meaningful milestone.',
            priority: VanPriority.achievement,
            defaultDuration: Duration(milliseconds: 2600),
            interruptible: false,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: false,
            allowsUserInteraction: false,
          ),
        VanState.speaking => const VanStateDefinition(
            id: 'speaking',
            meaning: 'Delivering an AI or short educational response.',
            priority: VanPriority.feedback,
            defaultDuration: Duration(milliseconds: 2200),
            interruptible: true,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: false,
            allowsUserInteraction: true,
          ),
        VanState.error => const VanStateDefinition(
            id: 'error',
            meaning: 'A gentle, recoverable system problem.',
            priority: VanPriority.critical,
            defaultDuration: Duration(milliseconds: 2600),
            interruptible: false,
            fallbackState: VanState.idle,
            allowsSpeech: true,
            allowsAiThinking: false,
            allowsUserInteraction: true,
          ),
      };
}
