/// Exam Mode 2.0 — Practice Screen (M6 + M7, §19/§26/§28)
///
/// The adaptive learning loop UI:
///
///   question → answer (MCQ / TYPED / PHOTO) → specific feedback
///   → ONE retry (§28 "Try again") → reveal + advance → summary
///
/// Photo answers (§26): pick/capture → quality preview → M7 vision
/// evaluation → honest uncertainty panel ("retake or type") when the
/// photo is unreadable/ambiguous. Typed input is always available as
/// the offline-safe path (§17).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_practice_providers.dart';
import 'package:vaanix_app/features/exam/presentation/widgets/exam_xp_strip.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamPracticeScreen extends ConsumerStatefulWidget {
  const ExamPracticeScreen({
    super.key,
    required this.trackId,
    this.focusTopicId,
  });

  final String trackId;
  final String? focusTopicId;

  String get providerKey => focusTopicId == null || focusTopicId!.isEmpty
      ? trackId
      : '$trackId::topic::$focusTopicId';

  @override
  ConsumerState<ExamPracticeScreen> createState() => _ExamPracticeScreenState();
}

class _ExamPracticeScreenState extends ConsumerState<ExamPracticeScreen> {
  int? _mcqSelected;
  final TextEditingController _typedController = TextEditingController();
  bool _evaluatingPhoto = false;
  Uint8List? _photoPreview;

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final practiceAsync = ref.watch(examPracticeProvider(widget.providerKey));

