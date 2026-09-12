/// VaaniX Learn Mode — Adaptive Placement Screen (M3)
///
/// The VAN-led, game-like placement flow (Master Brief §11/§43):
///
///   intro  — VAN invites: "Let's see what you already know 👀"
///            (short, friendly, honest: 3–7 minutes, adapts to you,
///            shapes your path — no scores, never an exam look)
///   rounds — one trusted probe at a time with a friendly progress
///            meter; after each answer VAN encourages first, then the
///            engine adapts (two correct → harder; a miss → an easier
///            prerequisite probe)
///   result — the friendly summary from [DiagnosticResult]
///            ("You're starting around Beginner level." / "Your biggest
///            opportunity is sentence building.") — raw internal scores
///            are NEVER rendered (Master Brief §11/§44)
///
/// Probe rendering mirrors the practice engine's interaction patterns
/// (choice / ordering / translation / matching) in a compact form; the
/// correctness semantics live in [DiagnosticAnswer] and are pinned by
/// tests to stay identical to the practice engine.
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
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic_engine.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/shared/widgets/empty_state_widget.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class DiagnosticScreen extends ConsumerWidget {
  const DiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(diagnosticSessionProvider);
    final selected = ref.watch(selectedLearnLanguageProvider);

    return VaaniXScaffold(
      title: 'Discover your level',
      body: switch (session.phase) {
        DiagnosticPhase.idle => selected == null
            ? const _NoLanguageView()
            : _IntroView(
                language: selected,
                onStart: () =>
                    ref.read(diagnosticSessionProvider.notifier).start(selected),
              ),
        DiagnosticPhase.unavailable => _UnavailableView(
            reason: session.unavailableReason ??
                'Something got in the way — everything else still works.',
          ),
        DiagnosticPhase.active ||
        DiagnosticPhase.feedback =>
          _RoundView(session: session),
        DiagnosticPhase.finished => _ResultView(result: session.result!),
      },
    );
  }
}

// ─── Intro ──────────────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  const _IntroView({required this.language, required this.onStart});

  final LearnLanguage language;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final spec = learnLanguageSpec(language);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const SizedBox(height: 8),
          const Center(
            child: VanWidget(
              state: VanState.happy,
              size: 150,
              showSpeechBubble: true,
              dialogueText: "Let's see what you already know!",
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'A tiny game for ${spec.englishName}',
            style: AppTextStyles.headlineSmall(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'A few quick rounds and I will shape your personal path — '
            'nothing to study for.',
            style: AppTextStyles.bodyMedium(color: subtext),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _IntroBullet(
            icon: Icons.timer_outlined,
            title: '3–7 minutes',
            subtitle: 'It gets shorter when the answers are clear.',
            subtext: subtext,
          ),
          _IntroBullet(
            icon: Icons.auto_awesome_rounded,
            title: 'It adapts to you',
            subtitle: 'Doing great? It gets playful-hard. Stuck? '
                'It gently steps back.',
            subtext: subtext,
          ),
          _IntroBullet(
            icon: Icons.favorite_rounded,
            title: 'No scores, no judgement',
            subtitle: 'The result only tunes your path — it is just for '
                'you and VAN.',
            subtext: subtext,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: "Let's play",
            icon: Icons.sports_esports_rounded,
            onPressed: onStart,
          ),
          const SizedBox(height: 8),
          PrimaryButton.secondary(
            label: 'Maybe later',
            onPressed: () => context.go(RouteNames.learn),
          ),
        ],
      ),
    );
  }
}

class _IntroBullet extends StatelessWidget {
  const _IntroBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtext,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color subtext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall()),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall(color: subtext)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLanguageView extends StatelessWidget {
  const _NoLanguageView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.language_rounded,
      title: 'Choose a language first',
      description:
          'The placement game is per language — pick the language you '
          'want to learn and VAN will start the discovery round.',
      actionLabel: 'Choose a language',
      onActionPressed: () => context.go(RouteNames.learnLanguageSelection),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.emoji_objects_rounded,
      title: 'Not ready yet',
      description: reason,
      actionLabel: 'Back to Learn',
      onActionPressed: () => context.go(RouteNames.learn),
    );
  }
}

