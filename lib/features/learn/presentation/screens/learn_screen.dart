/// Learn Screen — Lesson Tree
///
/// Renders the V1 Sanskrit curriculum as chapters → lessons. Completed
/// lessons show a check and award XP on first completion. Tapping a lesson
/// marks it complete (the lesson-content player lands in a later milestone;
/// for now completion is recorded so the Progress screen reflects activity).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.watch(curriculumProvider);
    final completed = ref.watch(completedLessonIdsProvider);

    return VaaniXScaffold(
      title: 'Learn',
      body: curriculum.isEmpty
          ? _empty(context)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: curriculum.length,
              itemBuilder: (context, i) {
                final chapter = curriculum[i];
                final doneInChapter = chapter.lessons
                    .where((l) => completed.contains(l.id))
                    .length;
                return _ChapterCard(
                  chapter: chapter,
                  completedCount: doneInChapter,
                  completedIds: completed,
                  onTapLesson: (lesson) => _onTapLesson(context, ref, lesson),
                );
              },
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanWidget(
            state: VanState.thinking,
            size: 140,
            showSpeechBubble: true,
            dialogueText: 'No lessons yet! 📚',
          ),
          const SizedBox(height: 16),
          Text('Curriculum is loading', style: AppTextStyles.headlineSmall()),
        ],
      ),
    );
  }

  Future<void> _onTapLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final completed = ref.read(completedLessonIdsProvider);
    if (completed.contains(lesson.id)) {
      // Already done — show a small recap notice.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lesson.title} — completed ✓')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lesson.title),
        content: Text(lesson.subtitle ?? 'Start this lesson?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete (+XP)'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Capture notifier references before the await so we don't touch
      // the WidgetRef after the widget may have been unmounted.
      final lessonsNotifier = ref.read(completedLessonIdsProvider.notifier);
      await lessonsNotifier.markComplete(lesson);
      // Refresh XP badge everywhere.
      ref.invalidate(xpTotalProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${lesson.xpReward} XP earned! 🎉')),
        );
      }
    }
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.completedCount,
    required this.completedIds,
    required this.onTapLesson,
  });

  final Chapter chapter;
  final int completedCount;
  final List<String> completedIds;
  final ValueChanged<Lesson> onTapLesson;

  @override
  Widget build(BuildContext context) {
    final progress = chapter.lessons.isEmpty
        ? 0.0
        : completedCount / chapter.lessons.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.title, style: AppTextStyles.titleMedium()),
                  if (chapter.subtitle != null)
                    Text(
                      chapter.subtitle!,
                      style: AppTextStyles.bodySmall(
                          color: AppColors.subtextLight),
                    ),
                ],
              ),
            ),
            Text(
              '$completedCount/${chapter.lessons.length}',
              style: AppTextStyles.labelMedium(color: AppColors.primary),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...chapter.lessons.map((lesson) {
            final isDone = completedIds.contains(lesson.id);
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: isDone ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(lesson.title, style: AppTextStyles.titleSmall()),
              subtitle: Text(
                '+${lesson.xpReward} XP',
                style: AppTextStyles.labelSmall(color: AppColors.subtextLight),
              ),
              trailing: Text(
                lesson.difficulty.name,
                style: AppTextStyles.labelSmall(color: AppColors.subtextLight),
              ),
              onTap: () => onTapLesson(lesson),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
