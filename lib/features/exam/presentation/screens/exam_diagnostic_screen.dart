/// Exam Mode 2.0 — Diagnostic Screen (M4, §10–§11)
///
/// The SHORT adaptive diagnostic rendered as a VaaniX challenge, not a
/// boring exam (§10): Van narrates, questions adapt silently (§11 —
/// the ladder itself is never narrated), progress shows answered
/// count, and the finish screen is a REPORT of meaningful qualitative
/// observations — never a score or percentage (§30).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_models.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_engine.dart'
    show DiagnosticSessionState;
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart';
import 'package:vaanix_app/features/exam/presentation/widgets/exam_xp_strip.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamDiagnosticScreen extends ConsumerStatefulWidget {
  const ExamDiagnosticScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamDiagnosticScreen> createState() =>
      _ExamDiagnosticScreenState();
}

class _ExamDiagnosticScreenState extends ConsumerState<ExamDiagnosticScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final diagAsync = ref.watch(examDiagnosticProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Diagnostic Challenge',
      body: diagAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Setting up your diagnostic…'),
        ),
        error: (e, _) => _DiagnosticUnavailable(
          onStart: _start,
          message: 'Couldn\'t start the diagnostic.\nPlease make sure you\'ve selected a syllabus.',
        ),
        data: (data) {
          if (data.isFinished && data.report != null) {
            return _ReportView(
                report: data.report!, trackId: widget.trackId);
          }
          if (data.isRunning && data.session != null) {
            return _QuestionFlow(
              session: data.session!,
              selected: _selected,
              onSelect: (i) => setState(() => _selected = i),
              onAnswer: _onAnswer,
              onSkip: _onSkip,
            );
          }
          return _IntroCard(onStart: _start);
        },
      ),
    );
  }

  Future<void> _start() async {
    await ref
        .read(examDiagnosticProvider(widget.trackId).notifier)
        .start();
  }

  Future<void> _onAnswer() async {
    final sel = _selected;
    if (sel == null) return;
    setState(() => _selected = null);
    await ref
        .read(examDiagnosticProvider(widget.trackId).notifier)
        .answer(sel);
  }

  Future<void> _onSkip() async {
    setState(() => _selected = null);
    await ref
        .read(examDiagnosticProvider(widget.trackId).notifier)
        .answer(-1);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'एक छोटा-सा challenge! 5–10 मिनट में समझ आ जाएगा कि '
              'आप कहाँ मज़बूत हैं और कहाँ थोड़ा ध्यान चाहिए। '
              'कोई नंबर नहीं — बस ईमानदार जानकारी।',
          state: VanState.happy,
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('कैसे चलेगा?', style: AppTextStyles.titleMedium()),
              const SizedBox(height: 8),
              _Bullet(
                  text: 'कुछ MCQ प्रश्न — जवाब के साथ-साथ कठिनाई भी अपने आप '
                      'बदलती है (§11 adaptive)।'),
              _Bullet(text: 'सवाल आपकी चुनी हुई syllabus से ही आते हैं — बाहर से कुछ नहीं।'),
              _Bullet(
                  text: 'स्किप करना ठीक है — Van समझ जाएगा (हिसाब ईमानदार रहेगा)।',
                  isDark: isDark),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Challenge शुरू करें',
                icon: const Icon(Icons.bolt),
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionFlow extends StatelessWidget {
  const _QuestionFlow({
    required this.session,
    required this.selected,
    required this.onSelect,
    required this.onAnswer,
    required this.onSkip,
  });

  final DiagnosticSessionState session;
  final int? selected;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onAnswer;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final q = session.current!;
    final answered = session.answeredCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'प्रश्न ${answered + 1} — आराम से, अपनी समझ से।',
          state: VanState.focus,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Question ${answered + 1}: ${q.prompt}',
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${q.topicTitle}',
                        style: AppTextStyles.labelMedium(
                            color: AppColors.primary)),
                    const Spacer(),
                    Text('$answered उत्तरित',
                        style: AppTextStyles.labelSmall(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppColors.subtextDark
                                : AppColors.subtextLight)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(q.prompt, style: AppTextStyles.titleMedium()),
                const SizedBox(height: 16),
                for (var i = 0; i < q.options.length; i++) ...[
                  _OptionTile(
                    label: q.options[i],
                    selected: selected == i,
                    onTap: () => onSelect(i),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'उत्तर दें',
                  icon: const Icon(Icons.check),
                  onPressed: selected == null ? null : onAnswer,
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onSkip, child: const Text('Skip')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report, required this.trackId});

  final DiagnosticReport report;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'हो गया! अब इसी आधार पर आपकी निजी योजना बनाते हैं।',
          state: VanState.achievement,
        ),
        const SizedBox(height: 8),
        // M10: the honest XP/streak line for the finished diagnostic.
        ExamSessionXpStrip(trackId: trackId),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Van के निरीक्षण', style: AppTextStyles.titleMedium()),
              const SizedBox(height: 12),
              for (final obs in report.observations) ...[
                _ObsRow(text: obs),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('विषय-वार आकलन', style: AppTextStyles.titleMedium()),
              const SizedBox(height: 12),
              for (final e in report.topicEstimates) ...[
                _TopicBandRow(estimate: e),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Next step (M5): the personalized plan.
        PrimaryButton(
          label: 'निजी योजना बनाएँ',
          icon: const Icon(Icons.auto_awesome),
          onPressed: () => GoRouter.of(context).pushNamed(
            RouteNames.examPlanName,
            pathParameters: {'trackId': trackId},
          ),
        ),
      ],
    );
  }
}

class _TopicBandRow extends StatelessWidget {
  const _TopicBandRow({required this.estimate});

  final TopicEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final color = switch (estimate.band) {
      TopicBand.strong => AppColors.success,
      TopicBand.learning => AppColors.info,
      TopicBand.needsAttention => AppColors.warning,
    };
    return Semantics(
      label: '${estimate.topicTitle}: ${estimate.band.label}',
      child: Row(
        children: [
          Expanded(child: Text(estimate.topicTitle, style: AppTextStyles.bodyMedium())),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              estimate.band.label,
              style: AppTextStyles.labelSmall(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObsRow extends StatelessWidget {
  const _ObsRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.insights,
            size: 18,
            color: AppColors.primary,
            semanticLabel: 'observation'),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodyMedium())),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(label, style: AppTextStyles.bodyMedium()),
        ),
      ),
    );
  }
}

class _DiagnosticUnavailable extends StatelessWidget {
  const _DiagnosticUnavailable({
    required this.onStart,
    required this.message,
  });

  final Future<void> Function() onStart;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.subtextDark
                      : AppColors.subtextLight),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'फिर कोशिश करें', onPressed: onStart),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.isDark = false});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight),
            ),
          ),
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