// ─── Rounds ─────────────────────────────────────────────────────────────────

/// One adaptive round: probe + answer area (+ feedback beat).
class _RoundView extends ConsumerWidget {
  const _RoundView({required this.session});

  final DiagnosticSessionState session;

  static const _cheers = <String>[
    'Nice — you know this!',
    'Smooth. Keep going!',
    'That is a solid yes!',
  ];

  static const _nudges = <String>[
    'No worries — I will pick an easier one.',
    'A sneaky one! Let us step back a bit.',
    'All good. We learn most from these.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final isFeedback = session.phase == DiagnosticPhase.feedback;
    final item = isFeedback ? session.lastAnsweredItem : session.currentItem;
    if (item == null) {
      // Branded, announced loading state — never a bare silent spinner.
      return const Center(
        child: VaaniXLoadingIndicator(message: 'Getting the next round ready…'),
      );
    }
    final exercise = item.exercise;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Friendly progress meter — a "rounds played" feel, never a
          // countdown or a question number (Master Brief §43).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Round ${session.askedCount + (isFeedback ? 0 : 1)}'
                  ' of about ${session.estimatedMax}',
                  style: AppTextStyles.labelMedium(color: subtext),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: session.estimatedMax == 0
                        ? 0
                        : (session.askedCount / session.estimatedMax)
                            .clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    color: AppColors.primary,
                    semanticsLabel:
                        'Round ${session.askedCount} of about '
                        '${session.estimatedMax} played',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Directionality(
                    textDirection: (ref.watch(selectedLearnLanguageProvider) ==
                                null
                            ? false
                            : learnLanguageSpec(
                                    ref.watch(selectedLearnLanguageProvider)!)
                                .isRTL)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      exercise.prompt,
                      style: AppTextStyles.titleMedium(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ProbeAnswerArea(
                  key: ValueKey('probe-${exercise.id}'),
                  exercise: exercise,
                  locked: isFeedback,
                ),
                if (isFeedback) ...[
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    wasCorrect: session.lastAnswerWasCorrect,
                    explanation: exercise.explanation,
                    cheer: (session.lastAnswerWasCorrect
                            ? _cheers
                            : _nudges)[session.askedCount % 3],
                    subtext: subtext,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: isFeedback
                ? PrimaryButton(
                    label: 'Continue',
                    onPressed: () =>
                        ref.read(diagnosticSessionProvider.notifier).next(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Encourage-first feedback beat (VAN reacts, explanation teaches —
/// the same feedback quality standard as the practice engine).
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.wasCorrect,
    required this.explanation,
    required this.cheer,
    required this.subtext,
  });

  final bool wasCorrect;
  final String? explanation;
  final String cheer;
  final Color subtext;

  @override
  Widget build(BuildContext context) {
    final accent = wasCorrect ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VanWidget(
                state: wasCorrect ? VanState.happy : VanState.caring,
                size: 46,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cheer,
                  style: AppTextStyles.titleSmall(),
                ),
              ),
            ],
          ),
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation!,
              style: AppTextStyles.bodyMedium(color: subtext),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Probe answer area (draft state lives per probe via its key) ───────────

/// Renders the answer interaction for a probe and reports the finished
/// [DiagnosticAnswer] upward. Re-keyed per probe id, so switching probes
/// naturally resets the draft (same pattern as the practice engine's
/// per-exercise state) — and the draft stays visible during the
/// feedback beat so the learner sees what they answered.
class _ProbeAnswerArea extends ConsumerStatefulWidget {
  const _ProbeAnswerArea({
    super.key,
    required this.exercise,
    required this.locked,
  });

  final Exercise exercise;
  final bool locked;

  @override
  ConsumerState<_ProbeAnswerArea> createState() => _ProbeAnswerAreaState();
}

class _ProbeAnswerAreaState extends ConsumerState<_ProbeAnswerArea> {
  int? _choiceIndex;
  String _text = '';
  final List<String> _chosen = [];
  final Map<int, int> _pairs = {};
  int? _pendingLeft;

  /// RTL awareness for the active Learn language (mirrors the practice
  /// engine): Urdu probe prompts, options and typed answers lay out RTL.
  bool get _isRTL {
    final selected = ref.watch(selectedLearnLanguageProvider);
    return selected == null ? false : learnLanguageSpec(selected).isRTL;
  }

  Color _subtext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.subtextDark : AppColors.subtextLight;
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = _subtext(context);

    final answer = _buildAnswer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...switch (exercise.type) {
          ExerciseType.mcq || ExerciseType.fillBlank => _choiceArea(),
          ExerciseType.translation => _translationArea(subtext),
          ExerciseType.ordering => _orderingArea(borderColor),
          ExerciseType.matching => _matchingArea(borderColor),
        },
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Check',
          onPressed: !widget.locked && _canSubmit(answer)
              ? () => ref
                  .read(diagnosticSessionProvider.notifier)
                  .submitAnswer(answer!),
              : null,
        ),
      ],
    );
  }

