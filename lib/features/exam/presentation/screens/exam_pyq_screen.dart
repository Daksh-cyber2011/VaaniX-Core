/// Exam Mode 2.0 — PYQ Screen (M9, §25)
///
/// The PYQ practice track: §25 provenance is ALWAYS visible (official
/// exam-pattern / PYQ-style — never a fake "actual CBSE PYQ" label),
/// section filter chips, the session loop (MCQ + typed on the M6
/// engine), and the honest per-topic PYQ performance summary (§30 —
/// bands, never percentages).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/pyq_mock_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart'
    show examScopeProvider;
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/presentation/widgets/exam_xp_strip.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamPyqScreen extends ConsumerStatefulWidget {
  const ExamPyqScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamPyqScreen> createState() => _ExamPyqScreenState();
}

class _ExamPyqScreenState extends ConsumerState<ExamPyqScreen> {
  final TextEditingController _typedController = TextEditingController();
  int? _mcqSelected;
  String? _selectedSection;

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  void _resetInput() {
    setState(() => _mcqSelected = null);
    _typedController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pyqAsync = ref.watch(examPyqProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'PYQ Practice',
      body: pyqAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading PYQ practice…'),
        ),
        error: (e, _) => _Unavailable(trackId: widget.trackId),
        data: (data) => _PyqBody(
          data: data,
          trackId: widget.trackId,
          selectedSection: _selectedSection,
          mcqSelected: _mcqSelected,
          typedController: _typedController,
          onSectionTap: (id) => setState(
              () => _selectedSection = _selectedSection == id ? null : id),
          onMcqSelect: (i) => setState(() => _mcqSelected = i),
          onSubmit: _submit,
          onRetry: () async {
            await ref
                .read(examPyqProvider(widget.trackId).notifier)
                .retryAttempt();
            _resetInput();
          },
          onAdvance: () async {
            await ref.read(examPyqProvider(widget.trackId).notifier).advance();
            _resetInput();
          },
          onReveal: () async {
            await ref.read(examPyqProvider(widget.trackId).notifier).reveal();
          },
          onStart: _start,
        ),
      ),
    );
  }

  Future<void> _start() async {
    _resetInput();
    await ref.read(examPyqProvider(widget.trackId).notifier).start(
          filter: PyqFilter(
            sectionIds:
                _selectedSection == null ? const {} : {_selectedSection!},
          ),
        );
  }

  Future<void> _submit() async {
    final data = ref.read(examPyqProvider(widget.trackId)).value;
    final q = data?.session?.current;
    if (q == null) return;
    final notifier = ref.read(examPyqProvider(widget.trackId).notifier);
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
          const Text('PYQ लोड नहीं हो सका — क्या दायरा चुना है?'),
          const SizedBox(height: 12),
          PrimaryButton.secondary(
            label: 'फिर से कोशिश करें',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(examPyqProvider(trackId)),
          ),
        ],
      ),
    );
  }
}

class _PyqBody extends ConsumerWidget {
  const _PyqBody({
    required this.data,
    required this.trackId,
    required this.selectedSection,
    required this.mcqSelected,
    required this.typedController,
    required this.onSectionTap,
    required this.onMcqSelect,
    required this.onSubmit,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
    required this.onStart,
  });

