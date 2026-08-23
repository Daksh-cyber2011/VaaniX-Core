/// Exam Screen — Practice Quiz
///
/// Interactive multiple-choice quiz built from [quizProvider]. On finish,
/// the result is persisted via [progressRepositoryProvider] and XP is awarded.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(vanControllerProvider.notifier).dispatch(
              const VanEvent(VanEventType.quizStarted),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider);
    final notifier = ref.read(quizProvider.notifier);
    final state = quiz;

    if (notifier.total == 0) {
      return VaaniXScaffold(
        title: 'Exam',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const VanWidget(
                state: VanState.thinking,
                size: 140,
                showSpeechBubble: true,
                dialogueText: 'No quiz questions yet! 🎯',
              ),
            ],
          ),
        ),
      );
    }

    if (state.finished) {
      return _ResultView(
        score: state.score,
        total: notifier.total,
        onRetry: () {
          ref.read(quizProvider.notifier).restart();
          setState(() => _submitted = false);
        },
        onPersist: () async {
          if (_submitted) return;
          setState(() => _submitted = true);
          final result = await ref.read(progressRepositoryProvider).completeQuiz(
                quizId: 'v1_practice_quiz',
                score: state.score,
                total: notifier.total,
              );
          if (!mounted) return;
          // Invalidate all progress-related providers so the Progress
          // screen's "Quizzes Done" card updates reactively.
          ref.invalidate(xpTotalProvider);
          ref.invalidate(completedQuizIdsProvider);
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
        },
      );
    }

    final question = notifier.current;
    final progress = (state.currentIndex + 1) / notifier.total;

    return VaaniXScaffold(
      title: 'Exam',
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
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
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
                        final showWrong = state.answered &&
                            isSelected &&
                            !isCorrect;

                        Color tileColor = Theme.of(context).cardTheme.color ?? Colors.white;
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
                                ref.read(vanControllerProvider.notifier).dispatch(
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
                              final correct = state.selectedOption ==
                                  question.correctIndex;
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

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.score,
    required this.total,
    required this.onRetry,
    required this.onPersist,
  });

  final int score;
  final int total;
  final VoidCallback onRetry;
  final Future<void> Function() onPersist;

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
                    : 'Keep practising, you\'ve got this! 🌿',
              ),
              const SizedBox(height: 32),
              Text('$score / $total', style: AppTextStyles.displaySmall()),
              const SizedBox(height: 8),
              Text(
                '${(pct * 100).round()}% correct',
                style:
                    AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Save Progress (+${score * 10} XP)',
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                onPressed: onPersist,
              ),
              const SizedBox(height: 12),
              PrimaryButton.secondary(
                label: 'Retry Quiz',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
