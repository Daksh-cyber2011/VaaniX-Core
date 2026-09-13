/// Exam Mode 2.0 — Weak-Area Screen (M8, §21/§22/§23/§30)
///
/// The weak-area hub:
///
///  * §21 REPORT — ranked findings with qualitative severity and
///    pattern-based evidence sentences (never a raw wrong count,
///    never a percentage). Honest "insufficient evidence" state.
///  * §23 REVISION — the forgetting-aware schedule: fresh / due /
///    overdue bands, and the mixed mistake-first revision session.
///  * §22 RECOVERY — the recovery-day decision (rationale always
///    shown, §50) and the four-phase recovery session:
///    recap → mistake retry + targeted practice → held-aside mastery
///    recheck → honest outcome.
///
/// MCQ + typed answers only here — the photo pipeline stays on the
/// practice screen (§24: do not force every answer type everywhere).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/remediation_engine.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart';
import 'package:vaanix_app/features/exam/presentation/widgets/exam_xp_strip.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamWeakAreaScreen extends ConsumerStatefulWidget {
  const ExamWeakAreaScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamWeakAreaScreen> createState() =>
      _ExamWeakAreaScreenState();
}

class _ExamWeakAreaScreenState extends ConsumerState<ExamWeakAreaScreen> {
  final TextEditingController _typedController = TextEditingController();

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(examWeakAreaProvider(widget.trackId));
    final overviewAsync = ref.watch(weakAreaOverviewProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Weak Areas',
      body: sessionAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Analysing your weak areas…'),
        ),
        error: (e, _) => _SessionUnavailable(trackId: widget.trackId),
        data: (session) => overviewAsync.when(
          loading: () => const Center(
            child: VaaniXLoadingIndicator(message: 'Loading your report…'),
          ),
          error: (e, _) => _SessionUnavailable(trackId: widget.trackId),
          data: (overview) => _WeakAreaBody(
            overview: overview,
            session: session,
            trackId: widget.trackId,
            typedController: _typedController,
          ),
        ),
      ),
    );
  }
}

class _SessionUnavailable extends ConsumerWidget {
  const _SessionUnavailable({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('कमज़ोर क्षेत्र लोड नहीं हो सका — दायरा चुना है न?'),
          const SizedBox(height: 12),
          PrimaryButton.secondary(
            label: 'फिर से कोशिश करें',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(weakAreaOverviewProvider(trackId)),
          ),
        ],
      ),
    );
  }
}

class _WeakAreaBody extends ConsumerWidget {
  const _WeakAreaBody({
    required this.overview,
    required this.session,
    required this.trackId,
    required this.typedController,
  });

