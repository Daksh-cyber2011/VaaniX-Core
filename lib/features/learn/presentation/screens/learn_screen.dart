/// Learn Screen - Lesson Tree
///
/// Renders the V1 Sanskrit curriculum as chapters  lessons. The curriculum
/// is loaded asynchronously from a JSON asset (Segment 8) via
/// [curriculumProvider] (now an AsyncNotifierProvider). Shows loading and
/// error states while the curriculum is being parsed.
///
/// Tapping a lesson navigates to [LessonContentScreen] where the user reads
/// the full lesson content and marks it complete. Completed lessons show a
/// check icon and can be re-read anytime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);
    final completed = ref.watch(completedLessonIdsProvider);

    return VaaniXScaffold(
      title: 'Learn',
      body: curriculumAsync.when(
        loading: () => _loading(context),
        error: (error, stack) => _error(context, ref),
        data: (curriculum) {
          if (curriculum.isEmpty) return _empty(context);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: curriculum.length,
            itemBuilder: (context, i) {
              final chapter = curriculum[i];
              final doneInChapter =
                  chapter.lessons.where((l) => completed.contains(l.id)).length;
              // Real persisted practice mastery per lesson (empty when no
              // exercises are authored for that lesson yet).
              final practice = <String, ({int mastered, int total})>{};
              for (final lesson in chapter.lessons) {
                final mastered =
                    ref.watch(masteredExercisesProvider(lesson.id)).length;
                final total = exercisesByLesson[lesson.id]?.length ?? 0;
                practice[lesson.id] = (mastered: mastered, total: total);
              }
              return _ChapterCard(
                chapter: chapter,
                completedCount: doneInChapter,
                completedIds: completed,
                practice: practice,
                onTapLesson: (lesson) => _onTapLesson(context, lesson),
              );
            },
          );
        },
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VanWidget(
            state: VanState.thinking,
            size: 140,
            showSpeechBubble: true,
            dialogueText: 'Getting your lessons ready...',
          ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanWidget(
              state: VanState.sad,
              size: 140,
              showSpeechBubble: true,
              dialogueText: 'I could not reach the lesson shelf.',
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again - your progress is safe.',
              style: AppTextStyles.bodyMedium(color: subtext),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(curriculumProvider.notifier).reload(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VanWidget(
            state: VanState.thinking,
            size: 140,
            showSpeechBubble: true,
            dialogueText: 'No lessons published yet.',
          ),
          const SizedBox(height: 16),
          Text('Nothing here yet', style: AppTextStyles.headlineSmall()),
          const SizedBox(height: 8),
          Text(
            'New lessons will appear here once they are published.',
            style: AppTextStyles.bodyMedium(color: subtext),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onTapLesson(BuildContext context, Lesson lesson) {
    context.go('/learn/lesson/${lesson.id}');
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.completedCount,
    required this.completedIds,
    required this.practice,
    required this.onTapLesson,
  });

  final Chapter chapter;
  final int completedCount;
  final List<String> completedIds;
  final Map<String, ({int mastered, int total})> practice;
  final ValueChanged<Lesson> onTapLesson;

  String _difficultyLabel(Lesson lesson) {
    final raw = lesson.difficulty.name;
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final progress =
        chapter.lessons.isEmpty ? 0.0 : completedCount / chapter.lessons.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: borderColor),
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
                      style: AppTextStyles.bodySmall(color: subtext),
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
                _practiceLabel(lesson) ?? '+${lesson.xpReward} XP',
                style: AppTextStyles.labelSmall(color: subtext),
              ),
              trailing: Text(
                _difficultyLabel(lesson),
                style: AppTextStyles.labelSmall(color: subtext),
              ),
              onTap: () => onTapLesson(lesson),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String? _practiceLabel(Lesson lesson) {
    final p = practice[lesson.id];
    if (p == null || p.total == 0) return null;
    if (p.mastered >= p.total) {
      return '+${lesson.xpReward} XP \u00b7 Practice \u2713';
    }
    return '+${lesson.xpReward} XP \u00b7 ${p.mastered}/${p.total} practised';
  }
}
