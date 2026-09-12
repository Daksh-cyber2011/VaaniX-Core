/// Exam Mode 2.0 — Mock Screen (M9, §25/§30/§41)
///
/// The mock ladder UI: mini → section → full selection (each with its
/// honest official marks/time), the mock session on the M6 loop
/// engine, and the deterministic result: overall band + per-section
/// bands + the §21 weak-section finding surfaced in the summary
/// (never a percentage, §30; never AI-scored, §41).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/pyq_mock_providers.dart';
import 'package:vaanix_app/features/exam/presentation/widgets/exam_xp_strip.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamMockScreen extends ConsumerStatefulWidget {
  const ExamMockScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamMockScreen> createState() => _ExamMockScreenState();
}

class _ExamMockScreenState extends ConsumerState<ExamMockScreen> {
  final TextEditingController _typedController = TextEditingController();
  int? _mcqSelected;
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _typedController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _resetInput() {
    setState(() => _mcqSelected = null);
    _typedController.clear();
  }

  void _startTicker(int minutes) {
    _ticker?.cancel();
    setState(() => _secondsLeft = minutes * 60);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mockAsync = ref.watch(examMockProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Mocks',
      body: mockAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading mocks'),
        ),
        error: (e, _) => _Unavailable(trackId: widget.trackId),
        data: (data) => _MockBody(
          data: data,
          trackId: widget.trackId,
          secondsLeft: _secondsLeft,
          mcqSelected: _mcqSelected,
          typedController: _typedController,
          onMcqSelect: (i) => setState(() => _mcqSelected = i),
          onSubmit: _submit,
          onRetry: () async {
            await ref
                .read(examMockProvider(widget.trackId).notifier)
                .retryAttempt();
            _resetInput();
          },
          onAdvance: () async {
            await ref
                .read(examMockProvider(widget.trackId).notifier)
                .advance();
            _resetInput();
          },
          onReveal: () async {
            await ref.read(examMockProvider(widget.trackId).notifier).reveal();
          },
          onKindSelected: (kind) => _start(kind, focusSectionId: null),
        ),
      ),
    );
  }

  Future<void> _start(MockKind kind, {String? focusSectionId}) async {
    _resetInput();
    await ref
        .read(examMockProvider(widget.trackId).notifier)
        .start(kind, focusSectionId: focusSectionId);
    final paper =
        ref.read(examMockProvider(widget.trackId)).value?.paper;
    if (mounted && paper != null) {
      _startTicker(paper.timeLimitMinutes);
    }
  }

  Future<void> _submit() async {
    final data = ref.read(examMockProvider(widget.trackId)).value;
    final q = data?.session?.current;
    if (q == null) return;
    final notifier = ref.read(examMockProvider(widget.trackId).notifier);
    if (q.kind == PracticeQuestionKind.mcq) {
      final sel = _mcqSelected;
      if (sel == null) return;
      await notifier.submitMcq(sel);
      if (mounted) setState(() => _mcqSelected = null);
    } else {
      final text = _typedController.text;
      if (text.trim().isEmpty) return;
      await notifier.submitTyped(text);
      if (mounted) _typedController.clear();
    }
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Mock तैयार नहीं हो सका — क्या दायरा चुना है?'),
          const SizedBox(height: 12),
          PrimaryButton.secondary(
            label: 'फिर से कोशिश करें',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(examMockProvider(trackId)),
          ),
        ],
      ),
    );
  }
}

class _MockBody extends ConsumerWidget {
  const _MockBody({
    required this.data,
    required this.trackId,
    required this.secondsLeft,
    required this.mcqSelected,
    required this.typedController,
    required this.onMcqSelect,
    required this.onSubmit,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
    required this.onKindSelected,
  });