  final WeakAreaOverview overview;
  final WeakAreaSessionData session;
  final String trackId;
  final TextEditingController typedController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A live session takes over the whole body (recap / practice /
    // recheck / done).
    if (session.phase != WeakSessionPhase.intro) {
      return _SessionView(
        session: session,
        trackId: trackId,
        typedController: typedController,
      );
    }

    final report = overview.report;
    final due = overview.dueRevision(limit: 5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: report.hasFindings
              ? 'आपके असली अभ्यास से कुछ कमज़ोर क्षेत्र दिखे हैं — साफ़-साफ़, बिना अंक।'
              : 'अभी काफ़ी सबूत नहीं है — अभ्यास बढ़ेगा तो कमज़ोरी खुद दिखेगी।',
          state: report.hasAttentionFinding
              ? VanState.achievement
              : VanState.happy,
        ),
        const SizedBox(height: 8),

        // --- §22 recovery-day decision (always explained, §50).
        if (overview.decision.shouldRecover) ...[
          _DecisionCard(decision: overview.decision, trackId: trackId),
          const SizedBox(height: 10),
        ],

        // --- §21 findings.
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('कमज़ोर क्षेत्र — सबूत के साथ', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 4),
              Text(report.evidenceNote, style: AppTextStyles.bodySmall()),
              const SizedBox(height: 10),
              if (!report.hasFindings)
                Text(
                  'फ़िलहाल कोई खास कमज़ोरी नहीं दिख रही — बढ़िया चल रहा है!',
                  style: AppTextStyles.bodyMedium(),
                ),
              for (final f in report.findings) ...[
                _FindingRow(finding: f),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // --- §23 revision schedule.
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('दोहराव की ज़रूरत (भूलने की गति के अनुसार)',
                  style: AppTextStyles.titleSmall()),
              const SizedBox(height: 4),
              Text(
                'हर विषय का दोहराव उसकी प्रगति से तय होता है — हर रविवार नहीं।',
                style: AppTextStyles.bodySmall(),
              ),
              const SizedBox(height: 10),
              if (due.isEmpty)
                Text('अभी किसी विषय का दोहराव देय नहीं है।',
                    style: AppTextStyles.bodyMedium())
              else ...[
                for (final item in due) ...[
                  _RevisionRow(item: item),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'दोहराव शुरू करें',
                  icon: const Icon(Icons.history),
                  onPressed: () => ref
                      .read(examWeakAreaProvider(trackId).notifier)
                      .startRevision(),
                ),
              ],
            ],
          ),
        ),
        if (session.notice != null) ...[
          const SizedBox(height: 10),
          _NoticeCard(text: session.notice!),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// §22 decision card
// ---------------------------------------------------------------------------

class _DecisionCard extends ConsumerWidget {
  const _DecisionCard({required this.decision, required this.trackId});

  final WeakAreaDayDecision decision;
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.healing, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('इस हफ़्ते का recovery दिन',
                  style: AppTextStyles.titleSmall()),
            ],
          ),
          const SizedBox(height: 8),
          Text(decision.rationale, style: AppTextStyles.bodyMedium()),
          const SizedBox(height: 8),
          Text(
            decision.dayIndex == 0
                ? 'आज recovery दिन है'
                : 'दिन ${decision.dayIndex + 1} recovery पर रखा गया है',
            style: AppTextStyles.labelMedium(color: AppColors.warning),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Recovery session शुरू करें',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => ref
                .read(examWeakAreaProvider(trackId).notifier)
                .startRecovery(decision.focusTopicId),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// §21 finding row
// ---------------------------------------------------------------------------

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final WeakTopicFinding finding;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (finding.severity) {
      WeakSeverity.needsAttention => ('ध्यान चाहिए', AppColors.error),
      WeakSeverity.focus => ('स focus करें', AppColors.warning),
      WeakSeverity.watch => ('नज़र रखें', AppColors.info),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: AppTextStyles.labelSmall(color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(finding.evidenceSentence,
              style: AppTextStyles.bodyMedium()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// §23 revision row
// ---------------------------------------------------------------------------

class _RevisionRow extends StatelessWidget {
  const _RevisionRow({required this.item});

  final RevisionItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (item.bandOf(DateTime.now())) {
      RevisionRiskBand.overdue => (
          Icons.error_outline,
          AppColors.error,
          'देर हो रही है'
        ),
      RevisionRiskBand.due => (Icons.schedule, AppColors.warning, 'समय आ गया'),
      RevisionRiskBand.fresh => (Icons.check_circle, AppColors.success, 'ताज़ा'),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(item.bandLabel, style: AppTextStyles.bodyMedium()),
        ),
        Text(label, style: AppTextStyles.labelSmall(color: color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session flow (§22 phases / §23 revision loop)
// ---------------------------------------------------------------------------

class _SessionView extends ConsumerStatefulWidget {
  const _SessionView({
    required this.session,
    required this.trackId,
    required this.typedController,
  });

  final WeakAreaSessionData session;
  final String trackId;
  final TextEditingController typedController;

  @override
  ConsumerState<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<_SessionView> {
  int? _mcqSelected;

  void _resetInput() {
    setState(() => _mcqSelected = null);
    widget.typedController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final notifier = ref.read(examWeakAreaProvider(widget.trackId).notifier);

    switch (s.phase) {
      case WeakSessionPhase.recap:
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            VanSpeechStrip(
              message: 'कमज़ोर क्षेत्र recovery — «${s.topicTitle}»',
              state: VanState.achievement,
            ),
            const SizedBox(height: 8),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('छोटा concept दोहराव', style: AppTextStyles.titleMedium()),
                  const SizedBox(height: 10),
                  Text(s.plan?.recap.recapText ?? '',
                      style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'समझ गया — आगे बढ़ें',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: notifier.beginPractice,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PhaseStrip(mode: s.mode, phase: s.phase),
          ],
        );

      case WeakSessionPhase.practice:
      case WeakSessionPhase.recheck:
        final q = s.session?.current;
        if (q == null) {
          return const Center(
            child: VaaniXLoadingIndicator(message: 'Getting ready…'),
          );
        }
        return _QuestionCard(
          session: s,
          question: q,
          mcqSelected: _mcqSelected,
          typedController: widget.typedController,
          onSelect: (i) => setState(() => _mcqSelected = i),
          onSubmit: _submit,
          onRetry: () async {
            await notifier.retryAttempt();
            _resetInput();
          },
          onAdvance: () async {
            await notifier.advance();
            _resetInput();
          },
          onReveal: () async {
            await notifier.reveal();
          },
        );

      case WeakSessionPhase.done:
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            VanSpeechStrip(
              message: s.notice ?? 'session पूरा हुआ।',
              state: s.outcome == RemediationOutcome.recovered
                  ? VanState.achievement
                  : VanState.happy,
            ),
            const SizedBox(height: 8),
            // M10: the honest XP/streak line for this finished
            // recovery/revision session.
            ExamSessionXpStrip(trackId: widget.trackId),
            const SizedBox(height: 10),
            if (s.mode == WeakSessionMode.recovery)
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('mastery जाँच', style: AppTextStyles.titleSmall()),
                    const SizedBox(height: 8),
                    Text(
                      switch (s.outcome) {
                        RemediationOutcome.recovered =>
                          'पूरी तरह साफ़ — recovery हो गई।',
                        RemediationOutcome.stillNeedsWork =>
                          'अभी थोड़ा और अभ्यास चाहिए।',
                        RemediationOutcome.notRun => '—',
                      },
                      style: AppTextStyles.bodyMedium(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'वापस रिपोर्ट पर',
              icon: const Icon(Icons.arrow_back),
              onPressed: notifier.close,
            ),
          ],
        );

      case WeakSessionPhase.intro:
        return const Center(
          child: VaaniXLoadingIndicator(message: 'Starting session…'),
        );
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(examWeakAreaProvider(widget.trackId).notifier);
    final q = widget.session.session?.current;
    if (q == null) return;
    if (q.kind == PracticeQuestionKind.mcq) {
      final sel = _mcqSelected;
      if (sel == null) return;
      await notifier.submitMcq(sel);
      if (mounted) setState(() => _mcqSelected = null);
    } else {
      final text = widget.typedController.text;
      if (text.trim().isEmpty) return;
      await notifier.submitTyped(text);
      if (mounted) widget.typedController.clear();
    }
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.session,
    required this.question,
    required this.mcqSelected,
    required this.typedController,
    required this.onSelect,
    required this.onSubmit,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
  });

  final WeakAreaSessionData session;
  final PracticeQuestion question;
  final int? mcqSelected;
  final TextEditingController typedController;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onAdvance;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final s = session.session!;
    final phaseLabel = session.phase == WeakSessionPhase.recheck
        ? 'mastery जाँच (बिना मदद)'
        : (session.mode == WeakSessionMode.revision ? 'दोहराव' : 'recovery अभ्यास');
    final progress =
        '${(s.index + 1).clamp(1, s.questions.length)}/${s.questions.length}';
    final isMcq = question.kind == PracticeQuestionKind.mcq;
    final answered = s.currentVerdict != null || s.awaitingNext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _PhaseStrip(mode: session.mode, phase: session.phase),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(phaseLabel, style: AppTextStyles.labelMedium(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
                  const Spacer(),
                  Text(progress, style: AppTextStyles.labelMedium(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
                ],
              ),
              const SizedBox(height: 12),
              Text(question.prompt, style: AppTextStyles.titleSmall()),
              const SizedBox(height: 14),

              if (isMcq && !answered)
                for (var i = 0; i < question.options.length; i++)
                  _OptionTile(
                    text: question.options[i],
                    selected: mcqSelected == i,
                    onTap: () => onSelect(i),
                  ),
              if (isMcq && !answered) ...[
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'उत्तर दें',
                  icon: const Icon(Icons.check),
                  onPressed: mcqSelected != null ? onSubmit : null,
                ),
              ],

              if (!isMcq && !answered) ...[
                TextField(
                  controller: typedController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'अपना उत्तर यहाँ लिखें…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'उत्तर दें',
                  icon: const Icon(Icons.check),
                  onPressed: onSubmit,
                ),
              ],

              if (s.awaitingNext) ...[
                _FeedbackPanel(text: s.currentVerdictText ?? ''),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'आगे',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: onAdvance,
                ),
              ] else if (answered) ...[
                // A miss with retry budget left → §28 "Try again".
                _FeedbackPanel(text: s.currentVerdictText ?? ''),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'फिर कोशिश करें',
                        icon: const Icon(Icons.refresh),
                        onPressed: onRetry,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton.secondary(
                        label: 'उत्तर देखें',
                        icon: const Icon(Icons.lightbulb_outline),
                        onPressed: onReveal,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: selected ? AppColors.primary : AppColors.subtextLight,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: AppTextStyles.bodyMedium())),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppTextStyles.bodyMedium()),
    );
  }
}

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.mode, required this.phase});

  final WeakSessionMode mode;
  final WeakSessionPhase phase;

  @override
  Widget build(BuildContext context) {
    if (mode == WeakSessionMode.revision) {
      return _PhaseChipRow(
          labels: const ['मिला-जुला दोहराव'], activeIndex: 0);
    }
    const labels = ['दोहराव', 'गलतियाँ + अभ्यास', 'mastery जाँच', 'पूरा'];
    final active = switch (phase) {
      WeakSessionPhase.recap => 0,
      WeakSessionPhase.practice => 1,
      WeakSessionPhase.recheck => 2,
      WeakSessionPhase.done => 3,
      WeakSessionPhase.intro => 0,
    };
    return _PhaseChipRow(labels: labels, activeIndex: active);
  }
}

class _PhaseChipRow extends StatelessWidget {
  const _PhaseChipRow({required this.labels, required this.activeIndex});

  final List<String> labels;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: i <= activeIndex
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: i <= activeIndex
                      ? AppColors.primary
                      : AppColors.borderLight,
                ),
              ),
              child: Text(
                labels[i],
                style: AppTextStyles.labelSmall(
                    color: i <= activeIndex
                        ? AppColors.primary
                        : AppColors.subtextLight),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall())),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: child,
    );
  }
}