    return VaaniXScaffold(
      title: 'Practice',
      body: practiceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading practice'),
        ),
        error: (e, _) => _PracticeUnavailable(
          onStart: _start,
          message:
              'अभ्यास शुरू नहीं हो सका — क्या आपने syllabus का दायरा चुना है?',
        ),
        data: (data) {
          if (data.isFinished) {
            return _SummaryView(
              summary: data.summary ?? '',
              onRestart: _start,
              trackId: widget.trackId,
            );
          }
          if (data.isRunning && data.session != null) {
            return _QuestionFlow(
              session: data.session!,
              lastEvaluation: data.lastEvaluation,
              mcqSelected: _mcqSelected,
              typedController: _typedController,
              evaluatingPhoto: _evaluatingPhoto,
              photoPreview: _photoPreview,
              onMcqSelect: (i) => setState(() => _mcqSelected = i),
              onMcqSubmit: _onMcqSubmit,
              onTypedSubmit: _onTypedSubmit,
              onPhotoPick: _onPhotoPick,
              onRetry: _onRetry,
              onAdvance: _onAdvance,
              onReveal: _onReveal,
            );
          }
          return _IntroCard(onStart: _start);
        },
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _mcqSelected = null;
      _typedController.clear();
      _photoPreview = null;
    });
    await ref.read(examPracticeProvider(widget.providerKey).notifier).start();
  }

  Future<void> _onMcqSubmit() async {
    final sel = _mcqSelected;
    if (sel == null) return;
    await ref
        .read(examPracticeProvider(widget.providerKey).notifier)
        .submitMcq(sel);
    if (mounted) setState(() => _mcqSelected = null);
  }

  Future<void> _onTypedSubmit() async {
    final text = _typedController.text;
    if (text.trim().isEmpty) return;
    await ref
        .read(examPracticeProvider(widget.providerKey).notifier)
        .submitTyped(text);
    if (mounted) _typedController.clear();
  }

  /// §26 photo flow: pick → preview → evaluate (vision pipeline).
  Future<void> _onPhotoPick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      if (mounted) {
        setState(() {
          _photoPreview = bytes;
          _evaluatingPhoto = true;
        });
      }
      await ref
          .read(examPracticeProvider(widget.providerKey).notifier)
          .submitPhoto(bytes: bytes, mime: 'image/jpeg');
    } catch (_) {
      // Picker cancelled / permission denied — a silent, safe return.
    } finally {
      if (mounted) setState(() => _evaluatingPhoto = false);
    }
  }

  Future<void> _onReveal() async {
    await ref.read(examPracticeProvider(widget.providerKey).notifier).reveal();
    if (mounted) setState(() => _photoPreview = null);
  }

  Future<void> _onRetry() async {
    await ref
        .read(examPracticeProvider(widget.providerKey).notifier)
        .retryAttempt();
    if (mounted) {
      setState(() {
        _mcqSelected = null;
        _photoPreview = null;
      });
      _typedController.clear();
    }
  }

  Future<void> _onAdvance() async {
    await ref.read(examPracticeProvider(widget.providerKey).notifier).advance();
    if (mounted) {
      setState(() {
        _mcqSelected = null;
        _photoPreview = null;
      });
      _typedController.clear();
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'अभ्यास का समय! जवाब टाइप करें या उत्तरपुस्तिका की फ़ोटो '
              'लगाएँ — Van दोनों पढ़ेगा।',
          state: VanState.happy,
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              PrimaryButton(
                label: 'अभ्यास शुरू करें',
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

class _QuestionFlow extends ConsumerWidget {
  const _QuestionFlow({
    required this.session,
    required this.lastEvaluation,
    required this.mcqSelected,
    required this.typedController,
    required this.evaluatingPhoto,
    required this.photoPreview,
    required this.onMcqSelect,
    required this.onMcqSubmit,
    required this.onTypedSubmit,
    required this.onPhotoPick,
    required this.onRetry,
    required this.onAdvance,
    required this.onReveal,
  });

  final PracticeSessionState session;
  final EvaluationResult? lastEvaluation;
  final int? mcqSelected;
  final TextEditingController typedController;
  final bool evaluatingPhoto;
  final Uint8List? photoPreview;
  final ValueChanged<int> onMcqSelect;
  final Future<void> Function() onMcqSubmit;
  final Future<void> Function() onTypedSubmit;
  final Future<void> Function(ImageSource) onPhotoPick;
  final Future<void> Function() onRetry;
  final Future<void> Function() onAdvance;
  final Future<void> Function() onReveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = session.current!;
    final feedback = session.currentVerdictText;
    final isTypedQuestion = q.kind == PracticeQuestionKind.shortAnswer;
    final inputOpen = feedback == null && !session.awaitingNext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: 'प्रश्न ${session.index + 1} / ${session.questions.length}',
          state: VanState.focus,
        ),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.topicTitle,
                  style: AppTextStyles.labelMedium(color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(q.prompt, style: AppTextStyles.titleMedium()),
              const SizedBox(height: 16),

              // --- MCQ input ---
              if (!isTypedQuestion) ...[
                for (var i = 0; i < q.options.length; i++) ...[
                  _OptionTile(
                    label: q.options[i],
                    selected: mcqSelected == i,
                    onTap: inputOpen ? () => onMcqSelect(i) : null,
                  ),
                  const SizedBox(height: 8),
                ],
                if (inputOpen) ...[
                  PrimaryButton(
                    label: 'उत्तर दें',
                    icon: const Icon(Icons.check),
                    onPressed: mcqSelected == null ? null : onMcqSubmit,
                  ),
                ],
              ],

              // --- TYPED input (M7 offline-safe path) ---
              if (isTypedQuestion && inputOpen) ...[
                TextField(
                  controller: typedController,
                  maxLines: 3,
                  enabled: true,
                  decoration: InputDecoration(
                    hintText: 'अपना उत्तर यहाँ लिखें…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'उत्तर जमा करें',
                  icon: const Icon(Icons.send),
                  onPressed: onTypedSubmit,
                ),
                const SizedBox(height: 8),
                _PhotoAnswerRow(
                  onPhotoPick: onPhotoPick,
                  enabled: !evaluatingPhoto,
                ),
                if (evaluatingPhoto) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('फ़ोटो पढ़ी जा रही है…'),
                    ],
                  ),
                ],
                if (photoPreview != null && !evaluatingPhoto) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(photoPreview!,
                        height: 160, fit: BoxFit.cover),
                  ),
                ],
              ],

              // --- §28 feedback panel ---
              if (feedback != null) ...[
                _FeedbackPanel(
                  feedback: feedback,
                  verdict: session.currentVerdict,
                  lastEvaluation: lastEvaluation,
                ),
                const SizedBox(height: 12),
                if (session.awaitingNext) ...[
                  PrimaryButton(
                    label: 'आगे बढ़ें',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: onAdvance,
                  ),
                ] else ...[
                  PrimaryButton(
                    label: 'फिर से कोशिश करें',
                    icon: const Icon(Icons.replay),
                    onPressed: onRetry,
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton.secondary(
                    label: 'समाधान देखें',
                    onPressed: onReveal,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// §26 photo submission affordances (camera + gallery).
class _PhotoAnswerRow extends StatelessWidget {
  const _PhotoAnswerRow({required this.onPhotoPick, required this.enabled});

  final Future<void> Function(ImageSource) onPhotoPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('फ़ोटो लें'),
            onPressed: enabled ? () => onPhotoPick(ImageSource.camera) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('गैलरी से'),
            onPressed: enabled ? () => onPhotoPick(ImageSource.gallery) : null,
          ),
        ),
      ],
    );
  }
}

