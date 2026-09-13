/// Exam Mode 2.0 — Track Selection Screen (M2)
///
/// Step 1 of the exam-mode setup flow: Board → Class → Subject → Course
/// (master plan §5, definition-of-done steps 3–5). The catalog comes from
/// Layer-1 official data ([syllabusIndexProvider]) — nothing is invented.
///
/// V1 scope honesty: CBSE is the only board with data (selected by
/// default); ICSE renders as an explicit "coming soon" card rather than a
/// fake choice. A previously saved track surfaces as a "continue editing"
/// card, which is the primary "edit selections later" entry (§6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/data/exam_scope_repository.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/shared/widgets/error_state_widget.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';

class ExamTrackSelectionScreen extends ConsumerStatefulWidget {
  const ExamTrackSelectionScreen({super.key});

  @override
  ConsumerState<ExamTrackSelectionScreen> createState() =>
      _ExamTrackSelectionScreenState();
}

class _ExamTrackSelectionScreenState
    extends ConsumerState<ExamTrackSelectionScreen> {
  int? _class;
  String? _subjectId;
  String? _trackId;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(syllabusIndexProvider);

    return VaaniXScaffold(
      title: 'Board Exam Prep',
      body: index.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading exam catalog…'),
        ),
        error: (e, _) => const _CatalogError(),
        data: (catalog) => _buildCatalog(context, catalog),
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, SyllabusIndex catalog) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        const VanSpeechStrip(
          message:
              'Board exam prep starts with your official syllabus. '
              'Pick your board, class and course.',
          state: VanState.idle,
        ),
        _ContinueCard(
          storeAsync: ref.watch(examScopeStoreProvider),
          catalog: catalog,
          onOpen: _openScope,
        ),
        const SizedBox(height: 20),

        _stepLabel(context, '1 · Board'),
        _ChoiceCard(
          title: 'CBSE',
          subtitle: 'Central Board of Secondary Education',
          selected: true,
          onTap: () {}, // CBSE is V1's only board — already selected.
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'ICSE',
          subtitle: 'Coming soon — not part of the V1 testing scope',
          selected: false,
          enabled: false,
          onTap: null,
        ),
        const SizedBox(height: 20),

        _stepLabel(context, '2 · Class'),
        for (final classEntry in catalog.classes) ...[
          _ChoiceCard(
            title: 'Class ${classEntry.klass}',
            subtitle: classEntry.klass == 9
                ? 'नवीं / दशमी की तैयारी'
                : 'Board exam year',
            selected: _class == classEntry.klass,
            onTap: () => setState(() {
              _class = classEntry.klass;
              _subjectId = null;
              _trackId = null;
            }),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),

        if (_class != null) ...[
          _stepLabel(context, '3 · Subject'),
          for (final subject in _subjectsOf(catalog)) ...[
            _ChoiceCard(
              title: subject.name,
              subtitle: '${subject.courses.length} course'
                  '${subject.courses.length > 1 ? 's' : ''}',
              selected: _subjectId == subject.id,
              onTap: () => setState(() {
                _subjectId = subject.id;
                _trackId = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),

          if (_subjectId != null) ...[
            _stepLabel(context, '4 · Course'),
            for (final course in _coursesOf(catalog)) ...[
              _ChoiceCard(
                title: course.name,
                subtitle: _courseSubtitle(course),
                selected: _trackId == course.id,
                onTap: () => setState(() => _trackId = course.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'View official syllabus',
              icon: const Icon(Icons.arrow_forward),
              onPressed:
                  _trackId == null ? null : () => _openScope(_trackId!),
            ),
          ],
        ],
      ],
    );
  }

  String _courseSubtitle(SyllabusCourseEntry course) {
    final bits = <String>[
      if (course.subjectCode != null) 'Subject code ${course.subjectCode}',
      if (course.literaturePending)
        'अध्याय सूची आधिकारिक रूप से बाकी'
      else
        'पूरा पाठ्यक्रम उपलब्ध',
    ];
    return bits.join(' · ');
  }

  List<SyllabusSubjectEntry> _subjectsOf(SyllabusIndex catalog) {
    final entry = catalog.classes.firstWhere(
      (c) => c.klass == _class,
      orElse: () => catalog.classes.first,
    );
    return entry.subjects;
  }

  List<SyllabusCourseEntry> _coursesOf(SyllabusIndex catalog) {
    return _subjectsOf(catalog)
        .firstWhere((s) => s.id == _subjectId)
        .courses;
  }

  void _openScope(String trackId) {
    final router = GoRouter.maybeOf(context);
    // No router (e.g. widget tests without go_router) — nothing to do.
    router?.pushNamed(
      RouteNames.examScopeName,
      pathParameters: {'trackId': trackId},
    );
  }

  Widget _stepLabel(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTextStyles.labelLarge(
            color: isDark ? AppColors.subtextDark : AppColors.subtextLight,
          ),
        ),
      ),
    );
  }
}

/// "Continue editing" card shown when a saved active track exists.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.storeAsync,
    required this.catalog,
    required this.onOpen,
  });

  final AsyncValue<ExamScopeStore> storeAsync;
  final SyllabusIndex catalog;
  final void Function(String trackId) onOpen;

  @override
  Widget build(BuildContext context) {
    return storeAsync.maybeWhen(
      data: (store) {
        final trackId = store.activeTrackId;
        if (trackId == null) return const SizedBox.shrink();
        final course = catalog.courseById(trackId);
        if (course == null) return const SizedBox.shrink();
        final selection = store.scopes[trackId];
        final count = selection?.selectedUnitIds.length ?? 0;

        return _ChoiceCard(
          title: 'Continue: ${course.name}',
          subtitle: count > 0
              ? 'सहेजा गया दायरा · $count इकाइयाँ चयनित — बदलें'
              : 'दायरा खाली है — अब चयन करें',
          selected: true,
          onTap: () => onOpen(trackId),
          accent: true,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Shared choice-card used at every step (Semantics-first, §52).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.enabled = true,
    this.accent = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final fillColor = selected
        ? AppColors.primary.withValues(alpha: 0.08)
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);

    final spoken = '$title, $subtitle'
        '${selected ? ', selected' : ''}'
        '${enabled ? '' : ', unavailable'}';

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      label: spoken,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent && !selected
                  ? AppColors.vanYellow.withValues(alpha: 0.15)
                  : fillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent && !selected
                    ? AppColors.vanYellow
                    : borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium()),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall(
                          color: isDark
                              ? AppColors.subtextDark
                              : AppColors.subtextLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 12),
                  Icon(
                    selected ? Icons.check_circle : Icons.chevron_right,
                    color: selected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight),
                    semanticLabel: selected ? 'selected' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state with retry (catalog files are bundled; this guards against
/// malformed data — a calm message, never a crash, §51).
class _CatalogError extends StatelessWidget {
  const _CatalogError();

  @override
  Widget build(BuildContext context) {
    return const ErrorStateWidget(
      title: 'Syllabus catalog unavailable',
      message:
          'The official syllabus data couldn\'t be read.\n'
          'Please go back and try again.',
    );
  }
}
