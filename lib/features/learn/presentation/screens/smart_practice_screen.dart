/// VaaniX Learn Mode — Smart Practice Screen (M5, Master Brief §15/§34)
///
/// The learner-facing face of DYNAMIC LEARNING CONTENT:
///
///   focus    — today's validated plan step (M4 planner output), shown
///              with an honest source label;
///   trusted  — the plan step's TRUSTED seeded content (§15/§32): the
///              lesson + its exercise bank, one tap from the existing
///              lesson/practice flows. Trusted content is the default
///              and always visible (§34 priority ladder);
///   personal — learner-triggered AI personalization (§15 "where safe
///              and supported"): an explanation / example / practice
///              question generated ONLY from the concept's trusted
///              excerpt, validated by the §45/§46/§47/§48 gate, honestly
///              labelled "Made for you" (§63) and cached (§35).
///
/// Failure contract (§46): an offline AI, a decline, or garbage output
/// never breaks this screen — the trusted material stays, a friendly
/// note explains, and no broken exercise UI can ever render.
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
import 'package:vaanix_app/features/learn/data/personalized_content_generator.dart'
    show GeneratedContentResult;
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_content_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class SmartPracticeScreen extends ConsumerStatefulWidget {
  const SmartPracticeScreen({super.key});

  @override
  ConsumerState<SmartPracticeScreen> createState() =>
      _SmartPracticeScreenState();
}

class _SmartPracticeScreenState extends ConsumerState<SmartPracticeScreen> {
  @override
  void initState() {
    super.initState();
    // Kick the trusted-first resolution once the first frame exists (the
    // controller is a plain StateNotifier — no auto-init).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(smartPracticeProvider.notifier);
      if (ref.read(smartPracticeProvider).phase == SmartPracticePhase.idle) {
        controller.prepare();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartPracticeProvider);
    final selected = ref.watch(selectedLearnLanguageProvider);

    return VaaniXScaffold(
      title: 'Smart practice',
      body: switch (state.phase) {
        SmartPracticePhase.idle ||
        SmartPracticePhase.loading =>
          const _LoadingView(),
        SmartPracticePhase.unavailable => _UnavailableView(
            reason: state.unavailableReason ??
                'Something got in the way — everything else still works.',
          ),
        SmartPracticePhase.ready => _ReadyView(
            state: state,
            spec: selected == null ? null : learnLanguageSpec(selected),
          ),
      },
    );
  }
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
        dialogueText: 'Picking today\'s material...',
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
              dialogueText: 'Nothing to personalize yet.',
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

// ─── Ready view ─────────────────────────────────────────────────────────────

class _ReadyView extends ConsumerWidget {
  const _ReadyView({required this.state, required this.spec});

  final SmartPracticeState state;
  final LearnLanguageSpec? spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final activity = state.activity;
    final lesson = state.lessonEntry;
    if (activity == null || lesson == null) {
      // Defensive: ready implies both — fall back to the safe view.
      return const _UnavailableView(
          reason: 'VAN could not resolve trusted material.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: VanWidget(
            state: VanState.happy,
            size: 130,
            showSpeechBubble: true,
            dialogueText: "Here's today's focus!",
          ),
        ),
        const SizedBox(height: 8),

        // ── Focus: today's plan step (honest source label, §63) ──
        _FocusCard(activity: activity),
        const SizedBox(height: 16),

        // ── Trusted seeded content (§15/§32) — always first (§34) ──
        Text('TRUSTED MATERIAL', style: AppTextStyles.labelMedium(
          color: subtext,
        )),
        const SizedBox(height: 8),
        _TrustedLessonCard(
          lesson: lesson,
          exerciseCount: state.exerciseEntries.length,
          isRTL: spec?.isRTL ?? false,
        ),
        if (state.exerciseEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _TrustedExerciseSummary(entries: state.exerciseEntries),
        ],
        const SizedBox(height: 20),