  final PyqStateData data;
  final String trackId;
  final String? selectedSection;
  final int? mcqSelected;
  final TextEditingController typedController;
  final ValueChanged<String?> onSectionTap;
  final ValueChanged<int> onMcqSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;
  final VoidCallback onAdvance;
  final VoidCallback onReveal;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.isFinished) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          VanSpeechStrip(
            message: data.summary ?? 'PYQ अभ्यास पूरा हुआ।',
            state: VanState.achievement,
          ),
          const SizedBox(height: 8),
          // M10: the honest XP/streak line for this finished session.
          ExamSessionXpStrip(trackId: trackId),
          const SizedBox(height: 12),
          _PerformanceCard(performance: data.performance),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'और PYQ करें',
            icon: const Icon(Icons.refresh),
            onPressed: onStart,
          ),
        ],
      );
    }

    if (data.isRunning && data.session != null) {
      return _QuestionCard(
        session: data.session!,
        mcqSelected: mcqSelected,
        typedController: typedController,
        onMcqSelect: onMcqSelect,
        onSubmit: onSubmit,
        onRetry: onRetry,
        onAdvance: onAdvance,
        onReveal: onReveal,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'आधिकारिक परीक्षा-पैटर्न पर बना अभ्यास — असली पेपर नहीं, '
              'पैटर्न ही असली है।',
          state: VanState.happy,
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('खंड चुनें (सब देखने के लिए खाली छोड़ें)',
                  style: AppTextStyles.titleSmall()),
              const SizedBox(height: 10),
              FutureBuilder<List<({String id, String title})>>(
                future: _sectionChoices(ref),
                builder: (context, snap) {
                  final choices =
                      snap.data ?? const <({String id, String title})>[];
                  if (choices.isEmpty) {
                    return const Text('इस दायरे में कोई खंड उपलब्ध नहीं है।');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in choices)
                        _SectionChip(
                          title: choice.title,
                          selected: selectedSection == choice.id,
                          onTap: (_) => onSectionTap(choice.id),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'PYQ अभ्यास शुरू करें',
                icon: const Icon(Icons.play_arrow),
                onPressed: onStart,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PerformanceCard(performance: data.performance),
        if (data.summary != null) ...[
          const SizedBox(height: 10),
          _NoticeCard(text: data.summary!),
        ],
      ],
    );
  }

  Future<List<({String id, String title})>> _sectionChoices(
      WidgetRef ref) async {
    try {
      final scope = await ref.read(examScopeProvider(trackId).future);
      final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
      if (syllabus == null || scope.view == null) return const [];
      final available = data.availableSectionIds;
      return [
        for (final section in scope.view!.sections)
          if (available.contains(section.id))
            (id: section.id, title: section.title),
      ];
    } catch (_) {
      return const [];
    }
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight),
        ),
        child: Text(title,
            style: AppTextStyles.labelSmall(
                color: selected ? AppColors.primary : AppColors.subtextLight)),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.performance});

  final Map<String, PyqTopicPerformance> performance;

  @override
  Widget build(BuildContext context) {
    final withEvidence = performance.values.where((p) => p.hasEvidence).toList()
      ..sort((a, b) => a.band.compareTo(b.band));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PYQ प्रगति (प्रति विषय)', style: AppTextStyles.titleSmall()),
          const SizedBox(height: 4),
          Text('कम-से-कम 2 प्रश्न हल होने पर ही राय बनती है।',
              style: AppTextStyles.bodySmall()),
          const SizedBox(height: 10),
          if (withEvidence.isEmpty)
            Text('अभी PYQ-अभ्यास शुरू नहीं हुआ।',
                style: AppTextStyles.bodyMedium())
          else
            for (final p in withEvidence.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      p.band == 'needsAttention'
                          ? Icons.error_outline
                          : (p.band == 'strong'
                              ? Icons.check_circle
                              : Icons.schedule),
                      size: 16,
                      color: p.band == 'needsAttention'
                          ? AppColors.error
                          : (p.band == 'strong'
                              ? AppColors.success
                              : AppColors.warning),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        switch (p.band) {
                          'needsAttention' =>
                            '«${_shortTopic(p.topicId)}» — PYQ में कमज़ोर',
                          'strong' =>
                            '«${_shortTopic(p.topicId)}» — ठीक चल रहा है',
                          _ => '«${_shortTopic(p.topicId)}» — बनता जा रहा है',
                        },
                        style: AppTextStyles.bodyMedium(),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _shortTopic(String topicId) {
    final parts = topicId.split('_');
    return parts.length > 3 ? parts.sublist(3).join(' ') : topicId;
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.session,
    required this.mcqSelected,
    required this.typedController,
    required this.onMcqSelect,
    required this.onSubmit,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
  });

  final PracticeSessionState session;
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
    final progress =
        '${(session.index + 1).clamp(1, session.questions.length)}/'
        '${session.questions.length}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.vanOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('PYQ-शैली',
                        style: AppTextStyles.labelSmall(
                            color: AppColors.vanOrange)),
                  ),
                  const Spacer(),
                  Text(progress,
                      style: AppTextStyles.labelMedium(
                          color: AppColors.subtextLight)),
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
                color: selected ? AppColors.primary : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
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
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: child,
    );
  }
}
