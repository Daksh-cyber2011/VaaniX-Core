/// Riverpod controller for Van's event-driven presentation state.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/van/domain/van_domain.dart';

@immutable
class VanPresentationState {
  const VanPresentationState({
    this.current = VanState.idle,
    this.reaction,
    this.message,
    this.isLoading = false,
  });

  final VanState current;
  final VanReaction? reaction;
  final String? message;
  final bool isLoading;

  VanPresentationState copyWith({
    VanState? current,
    VanReaction? reaction,
    String? message,
    bool? isLoading,
    bool clearReaction = false,
    bool clearMessage = false,
  }) {
    return VanPresentationState(
      current: current ?? this.current,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      message: clearMessage ? null : (message ?? this.message),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Owns arbitration, cancellation, and automatic fallbacks for VAN reactions.
class VanController extends StateNotifier<VanPresentationState> {
  VanController() : super(const VanPresentationState());

  Timer? _fallbackTimer;
  int _reactionSequence = 0;

  /// Sends [event] through the resolver. Returns false when a current,
  /// non-interruptible or higher-priority reaction must remain visible.
  bool dispatch(VanEvent event) {
    if (!mounted) return false;
    if (event.type == VanEventType.aiResponseFinished ||
        event.type == VanEventType.userIdle) {
      return settle();
    }
    final next = VanReactionResolver.resolve(event);
    if (!canPresent(next)) return false;

    _fallbackTimer?.cancel();
    final sequence = ++_reactionSequence;
    final isLoading = next.state == VanState.thinking;
    state = VanPresentationState(
      current: next.state,
      reaction: next,
      message: next.message,
      isLoading: isLoading,
    );

    final duration = next.duration;
    if (duration != null) {
      _fallbackTimer = Timer(duration, () {
        if (!mounted || sequence != _reactionSequence) return;
        _returnTo(next.fallbackState);
      });
    }
    return true;
  }

  /// Whether [candidate] can replace the state currently on screen.
  bool canPresent(VanReaction candidate) {
    final current = state.reaction;
    if (current == null || state.current == VanState.idle) return true;
    if (!state.current.definition.interruptible) {
      return candidate.priority == VanPriority.critical;
    }
    if (candidate.priority.index > current.priority.index) return true;
    if (candidate.priority.index == current.priority.index) return true;
    return false;
  }

  /// Ends a sustained state, for example after an AI stream completes.
  ///
  /// Non-interruptible reactions (celebration, critical error) are never cut
  /// short: their own fallback timer returns Van to idle when they finish.
  /// Returns true when Van settled to idle, false when the request was
  /// deferred so a protected reaction could complete.
  bool settle() {
    if (!mounted) return false;
    if (!state.current.definition.interruptible) return false;
    _fallbackTimer?.cancel();
    ++_reactionSequence;
    _returnTo(VanState.idle);
    return true;
  }

  void _returnTo(VanState fallback) {
    state = VanPresentationState(
      current: fallback,
      isLoading: false,
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }
}

/// Global companion presentation state. Only consumers of this provider
/// rebuild when Van reacts.
final vanControllerProvider =
    StateNotifierProvider<VanController, VanPresentationState>((ref) {
  return VanController();
});
