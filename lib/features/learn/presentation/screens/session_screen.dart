/// VaaniX Learn Mode — Guided Session Screen (M6, Master Brief §18)
///
/// The learner-facing face of the ADAPTIVE EXERCISE ENGINE: one session
/// through any of the SIX activity kinds (new learning, practice,
/// review, weak-area repair, mastery check, challenge), adapting live
/// per the §18 ladder. The engine ([AdaptiveSessionEngine]) selects and
/// adapts; this screen renders:
///
///   active    — the current step: a REAL trusted exercise (all five
///               engine types render: mcq / fillBlank / ordering /
///               translation / matching) or a trusted explanation beat
///               from the §18 ladder;
///   feedback  — encourage-first beat with the explanation (§44);
///   finished  — a friendly summary (no raw jargon) + honest footer:
///               sessions tune VAN's path; lesson XP stays with lessons.
///
/// Failure contract (§46): no language, a stub curriculum, or an empty
/// trusted pool surface an honest unavailable state — never a crash.
///
/// AI-generated exercises (M5 cache) appear ONLY as easier/guided rungs
/// and are labelled "Made for you · AI"; they never write progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/session_engine.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/session_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({
    super.key,
    required this.kind,
    required this.conceptId,
    this.difficultyKnob,
  });

  final ActivityKind kind;
  final String conceptId;
  final int? difficultyKnob;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adaptiveSessionProvider.notifier).start(
            kind: widget.kind,
            conceptId: widget.conceptId,
            difficultyKnob: widget.difficultyKnob,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adaptiveSessionProvider);
    final selected = ref.watch(selectedLearnLanguageProvider);
    final isRTL = selected == null ? false : learnLanguageSpec(selected).isRTL;

    return VaaniXScaffold(
      title: _screenTitle(state.kind),
      body: switch (state.phase) {
        AdaptiveSessionPhase.idle ||
        AdaptiveSessionPhase.loading =>
          const _LoadingView(),
        AdaptiveSessionPhase.unavailable => _UnavailableView(
            reason: state.unavailableReason ??
                'Something got in the way — everything else still works.',
          ),
        AdaptiveSessionPhase.active => _ActiveView(
            state: state,
            isRTL: isRTL,
          ),
        AdaptiveSessionPhase.feedback => _FeedbackView(
            state: state,
            isRTL: isRTL,
          ),
        AdaptiveSessionPhase.finished => _FinishedView(state: state),
      },
    );
  }

  String _screenTitle(ActivityKind? kind) => switch (kind) {
        ActivityKind.newLearning => 'New lesson',
        ActivityKind.review => 'Review',
        ActivityKind.weakRepair => 'Rebuild',
        ActivityKind.masteryCheck => 'Mastery check',
        ActivityKind.challenge => 'Challenge',
        _ => 'Guided session',
      };
}

