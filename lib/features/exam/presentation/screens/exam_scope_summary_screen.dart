/// Exam Mode 2.0 — Scope Summary Screen (M2)
///
/// Step 3 of the setup flow (master plan §49): before anything further
/// happens, the student reviews Board, Class, Subject, Course and their
/// selected syllabus, and can go back and edit. Confirming persists the
/// scope as the ACTIVE track.
///
/// Honesty contract (§43, §12 "no fake AI"): readiness target and study
/// time arrive in M3 and the personalized plan in M5 — they render as
/// clearly-labelled upcoming steps, never as fake features.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';

class ExamScopeSummaryScreen extends ConsumerStatefulWidget {
  const ExamScopeSummaryScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamScopeSummaryScreen> createState() =>
      _ExamScopeSummaryScreenState();
}

class _ExamScopeSummaryScreenState
    extends ConsumerState<ExamScopeSummaryScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final scopeAsync = ref.watch(examScopeProvider(widget.trackId));
    final syllabusAsync = ref.watch(courseSyllabusProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Selection Summary',
      body: scopeAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading your selection…'),
        ),
        error: (e, _) => _SummaryUnavailable(trackId: widget.trackId),
        data: (state) => syllabusAsync.maybeWhen(
          data: (syllabus) => syllabus == null
              ? _SummaryUnavailable(trackId: widget.trackId)
              : _SummaryBody(
                  state: state,
                  syllabus: syllabus,
                  confirmed: _confirmed,
                  onConfirm: _onConfirm,
                  onEdit: _onEdit,
                ),
          orElse: () => const Center(
            child: VaaniXLoadingIndicator(message: 'Loading course…'),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    await ref
        .read(examScopeProvider(widget.trackId).notifier)
        .confirmSelection();
    if (mounted) setState(() => _confirmed = true);
  }

  void _onEdit() {
    GoRouter.of(context).pushNamedUnique(
      RouteNames.examScopeName,
      pathParameters: {'trackId': widget.trackId},
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.state,
    required this.syllabus,
    required this.confirmed,
    required this.onConfirm,
    required this.onEdit,
  });

  final ExamScopeState state;
  final CourseSyllabus syllabus;
  final bool confirmed;
  final Future<void> Function() onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final covered = state.coveredMarks;
    final coveredLabel = covered == covered.roundToDouble()
        ? covered.toInt().toString()
        : covered.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VanSpeechStrip(
            message: confirmed
                ? 'दायरा सहेज लिया गया। आप इसे कभी भी बदल सकते हैं।'
                : 'एक बार देख लें — यही आपकी तैयारी की सीमा होगी।'
                    ' चाहें तो अभी बदल लें।',
            state: confirmed ? VanState.achievement : VanState.idle,
          ),
          const SizedBox(height: 8),

          _IdentityCard(syllabus: syllabus),
          const SizedBox(height: 12),

          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('चयनित पाठ्यक्रम दायरा',
                    style: AppTextStyles.titleMedium()),
                const SizedBox(height: 12),
                for (final section in state.view!.sections) ...[
                  _ScopeRow(
                    title: section.title,
                    selectedCount: section.selectableUnits
                        .where((u) => state.selection.isSelected(u.id))
                        .length,
                    totalCount: section.selectableUnits.length,
                    marks: section.marks,
                    isDark: isDark,
                  ),
                ],
                const Divider(height: 24),
                Semantics(
                  label:
                      'Total: ${state.selectedCount} units, ${state.view!.engagedSections(state.selection)} of ${state.view!.sections.length} sections engaged'
                      '${state.view!.marksCoverageExact ? ", $coveredLabel of ${state.boardMarks.toInt()} marks" : ""}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('कुल', style: AppTextStyles.titleSmall()),
                      Text(
                        state.view!.marksCoverageExact
                            ? '${state.selectedCount} इकाइयाँ · '
                                '$coveredLabel / ${state.boardMarks.toInt()} अंक'
                            : '${state.selectedCount} इकाइयाँ · '
                                '${state.view!.engagedSections(state.selection)} / ${state.view!.sections.length} खंड',
                        style:
                            AppTextStyles.titleSmall(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                if (state.view!.hasPendingSections) ...[
                  const SizedBox(height: 12),
                  _PendingNote(view: state.view!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Upcoming steps — honest placeholders, never fake features.
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('आगे के कदम', style: AppTextStyles.titleMedium()),
                const SizedBox(height: 8),
                _UpcomingRow(
                    label: 'Exam profile — readiness और समय (अगला कदम)'),
                _UpcomingRow(label: 'Adaptive diagnostic + personalized plan'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!confirmed) ...[
            PrimaryButton(
              label: 'Confirm Scope',
              icon: const Icon(Icons.check),
              onPressed: onConfirm,
            ),
            const SizedBox(height: 12),
            PrimaryButton.secondary(
              label: 'Edit Selection',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          ] else ...[
            _ConfirmedCard(
              trackId: state.view!.trackId,
              onDone: () => GoRouter.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.syllabus});

  final CourseSyllabus syllabus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('आपकी परीक्षा', style: AppTextStyles.titleMedium()),
          const SizedBox(height: 8),
          _IdentityRow(label: 'Board', value: 'CBSE', isDark: isDark),
          _IdentityRow(
              label: 'Class', value: 'Class ${syllabus.klass}', isDark: isDark),
          _IdentityRow(
              label: 'Subject', value: syllabus.subjectName, isDark: isDark),
          _IdentityRow(
              label: 'Course',
              value: syllabus.courseName +
                  (syllabus.subjectCode == null
                      ? ''
                      : ' (${syllabus.subjectCode})'),
              isDark: isDark),
          _IdentityRow(
              label: 'Syllabus',
              value: 'Official CBSE ${syllabus.syllabusVersion}',
              isDark: isDark),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTextStyles.bodySmall(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium()),
          ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.title,
    required this.selectedCount,
    required this.totalCount,
    required this.marks,
    required this.isDark,
  });

  final String title;
  final int selectedCount;
  final int totalCount;
  final double marks;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final marksLabel = marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toString();
    return Semantics(
      label: '$title: $selectedCount of $totalCount units selected',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.bodyMedium())),
            Text(
              totalCount == 0
                  ? '—'
                  : '$selectedCount / $totalCount चयनित · $marksLabel अंक',
              style: AppTextStyles.bodySmall(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.schedule,
              size: 18,
              color: isDark ? AppColors.subtextDark : AppColors.subtextLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight),
            ),
          ),
          Text(
            'अगला चरण',
            style: AppTextStyles.labelSmall(
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight),
          ),
        ],
      ),
    );
  }
}

