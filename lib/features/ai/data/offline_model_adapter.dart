/// VaaniX AI — Offline Model Adapter
///
/// The always-available, dependency-free [ModelAdapter]. It is the registry's
/// fallback when no remote provider is configured, so the AI seam is fully
/// functional (returns encouraging, persona-aware canned replies) even before
/// any LLM credentials exist. This keeps the app runnable and the pipeline
/// exercised in every build.
///
/// When a real adapter (Gemini/GLM/…) is registered AND available, the
/// [AIService] prefers it; this adapter only serves direct calls or the
/// offline fallback path.

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';

class OfflineModelAdapter implements ModelAdapter {
  OfflineModelAdapter();

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
      final reply = _buildReply(context);
      return AiMessage.assistant(
        id: _nextId(),
        content: reply,
        createdAt: DateTime.now().toUtc(),
        metadata: const {'provider': 'offline'},
      );
    });
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) async* {
    // Emit the reply word-by-word to exercise the streaming seam without a
    // real backend. Adapters that buffer natively can mimic this shape.
    final words = _buildReply(context).split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      buffer.write(chunk);
      final isLast = i == words.length - 1;
      yield ok(AiStreamDelta(content: chunk, done: isLast));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  @override
  void dispose() {
    // No resources to release.
  }

  // ──────────────────────────────────────────────────────────────────
  // Reply composition
  // ──────────────────────────────────────────────────────────────────

  String _buildReply(ConversationContext context) {
    final learner = context.learner;
    final name = learner.displayName.trim();
    final companion = learner.companionName.trim().isEmpty
        ? 'Van'
        : learner.companionName.trim();
    final last = context.lastMessage?.content.trim() ?? '';

    if (last.isEmpty) {
      return name.isEmpty
          ? 'नमस्ते! I am $companion, your Sanskrit buddy. 🦆 What shall we learn today?'
          : 'नमस्ते $name! I am $companion. Ready to practice some Sanskrit? 🦆';
    }

    final greeting = name.isEmpty ? '' : '$name, ';
    return '$greeting'
        "I'm running offline right now, but I'm still here to cheer you on! 🦆 "
        'Once a learning model is connected I can answer: "$last" in detail. '
        'Keep going — every word counts!';
  }

  String _nextId() {
    _counter += 1;
    return 'offline_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