  final MockStateData data;
  final String trackId;
  final int secondsLeft;
  final int? mcqSelected;
  final TextEditingController typedController;
  final ValueChanged<int> onMcqSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onAdvance;
  final VoidCallback onReveal;
  final ValueChanged<MockKind> onKindSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isFinished && data.result != null) {
      return _ResultView(
        result: data.result!,
        history: data.history,
        onAnother: () => onKindSelected(data.result!.kind),
        trackId: trackId,
      );
    }

    if (data.isRunning && data.session != null) {
      final paper = data.paper!;
      return _PaperCard(
        paper: paper,
        session: data.session!,
        secondsLeft: secondsLeft,
        mcqSelected: mcqSelected,
        typedController: typedController,
        onMcqSelect: onMcqSelect,
        onSubmit: onSubmit,
        onRetry: onRetry,
        onAdvance: onAdvance,
        onReveal: onReveal,
      );
    }

    // Selection view — the mock ladder (§25 honest structure).
    return FutureBuilder<List<MockSectionResult>>(
      future: _sectionSummaries(ref),
      builder: (context, snap) {
        final sectionSummaries = snap.data ?? const <MockSectionResult>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            VanSpeechStrip(
              message: 'छोटे mock से शुरू करें, फिर खंड, फिर पूरा पेपर — '
                  'जैसे असली परीक्षा की तैयारी होती है।',
              state: VanState.happy,
            ),
            const SizedBox(height: 12),
            for (final kind in MockKind.values) ...[
              _KindCard(
                kind: kind,
                onTap: () => onKindSelected(kind),
              ),
              const SizedBox(height: 10),
            ],
            if (sectionSummaries.isNotEmpty) ...[
              _SectionHistoryCard(sections: sectionSummaries),
              const SizedBox(height: 10),
            ],
            if (data.history.isNotEmpty) ...[
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('पिछले mocks', style: AppTextStyles.titleSmall()),
                    const SizedBox(height: 6),
                    for (final r in data.history.reversed.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${_kindLabel(r.kind)} — '
                          '${r.totalCorrect}/${r.totalAttempted} सही '
                          '(${r.completedAtIso.substring(0, 10)})',
                          style: AppTextStyles.bodySmall(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _kindLabel(MockKind kind) => switch (kind) {
        MockKind.mini => 'मिनी mock',
        MockKind.section => 'खंड mock',
        MockKind.full => 'पूरा mock',
      };

  /// §21 weak-section evidence from the last mock (for the honest
  /// "where to work next" card).
  Future<List<MockSectionResult>> _sectionSummaries(WidgetRef ref) async {
    if (data.history.isEmpty) return const [];
    return data.history.last.sectionResults;
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({required this.kind, required this.onTap});

  final MockKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      MockKind.mini => (Icons.timelapse, AppColors.success),
      MockKind.section => (Icons.view_agenda_outlined, AppColors.info),
      MockKind.full => (Icons.assignment, AppColors.vanOrange),
    };
    return _Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.label, style: AppTextStyles.titleSmall()),
                  const SizedBox(height: 2),
                  Text(kind.description, style: AppTextStyles.bodySmall()),
                ],
              ),
            ),
            const Icon(Icons.play_arrow, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionHistoryCard extends StatelessWidget {
  const _SectionHistoryCard({required this.sections});

  final List<MockSectionResult> sections;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('पिछले mock के खंड', style: AppTextStyles.titleSmall()),
          const SizedBox(height: 6),
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    s.band == 'needsAttention'
                        ? Icons.error_outline
                        : (s.band == 'strong'
                            ? Icons.check_circle
                            : Icons.schedule),
                    size: 16,
                    color: s.band == 'needsAttention'
                        ? AppColors.error
                        : (s.band == 'strong'
                            ? AppColors.success
                            : AppColors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${s.title} — ${s.bandLabel}',
                        style: AppTextStyles.bodyMedium()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.paper,
    required this.session,
    required this.secondsLeft,
    required this.mcqSelected,
    required this.typedController,
    required this.onMcqSelect,
    required this.onSubmit,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
  });

  final MockPaper paper;
  final PracticeSessionState session;
  final int secondsLeft;
  final int? mcqSelected;
  final TextEditingController typedController;
  final ValueChanged<int> onMcqSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onAdvance;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final q = session.current;
    if (q == null) return const SizedBox.shrink();
    final isMcq = q.kind == PracticeQuestionKind.mcq;
    final answered = session.currentVerdict != null || session.awaitingNext;
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    final progress =
        '${(session.index + 1).clamp(1, session.questions.length)}/'
        '${session.questions.length}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${paper.kind == MockKind.full ? 'पूरा' : (paper.kind == MockKind.section ? 'खंड' : 'मिनी')} mock — '
                '${paper.totalMarks.toStringAsFixed(0)} अंक',
                style: AppTextStyles.labelMedium(color: AppColors.subtextLight),
              ),
            ),
            Icon(Icons.timer, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('$minutes:$seconds',
                style: AppTextStyles.labelMedium(color: AppColors.warning)),
          ],
        ),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('प्रश्न $progress',
                      style: AppTextStyles.labelMedium(
                          color: AppColors.subtextLight)),
                  const Spacer(),
                  Text(
                    paper.sections.length > 1
                        ? paper.sections
                            .firstWhere(
                              (s) => s.questions.any((x) => x.id == q.id),
                              orElse: () => paper.sections.first,
                            )
                            .title
                        : (paper.sections.isEmpty
                            ? ''
                            : paper.sections.first.title),
                    style: AppTextStyles.labelSmall(color: AppColors.info),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(q.prompt, style: AppTextStyles.titleSmall()),
              const SizedBox(height: 14),
              if (isMcq && !answered)
                for (var i = 0; i < q.options.length; i++)
                  _OptionTile(
                    text: q.options[i],
                    selected: mcqSelected == i,
                    onTap: () => onMcqSelect(i),
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
              if (session.awaitingNext) ...[
                _FeedbackPanel(text: session.currentVerdictText ?? ''),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'आगे',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: onAdvance,
                ),
              ] else if (answered) ...[
                _FeedbackPanel(text: session.currentVerdictText ?? ''),
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

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.history,
    required this.onAnother,
    required this.trackId,
  });

  final MockResult result;
  final List<MockResult> history;
  final VoidCallback onAnother;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: result.summary,
          state: result.hasWeakSection
              ? VanState.achievement
              : VanState.happy,
        ),
        const SizedBox(height: 8),
        // M10: the honest XP/streak line for this finished mock.
        ExamSessionXpStrip(trackId: trackId),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('खंड-वार नतीजे', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 4),
              Text('गुणात्मक राय — कोई प्रतिशत नहीं (ईमानदार आकलन)।',
                  style: AppTextStyles.bodySmall()),
              const SizedBox(height: 10),
              for (final s in result.sectionResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        s.band == 'needsAttention'
                            ? Icons.error_outline
                            : (s.band == 'strong'
                                ? Icons.check_circle
                                : Icons.schedule),
                        size: 16,
                        color: s.band == 'needsAttention'
                            ? AppColors.error
                            : (s.band == 'strong'
                                ? AppColors.success
                                : AppColors.warning),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${s.title} — ${s.bandLabel}',
                            style: AppTextStyles.bodyMedium()),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'एक और mock',
          icon: const Icon(Icons.refresh),
          onPressed: onAnother,
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderLight),
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