class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.view});

  final ExamScopeView view;

  @override
  Widget build(BuildContext context) {
    final pending = view.sections.where((s) => s.isPending).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'साहित्य खंड की आधिकारिक अध्याय सूची जारी होने बाकी है '
              '(${pending.map((s) => s.title).join(', ')})। जारी होते ही '
              'आपके दायरे में जुड़ जाएगी।',
              style: AppTextStyles.bodySmall(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.onSurfaceDark
                      : AppColors.onSurfaceLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  const _ConfirmedCard({required this.trackId, required this.onDone});

  final String trackId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: [
          Icon(Icons.check_circle,
              size: 40, color: AppColors.success, semanticLabel: 'confirmed'),
          const SizedBox(height: 12),
          Text('दायरा सहेज दिया गया', style: AppTextStyles.titleMedium()),
          const SizedBox(height: 8),
          Text(
            'अगला कदम: आपकी readiness और समय सेट करें — फिर diagnostic और '
            'निजीकृत योजना बनेगी।',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Exam Profile सेट करें',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => GoRouter.of(context).pushNamedUnique(
              RouteNames.examProfileName,
              pathParameters: {'trackId': trackId},
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton.secondary(
            label: 'Done',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

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

class _SummaryUnavailable extends StatelessWidget {
  const _SummaryUnavailable({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Selection data unavailable for $trackId. '
          'Go back and try again.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.subtextDark
                : AppColors.subtextLight,
          ),
        ),
      ),
    );
  }
}
