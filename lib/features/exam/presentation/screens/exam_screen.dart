/// Exam Screen — Chapter + Difficulty Exam Flow
///
/// Exam V1: the student first picks a chapter and a difficulty band, then
/// answers a deterministic, chapter/difficulty-scoped question set. Answers
/// give immediate feedback + explanation; finishing AUTOMATICALLY records
/// the attempt via [progressRepositoryProvider] keyed by the exam
/// configuration (Phase 1 autosave — the manual Save button remains as a
/// visible confirmation and retry path, never as the only write path).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
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

/// Lifecycle of the result persistence for the current attempt.
enum _SaveState { unsaved, saving, saved, failed }

class _ExamScreenState extends ConsumerState<ExamScreen> {
  String? _chapterId;
  Difficulty _difficulty = Difficulty.beginner;
  bool _confirming = false;
  bool _started = false;
  _SaveState _saveState = _SaveState.unsaved;

  ExamConfig get _config =>
      ExamConfig(chapterId: _chapterId, difficulty: _difficulty);

  void _startExam() {
    setState(() => _confirming = true);
  }

  void _beginQuiz() {
    ref.log(AnalyticsEvent(AnalyticsEventName.examStarted,
        {'quizId': _config.quizId}));
    ref
        .read(vanControllerProvider.notifier)
        .dispatch(const VanEvent(VanEventType.quizStarted));
    // The family session for this config may still hold a FINISHED attempt
    // from a previous run (stale-provider hazard when retaking the same
    // topic + level after "Change topic"). Restart it so the learner always
    // gets a fresh question set, never the cached result screen.
    final current = ref.read(examQuizProvider(_config)).valueOrNull;
    if (current != null && current.finished) {
      ref.read(examQuizProvider(_config).notifier).restart();
    }
    setState(() {
      _confirming = false;
      _started = true;
      _saveState = _SaveState.unsaved;
    });
  }

  void _backToSetup() {
    setState(() {
      _confirming = false;
      _started = false;
      _saveState = _SaveState.unsaved;
    });
  }

