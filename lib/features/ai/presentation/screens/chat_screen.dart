/// VaaniX AI — Chat Screen
///
/// The conversational surface where the learner talks to Van. Shows a
/// scrolling list of message bubbles, a typing indicator while Van is
/// replying, and a text input at the bottom. Conversations persist across
/// app restarts via [LocalConversationMemory].
///
/// Entry points: Van Profile screen ("Chat with Van" button) and Home
/// screen (chat icon in the top bar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/ai/data/token_usage_tracker.dart';

import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/ai/presentation/widgets/chat_input.dart';
import 'package:vaanix_app/features/ai/presentation/widgets/message_bubble.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to the bottom when a new message arrives.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final profile = ref.watch(userProfileProvider);
    final companionName = profile.resolvedCompanionName;

    // Auto-scroll when messages change.
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VanWidget(useController: true, size: 32),
            const SizedBox(width: 10),
            Text(companionName, style: AppTextStyles.titleMedium()),
          ],
        ),
        centerTitle: true,
        actions: [
          // ─── AI Usage Indicator ──────────────────────────────────
          // Shows remaining daily requests as a small chip. Tapping
          // it shows detailed usage in a dialog.
          FutureBuilder(
            future: ref.read(tokenUsageTrackerProvider).getTodayUsage(),
            builder: (context, snapshot) {
              final usage = snapshot.data ?? DailyUsage.zero();
              final remaining = usage.remainingRequests;
              final color = remaining > 100
                  ? AppColors.success
                  : (remaining > 20 ? AppColors.warning : AppColors.error);

              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showUsageDialog(context, usage),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '$remaining',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () {
              ref.read(chatControllerProvider.notifier).startNewConversation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Message List ─────────────────────────────────────────
          Expanded(
            child: chatState.messages.isEmpty
                ? _emptyState(companionName)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: chatState.messages.length +
                        (chatState.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Typing indicator at the end while sending.
                      if (index == chatState.messages.length &&
                          chatState.isSending) {
                        return _typingIndicator();
                      }
                      return MessageBubble(
                        message: chatState.messages[index],
                      );
                    },
                  ),
          ),

          // ─── Error Banner (if any) ────────────────────────────────
          if (chatState.error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: AppTextStyles.bodySmall(color: AppColors.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      ref.read(chatControllerProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),

          // ─── Input ────────────────────────────────────────────────
          ChatInput(
            onSend: (text) {
              ref.read(chatControllerProvider.notifier).sendMessage(text);
            },
            isSending: chatState.isSending,
          ),
        ],
      ),
    );
  }

  /// Show a dialog with detailed AI usage stats.
  void _showUsageDialog(BuildContext context, DailyUsage usage) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('AI Usage Today'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _usageRow('Requests used',
                '${usage.requestCount} / ${TokenUsageTracker.dailyRequestLimit}'),
            _usageRow('Tokens used',
                '${_formatTokens(usage.totalTokens)} / ${_formatTokens(TokenUsageTracker.dailyTokenLimit)}'),
            _usageRow('Remaining requests', '${usage.remainingRequests}'),
            const SizedBox(height: 12),
            // Request usage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usage.requestUsageFraction.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                color: usage.requestUsageFraction < 0.7
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cached responses don\'t count against your quota. '
              'Van remembers repeated questions to save your limits!',
              style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _usageRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium()),
          Text(value,
              style: AppTextStyles.bodyMedium(
                color: AppColors.primary,
              )),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '$tokens';
  }

  /// Empty state shown when the conversation has no messages yet.
  Widget _emptyState(String companionName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanWidget(
            state: VanState.happy,
            size: 120,
            showSpeechBubble: true,
            dialogueText: 'नमस्ते! Ask me anything about Sanskrit! 🦆',
          ),
          const SizedBox(height: 16),
          Text(
            'Chat with $companionName',
            style: AppTextStyles.headlineSmall(),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a message below to start learning!',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Typing indicator shown while Van is generating a reply.
  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VanWidget(useController: true, size: 32),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.subtextLight,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