/// The §28 feedback panel: verdict chip, specific feedback, rubric
/// points, extracted text (photos — §26 honest transcription), and
/// §30-safe confidence band wording.
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.feedback,
    required this.verdict,
    required this.lastEvaluation,
  });

  final String feedback;
  final String? verdict;
  final EvaluationResult? lastEvaluation;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      'correct' => ('सही', AppColors.success),
      'partiallyCorrect' => ('आधा सही', AppColors.warning),
      'incorrect' => ('ग़लत', AppColors.error),
      _ => ('अनिश्चित', AppColors.info),
    };
    final eval = lastEvaluation;
    final bandLabel = switch (eval?.confidenceBand) {
      ConfidenceBand.high => 'पक्की',
      ConfidenceBand.medium => 'ठीक-ठाक',
      ConfidenceBand.low => 'कम',
      null => '',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Text(label, style: AppTextStyles.labelSmall(color: color)),
              ),
              const Spacer(),
              if (eval != null && bandLabel.isNotEmpty)
                Text(
                  'पकड़: $bandLabel',
                  style: AppTextStyles.labelSmall(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(feedback, style: AppTextStyles.bodyMedium()),
          if (eval != null && eval.rubricPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ज़रूरी बिंदु:', style: AppTextStyles.labelMedium()),
            const SizedBox(height: 4),
            for (final p in eval.rubricPoints) ...[
              Row(
                children: [
                  Icon(
                    p.met ? Icons.check : Icons.close,
                    size: 14,
                    color: p.met ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child:
                        Text(p.requirement, style: AppTextStyles.bodySmall()),
                  ),
                ],
              ),
            ],
          ],
          if (eval != null && eval.extractedText != null) ...[
            const SizedBox(height: 8),
            Text('फ़ोटो से पढ़ा: «${eval.extractedText}»',
                style: AppTextStyles.bodySmall(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight)),
          ],
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.onRestart,
    required this.trackId,
  });

  final String summary;
  final Future<void> Function() onRestart;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(message: summary, state: VanState.achievement),
        const SizedBox(height: 8),
        // M10: the honest XP/streak line for this finished session.
        ExamSessionXpStrip(trackId: trackId),
        const SizedBox(height: 12),
        _Card(
          child: PrimaryButton(
            label: 'और अभ्यास करें',
            icon: const Icon(Icons.refresh),
            onPressed: onRestart,
          ),
        ),
      ],
    );
  }
}

class _PracticeUnavailable extends StatelessWidget {
  const _PracticeUnavailable({
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
