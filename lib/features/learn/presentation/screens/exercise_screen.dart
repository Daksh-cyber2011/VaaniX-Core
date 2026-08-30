/// Practice Screen - Learn V1 interactive exercises.
///
/// Turns a lesson from "read  mark complete" into
/// "read  practice  feedback  master  complete". The session is driven
/// by [ExerciseNotifier] (deterministic ordering/scoring). Finishing the
/// session lets the student complete the lesson through the existing
/// idempotent progress path, so XP is awarded exactly once per lesson.
///
/// All five engine types render here: mcq / fillBlank (option tiles),
/// ordering (tap-in-sequence), translation (free text) and matching
/// (two-column pairing).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  bool _isCompleting = false;
  bool _completionDone = false;

  /// True once the finished session's mastery has been persisted
  /// (fire-and-forget; recordMasteredExercises is an idempotent union).
  bool _masteryRecorded = false;

  /// Exercise id whose hint is revealed (null = no hint shown).
  String? _hintRevealedFor;

  /// Text entry for the current translation exercise (synced to state).
  final TextEditingController _answerController = TextEditingController();

  /// Left-column slot selected but not yet paired (matching exercises).
  int? _pendingLeftIndex;

  // Theme-aware surface / border / subtext tokens (fixes dark-mode washouts).
  Color get _surface => Theme.of(context).brightness == Brightness.dark
      ? AppColors.surfaceDark
      : AppColors.surfaceLight;
  Color get _borderColor =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.borderDark
          : AppColors.borderLight;
  Color get _subtext => Theme.of(context).brightness == Brightness.dark
      ? AppColors.subtextDark
      : AppColors.subtextLight;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
              VanEventType.quizStarted,
              message: 'Practice time! Let\'s master ${widget.lesson.title}.',
              payload: {'lessonId': widget.lesson.id},
            ));
      }
    });
  }

  Future<void> _completeLesson() async {
    if (_isCompleting || _completionDone) return;
    setState(() => _isCompleting = true);

    final notifier = ref.read(completedLessonIdsProvider.notifier);
    await notifier.markComplete(widget.lesson);
    ref.invalidate(xpTotalProvider);
    ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
          VanEventType.lessonCompleted,
          message: 'Nice work - you completed ${widget.lesson.title}!',
          payload: {'lessonId': widget.lesson.id},
        ));

    final checker = ref.read(achievementCheckerProvider);
    final newlyUnlocked = await checker.checkAchievements();

    if (!mounted) return;
    setState(() {
      _isCompleting = false;
      _completionDone = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Practice complete! +${widget.lesson.xpReward} XP earned! âœ¨'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    for (final ach in newlyUnlocked) {
      ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
            VanEventType.achievementUnlocked,
            message: 'I\'ll remember this: ${ach.title}!',
            payload: {'achievementId': ach.id},
          ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ðŸ† Achievement Unlocked: ${ach.title}!'
            '${ach.xpReward > 0 ? ' (+${ach.xpReward} XP)' : ''}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseSessionProvider(widget.lesson.id));
    final notifier =
        ref.read(exerciseSessionProvider(widget.lesson.id).notifier);
    final completed = ref.watch(completedLessonIdsProvider);
    final isAlreadyDone = completed.contains(widget.lesson.id);

    // Keep the translation input in sync with provider state (retry/next
    // reset it to an empty string server-side).
    if (_answerController.text != state.answerText) {
      _answerController.text = state.answerText;
    }
    if (_pendingLeftIndex != null &&
        (state.answered ||
            state.selectedPairs.any((p) => p.left == _pendingLeftIndex))) {
      _pendingLeftIndex = null;
    }

    // Persist mastery exactly once per finished session (idempotent union).
    if (state.finished && !_masteryRecorded) {
      _masteryRecorded = true;
      final ids = notifier.masteredExerciseIds;
      if (ids.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(recordMasteryProvider)(widget.lesson.id, ids);
          ref
              .read(masteredExercisesProvider(widget.lesson.id).notifier)
              .refresh();
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Practice',
          style: AppTextStyles.titleMedium(),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: VanWidget(useController: true, size: 34),
          ),
        ],
      ),
      body: switch ((notifier.total, state.finished)) {
        (0, _) => _empty(context),
        (_, true) => _result(context, state, notifier, isAlreadyDone),
        _ => _question(context, state, notifier, isAlreadyDone),
      },
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
            dialogueText: 'No practice exercises for this lesson yet.',
          ),
          const SizedBox(height: 16),
          Text(
            'Exercises are being prepared.',
            style: AppTextStyles.bodyMedium(color: _subtext),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Back to lesson',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _question(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    bool isAlreadyDone,
  ) {
    final exercise = notifier.current;
    final isCurrentCorrect = notifier.currentAnswerIsCorrect;
    final isLast = state.currentIndex + 1 >= notifier.total;

    final String typeLabel = switch (exercise.type) {
      ExerciseType.mcq => 'Choose one',
      ExerciseType.fillBlank => 'Fill the blank',
      ExerciseType.ordering => 'Arrange in order',
      ExerciseType.translation => 'Translate',
      ExerciseType.matching => 'Match the pairs',
    };

    return Column(
      children: [
        // Progress header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                'Q ${state.currentIndex + 1} / ${notifier.total}',
                style: AppTextStyles.labelLarge(color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (state.currentIndex + 1) / notifier.total,
                    minHeight: 6,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              XpBadge(xpTotal: state.score),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    typeLabel,
                    style: AppTextStyles.labelSmall(color: AppColors.primary),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Text(
                  exercise.prompt,
                  style: AppTextStyles.headlineSmall(),
                ),
              ),
              if (exercise.hint != null && !state.answered) ...[
                const SizedBox(height: 8),
                _hintArea(context, exercise),
              ],
              const SizedBox(height: 20),
              if (exercise.type == ExerciseType.ordering)
                _orderingArea(context, state, notifier, exercise)
              else if (exercise.type == ExerciseType.translation)
                _translationArea(context, state, notifier, exercise)
              else if (exercise.type == ExerciseType.matching)
                _matchingArea(context, state, notifier, exercise)
              else
                ..._choiceArea(context, state, notifier, exercise),
              if (state.answered) ...[
                const SizedBox(height: 16),
                _feedbackCard(exercise, isCurrentCorrect),
              ],
              const SizedBox(height: 20),
              _actionRow(state, notifier, isCurrentCorrect, isLast),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hintArea(BuildContext context, Exercise exercise) {
    final revealed = _hintRevealedFor == exercise.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _hintRevealedFor = revealed ? null : exercise.id;
            });
          },
          icon: Icon(
            revealed
                ? Icons.lightbulb_outline_rounded
                : Icons.lightbulb_rounded,
            size: 18,
            color: AppColors.accent,
          ),
          label: Text(
            revealed ? 'Hide hint' : 'Hint',
            style: AppTextStyles.labelLarge(color: AppColors.accent),
          ),
        ),
        if (revealed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              exercise.hint!,
              style: AppTextStyles.bodyMedium(color: _subtext),
            ),
          ),
      ],
    );
  }

  List<Widget> _choiceArea(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    Exercise exercise,
  ) {
    final options = notifier.currentOptions;
    return [
      for (var i = 0; i < options.length; i++) ...[
        _optionTile(
          context,
          label: options[i],
          index: i,
          state: state,
          notifier: notifier,
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _optionTile(
    BuildContext context, {
    required String label,
    required int index,
    required ExerciseState state,
    required ExerciseNotifier notifier,
  }) {
    final isSelected = state.selectedIndex == index;
    final isCorrect =
        state.answered && index == notifier.currentCorrectDisplayIndex;
    final isWrong = state.answered && isSelected && !isCorrect;

    Color tileColor = _surface;
    Color borderColor = _borderColor;
    if (isCorrect) {
      tileColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success;
    } else if (isWrong) {
      tileColor = AppColors.error.withValues(alpha: 0.1);
      borderColor = AppColors.error;
    } else if (isSelected) {
      tileColor = AppColors.primary.withValues(alpha: 0.08);
      borderColor = AppColors.primary;
    }

    return InkWell(
      onTap: state.answered ? null : () => notifier.select(index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor, width: isSelected || isCorrect ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: isCorrect
                  ? const Icon(Icons.check, color: AppColors.success, size: 18)
                  : isWrong
                      ? const Icon(Icons.close,
                          color: AppColors.error, size: 18)
                      : Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: AppTextStyles.labelMedium(),
                          ),
                        ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyLarge()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderingArea(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    Exercise exercise,
  ) {
    final remaining = notifier.currentOptions
        .where((o) => !state.chosenItems.contains(o))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the items in the correct order:',
          style: AppTextStyles.bodyMedium(color: _subtext),
        ),
        const SizedBox(height: 12),
        // Chosen sequence
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: state.chosenItems.isEmpty
              ? Text(
                  'Your sequence appears here.',
                  style: AppTextStyles.bodySmall(color: _subtext),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < state.chosenItems.length; i++)
                      InputChip(
                        label: Text(state.chosenItems[i],
                            style: AppTextStyles.labelMedium()),
                        onDeleted: state.answered
                            ? null
                            : () => notifier.removeChosenItem(i),
                        backgroundColor:
                            _surface,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1),
                        deleteIconColor: AppColors.primary,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        // Remaining pool
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in remaining)
              ActionChip(
                label: Text(item, style: AppTextStyles.labelMedium()),
                onPressed:
                    state.answered ? null : () => notifier.addChosenItem(item),
                backgroundColor:
                    _surface,
                side: BorderSide(color: _borderColor),
              ),
          ],
        ),
      ],
    );
  }

  Widget _translationArea(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    Exercise exercise,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type your answer:',
          style: AppTextStyles.bodyMedium(color: _subtext),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          enabled: !state.answered,
          onChanged: notifier.setAnswerText,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (state.answerText.trim().isNotEmpty) notifier.submit();
          },
          decoration: InputDecoration(
            hintText: 'e.g. namaste',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Answers are checked without case or extra spaces.',
          style: AppTextStyles.bodySmall(color: _subtext),
        ),
      ],
    );
  }

  Widget _matchingArea(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    Exercise exercise,
  ) {
    final rightOptions = notifier.currentOptions;
    final pairedLeft = state.selectedPairs.map((p) => p.left).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap one item from each side to join them:',
          style: AppTextStyles.bodyMedium(color: _subtext),
        ),
        const SizedBox(height: 12),
        // Formed pairs
        if (state.selectedPairs.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                for (var i = 0; i < state.selectedPairs.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${exercise.pairs[state.selectedPairs[i].left].left}  â†”  '
                      '${rightOptions[state.selectedPairs[i].right]}',
                      style: AppTextStyles.bodyMedium(),
                    ),
                    trailing: state.answered
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.error),
                            onPressed: () => notifier.removeMatch(i),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _matchColumn(
                title: 'Left',
                chips: [
                  for (var i = 0; i < exercise.pairs.length; i++)
                    _matchChip(
                      label: exercise.pairs[i].left,
                      selected: _pendingLeftIndex == i,
                      done: pairedLeft.contains(i) || state.answered,
                      onTap: () {
                        setState(() {
                          _pendingLeftIndex = _pendingLeftIndex == i ? null : i;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _matchColumn(
                title: 'Right',
                chips: [
                  for (var d = 0; d < rightOptions.length; d++)
                    _matchChip(
                      label: rightOptions[d],
                      selected: false,
                      done: state.selectedPairs.any((p) => p.right == d) ||
                          state.answered,
                      onTap: () {
                        final pending = _pendingLeftIndex;
                        if (pending == null) return;
                        notifier.addMatch(pending, d);
                        setState(() => _pendingLeftIndex = null);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Matched pairs appear above - tap âœ• to undo.',
          style: AppTextStyles.bodySmall(color: _subtext),
        ),
      ],
    );
  }

  Widget _matchColumn({
    required String title,
    required List<Widget> chips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelSmall(color: _subtext),
        ),
        const SizedBox(height: 8),
        ...chips,
      ],
    );
  }

  Widget _matchChip({
    required String label,
    required bool selected,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : (done
                    ? _subtext.withValues(alpha: 0.08)
                    : (Theme.of(context).cardTheme.color ?? Colors.white)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (done ? _borderColor : _borderColor),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium(
              color: done ? _subtext : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedbackCard(Exercise exercise, bool isCorrect) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isCorrect ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.error,
        ),
      ),
      child: Text(
        isCorrect
            ? 'Correct! âœ¨'
            : exercise.explanation ?? 'Not quite - try again!',
        style: AppTextStyles.bodySmall(
          color: isCorrect ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }

  Widget _actionRow(
    ExerciseState state,
    ExerciseNotifier notifier,
    bool isCurrentCorrect,
    bool isLast,
  ) {
    final exercise = notifier.current;
    final bool canSubmit = switch (exercise.type) {
      ExerciseType.ordering =>
        state.chosenItems.length == exercise.items.length,
      ExerciseType.translation => state.answerText.trim().isNotEmpty,
      ExerciseType.matching =>
        state.selectedPairs.length == exercise.pairs.length,
      _ => state.selectedIndex != null,
    };
    final isOrdering = exercise.type == ExerciseType.ordering;

    return Row(
      children: [
        if (state.answered && !isCurrentCorrect) ...[
          Expanded(
            child: PrimaryButton.secondary(
              label: 'Try Again',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                notifier.retry();
                setState(() => _pendingLeftIndex = null);
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: PrimaryButton(
            label: !state.answered
                ? (isOrdering ? 'Check' : 'Submit')
                : (isLast ? 'Finish' : 'Next'),
            onPressed: !state.answered
                ? (canSubmit
                    ? () {
                        notifier.submit();
                        ref
                            .read(vanControllerProvider.notifier)
                            .dispatch(VanEvent(
                              notifier.currentAnswerIsCorrect
                                  ? VanEventType.quizAnswerCorrect
                                  : VanEventType.quizAnswerWrong,
                              message: notifier.currentAnswerIsCorrect
                                  ? 'Nice thinking!'
                                  : 'Almost there - learn and try again.',
                            ));
                      }
                    : null)
                : () {
                    if (isLast) {
                      final perfect = state.score == notifier.total;
                      ref
                          .read(vanControllerProvider.notifier)
                          .dispatch(VanEvent(
                            perfect
                                ? VanEventType.perfectScore
                                : VanEventType.quizCompleted,
                            message: perfect
                                ? 'Perfect practice - wonderful work!'
                                : 'Practice finished. Nice effort!',
                          ));
                    }
                    notifier.next();
                  },
          ),
        ),
      ],
    );
  }

  Widget _result(
    BuildContext context,
    ExerciseState state,
    ExerciseNotifier notifier,
    bool isAlreadyDone,
  ) {
    final pct = notifier.total == 0 ? 0.0 : state.score / notifier.total;
    final passed = pct >= 0.7;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VanWidget(
              state: passed ? VanState.achievement : VanState.caring,
              size: 150,
              showSpeechBubble: true,
              dialogueText: passed
                  ? 'Great practice! ${(pct * 100).round()}% âœ¨'
                  : 'Keep practising - you\'ve got this! ðŸ’ª',
            ),
            const SizedBox(height: 24),
            Text('${state.score} / ${notifier.total}',
                style: AppTextStyles.displaySmall()),
            const SizedBox(height: 8),
            Text(
              '${(pct * 100).round()}% mastered',
              style: AppTextStyles.bodyMedium(color: _subtext),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: isAlreadyDone
                  ? 'Lesson completed âœ…'
                  : 'Complete Lesson (+${widget.lesson.xpReward} XP)',
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              onPressed:
                  (isAlreadyDone || _isCompleting) ? null : _completeLesson,
            ),
            const SizedBox(height: 12),
            PrimaryButton.secondary(
              label: 'Practise Again',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                setState(() => _masteryRecorded = false);
                notifier.restart();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
