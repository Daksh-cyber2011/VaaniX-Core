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
///
/// Part 0 extension: the AppBar now exposes a "switch Learn language"
/// action that opens [LearnLanguageSelectionScreen]. When a Learn
/// language IS selected, the screen also shows a banner noting that the
/// selected language's curriculum is in development (Part 0 ships only
/// the infrastructure; Parts A–J deliver each curriculum). The legacy
/// Sanskrit tree stays visible underneath so no existing functionality
/// is lost.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/data/bengali_exercises.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/data/marathi_exercises.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/data/gujarati_exercises.dart';
import 'package:vaanix_app/features/learn/data/tamil_exercises.dart';
import 'package:vaanix_app/features/learn/data/urdu_exercises.dart';
import 'package:vaanix_app/features/learn/data/telugu_exercises.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/personalized_course_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(activeCurriculumProvider);
    final completed = ref.watch(completedLessonIdsProvider);
    final selectedSpec = ref.watch(selectedLearnLanguageSpecProvider);

    return VaaniXScaffold(
      title: 'Learn',
      // AppBar action: open the Learn Mode language picker. Always
      // present so the learner can switch or clear their selection.
      // The icon shows a check overlay when a language is selected,
      // so the current state is visible without opening the picker.
      actions: [
        IconButton(
          icon: const Icon(Icons.language_rounded),
          tooltip: selectedSpec == null
              ? 'Choose Learn language'
              : 'Learn language: ${selectedSpec.englishName}',
          onPressed: () => context.go(RouteNames.learnLanguageSelection),
        ),
        // M2: per-language learner profile. Only meaningful once a
        // language is selected (profiles are per-language).
        if (selectedSpec != null)
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Personalize your learning',
            onPressed: () => context.go(RouteNames.learnProfile),
          ),
      ],
      body: Column(
        children: [
          if (selectedSpec != null)
            _SelectedLanguageBanner(
              spec: selectedSpec,
              hasCurriculum: curriculumAsync.value?.isNotEmpty ?? false,
            ),
          // M2: gentle one-time prompt when the language is chosen but
          // the learner has not personalized their path yet. Purely
          // optional — the planner runs on honest defaults otherwise.
          if (selectedSpec != null &&
              !ref.watch(
                  learnerProfileConfiguredProvider(selectedSpec.language)))
            _ProfilePromptCard(
              languageName: selectedSpec.englishName,
              onTap: () => context.go(RouteNames.learnProfile),
            ),
          // M3: VAN-led placement game. Shown once the language has real
          // lessons (the probe bank is built from trusted content), in
          // two states: undiscovered → invite; discovered → level badge
          // with a quiet retake entry. Repeatable, never blocking.
          if (selectedSpec != null &&
              (curriculumAsync.value?.isNotEmpty ?? false))
            _DiagnosticPromptCard(
              languageName: selectedSpec.englishName,
              result: ref.watch(lastDiagnosticProvider(selectedSpec.language)),
              onTap: () => context.go(RouteNames.learnDiagnostic),
            ),
          // M5: Smart practice — trusted-first content for today's plan
          // step, plus learner-triggered (validated, grounded) AI
          // personalization. Same gating as the placement card: only
          // when a language with real lessons is selected.
          if (selectedSpec != null &&
              (curriculumAsync.value?.isNotEmpty ?? false))
            _SmartPracticeCard(
              languageName: selectedSpec.englishName,
              onTap: () => context.go(RouteNames.learnSmartPractice),
            ),
          // PRIMARY LEARN EXPERIENCE: when a personalized course exists,
          // it drives the lesson tree. The static curriculum becomes a
          // fallback for when no personalized course is available.
          Expanded(
            child: _buildPrimaryLearnContent(
              context,
              ref,
              selectedSpec: selectedSpec,
              curriculumAsync: curriculumAsync,
              completed: completed,
            ),
          ),
        ],
      ),
    );
  }

  /// Decides whether to show the personalized course or static curriculum.
  Widget _buildPrimaryLearnContent(
    BuildContext context,
    WidgetRef ref, {
    required LearnLanguageSpec? selectedSpec,
    required AsyncValue<List<Chapter>> curriculumAsync,
    required List<String> completed,
  }) {
    if (selectedSpec == null) {
      // No language selected — show static curriculum (Sanskrit default)
      return _buildStaticCurriculum(context, ref, curriculumAsync, completed);
    }

    final courseAsync = ref.watch(personalizedCourseProvider);

    return courseAsync.when(
      loading: () => _loading(context),
      error: (_, __) =>
          _buildStaticCurriculum(context, ref, curriculumAsync, completed),
      data: (course) {
        if (course == null || course.isEmpty) {
          return _buildStaticCurriculum(
              context, ref, curriculumAsync, completed);
        }

        // The personalized course IS the primary Learn navigation.
        return _buildPersonalizedCourseTree(context, ref, course, completed);
      },
    );
  }

  /// Renders the personalized course as the primary navigable lesson tree.
  Widget _buildPersonalizedCourseTree(
    BuildContext context,
    WidgetRef ref,
    PersonalizedCourse course,
    List<String> completed,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: course.units.length + 1, // +1 for the course header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PersonalizedCourseHeader(course: course);
        }

        final unit = course.units[index - 1];
        return _PersonalizedUnitCard(
          unit: unit,
          completedLessonIds: completed,
          onTapLesson: (lesson) => _onTapPersonalizedLesson(context, lesson),
        );
      },
    );
  }

  /// Renders the static curriculum (fallback when no personalized course).
  Widget _buildStaticCurriculum(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Chapter>> curriculumAsync,
    List<String> completed,
  ) {
    return curriculumAsync.when(
      loading: () => _loading(context),
      error: (error, stack) => _error(context, ref),
      data: (curriculum) {
        if (curriculum.isEmpty) return _empty(context);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: curriculum.length,
          itemBuilder: (context, i) {
            final chapter = curriculum[i];
            final doneInChapter = chapter.lessons
                .where((l) => completed.contains(l.id))
                .length;
            // Real persisted practice mastery per lesson (empty when no
            // exercises are authored for that lesson yet).
            final practice = <String, ({int mastered, int total})>{};
            for (final lesson in chapter.lessons) {
              final mastered = ref
                  .watch(masteredExercisesProvider(lesson.id))
                  .length;
              // Look up exercises across all shipped language
              // banks. Lesson IDs are globally unique
              // (Sanskrit: ls_*, Hindi: hi_*, Bengali: bn_*,
              // Marathi: mr_*, Telugu: te_*), so only one bank
              // matches.
              final total = exercisesByLesson[lesson.id]?.length ??
                  hindiExercisesByLesson[lesson.id]?.length ??
                  bengaliExercisesByLesson[lesson.id]?.length ??
                  marathiExercisesByLesson[lesson.id]?.length ??
                  teluguExercisesByLesson[lesson.id]?.length ??
                  tamilExercisesByLesson[lesson.id]?.length ??
                  gujaratiExercisesByLesson[lesson.id]?.length ??
                  urduExercisesByLesson[lesson.id]?.length ??
                  0;
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
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const VanWidget(
                // A system stumble — the confused/reassuring expression, not
                // the tired "sad" pose (VAN state-context correctness).
                state: VanState.error,
                size: 140,
                showSpeechBubble: true,
                dialogueText: 'I could not reach the lesson shelf.',
              ),
              const SizedBox(height: 8),
              Text(
                'Lessons live on your device, so this is usually temporary. '
                'Your progress is safe.',
                style: AppTextStyles.bodyMedium(color: subtext),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Try again',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => ref.invalidate(activeCurriculumProvider),
              ),
            ],
          ),
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
    context.go(RouteNames.lessonContent.replaceFirst(':lessonId', lesson.id));
  }

  void _onTapPersonalizedLesson(
      BuildContext context, PersonalizedLesson lesson) {
    // Navigate to the adaptive session engine, driven by this lesson's
    // activity type and concept. (Master Brief §18)
    final kind = lesson.activityType ?? 'newLearning';
    final uri = Uri(
      path: RouteNames.learnSession,
      queryParameters: {
        'kind': kind,
        'concept': lesson.conceptId,
      },
    );
    context.go(uri.toString());
  }
}

/// Course header: honest provenance + offline status. Replaces the old
/// decorative card with truthful labeling per Master Brief §63.
class _PersonalizedCourseHeader extends StatelessWidget {
  const _PersonalizedCourseHeader({required this.course});

  final PersonalizedCourse course;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final sourceLabel = course.isAiGenerated
        ? 'Personalized for you'
        : 'Your learning path';
    final sourceIcon = course.isAiGenerated
        ? Icons.auto_awesome_rounded
        : Icons.route_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(sourceIcon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sourceLabel, style: AppTextStyles.titleSmall()),
                const SizedBox(height: 3),
                Text(
                  '${course.units.length} units · '
                  '${course.lessonCount} lessons · '
                  '${course.offlineStatusDescription}',
                  style: AppTextStyles.bodySmall(color: subtext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One unit in the personalized course — an expandable card that shows
/// its lessons as tappable rows, driving actual lesson navigation.
class _PersonalizedUnitCard extends StatelessWidget {
  const _PersonalizedUnitCard({
    required this.unit,
    required this.completedLessonIds,
    required this.onTapLesson,
  });

  final PersonalizedUnit unit;
  final List<String> completedLessonIds;
  final ValueChanged<PersonalizedLesson> onTapLesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    // A lesson counts as done when its trusted lessonId is in the
    // completed set OR its conceptId matches a completed lesson.
    final doneCount = unit.lessons.where((l) {
      final lid = l.lessonId ?? l.conceptId;
      return completedLessonIds.contains(lid) ||
          completedLessonIds.contains(l.conceptId);
    }).length;
    final progress =
        unit.lessons.isEmpty ? 0.0 : doneCount / unit.lessons.length;

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
                  Text(unit.title, style: AppTextStyles.titleMedium()),
                  Text(
                    unit.objective,
                    style: AppTextStyles.bodySmall(color: subtext),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '$doneCount/${unit.lessons.length}',
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
                semanticsLabel:
                    '$doneCount of ${unit.lessons.length} lessons completed',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...unit.lessons.map((lesson) {
            final lid = lesson.lessonId ?? lesson.conceptId;
            final isDone = completedLessonIds.contains(lid) ||
                completedLessonIds.contains(lesson.conceptId);

            // Honest activity type label
            final activityLabel = _activityLabel(lesson.activityType);

            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDone ? AppColors.success : _activityColor(lesson))
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : _activityIcon(lesson.activityType),
                  color: isDone ? AppColors.success : _activityColor(lesson),
                  size: 20,
                  semanticLabel: isDone ? 'Completed' : activityLabel,
                ),
              ),
              title: Text(lesson.title, style: AppTextStyles.titleSmall()),
              subtitle: Text(
                '$activityLabel · ~${lesson.estimatedMinutes} min',
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

  String _activityLabel(String? type) {
    return switch (type) {
      'newLearning' => 'New lesson',
      'review' => 'Review',
      'practice' => 'Practice',
      'weakRepair' => 'Strengthen',
      'masteryCheck' => 'Mastery check',
      'challenge' => 'Challenge',
      _ => 'Lesson',
    };
  }

  IconData _activityIcon(String? type) {
    return switch (type) {
      'newLearning' => Icons.play_arrow_rounded,
      'review' => Icons.replay_rounded,
      'practice' => Icons.fitness_center_rounded,
      'weakRepair' => Icons.build_rounded,
      'masteryCheck' => Icons.verified_rounded,
      'challenge' => Icons.emoji_events_rounded,
      _ => Icons.play_arrow_rounded,
    };
  }

  Color _activityColor(PersonalizedLesson lesson) {
    return switch (lesson.activityType) {
      'review' => AppColors.info,
      'weakRepair' => AppColors.warning,
      'masteryCheck' => AppColors.success,
      'challenge' => AppColors.warning,
      _ => AppColors.primary,
    };
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
                // The bar mirrors the 'x/y' counter; give it its own spoken
                // label so the indicator is not an unlabeled node.
                semanticsLabel:
                    '$completedCount of ${chapter.lessons.length} lessons completed',
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
                  // Done/not-done is otherwise conveyed by the icon's
                  // color only; the label merges into the ListTile node.
                  semanticLabel: isDone ? 'Completed' : 'Not started yet',
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

/// M2: gentle prompt card shown while the learner has picked a language
/// but not yet personalized their path. Tapping it opens the profile
/// screen; saving any profile there makes it disappear. It never blocks
/// the lesson tree.
class _ProfilePromptCard extends StatelessWidget {
  const _ProfilePromptCard({
    required this.languageName,
    required this.onTap,
  });

  final String languageName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Semantics(
        button: true,
        container: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Make it yours',
                            style: AppTextStyles.titleSmall()),
                        const SizedBox(height: 2),
                        Text(
                          'Tell VAN your goal for $languageName — '
                          'your path adapts to it.',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: subtext, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// M3: the placement card — VAN's invitation to the adaptive discovery
/// game before the first run, and the learner's current level (with a
/// quiet retake entry) afterwards. It never blocks the lesson tree and
/// never exposes raw scores — only the friendly level name.
class _DiagnosticPromptCard extends StatelessWidget {
  const _DiagnosticPromptCard({
    required this.languageName,
    required this.result,
    required this.onTap,
  });

  final String languageName;
  final DiagnosticResult? result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final diagnosed = result != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Semantics(
        button: true,
        container: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: diagnosed
                      ? AppColors.success.withValues(alpha: 0.5)
                      : borderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    diagnosed
                        ? Icons.verified_rounded
                        : Icons.emoji_events_rounded,
                    color: diagnosed ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diagnosed
                              ? 'Your path starts at ${result!.levelLabel}'
                              : 'Discover your level',
                          style: AppTextStyles.titleSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          diagnosed
                              ? 'VAN shaped your path from a quick game — '
                                  'retake it anytime.'
                              : 'A 3–7 minute game with VAN — and $languageName '
                                  'learning fits you.',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: subtext,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// M5: Smart practice entry card — sits under the placement card and
/// mirrors its style. Trust-first copy: VAN personalizes FROM the
/// learner's own trusted lessons, never instead of them (Master Brief
/// §34).
class _SmartPracticeCard extends StatelessWidget {
  const _SmartPracticeCard({
    required this.languageName,
    required this.onTap,
  });

  final String languageName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Semantics(
        button: true,
        container: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart practice',
                            style: AppTextStyles.titleSmall()),
                        const SizedBox(height: 2),
                        Text(
                          "Today's focus from your trusted $languageName "
                          'lessons — VAN can explain, show, or quiz it '
                          'your way.',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: subtext,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The language banner above the lesson tree: shows the selected Learn
/// language and its curriculum availability status.
class _SelectedLanguageBanner extends StatelessWidget {
  const _SelectedLanguageBanner({
    required this.spec,
    required this.hasCurriculum,
  });

  final LearnLanguageSpec spec;

  /// Data-driven (M9): derived from the LOADED curriculum state, not a
  /// hardcoded language list. A language ships when its curriculum asset
  /// has chapters — no per-language code changes needed anymore.
  final bool hasCurriculum;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg = isDark ? AppColors.nestWarmDark : AppColors.nestWarmLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    // M9: curriculum availability is now derived from the LOADED
    // curriculum (see [hasCurriculum]) — Parts A–G shipped first;
    // Parts H–J (Kannada, Malayalam, Odia) ship in M9. Any future
    // language needs zero changes here.
    final statusMessage = hasCurriculum
        ? 'Tap a chapter below to start learning ${spec.englishName}.'
        : "Curriculum in development — a future Part ships this language's lessons. "
            'The Sanskrit tree below stays available in the meantime.';

    return Container(
      width: double.infinity,
      color: bannerBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Directionality(
                      textDirection:
                          spec.isRTL ? TextDirection.rtl : TextDirection.ltr,
                      child: Text(
                        spec.nativeName,
                        style: AppTextStyles.titleSmall(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${spec.englishName}',
                      style: AppTextStyles.labelMedium(color: subtext),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusMessage,
                  style: AppTextStyles.bodySmall(color: subtext),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Learn language',
            onPressed: () => context.go(RouteNames.learnLanguageSelection),
          ),
        ],
      ),
    );
  }
}
