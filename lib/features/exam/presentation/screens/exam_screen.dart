/// Exam Screen — Chapter + Difficulty Exam Flow
///
/// Exam V1: the student first picks a chapter and a difficulty band, then
/// answers a deterministic, chapter/difficulty-scoped question set. Answers
/// give immediate feedback + explanation; finishing awards XP and records an
/// attempt via [progressRepositoryProvider] keyed by the exam configuration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

String _difficultyLabel(Difficulty d) => switch (d) {
      Difficulty.beginner => 'Beginner',
      Difficulty.intermediate => 'Intermediate',
      Difficulty.advanced => 'Advanced',
    };

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  String? _chapterId;
  Difficulty _difficulty = Difficulty.beginner;
  bool _confirming = false;
  bool _started = false;
  bool _submitted = false;

  ExamConfig get _config =>
      ExamConfig(chapterId: _chapterId, difficulty: _difficulty);

  void _startExam() {
    setState(() => _confirming = true);
  }

  void _beginQuiz() {
    ref
        .read(vanControllerProvider.notifier)
        .dispatch(const VanEvent(VanEventType.quizStarted));
    // The family provider for this config may still hold a FINISHED attempt
    // from a previous run (stale-provider hazard when retaking the same
    // topic + level after "Change topic"). Restart it so the learner always
    // gets a fresh question set, never the cached result screen.
    final current = ref.read(examQuizProvider(_config));
    if (current.finished) {
      ref.read(examQuizProvider(_config).notifier).restart();
    }
    setState(() {
      _confirming = false;
      _started = true;
      _submitted = false;
    });
  }

  void _backToSetup() {
    setState(() {
      _confirming = false;
      _started = false;
      _submitted = false;
    });
  }

  int _chapterTotal(
      Map<String, Map<Difficulty, int>> counts, String chapterId) {
    final chapterCounts = counts[chapterId];
    if (chapterCounts == null) return 0;
    return chapterCounts.values.fold(0, (sum, n) => sum + n);
  }

  @override
  Widget build(BuildContext context) {
    return _confirming
        ? _buildInstructions()
        : (_started ? _buildQuiz() : _buildSetup());
  }

  // ---------------------------------------------------------------------
  // Setup: choose chapter + difficulty
  // ---------------------------------------------------------------------
  Widget _buildSetup() {
    final all = ref.watch(quizQuestionsProvider);
    final chapters = sanskritCurriculum
        .where((c) => all.any((q) => q.chapterId == c.id))
        .toList();

    final counts = <String, Map<Difficulty, int>>{};
    for (final q in all) {
      counts.putIfAbsent(q.chapterId, () => {});
      counts[q.chapterId]![q.difficulty] =
          (counts[q.chapterId]![q.difficulty] ?? 0) + 1;
    }

    final selectedCount =
        _chapterId == null ? 0 : (counts[_chapterId]?[_difficulty] ?? 0);

    return VaaniXScaffold(
      title: 'Exam',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Choose your exam', style: AppTextStyles.headlineSmall()),
          const SizedBox(height: 8),
          Text(
            'Pick a topic and a difficulty level to build your question set.',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
          ),
          const SizedBox(height: 20),
          for (final c in chapters) ...[
            _ChapterTile(
              title: c.title,
              subtitle: c.subtitle ?? '',
              totalQuestions: _chapterTotal(counts, c.id),
              selected: _chapterId == c.id,
              onTap: () => setState(() => _chapterId = c.id),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Text(
            'Difficulty',
            style: AppTextStyles.labelLarge(color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final d in Difficulty.values)
                _DifficultyChip(
                  label: _difficultyLabel(d),
                  count: _chapterId == null ? 0 : (counts[_chapterId]?[d] ?? 0),
                  selected: _difficulty == d,
                  enabled:
                      _chapterId != null && (counts[_chapterId]?[d] ?? 0) > 0,
                  onTap: () => setState(() => _difficulty = d),
                ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: selectedCount > 0
                ? 'Start Exam ($selectedCount '
                    '${selectedCount == 1 ? 'question' : 'questions'})'
                : 'Select a topic & level',
            onPressed: selectedCount > 0 ? _startExam : null,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Instructions: confirm the selected exam before starting
  // ---------------------------------------------------------------------
  Widget _buildInstructions() {
    final all = ref.watch(quizQuestionsProvider);
    final count = all
        .where((q) =>
            (_chapterId == null || q.chapterId == _chapterId) &&
            q.difficulty == _difficulty)
        .length;
    Chapter? chapter;
    for (final c in sanskritCurriculum) {
      if (c.id == _chapterId) chapter = c;
    }
    final xpPer = AppConstants.xpPerCorrectAnswer;
    return VaaniXScaffold(
      title: 'Exam',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Ready for the exam?', style: AppTextStyles.headlineSmall()),
          const SizedBox(height: 8),
          Text(
            chapter?.title ?? 'All chapters',
            style: AppTextStyles.titleMedium(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_difficultyLabel(_difficulty)} \u00b7 $count '
            '${count == 1 ? 'question' : 'questions'}',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
          ),
          const SizedBox(height: 24),
          _instructionTile(
            icon: Icons.feedback_outlined,
            title: 'Instant feedback',
            body: 'Every answer is checked right away, with an explanation '
                'you can learn from.',
          ),
          _instructionTile(
            icon: Icons.emoji_events_outlined,
            title: 'XP on first completion',
            body: 'Earn up to $count \u00d7 $xpPer XP points the first time '
                'you finish this topic + level.',
          ),
          _instructionTile(
            icon: Icons.refresh_rounded,
            title: 'Retry anytime',
            body: 'You can retake the exam or change topic whenever you like.',
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Begin Exam',
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            onPressed: _beginQuiz,
          ),
          const SizedBox(height: 12),
          PrimaryButton.secondary(
            label: 'Back to setup',
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: _backToSetup,
          ),
        ],
      ),
    );
  }

  Widget _instructionTile({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge()),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Quiz: answer the selected question set
  // ---------------------------------------------------------------------
  Widget _buildQuiz() {
    final config = _config;
    final quiz = ref.watch(examQuizProvider(config));
    final notifier = ref.read(examQuizProvider(config).notifier);
    final state = quiz;

    if (notifier.total == 0) {
      return VaaniXScaffold(
        title: 'Exam',
        actions: [
          TextButton(onPressed: _backToSetup, child: const Text('Change')),
        ],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const VanWidget(
                state: VanState.thinking,
                size: 140,
                showSpeechBubble: true,
                dialogueText: 'No questions for this level yet.',
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Choose a topic', onPressed: _backToSetup),
            ],
          ),
        ),
      );
    }

    if (state.finished) {
      final attempts = ref
          .read(progressRepositoryProvider)
          .getQuizAttempts(config.quizId)
          .fold<List<QuizResult>>((_) => const [], (v) => v);
      var bestScore = 0;
      for (final a in attempts) {
        if (a.score > bestScore) bestScore = a.score;
      }
      return _ResultView(
        score: state.score,
        total: notifier.total,
        bestScore: bestScore,
        attemptsCount: attempts.length,
        saved: _submitted,
        onRetry: () {
          ref.read(examQuizProvider(config).notifier).restart();
          setState(() => _submitted = false);
        },
        onPersist: () async {
          if (_submitted) return;
          setState(() => _submitted = true);
          final result =
              await ref.read(progressRepositoryProvider).completeQuiz(
                    quizId: config.quizId,
                    score: state.score,
                    total: notifier.total,
                  );
          if (!mounted) return;
          // Invalidate all progress-related providers so the Progress
          // screen's "Quizzes Done" card updates reactively.
          ref.invalidate(xpTotalProvider);
          ref.invalidate(completedQuizIdsProvider);
          ref.invalidate(quizAttemptsIndexProvider);
          ref.invalidate(adaptiveNextActionProvider);
          // Surface the actual XP earned (0 on repeat completions due to
          // the idempotency guard added in Segment 1).
          final xpEarned = result.fold(
            (_) => 0,
            (r) => r.xpEarned,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: xpEarned > 0
                  ? Text('+$xpEarned XP earned! 🎉')
                  : const Text('Quiz already completed — no extra XP'),
            ),
          );
          // Exam completions must also drive the achievement checker
          // (quiz category + perfect-score achievements live on this path).
          final checker = ref.read(achievementCheckerProvider);
          final newlyUnlocked = await checker.checkAchievements(
            quizScorePercentage: notifier.total == 0
                ? 0
                : ((state.score / notifier.total) * 100).round(),
          );
          if (!mounted) return;
          for (final ach in newlyUnlocked) {
            ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
                  VanEventType.achievementUnlocked,
                  message: 'I\'ll remember this: ${ach.title}!',
                  payload: {'achievementId': ach.id},
                ));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Achievement Unlocked: ${ach.title}!'
                  '${ach.xpReward > 0 ? ' (+${ach.xpReward} XP)' : ''}',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        onBack: _backToSetup,
      );
    }

    final question = notifier.current;
    final progress = (state.currentIndex + 1) / notifier.total;

    return VaaniXScaffold(
      title: 'Exam',
      actions: [
        TextButton(onPressed: _backToSetup, child: const Text('Change')),
      ],
      body: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                      value: progress,
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

          // Question card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
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
                      question.prompt,
                      style: AppTextStyles.headlineSmall(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: question.options.length,
                      itemBuilder: (context, i) {
                        final isSelected = state.selectedOption == i;
                        final isCorrect = i == question.correctIndex;
                        final showCorrect = state.answered && isCorrect;
                        final showWrong =
                            state.answered && isSelected && !isCorrect;

                        Color tileColor =
                            Theme.of(context).cardTheme.color ?? Colors.white;
                        Color borderColor = AppColors.borderLight;
                        if (showCorrect) {
                          tileColor = AppColors.success.withValues(alpha: 0.1);
                          borderColor = AppColors.success;
                        } else if (showWrong) {
                          tileColor = AppColors.error.withValues(alpha: 0.1);
                          borderColor = AppColors.error;
                        } else if (isSelected) {
                          tileColor = AppColors.primary.withValues(alpha: 0.08);
                          borderColor = AppColors.primary;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: state.answered
                                ? null
                                : () => notifier.select(i),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: tileColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: borderColor,
                                    width: isSelected || showCorrect ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: borderColor, width: 2),
                                    ),
                                    child: showCorrect
                                        ? const Icon(Icons.check,
                                            color: AppColors.success, size: 18)
                                        : showWrong
                                            ? const Icon(Icons.close,
                                                color: AppColors.error,
                                                size: 18)
                                            : Center(
                                                child: Text(
                                                  String.fromCharCode(
                                                      65 + i), // A, B, C...
                                                  style: AppTextStyles
                                                      .labelMedium(),
                                                ),
                                              ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      question.options[i],
                                      style: AppTextStyles.bodyLarge(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (state.answered && question.explanation != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.vanYellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        question.explanation!,
                        style: AppTextStyles.bodySmall(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(
                    label: state.answered ? 'Next' : 'Submit',
                    onPressed: state.selectedOption == null
                        ? null
                        : () {
                            if (state.answered) {
                              if (state.currentIndex + 1 >= notifier.total) {
                                final score = state.score;
                                final isPerfect = score == notifier.total;
                                ref
                                    .read(vanControllerProvider.notifier)
                                    .dispatch(
                                      VanEvent(
                                        isPerfect
                                            ? VanEventType.perfectScore
                                            : VanEventType.quizCompleted,
                                        message: isPerfect
                                            ? 'A perfect score — wonderful work!'
                                            : 'You finished the quiz. Nice effort!',
                                      ),
                                    );
                              }
                              notifier.next();
                            } else {
                              notifier.submit();
                              final correct =
                                  state.selectedOption == question.correctIndex;
                              ref.read(vanControllerProvider.notifier).dispatch(
                                    VanEvent(
                                      correct
                                          ? VanEventType.quizAnswerCorrect
                                          : VanEventType.quizAnswerWrong,
                                      message: correct
                                          ? 'Nice thinking!'
                                          : 'Almost there. Let\'s learn from this one.',
                                    ),
                                  );
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.title,
    required this.subtitle,
    required this.totalQuestions,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int totalQuestions;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium()),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:
                        AppTextStyles.bodySmall(color: AppColors.subtextLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$totalQuestions',
              style: AppTextStyles.labelLarge(color: AppColors.primary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.subtextLight),
          ],
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.primary
        : (enabled ? AppColors.subtextLight : AppColors.subtextLight);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (enabled
                  ? (Theme.of(context).cardTheme.color ?? Colors.white)
                  : Colors.grey.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? (selected ? AppColors.primary : AppColors.borderLight)
                : AppColors.borderLight,
          ),
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: AppTextStyles.labelLarge(
            color: enabled
                ? foreground
                : AppColors.subtextLight.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.score,
    required this.total,
    required this.bestScore,
    required this.attemptsCount,
    required this.saved,
    required this.onRetry,
    required this.onPersist,
    required this.onBack,
  });

  final int score;
  final int total;
  final int bestScore;
  final int attemptsCount;
  final bool saved;
  final VoidCallback onRetry;
  final Future<void> Function() onPersist;
  final VoidCallback onBack;

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium(color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : score / total;
    final passed = pct >= 0.6;

    return VaaniXScaffold(
      title: 'Exam',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VanWidget(
                state: passed ? VanState.achievement : VanState.caring,
                size: 160,
                showSpeechBubble: true,
                dialogueText: passed
                    ? 'Great job! ${(pct * 100).round()}% 🎉'
                    : 'Keep practising, you\'ve got this! 💪',
              ),
              const SizedBox(height: 32),
              Text('$score / $total', style: AppTextStyles.displaySmall()),
              const SizedBox(height: 8),
              Text(
                '${(pct * 100).round()}% correct',
                style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('Score', '$score/$total'),
                    _stat(
                      'Best',
                      bestScore > 0 ? '$bestScore/$total' : '-',
                    ),
                    _stat('Attempts', '$attemptsCount'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: saved
                    ? 'Progress saved \u2713'
                    : 'Save Progress (+${score * AppConstants.xpPerCorrectAnswer} XP)',
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                onPressed: saved ? null : onPersist,
              ),
              const SizedBox(height: 12),
              PrimaryButton.secondary(
                label: 'Retry',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: onRetry,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onBack,
                child: const Text('Change topic'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