// ─── Loading / unavailable ──────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: VanWidget(
        state: VanState.thinking,
        size: 140,
        showSpeechBubble: true,
        dialogueText: 'Shaping your session...',
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanWidget(
              state: VanState.caring,
              size: 140,
              showSpeechBubble: true,
              dialogueText: 'Nothing to practise yet.',
            ),
            const SizedBox(height: 16),
            Text(
              reason,
              style: AppTextStyles.bodyMedium(color: subtext),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton.secondary(
              label: 'Back to Learn',
              onPressed: () => context.go(RouteNames.learn),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active view ────────────────────────────────────────────────────────────

class _ActiveView extends ConsumerWidget {
  const _ActiveView({required this.state, required this.isRTL});

  final AdaptiveSessionState state;
  final bool isRTL;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = state.currentStep;
    if (step == null) {
      return const _UnavailableView(reason: 'This session ended.');
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text(
              'Step ${state.stepIndex}',
              style: AppTextStyles.labelLarge(color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            _LadderChip(step: step),
            const Spacer(),
            Flexible(
              child: Text(
                '${state.firstTryCorrect}/${state.answered} on first try',
                style: AppTextStyles.labelSmall(color: subtext),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (step.isSupport)
          _SupportCard(step: step, isRTL: isRTL)
        else ...[
          _ExerciseRunner(
            key: ValueKey(
                '${step.exercise!.id}#${step.presentation?.name ?? "normal"}'),
            exercise: step.exercise!,
            isRTL: isRTL,
            showHint: step.presentation == StepPresentation.guided,
          ),
        ],
        if (step.isSupport) ...[
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Got it — continue',
            onPressed: () => ref.read(adaptiveSessionProvider.notifier).next(),
          ),
        ],
      ],
    );
  }
}

/// Ladder honesty chip: where this step sits on the §18 ladder, and an
/// "AI" badge when the exercise is generated (never hidden).
class _LadderChip extends StatelessWidget {
  const _LadderChip({required this.step});

  final SessionStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGenerated =
        step.exercise != null && step.exercise!.id.startsWith('gen-');
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          child: Text(
            step.presentationLabel,
            style: AppTextStyles.labelSmall(color: colorScheme.primary),
          ),
        ),
        if (isGenerated) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: Text(
              'Made for you · AI',
              style: AppTextStyles.labelSmall(color: AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }
}

/// A trusted explanation beat (the §18 ladder's explanation rung).
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.step, required this.isRTL});

  final SessionStep step;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                step.explanationTitle ?? 'From your lesson',
                style: AppTextStyles.labelSmall(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              step.explanation ?? '',
              style: AppTextStyles.bodyMedium(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Read it once, then the next step is easier.',
            style: AppTextStyles.bodySmall(color: subtext),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise runner (all five engine types, one attempt per step) ─────────

class _ExerciseRunner extends ConsumerStatefulWidget {
  const _ExerciseRunner({
    super.key,
    required this.exercise,
    required this.isRTL,
    required this.showHint,
  });

  final Exercise exercise;
  final bool isRTL;

  /// Guided steps surface the hint up front (the "guided" in §18).
  final bool showHint;

  @override
  ConsumerState<_ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends ConsumerState<_ExerciseRunner> {
  /// Display preparation (deterministic shuffle) — mirrors the practice
  /// engine's [prepareExerciseOptions] exactly, for every type.
  late final ({
    List<String> options,
    int correctIndex,
    List<int> pairIndexByDisplay
  }) _display = prepareExerciseOptions(widget.exercise, 0);

  String _answerText = '';
  List<String> _chosen = [];
  int? _pendingLeft;
  final List<UserMatch> _pairs = [];

  bool _lockAll = false;

  bool get _isChoice =>
      widget.exercise.type == ExerciseType.mcq ||
      widget.exercise.type == ExerciseType.fillBlank;

  void _submit(bool correct) {
    if (_lockAll) return;
    setState(() => _lockAll = true);
    ref.read(adaptiveSessionProvider.notifier).submitAnswer(
          correct: correct,
          firstTry: true,
        );
  }

  void _submitChoice(int index) {
    if (_lockAll) return;
    _submit(index == _display.correctIndex);
  }

  void _submitTranslation() {
    if (_lockAll) return;
    final given = ExerciseNotifier.normalizeAnswer(_answerText);
    if (given.isEmpty) return;
    _submit(widget.exercise.acceptedAnswers
        .any((a) => ExerciseNotifier.normalizeAnswer(a) == given));
  }

  void _submitOrdering() {
    if (_lockAll) return;
    if (_chosen.length != widget.exercise.items.length) return;
    var allMatch = true;
    for (var i = 0; i < _chosen.length; i++) {
      if (_chosen[i] != widget.exercise.items[i]) allMatch = false;
    }
    _submit(allMatch);
  }

  void _submitMatching() {
    if (_lockAll) return;
    final exercise = widget.exercise;
    if (_pairs.length != exercise.pairs.length) return;
    final slotToPair = _display.pairIndexByDisplay;
    final seenLeft = <int>{};
    var correct = true;
    for (final p in _pairs) {
      if (p.left < 0 || p.left >= exercise.pairs.length) correct = false;
      if (p.right < 0 || p.right >= slotToPair.length) correct = false;
      if (!seenLeft.add(p.left)) correct = false;
      if (slotToPair[p.right] != p.left) correct = false;
    }
    _submit(correct);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final typeLabel = switch (exercise.type) {
      ExerciseType.mcq => 'Choose one',
      ExerciseType.fillBlank => 'Fill the blank',
      ExerciseType.ordering => 'Arrange in order',
      ExerciseType.translation => 'Translate',
      ExerciseType.matching => 'Match the pairs',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(typeLabel, style: AppTextStyles.labelSmall(color: subtext)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Text(exercise.prompt, style: AppTextStyles.titleSmall()),
          ),
          if (widget.showHint && exercise.hint != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exercise.hint!,
                      style: AppTextStyles.bodySmall(color: subtext),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_isChoice)
            ..._choiceOptions(context)
          else if (exercise.type == ExerciseType.translation)
            _translationArea(subtext)
          else if (exercise.type == ExerciseType.ordering)
            _orderingArea(context)
          else if (exercise.type == ExerciseType.matching)
            _matchingArea(context),
        ],
      ),
    );
  }

  // ── Choice (mcq / fillBlank) ──

  List<Widget> _choiceOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return [
      for (var i = 0; i < _display.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // M12 accessibility (Master Brief §94): the post-answer state was
          // previously conveyed by colour + an unlabeled check icon only.
          // Mirror the practice engine's one-node-per-option pattern
          // (exercise_screen): the label carries the option text plus the
          // locked 'correct answer' state, the flags carry
          // selected/enabled/button.
          child: Semantics(
            button: true,
            selected: _lockAll && i == _display.correctIndex,
            enabled: !_lockAll,
            onTap: _lockAll ? null : () => _submitChoice(i),
            label: _lockAll && i == _display.correctIndex
                ? 'Option ${i + 1}: ${_display.options[i]}, correct answer'
                : 'Option ${i + 1}: ${_display.options[i]}',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: _lockAll ? null : () => _submitChoice(i),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _lockAll && i == _display.correctIndex
                        ? AppColors.success.withValues(alpha: 0.12)
                        : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: _lockAll && i == _display.correctIndex
                          ? AppColors.success
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Directionality(
                          textDirection: widget.isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(_display.options[i],
                              style: AppTextStyles.bodyMedium()),
                        ),
                      ),
                      if (_lockAll && i == _display.correctIndex)
                        const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.success),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  // ── Translation ──

  Widget _translationArea(Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => _answerText = v,
          enabled: !_lockAll,
          textAlign: widget.isRTL ? TextAlign.right : TextAlign.start,
          decoration: const InputDecoration(
            hintText: 'Type your answer',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        if (!_lockAll)
          Row(
            children: [
              PrimaryButton(label: 'Check', onPressed: _submitTranslation),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _submit(false),
                child: Text('Not sure',
                    style: AppTextStyles.labelLarge(
                      color: subtext,
                    )),
              ),
            ],
          ),
      ],
    );
  }

  // ── Ordering ──

  Widget _orderingArea(BuildContext context) {
    final exercise = widget.exercise;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final remaining = _display.options
        .where((o) => !_chosen.contains(o))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.borderDark
                  : AppColors.borderLight,
            ),
          ),
          child: _chosen.isEmpty
              ? Text('Tap the words below in order',
                  style: AppTextStyles.bodySmall(color: subtext))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _chosen.length; i++)
                      InputChip(
                        label: Text('${i + 1}. ${_chosen[i]}'),
                        onDeleted: _lockAll
                            ? null
                            : () => setState(() {
                                  final next = [..._chosen]..removeAt(i);
                                  _chosen = next;
                                }),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in remaining)
              ActionChip(
                label: Directionality(
                  textDirection:
                      widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(item),
                ),
                onPressed: _lockAll
                    ? null
                    : () => setState(() => _chosen = [..._chosen, item]),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_lockAll)
          PrimaryButton(
            label: 'Check',
            onPressed: _chosen.length == exercise.items.length
                ? _submitOrdering
                : null,
          ),
      ],
    );
  }

  // ── Matching ──

  Widget _matchingArea(BuildContext context) {
    final exercise = widget.exercise;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final pairedLeft = _pairs.map((p) => p.left).toSet();
    final usedSlots = _pairs.map((p) => p.right).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < exercise.pairs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            // M12 accessibility (§94): the 'waiting for its match' state
            // was previously colour-only — carry it in the label and the
            // selected flag instead.
            child: Semantics(
              button: true,
              selected: _pendingLeft == i,
              enabled: !_lockAll && !pairedLeft.contains(i),
              onTap: (_lockAll || pairedLeft.contains(i))
                  ? null
                  : () => setState(() => _pendingLeft = i),
              label: _pendingLeft == i
                  ? '${exercise.pairs[i].left}, selected — now choose its '
                      'match below'
                  : exercise.pairs[i].left,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: _lockAll || pairedLeft.contains(i)
                      ? null
                      : () => setState(() => _pendingLeft = i),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _pendingLeft == i
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: _pendingLeft == i
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                      ),
                    ),
                    child: Text(exercise.pairs[i].left),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 0; d < _display.options.length; d++)
              if (!usedSlots.contains(d))
                ActionChip(
                  label: Directionality(
                    textDirection:
                        widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(_display.options[d]),
                  ),
                  onPressed: (_lockAll || _pendingLeft == null)
                      ? null
                      : () {
                          final left = _pendingLeft!;
                          setState(() {
                            _pairs.add((left: left, right: d));
                            _pendingLeft = null;
                          });
                        },
                ),
          ],
        ),
        if (_pairs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Your pairs — tap one to undo',
              style: AppTextStyles.labelSmall(color: subtext)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _pairs.length; i++)
                InputChip(
                  label: Text(
                    '${exercise.pairs[_pairs[i].left].left} — '
                    '${_display.options[_pairs[i].right]}',
                  ),
                  onDeleted: _lockAll
                      ? null
                      : () => setState(() {
                            final next = [..._pairs]..removeAt(i);
                            _pairs
                              ..clear()
                              ..addAll(next);
                          }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (!_lockAll)
          PrimaryButton(
            label: 'Check',
            onPressed:
                _pairs.length == exercise.pairs.length ? _submitMatching : null,
          ),
        if (_pendingLeft != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Now tap the matching item below',
                style: AppTextStyles.labelSmall(color: subtext)),
          ),
      ],
    );
  }
}

