/// Lesson Content Screen
///
/// Full-screen lesson reader. Renders the lesson's markdown-like content
/// via [LessonContentView], tracks whether the user has scrolled to the
/// bottom, and gates the "Mark Complete" button behind that scroll.
///
/// On mark complete: calls [CompletedLessonsNotifier.markComplete],
/// invalidates [xpTotalProvider], shows a snackbar, and pops back to the
/// Learn screen.
///
/// If the lesson is already completed, the button reads "Completed ✓"
/// and is disabled — the user can still re-read the content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/presentation/widgets/lesson_content_view.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LessonContentScreen extends ConsumerStatefulWidget {
  const LessonContentScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonContentScreen> createState() =>
      _LessonContentScreenState();
}

class _LessonContentScreenState extends ConsumerState<LessonContentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasScrolledToBottom) return; // Once true, stay true.
    final position = _scrollController.position;
    // Consider "reached bottom" when within 80px of the max scroll extent.
    // This accounts for minor rounding differences across devices.
    if (position.pixels >= position.maxScrollExtent - 80) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  Future<void> _markComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final notifier = ref.read(completedLessonIdsProvider.notifier);
    await notifier.markComplete(widget.lesson);
    ref.invalidate(xpTotalProvider);

    if (!mounted) return;
    setState(() => _isCompleting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+${widget.lesson.xpReward} XP earned! 🎉'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedLessonIdsProvider);
    final isAlreadyDone = completed.contains(widget.lesson.id);
    final content = widget.lesson.content;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lesson.title,
          style: AppTextStyles.titleMedium(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                '+${widget.lesson.xpReward} XP',
                style: AppTextStyles.labelSmall(color: AppColors.primary),
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: content == null || content.isEmpty
          ? _emptyContent(context)
          : _contentBody(context, content),
      bottomNavigationBar: _bottomBar(isAlreadyDone),
    );
  }

  Widget _contentBody(BuildContext context, String content) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Fallback scroll detection for cases where the ScrollController
        // listener doesn't fire (e.g., very short content that doesn't
        // actually scroll).
        if (notification is ScrollUpdateNotification && !_hasScrolledToBottom) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 80) {
            setState(() => _hasScrolledToBottom = true);
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        child: LessonContentView(content: content),
      ),
    );
  }

  Widget _emptyContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanWidget(
            state: VanState.thinking,
            size: 120,
            showSpeechBubble: true,
            dialogueText: 'Content coming soon! 📖',
          ),
          const SizedBox(height: 16),
          Text(
            'This lesson\'s content is being prepared.',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(bool isAlreadyDone) {
    // If already completed, show a disabled "Completed ✓" button.
    if (isAlreadyDone) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lesson completed — review anytime',
                  style: AppTextStyles.bodyMedium(color: AppColors.success),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Lessons'),
              ),
            ],
          ),
        ),
      );
    }

    // If not yet scrolled to bottom, show a hint.
    final canComplete = _hasScrolledToBottom;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        child: Row(
          children: [
            if (!canComplete) ...[
              Icon(Icons.arrow_downward_rounded,
                  color: AppColors.subtextLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scroll to the bottom to mark complete',
                  style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                ),
              ),
            ] else ...[
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Finished reading? Mark this lesson complete.',
                  style: AppTextStyles.bodySmall(color: AppColors.success),
                ),
              ),
            ],
            const SizedBox(width: 12),
            FilledButton(
              onPressed: (canComplete && !_isCompleting) ? _markComplete : null,
              style: FilledButton.styleFrom(
                backgroundColor: canComplete ? AppColors.primary : null,
                minimumSize: const Size(140, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCompleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      canComplete ? 'Mark Complete' : 'Read More',
                      style: AppTextStyles.labelLarge(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