  DiagnosticAnswer? _buildAnswer() {
    final exercise = widget.exercise;
    return switch (exercise.type) {
      ExerciseType.mcq ||
      ExerciseType.fillBlank =>
        _choiceIndex == null ? null : DiagnosticChoiceAnswer(_choiceIndex!),
      ExerciseType.translation => DiagnosticTextAnswer(_text),
      ExerciseType.ordering => _chosen.length == exercise.items.length
          ? DiagnosticOrderAnswer(List.of(_chosen))
          : null,
      ExerciseType.matching => _pairs.length == exercise.pairs.length
          ? DiagnosticMatchAnswer(Map.of(_pairs))
          : null,
    };
  }

  bool _canSubmit(DiagnosticAnswer? answer) {
    if (answer == null) return false;
    if (answer is DiagnosticTextAnswer) {
      return normalizeDiagnosticAnswer(answer.text).isNotEmpty;
    }
    return true;
  }

  Widget _choiceArea() {
    final exercise = widget.exercise;
    final display = prepareExerciseOptions(exercise, 0);
    return Column(
      children: [
        for (var i = 0; i < display.options.length; i++)
          _ChoiceTile(
            label: display.options[i],
            optionLetter: String.fromCharCode(65 + i),
            selected: _choiceIndex == i,
            locked: widget.locked,
            rtl: _isRTL,
            onTap: () => setState(() => _choiceIndex = i),
          ),
      ],
    );
  }

