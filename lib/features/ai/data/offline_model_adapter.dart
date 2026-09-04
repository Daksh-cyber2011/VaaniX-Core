/// VaaniX AI - Offline Model Adapter
///
/// The always-available, dependency-free [ModelAdapter]. It is the registry's
/// fallback when no remote provider is configured, so the AI seam is fully
/// functional even before any LLM credentials exist.
///
/// Instead of a generic "I am offline" echo, this adapter powers a real
/// offline Sanskrit tutor: intent detection (greetings, translation lookups,
/// numbers, family words, grammar cards, practice quizzes with grading),
/// grounded in the seeded curriculum via [OfflineTutor]. It still explains
/// that it is offline whenever a request needs a real model.
///
/// When a real adapter (Gemini/GLM/...) is registered AND available, the
/// [AIService] prefers it; this adapter only serves direct calls or the
/// offline fallback path.
library;

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/offline_tutor.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

class OfflineModelAdapter implements ModelAdapter {
  OfflineModelAdapter();

  static const OfflineTutor _tutor = OfflineTutor();

  /// Per-conversation cursor into [OfflineTutor.practiceQuestions].
  /// Deterministic per conversation so retries and "skip" behave predictably.
  final Map<String, int> _practiceCursor = {};

  int _counter = 0;

  @override
  AiProviderId get providerId => AiProviderId.offline;

  @override
  String get displayName => 'Van (Offline)';

  @override
  bool get isAvailable => true;

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    return guardAsync(() async {
      final pending = _pendingQuestion(context);
      final reply = _buildReply(context, pending);
      _afterReply(context, pending, reply);
      return AiMessage.assistant(
        id: _nextId(),
        content: reply.text,
        createdAt: DateTime.now().toUtc(),
        metadata: {
          'provider': 'offline',
          if (reply.nextQuestion != null) 'practiceQId': reply.nextQuestion!.id,
        },
      );
    });
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) async* {
    // Emit the reply word-by-word to exercise the streaming seam without a
    // real backend.
    final pending = _pendingQuestion(context);
    final reply = _buildReply(context, pending);
    final words = reply.text.split(' ');
    for (var i = 0; i < words.length; i++) {
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      final isLast = i == words.length - 1;
      yield ok(AiStreamDelta(content: chunk, done: isLast));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    _afterReply(context, pending, reply);
  }

  @override
  void dispose() {
    // No resources to release; the practice cursor map is small and owned by
    // this adapter instance for the app's lifetime.
  }

  // ---------------------------------------------------------------------
  // Tutor wiring
  // ---------------------------------------------------------------------

  /// The outstanding practice question, if the most recent assistant reply
  /// was one. Detected from the transcript alone (no metadata dependency),
  /// so it works for both the complete() and stream() paths.
  PracticeQuestion? _pendingQuestion(ConversationContext context) {
    AiMessage? lastAssistant;
    for (final message in context.messages.reversed) {
      if (message.role == AiRole.assistant) {
        lastAssistant = message;
        break;
      }
    }
    if (lastAssistant == null || !lastAssistant.content.contains('Practice:')) {
      return null;
    }
    for (final q in OfflineTutor.practiceQuestions) {
      if (lastAssistant.content.contains(q.question)) return q;
    }
    return null;
  }

  OfflineTutorReply _buildReply(
    ConversationContext context,
    PracticeQuestion? pending,
  ) {
    return _tutor.reply(
      message: context.lastMessage?.content ?? '',
      displayName: context.learner.displayName,
      companionName: context.learner.companionName,
      pendingQuestion: pending,
      practiceIndex: _practiceCursor[context.conversationId] ?? 0,
    );
  }

  /// Advances the practice cursor when a fresh question was asked, or when a
  /// pending question was answered correctly or skipped. A wrong retry keeps
  /// the same question.
  void _afterReply(
    ConversationContext context,
    PracticeQuestion? pending,
    OfflineTutorReply reply,
  ) {
    final advanced = reply.nextQuestion != null &&
        (pending == null || pending.id != reply.nextQuestion!.id);
    if (advanced) {
      _practiceCursor[context.conversationId] =
          (_practiceCursor[context.conversationId] ?? 0) + 1;
    }
  }

  String _nextId() {
    _counter += 1;
    return 'offline_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