// ─── Feedback beat (encourage-first, §44) ───────────────────────────────────

class _FeedbackView extends ConsumerWidget {
  const _FeedbackView({required this.state, required this.isRTL});

  final AdaptiveSessionState state;
  final bool isRTL;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = state.lastStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final correct = state.lastWasCorrect;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: VanWidget(
            state: correct ? VanState.happy : VanState.caring,
            size: 130,
            showSpeechBubble: true,
            dialogueText: correct
                ? _praiseLine(state.kind)
                : 'That one\'s tricky — here\'s a hand.',
          ),
        ),
        const SizedBox(height: 16),
        if (step?.exercise != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: correct
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                      color: correct ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      correct ? 'Correct!' : 'Not quite',
                      style: AppTextStyles.titleSmall(
                        color: correct ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ],
                ),
                if (!correct) ...[
                  const SizedBox(height: 8),
                  Text(
                    'The answer was:',
                    style: AppTextStyles.labelSmall(color: subtext),
                  ),
                  const SizedBox(height: 2),
                  Directionality(
                    textDirection:
                        isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      _answerReveal(step!.exercise!),
                      style: AppTextStyles.bodyMedium(),
                    ),
                  ),
                ],
                if (step!.exercise!.explanation != null &&
                    step.exercise!.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection:
                        isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(
                      step.exercise!.explanation!,
                      style: AppTextStyles.bodySmall(color: subtext),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Continue',
          onPressed: () => ref.read(adaptiveSessionProvider.notifier).next(),
        ),
      ],
    );
  }

  String _praiseLine(ActivityKind? kind) => switch (kind) {
        ActivityKind.masteryCheck => 'Check passed — that counted!',
        ActivityKind.challenge => 'Strong work for a challenge!',
        _ => 'Nice! Keep it going.',
      };

  String _answerReveal(Exercise exercise) => switch (exercise.type) {
        ExerciseType.ordering => exercise.items.join(' → '),
        ExerciseType.translation => exercise.acceptedAnswers.firstOrNull ?? '',
        ExerciseType.matching => [
            for (final p in exercise.pairs) '${p.left} = ${p.right}',
          ].join('  ·  '),
        _ => (exercise.correctIndex != null &&
                exercise.correctIndex! < exercise.options.length)
            ? exercise.options[exercise.correctIndex!]
            : '',
      };
}