        // ── Personalization (learner-triggered, §15) ──
        Text('MAKE IT PERSONAL', style: AppTextStyles.labelMedium(
          color: subtext,
        )),
        const SizedBox(height: 8),
        _PersonalizeChips(
          enabled: state.personalizingKind == null,
          busyKind: state.personalizingKind,
        ),
        const SizedBox(height: 12),

        if (state.materialError != null)
          _MaterialErrorCard(message: state.materialError!),

        if (state.material != null) ...[
          _MaterialCard(material: state.material!, spec: spec),
          const SizedBox(height: 8),
          Text(
            'Made for you by VAN — built only from this lesson\'s trusted '
            'material, and never counted towards your lesson scores.',
            style: AppTextStyles.labelSmall(color: subtext),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(smartPracticeProvider.notifier).dismissMaterial(),
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Focus card ─────────────────────────────────────────────────────────────

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.activity});

  final SmartPracticeActivity activity;

  String get _sourceLabel => switch (activity.planSource) {
        PlanSource.ai => 'AI-planned',
        PlanSource.cached => 'Saved plan',
        PlanSource.deterministic => 'Daily mix',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _sourceLabel,
                  style: AppTextStyles.labelSmall(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                activity.kind.label,
                style: AppTextStyles.labelSmall(color: subtext),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(activity.title, style: AppTextStyles.titleMedium()),
          if (activity.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              activity.reason,
              style: AppTextStyles.bodySmall(color: subtext),
            ),
          ],
          const SizedBox(height: 10),
          // M6: the adaptive session engine entry (Master Brief §18) —
          // this same plan activity, run as a GUIDED session with live
          // difficulty adaptation (reduce repetition / ladder down).
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton.text(
              label: 'Start guided session',
              onPressed: () => context.go(
                '${RouteNames.learnSession}'
                '?kind=${activity.kind.name}'
                '&concept=${activity.conceptId}'
                '&knob=${activity.difficultyKnob}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trusted content cards ──────────────────────────────────────────────────

class _TrustedLessonCard extends ConsumerWidget {
  const _TrustedLessonCard({
    required this.lesson,
    required this.exerciseCount,
    required this.isRTL,
  });

  final TrustedContent lesson;
  final int exerciseCount;
  final bool isRTL;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                'Trusted lesson',
                style: AppTextStyles.labelSmall(color: AppColors.success),
              ),
              if (exerciseCount > 0) ...[
                const Spacer(),
                Text(
                  '$exerciseCount practice ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                  style: AppTextStyles.labelSmall(color: subtext),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Text(lesson.title, style: AppTextStyles.titleSmall()),
          ),
          if (lesson.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                lesson.detail,
                style: AppTextStyles.bodySmall(color: subtext),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Read lesson'),
                  onPressed: () =>
                      context.go(RouteNames.lessonContent
                          .replaceFirst(':lessonId', lesson.lessonId)),
                ),
              ),
              if (exerciseCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.fitness_center_rounded, size: 18),
                    label: const Text('Practice'),
                    onPressed: () => context
                        .go('/learn/lesson/${lesson.lessonId}/practice'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustedExerciseSummary extends StatelessWidget {
  const _TrustedExerciseSummary({required this.entries});

  final List<TrustedContent> entries;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final types = entries
        .map((e) => e.exerciseType?.name ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in types)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              type,
              style: AppTextStyles.labelSmall(color: AppColors.success),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: subtext.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'from your lesson bank',
            style: AppTextStyles.labelSmall(color: subtext),
          ),
        ),
      ],
    );
  }
}

// ─── Personalization ────────────────────────────────────────────────────────

class _PersonalizeChips extends ConsumerWidget {
  const _PersonalizeChips({required this.enabled, required this.busyKind});