  /// Persists the finished attempt (XP award is idempotent inside the
  /// repository; the attempt is always appended to history).
  ///
  /// Phase 1: called automatically the moment the quiz finishes, so an app
  /// kill on the result screen can no longer lose the attempt, XP or the
  /// achievement check. The manual Save button shares this method as the
  /// visible confirmation + retry path after a failure.
  Future<void> _persistResult() async {
    if (_saveState == _SaveState.saving || _saveState == _SaveState.saved) {
      return;
    }
    final config = _config;
    final quizState = ref.read(examQuizProvider(config)).valueOrNull;
    if (quizState == null || !quizState.finished) return;
    final notifier = ref.read(examQuizProvider(config).notifier);

    setState(() => _saveState = _SaveState.saving);
    final result = await ref.read(progressRepositoryProvider).completeQuiz(
          quizId: config.quizId,
          score: quizState.score,
          total: notifier.total,
        );
    if (!mounted) return;

    // Invalidate all progress-related providers so the Progress
    // screen's "Quizzes Done" card updates reactively.
    ref.invalidate(xpTotalProvider);
    ref.invalidate(completedQuizIdsProvider);
    ref.invalidate(quizAttemptsIndexProvider);
    ref.invalidate(adaptiveNextActionProvider);
    // Analytics: exam outcome with real score.
    ref.log(AnalyticsEvent(
      AnalyticsEventName.examCompleted,
      {
        'quizId': config.quizId,
        'score': quizState.score,
        'total': notifier.total,
      },
    ));

    await result.fold(
      (_) async {
        if (!mounted) return;
        setState(() => _saveState = _SaveState.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your result. Tap Save to retry.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (saved) async {
        if (!mounted) return;
        setState(() => _saveState = _SaveState.saved);
        // Surface the actual XP earned (0 on repeat completions due to
        // the idempotency guard added in Segment 1).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: saved.xpEarned > 0
                ? Text('+${saved.xpEarned} XP earned!')
                : const Text('Quiz already completed — no extra XP'),
          ),
        );
      },
    );
    if (!mounted) return;

    // Exam completions must also drive the achievement checker
    // (quiz category + perfect-score achievements live on this path).
    final checker = ref.read(achievementCheckerProvider);
    final newlyUnlocked = await checker.checkAchievements(
      quizScorePercentage: notifier.total == 0
          ? 0
          : ((quizState.score / notifier.total) * 100).round(),
    );
    if (!mounted) return;
    // One consolidated celebration for the batch: a single Van reaction and
    // a single snackbar, no matter how many achievements unlocked in this
    // pass. The old per-achievement loop stacked snackbars and dispatched a
    // burst of non-interruptible reactions that arbitration dropped anyway.
    if (newlyUnlocked.isNotEmpty) {
      final first = newlyUnlocked.first;
      final extra = newlyUnlocked.length > 1
          ? ' (+${newlyUnlocked.length - 1} more)'
          : '';
      ref.read(vanControllerProvider.notifier).dispatch(VanEvent(
            VanEventType.achievementUnlocked,
            message: 'I\'ll remember this: ${first.title}!',
            payload: {
              'achievementId': first.id,
              'achievementCount': newlyUnlocked.length,
            },
          ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement Unlocked: ${first.title}!'
            '${first.xpReward > 0 ? '(+${first.xpReward} XP)' : ''}$extra',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
    // Phase 2 single source: the question bank and the chapter list both
    // come from the JSON curriculum (the Dart constants remain only as a
    // malformed-asset fallback). While the bank settles, show progress —
    // an empty, unselectable setup must never flash during the load.
    final all = ref.watch(quizBankProvider).valueOrNull ?? const [];
    if (all.isEmpty) {
      return const VaaniXScaffold(
        title: 'Exam',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final curriculumList =
        ref.watch(curriculumProvider).valueOrNull ?? sanskritCurriculum;
    final chapters = curriculumList
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
            style: AppTextStyles.bodyMedium(
                color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight)),
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
    final all = ref.watch(quizBankProvider).valueOrNull ?? const [];
    final curriculumList =
        ref.watch(curriculumProvider).valueOrNull ?? sanskritCurriculum;
    final count = all
        .where((q) =>
            (_chapterId == null || q.chapterId == _chapterId) &&
            q.difficulty == _difficulty)
        .length;
    Chapter? chapter;
    for (final c in curriculumList) {
      if (c.id == _chapterId) chapter = c;
    }
    const xpPer = AppConstants.xpPerCorrectAnswer;
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
            style: AppTextStyles.bodyMedium(
                color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight)),
          ),
          // Phase 3: VanSpeechStrip wired at its designed "exam preparation"
          // surface — encouragement before the task without competing with
          // the answer-flow VAN moments lower in the exam.
          const VanSpeechStrip(
            state: VanState.happy,
            message: 'Read each question with care — I will be right here.',
          ),
          const SizedBox(height: 8),
          _instructionTile(
            icon: Icons.feedback_outlined,
            title: 'Instant feedback',
            body: 'Every answer is checked right away, with an explanation'
                'you can learn from.',
          ),
          _instructionTile(
            icon: Icons.emoji_events_outlined,
            title: 'XP on first completion',
            body: 'Earn up to $count \u00d7 $xpPer XP points the first time'
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
                  style: AppTextStyles.bodySmall(
                      color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
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
    final quizAsync = ref.watch(examQuizProvider(config));

    return quizAsync.when(
      loading: () => VaaniXScaffold(
        title: 'Exam',
        actions: [
          TextButton(onPressed: _backToSetup, child: const Text('Change')),
        ],
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => VaaniXScaffold(
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
                dialogueText: 'Something went wrong loading this exam.',
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Back to setup', onPressed: _backToSetup),
            ],
          ),
        ),
      ),
      data: (state) => _buildQuizBody(config, state),
    );
  }

  Widget _buildQuizBody(ExamConfig config, QuizState state) {
    final notifier = ref.read(examQuizProvider(config).notifier);

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
      // Honest Save button: on a repeat completion the repository's
      // idempotency guard awards 0 XP, so the label must not promise any.
      final alreadyCompleted =
          ref.watch(completedQuizIdsProvider).contains(config.quizId);
      return _ResultView(
        score: state.score,
        total: notifier.total,
        bestScore: bestScore,
        attemptsCount: attempts.length,
        saveState: _saveState,
        alreadyCompleted: alreadyCompleted,
        onRetry: () {
          ref.read(examQuizProvider(config).notifier).restart();
          setState(() => _saveState = _SaveState.unsaved);
        },
        onPersist: _persistResult,
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
                            (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight);
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
                                // Advance to the result view first, then
                                // autosave: the attempt, XP and achievement
                                // check are recorded without any extra tap.
                                notifier.next();
                                _persistResult();
                                return;
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
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight),
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
                    style: AppTextStyles.bodySmall(
                        color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight)),
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
            Icon(Icons.chevron_right,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight),
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
        : (enabled
            ? (Theme.of(context).brightness == Brightness.dark
                ? AppColors.subtextDark
                : AppColors.subtextLight)
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.subtextDark
                : AppColors.subtextLight));
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
                  ? ((Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight))
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.06)),
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
                : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight)
                    .withValues(alpha: 0.5),
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
    required this.saveState,
    required this.alreadyCompleted,
    required this.onRetry,
    required this.onPersist,
    required this.onBack,
  });

  final int score;
  final int total;
  final int bestScore;
  final int attemptsCount;
  final _SaveState saveState;

  /// True when this quizId was completed before this attempt. The save
  /// button must not promise XP the idempotency guard will not award.
  final bool alreadyCompleted;
  final VoidCallback onRetry;
  final Future<void> Function() onPersist;
  final VoidCallback onBack;

  Widget _stat(String label, String value, Color subtext) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium(color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall(color: subtext),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : score / total;
    final passed = pct >= 0.6;
    final subtext = Theme.of(context).brightness == Brightness.dark
        ? AppColors.subtextDark
        : (Theme.of(context).brightness == Brightness.dark
            ? AppColors.subtextDark
            : AppColors.subtextLight);

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
                    ? 'Great job! ${(pct * 100).round()}%'
                    : 'Keep practising, you\'ve got this!',
              ),
              const SizedBox(height: 32),
              Text('$score / $total', style: AppTextStyles.displaySmall()),
              const SizedBox(height: 8),
              Text(
                '${(pct * 100).round()}% correct',
                style: AppTextStyles.bodyMedium(color: subtext),
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
                    _stat('Score', '$score/$total', subtext),
                    // Honest Best: show the real best (even 0/total) once
                    // any attempt exists — "-" means never attempted.
                    _stat(
                      'Best',
                      attemptsCount > 0 ? '$bestScore/$total' : '-',
                      subtext,
                    ),
                    _stat('Attempts', '$attemptsCount', subtext),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Autosave (Phase 1): the attempt is persisted the moment the
              // quiz finishes. The button reflects the save lifecycle and
              // doubles as the manual retry path after a failure.
              PrimaryButton(
                label: switch (saveState) {
                  _SaveState.saved => 'Progress saved \u2713',
                  _SaveState.saving => 'Saving\u2026',
                  // Unsaved / failed: retryable. XP is only promised on a
                  // first completion — repeats earn 0 by design.
                  _SaveState.unsaved ||
                  _SaveState.failed =>
                    alreadyCompleted
                        ? 'Save Progress'
                        : 'Save Progress (+${score * AppConstants.xpPerCorrectAnswer} XP)',
                },
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                onPressed: saveState == _SaveState.saved ||
                        saveState == _SaveState.saving
                    ? null
                    : () => onPersist(),
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