// ─── Finish view ────────────────────────────────────────────────────────────

class _FinishedView extends ConsumerWidget {
  const _FinishedView({required this.state});

  final AdaptiveSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final headline = switch (state.kind) {
      ActivityKind.masteryCheck => 'Check complete',
      ActivityKind.challenge => 'Challenge done!',
      ActivityKind.review => 'Review banked',
      ActivityKind.weakRepair => 'Rebuilt, step by step',
      ActivityKind.newLearning => 'Great start!',
      _ => 'Session complete',
    };

    final answered = state.answered;
    final firstTry = state.firstTryCorrect;
    final summary = answered == 0
        ? 'This round was all guidance — the next one practises.'
        : firstTry == answered
            ? 'Every single one on the first try. VAN is impressed.'
            : firstTry * 2 >= answered
                ? 'Solid work — VAN tuned your path as you went.'
                : 'Tough round — VAN already scheduled the right reviews.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: VanWidget(
            state: VanState.achievement,
            size: 140,
            showSpeechBubble: true,
            dialogueText: headline,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary, style: AppTextStyles.titleSmall()),
              const SizedBox(height: 10),
              Text(
                '$answered ${answered == 1 ? 'step' : 'steps'} answered · '
                '$firstTry on the first try · '
                '${state.conceptsTouched} ${state.conceptsTouched == 1 ? 'concept' : 'concepts'} touched',
                style: AppTextStyles.bodySmall(color: subtext),
              ),
              if (state.focusTitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Focus: ${state.focusTitle}',
                  style: AppTextStyles.bodySmall(color: subtext),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This session tuned VAN\'s plan for you. Lesson XP and streaks '
          'still live in the lessons themselves.',
          style: AppTextStyles.labelSmall(color: subtext),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Back to Smart Practice',
          onPressed: () => context.go(RouteNames.learnSmartPractice),
        ),
        const SizedBox(height: 8),
        PrimaryButton.secondary(
          label: 'Back to Learn',
          onPressed: () => context.go(RouteNames.learn),
        ),
      ],
    );
  }
}