  final bool enabled;
  final GeneratedContentKind? busyKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _KindChip(
          kind: GeneratedContentKind.explanation,
          icon: Icons.lightbulb_outline_rounded,
          label: 'Explain differently',
          enabled: enabled,
          busy: busyKind == GeneratedContentKind.explanation,
          onTap: () => ref
              .read(smartPracticeProvider.notifier)
              .personalize(GeneratedContentKind.explanation),
        ),
        _KindChip(
          kind: GeneratedContentKind.example,
          icon: Icons.format_quote_rounded,
          label: 'Show examples',
          enabled: enabled,
          busy: busyKind == GeneratedContentKind.example,
          onTap: () => ref
              .read(smartPracticeProvider.notifier)
              .personalize(GeneratedContentKind.example),
        ),
        _KindChip(
          kind: GeneratedContentKind.practice,
          icon: Icons.quiz_outlined,
          label: 'Quick quiz',
          enabled: enabled,
          busy: busyKind == GeneratedContentKind.practice,
          onTap: () => ref
              .read(smartPracticeProvider.notifier)
              .personalize(GeneratedContentKind.practice),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final GeneratedContentKind kind;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    // Theme-aware: the raw light-theme tokens wash out on dark surfaces.
    final color = enabled
        ? Theme.of(context).colorScheme.primary
        : (isDark ? AppColors.subtextDark : AppColors.subtextLight);

    return Semantics(
      button: enabled && !busy,
      container: true,
      label: busy ? '$label — generating' : label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: InkWell(
          onTap: enabled && !busy ? onTap : null,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: Container(
            constraints: const BoxConstraints(
                minHeight: AppDimens.minTouchTarget),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              border: Border.all(
                color: busy
                    ? Theme.of(context).colorScheme.primary
                    : borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Generating',
                        ),
                      )
                    : Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: AppTextStyles.labelMedium(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialErrorCard extends StatelessWidget {
  const _MaterialErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      // Live region: screen readers must announce the AI failure instead of
      // silently showing a banner (the chips stay enabled as the retry path).
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall(color: subtext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generated material rendering (honest "Made for you", §63) ─────────────

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.spec});

  final GeneratedContentResult material;
  final LearnLanguageSpec? spec;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final content = material.content;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge(
                context,
                icon: Icons.auto_awesome_rounded,
                label: 'Made for you · AI',
                color: AppColors.primary,
              ),
              if (material.fromCache)
                _badge(
                  context,
                  icon: Icons.bookmark_rounded,
                  label: 'Saved from earlier',
                  color: subtext,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(content.title, style: AppTextStyles.titleSmall()),
          const SizedBox(height: 8),
          switch (content.kind) {
            GeneratedContentKind.explanation => _ExplanationBody(
                body: content.body ?? '',
                isRTL: spec?.isRTL ?? false,
              ),
            GeneratedContentKind.example => _ExampleLines(
                lines: content.lines,
                isRTL: spec?.isRTL ?? false,
              ),
            GeneratedContentKind.practice => _GeneratedExerciseRunner(
                exercise: content.exercise!,
                isRTL: spec?.isRTL ?? false,
              ),
          },
        ],
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall(color: color)),
        ],
      ),
    );
  }
}

class _ExplanationBody extends StatelessWidget {
  const _ExplanationBody({required this.body, required this.isRTL});

  final String body;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        body,
        style: AppTextStyles.bodyMedium(color: subtext),
      ),
    );
  }
}

class _ExampleLines extends StatelessWidget {
  const _ExampleLines({required this.lines, required this.isRTL});

