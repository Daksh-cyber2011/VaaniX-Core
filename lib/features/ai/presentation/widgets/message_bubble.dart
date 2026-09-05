/// VaaniX AI — Message Bubble
///
/// Renders a single chat message with appropriate styling based on the
/// sender's role. User messages are right-aligned with primary color;
/// assistant (Van) messages are left-aligned with a small Van avatar.
///
/// Devanagari text (U+0900–U+097F) is rendered with [AppTextStyles.sanskritBody]
/// for proper font support. Long-press copies the message to clipboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
  });

  final AiMessage message;

  bool get _isUser => message.role == AiRole.user;

  /// Returns true if the string contains any Devanagari character
  /// (Unicode range U+0900–U+097F).
  bool _containsDevanagari(String text) {
    for (final codeUnit in text.codeUnits) {
      if (codeUnit >= 0x0900 && codeUnit <= 0x097F) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasDevanagari = _containsDevanagari(message.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) ...[
            const VanWidget(
              state: VanState.happy,
              size: 32,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            // The copy action is only reachable via long-press; expose it
            // on the same semantics node as the message text (plus a
            // hint) so screen-reader users can copy messages too.
            child: Semantics(
              label: message.content,
              onLongPress: () => _copyMessage(context),
              hint: 'Long-press to copy message',
              child: ExcludeSemantics(
                child: GestureDetector(
                  onLongPress: () => _copyMessage(context),
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isUser
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        _isUser ? const Radius.circular(16) : Radius.zero,
                    bottomRight:
                        _isUser ? Radius.zero : const Radius.circular(16),
                  ),
                  border: _isUser
                      ? null
                      : Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: hasDevanagari
                          ? AppTextStyles.sanskritBody(
                              color: _isUser ? Colors.white : null,
                            )
                          : AppTextStyles.bodyMedium(
                              color: _isUser ? Colors.white : null,
                            ),
                    ),
                    if (message.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.createdAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: _isUser
                              ? Colors.white.withValues(alpha: 0.6)
                              : (isDark
                                  ? AppColors.subtextDark
                                  : AppColors.subtextLight),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
