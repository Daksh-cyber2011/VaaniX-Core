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
/// If the lesson is already completed, the button reads "Completed" and is
/// disabled - the user can still re-read the content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/learn/presentation/widgets/lesson_content_view.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
            VanEventType.lessonStarted,
            message: 'Let\'s explore ${widget.lesson.title}.',
            payload: {'lessonId': widget.lesson.id},
          ));
      _checkShortContent();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Short lessons may fit on screen without any scroll extent. In that case
  /// there is nothing to scroll to - unlock "Mark Complete" immediately so
  /// the lesson can never get stuck.
  void _checkShortContent() {
    if (_hasScrolledToBottom) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) {
      setState(() => _hasScrolledToBottom = true);
    }
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

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      final notifier = ref.read(completedLessonIdsProvider.notifier);
      await notifier.markComplete(widget.lesson);
      ref.invalidate(xpTotalProvider);
      ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
            VanEventType.lessonCompleted,
            message: 'Nice work - you completed ${widget.lesson.title}!',
            payload: {'lessonId': widget.lesson.id},
          ));

      // Achievement check: after completing a lesson, check if any
      // lesson-count achievements are newly unlocked.
      final checker = ref.read(achievementCheckerProvider);
      final newlyUnlocked = await checker.checkAchievements();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+${widget.lesson.xpReward} XP earned!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // One consolidated celebration for the batch (no snackbar stacking).
      if (newlyUnlocked.isNotEmpty) {
        final first = newlyUnlocked.first;
        final extra = newlyUnlocked.length > 1
            ? ' (+${newlyUnlocked.length - 1} more)'
            : '';
        ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
              VanEventType.achievementUnlocked,
              message: 'I\'ll remember this: ${first.title}!',
              payload: {'achievementId': first.id},
            ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Achievement Unlocked: ${first.title}!'
              '${first.xpReward > 0 ? ' (+${first.xpReward} XP)' : ''}$extra',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save progress. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
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
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: VanWidget(useController: true, size: 34),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanWidget(
            state: VanState.thinking,
            size: 120,
            showSpeechBubble: true,
            dialogueText: 'Content coming soon!',
          ),
          const SizedBox(height: 16),
          Text(
            'This lesson\'s content is being prepared.',
            style: AppTextStyles.bodyMedium(color: subtext),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(bool isAlreadyDone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isAlreadyDone) ...[
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lesson completed - review anytime',
                style: AppTextStyles.bodyMedium(color: AppColors.success),
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  context.go('/learn/lesson/${widget.lesson.id}/practice'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Practice',
                style: AppTextStyles.labelLarge(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ] else ...[
            if (!_hasScrolledToBottom) ...[
              Icon(Icons.arrow_downward_rounded, color: subtext, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scroll to the bottom to mark complete',
                  style: AppTextStyles.bodySmall(color: subtext),
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
            OutlinedButton(
              onPressed: () =>
                  context.go('/learn/lesson/${widget.lesson.id}/practice'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Practice',
                style: AppTextStyles.labelLarge(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isCompleting
                  ? null
                  : (_hasScrolledToBottom ? _markComplete : _scrollToBottom),
              style: FilledButton.styleFrom(
                backgroundColor: _hasScrolledToBottom
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
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
                      _hasScrolledToBottom ? 'Mark Complete' : 'Read More',
                      style: AppTextStyles.labelLarge(
                        color: _hasScrolledToBottom
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );

    return SafeArea(child: container);
  }
}