  final List<GeneratedExampleLine> lines;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection:
                      isRTL ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    lines[i].text,
                    style: AppTextStyles.titleSmall(),
                  ),
                ),
                if (lines[i].translation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    lines[i].translation!,
                    style: AppTextStyles.bodySmall(color: subtext),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Inline runner for GENERATED practice questions (mcq / fillBlank /
/// translation only — the generatable set). This is a PREVIEW: it never
/// writes progress, XP, or mastery — the trusted practice flow stays the
/// only scorer (M5 contract; M6 integrates generated material properly).
class _GeneratedExerciseRunner extends StatefulWidget {
  const _GeneratedExerciseRunner({
    required this.exercise,
    required this.isRTL,
  });

  final Exercise exercise;
  final bool isRTL;

  @override
  State<_GeneratedExerciseRunner> createState() =>
      _GeneratedExerciseRunnerState();
}

class _GeneratedExerciseRunnerState extends State<_GeneratedExerciseRunner> {
  /// Display preparation (deterministic shuffle) for choice types.
  late final ({List<String> options, int correctIndex}) _display;
  int? _selected;
  String _answerText = '';
  bool _answered = false;
  bool _wasCorrect = false;

  @override
  void initState() {
    super.initState();
    final prepared = prepareExerciseOptions(widget.exercise, 0);
    _display = (options: prepared.options, correctIndex: prepared.correctIndex);
  }

  bool get _isChoice =>
      widget.exercise.type == ExerciseType.mcq ||
      widget.exercise.type == ExerciseType.fillBlank;

  void _submitChoice(int index) {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
      _wasCorrect = index == _display.correctIndex;
    });
  }

  void _submitTranslation() {
    if (_answered) return;
    final given = ExerciseNotifier.normalizeAnswer(_answerText);
    if (given.isEmpty) return;
    setState(() {
      _answered = true;
      _wasCorrect = widget.exercise.acceptedAnswers
          .any((a) => ExerciseNotifier.normalizeAnswer(a) == given);
    });
  }

  void _retry() {
    setState(() {
      _selected = null;
      _answerText = '';
      _answered = false;
      _wasCorrect = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final exercise = widget.exercise;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Text(exercise.prompt, style: AppTextStyles.titleSmall()),
        ),
        const SizedBox(height: 12),
        if (_isChoice)
          ..._buildChoiceOptions(context)
        else ...[
          TextField(
            onChanged: (v) => _answerText = v,
            enabled: !_answered,
            textAlign: widget.isRTL ? TextAlign.right : TextAlign.start,
            decoration: const InputDecoration(
              hintText: 'Type your answer',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (!_answered)
            PrimaryButton(
              label: 'Check',
              onPressed: _submitTranslation,
            ),
        ],
        if (_answered) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _wasCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 18,
                color: _wasCorrect ? AppColors.success : subtext,
              ),
              const SizedBox(width: 6),
              Text(
                _wasCorrect ? 'Correct!' : 'Not quite — try again?',
                style: AppTextStyles.titleSmall(
                  color:
                      _wasCorrect ? AppColors.success : subtext,
                ),
              ),
              if (!_wasCorrect && !_isChoice) ...[
                const Spacer(),
                TextButton(onPressed: _retry, child: const Text('Try again')),
              ],
            ],
          ),
          if (exercise.explanation != null &&
              exercise.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection:
                  widget.isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                exercise.explanation!,
                style: AppTextStyles.bodySmall(color: subtext),
              ),
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _buildChoiceOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return [
      for (var i = 0; i < _display.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _answered ? null : () => _submitChoice(i),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Semantics(
              button: !_answered,
              container: true,
              label: _answered && i == _display.correctIndex
                  ? '${_display.options[i]} — correct answer'
                  : _display.options[i],
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _answered && i == _display.correctIndex
                    ? AppColors.success.withValues(alpha: 0.12)
                    : (_answered && i == _selected
                        ? (isDark
                                ? AppColors.subtextDark
                                : AppColors.subtextLight)
                            .withValues(alpha: 0.08)
                        : Theme.of(context).cardTheme.color),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: _answered && i == _display.correctIndex
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
                      child: Text(
                        _display.options[i],
                        style: AppTextStyles.bodyMedium(),
                      ),
                    ),
                  ),
                  if (_answered && i == _display.correctIndex)
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.success),
                ],
              ),
              ),
            ),
          ),
        ),
      if (_answered && !_wasCorrect)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _retry, child: const Text('Try again')),
        ),
    ];
  }
}
