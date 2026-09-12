/// Exam Mode 2.0 — Scope Selection Screen (M2)
///
/// Step 2 of the setup flow: the official syllabus display with SELECT ALL /
/// CLEAR ALL / section selection / individual selection (master plan §5),
/// plus the pending-literature and internal-only-chapter states from the
/// canonical data (never fabricated).
///
/// Every toggle is write-through persisted (§6: the scope stays editable —
/// this same screen is reached again via "Continue" or "Edit selection").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';

class ExamScopeSelectionScreen extends ConsumerWidget {
  const ExamScopeSelectionScreen({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeAsync = ref.watch(examScopeProvider(trackId));

    return VaaniXScaffold(
      title: 'Select Your Scope',
      body: scopeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading syllabus'),
        ),
        error: (e, _) => _ScopeUnavailable(trackId: trackId),
        data: (state) => _ScopeBody(trackId: trackId, state: state),
      ),
    );
  }
}

class _ScopeBody extends ConsumerWidget {
  const _ScopeBody({required this.trackId, required this.state});

  final String trackId;
  final ExamScopeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = state.view!;
    final controller = ref.read(examScopeProvider(trackId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            children: [
              VanSpeechStrip(
                message: state.selection.isEmpty
                    ? 'यह आधिकारिक CBSE पाठ्यक्रम है। जो आप तैयार करना '
                        'चाहते हैं, बस वही चुनें — बाद में कभी भी बदल सकते हैं।'
                    : 'चयन बदलते ही स्वतः सहेज दिया जाता है। '
                        '${state.selectedCount} इकाइयाँ चयनित।',
                state: state.selection.isEmpty
                    ? VanState.idle
                    : VanState.achievement,
              ),
              const SizedBox(height: 8),

              // SELECT ALL / CLEAR ALL (§5 required controls).
              Semantics(
                container: true,
                label:
                    'Selection actions. ${state.selectedCount} of ${state.totalSelectable} units selected.',
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton.secondary(
                        label: 'Select All',
                        onPressed: state.selectedCount == state.totalSelectable
                            ? null
                            : controller.selectAll,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton.secondary(
                        label: 'Clear All',
                        onPressed: state.selection.isEmpty
                            ? null
                            : controller.clearAll,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              for (final section in view.sections) ...[
                _ScopeSectionCard(
                  section: section,
                  state: state,
                  onToggleSection: () =>
                      controller.toggleSection(section.id),
                  onToggleUnit: (unitId) =>
                      controller.toggleUnit(unitId),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),

        // Sticky summary bar (§49 preview before summary screen).
        _SummaryBar(state: state, isDark: isDark, trackId: trackId),
      ],
    );
  }
}

class _ScopeSectionCard extends StatelessWidget {
  const _ScopeSectionCard({
    required this.section,
    required this.state,
    required this.onToggleSection,
    required this.onToggleUnit,
  });

  final ScopeSection section;
  final ExamScopeState state;
  final VoidCallback onToggleSection;
  final void Function(String unitId) onToggleUnit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectable = section.selectableUnits;
    final selectedCount =
        selectable.where((u) => state.selection.isSelected(u.id)).length;
    final allSelected = selectable.isNotEmpty && selectedCount == selectable.length;
    final someSelected = selectedCount > 0 && !allSelected;

    final marksLabel = section.marks == section.marks.roundToDouble()
        ? section.marks.toInt().toString()
        : section.marks.toString();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header: tristate checkbox + title + marks + count.
          Semantics(
            button: true,
            enabled: selectable.isNotEmpty,
            toggled: allSelected,
            label:
                '${section.title}, $marksLabel marks, $selectedCount of ${selectable.length} selected',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: selectable.isNotEmpty ? onToggleSection : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectable.isEmpty
                            ? false
                            : (someSelected ? null : allSelected),
                        tristate: true,
                        onChanged: selectable.isNotEmpty
                            ? (_) => onToggleSection()
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: AppTextStyles.titleMedium(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$marksLabel अंक',
                          style: AppTextStyles.labelMedium(
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pending literature: honest awaiting state (never fake chapters).
          if (section.isPending)
            _PendingBanner(note: section.pendingNote!),

          for (final unit in section.units) ...[
            _ScopeUnitTile(
              unit: unit,
              selected: state.selection.isSelected(unit.id),
              onToggle: unit.selectable ? () => onToggleUnit(unit.id) : null,
            ),
          ],
          if (section.units.isEmpty && !section.isPending)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'इस खंड के लिए कोई चयन योग्य इकाई नहीं।',
                style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ScopeUnitTile extends StatelessWidget {
  const _ScopeUnitTile({
    required this.unit,
    required this.selected,
    this.onToggle,
  });

  final ScopeUnit unit;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    final statusSuffix = unit.selectable
        ? (selected ? ', selected' : ', not selected')
        : ', not available';

    return Semantics(
      button: unit.selectable,
      toggled: selected,
      enabled: unit.selectable,
      onTap: onToggle,
      label: '${unit.title}'
          '${unit.subtitle != null ? ', ${unit.subtitle}' : ''}'
          '$statusSuffix',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.title,
                          style: AppTextStyles.sanskritBody(
                            color: unit.selectable ? null : subtext,
                          ),
                        ),
                        if (unit.subtitle != null &&
                            unit.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            unit.subtitle!,
                            style:
                                AppTextStyles.bodySmall(color: subtext),
                          ),
                        ],
                        if (unit.note != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            unit.note!,
                            style: AppTextStyles.labelSmall(
                                color: AppColors.warning),
                          ),
                        ],
                        if (unit.info != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            unit.info!,
                            style: AppTextStyles.bodySmall(
                                color: subtext),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (unit.marks != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_marksLabel(unit.marks!)}',
                    style: AppTextStyles.labelMedium(color: subtext),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _marksLabel(double m) => m == m.roundToDouble()
      ? '${m.toInt()} अंक'
      : '$m अंक';
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top,
              size: 18, color: AppColors.warning,
              semanticLabel: 'pending announcement'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
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

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.state,
    required this.isDark,
    required this.trackId,
  });

  final ExamScopeState state;
  final bool isDark;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final view = state.view!;
    final covered = state.coveredMarks;
    final coveredLabel = covered == covered.roundToDouble()
        ? covered.toInt().toString()
        : covered.toStringAsFixed(1);
    final engaged = view.engagedSections(state.selection);

    // Marks total only when it is exact (all selectable units carry
    // item-level marks). Chapter-based tracks show section engagement
    // instead — never a misleading partial-marks figure.
    final secondary = view.marksCoverageExact
        ? '$coveredLabel / ${state.boardMarks.toInt()} अंक दायरा'
        : '$engaged / ${view.sections.length} खंड सक्रिय';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label:
                    '${state.selectedCount} of ${state.totalSelectable} units selected, $secondary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.selectedCount} / ${state.totalSelectable} इकाइयाँ',
                      style: AppTextStyles.titleSmall(),
                    ),
                    Text(
                      secondary,
                      style: AppTextStyles.bodySmall(
                        color: isDark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            PrimaryButton(
              label: 'Review Summary',
              onPressed: state.selection.isEmpty
                  ? null
                  : () => GoRouter.of(context).pushNamed(
                        RouteNames.examScopeSummaryName,
                        pathParameters: {'trackId': trackId},
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeUnavailable extends StatelessWidget {
  const _ScopeUnavailable({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 48),
            const SizedBox(height: 16),
            Text('Syllabus unavailable for this course',
                style: AppTextStyles.titleMedium()),
            const SizedBox(height: 8),
            Text(
              'The official data for $trackId could not be loaded. '
              'Go back and pick the course again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.subtextDark
                    : AppColors.subtextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