  Widget _translationArea(Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          enabled: !widget.locked,
          onChanged: (value) => setState(() => _text = value),
          textInputAction: TextInputAction.done,
          textDirection:
              _isRTL ? TextDirection.rtl : TextDirection.ltr,
          decoration: InputDecoration(
            hintText: 'Type your answer',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Checked without case or extra spaces.',
          style: AppTextStyles.bodySmall(color: subtext),
        ),
      ],
    );
  }

  Widget _orderingArea(Color borderColor) {
    final exercise = widget.exercise;
    final remaining = exercise.items
        .where((o) => !_chosen.contains(o))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the items in the correct order:',
          style: AppTextStyles.bodyMedium(color: _subtext(context)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _chosen.length; i++)
                InputChip(
                  label: Directionality(
                    textDirection:
                        _isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(_chosen[i]),
                  ),
                  onDeleted: widget.locked
                      ? null
                      : () => setState(() => _chosen.removeAt(i)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in remaining)
              ActionChip(
                label: Directionality(
                  textDirection:
                      _isRTL ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(item),
                ),
                onPressed: widget.locked
                    ? null
                    : () => setState(() => _chosen.add(item)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _matchingArea(Color borderColor) {
    final exercise = widget.exercise;
    final display = prepareExerciseOptions(exercise, 0);
    final rightOptions = display.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap one item from each side to join them:',
          style: AppTextStyles.bodyMedium(color: _subtext(context)),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var left = 0; left < exercise.pairs.length; left++)
                    _PairTile(
                      label: exercise.pairs[left].left,
                      rtl: _isRTL,
                      highlight: _pendingLeft == left,
                      paired: _pairs.containsKey(left),
                      onTap: widget.locked
                          ? null
                          : () => setState(() => _pendingLeft = left),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (var slot = 0; slot < rightOptions.length; slot++)
                    _PairTile(
                      label: rightOptions[slot],
                      highlight: _pendingLeft != null &&
                          !_pairs.containsValue(slot),
                      paired: _pairs.containsValue(slot),
                      onTap: widget.locked || _pendingLeft == null
                          ? null
                          : () => setState(() {
                                _pairs[_pendingLeft!] = slot;
                                _pendingLeft = null;
                              }),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_pairs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _pairs.entries)
                InputChip(
                  label: Text(
                    '${exercise.pairs[entry.key].left} = '
                    '${rightOptions[entry.value]}',
                  ),
                  onDeleted: widget.locked
                      ? null
                      : () => setState(() => _pairs.remove(entry.key)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.optionLetter,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.rtl = false,
  });

  final String label;
  final String optionLetter;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;
    final surface = Theme.of(context).cardTheme.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Screen-reader parity with the practice engine: one semantics node
      // carrying the option text, selected/enabled/button flags.
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !locked,
        onTap: locked ? null : onTap,
        label: 'Option $optionLetter: $label',
        child: ExcludeSemantics(
          child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : borderColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      optionLetter,
                      style: AppTextStyles.labelMedium(
                        color: selected ? Colors.white : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Directionality(
                    textDirection:
                        rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: Text(label, style: AppTextStyles.bodyLarge()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.label,
    required this.highlight,
    required this.paired,
    required this.onTap,
    this.rtl = false,
  });

  final String label;
  final bool highlight;
  final bool paired;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Screen-reader parity with the practice engine: highlight/paired
      // states are spoken, never color-only; paired is announced in-line.
      child: Semantics(
        button: true,
        selected: highlight,
        enabled: onTap != null,
        onTap: onTap,
        label: paired ? '$label, already matched' : label,
        child: ExcludeSemantics(
          child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
                minHeight: AppDimens.minTouchTarget),
            alignment: Alignment.centerLeft,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paired
                    ? AppColors.success.withValues(alpha: 0.6)
                    : highlight
                        ? AppColors.primary
                        : borderColor,
                width: highlight ? 2 : 1,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Directionality(
                textDirection:
                    rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(label, style: AppTextStyles.bodyMedium()),
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }
}

// ─── Result ─────────────────────────────────────────────────────────────────

class _ResultView extends ConsumerWidget {
  const _ResultView({required this.result});

  final DiagnosticResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final lines = result.friendlySummary();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          const Center(
            child: VanWidget(
              state: VanState.achievement,
              size: 150,
              showSpeechBubble: true,
              dialogueText: 'Here is your path!',
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        i == 0
                            ? Icons.emoji_events_rounded
                            : Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lines[i],
                          style: AppTextStyles.bodyLarge(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your path adapts as you learn — VAN keeps reading your '
            'practice and will retune it along the way.',
            style: AppTextStyles.bodySmall(color: subtext),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'See my path',
            icon: Icons.map_rounded,
            onPressed: () {
              ref.read(diagnosticSessionProvider.notifier).reset();
              context.go(RouteNames.learn);
            },
          ),
          const SizedBox(height: 8),
          PrimaryButton.secondary(
            label: 'Play again',
            onPressed: () {
              final language = result.language;
              ref.read(diagnosticSessionProvider.notifier).reset();
              ref.read(diagnosticSessionProvider.notifier).start(language);
            },
          ),
        ],
      ),
    );
  }
}
