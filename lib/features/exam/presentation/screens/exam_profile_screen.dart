/// Exam Mode 2.0 — Exam Profile Screen (M3, master plan §8–§9)
///
/// Step 4 of the setup flow, reached from the confirmed scope summary:
/// the student sets WHEN they want to be exam-ready (date, duration, or
/// both — date is the primary anchor), how much time they can
/// realistically study, and an OPTIONAL actual exam date. Everything is
/// editable later (re-entering this screen re-loads the draft).
///
/// Honesty rules:
///  * §8: the primary question is "by when do you want to be
///    exam-ready?" — NOT "when is your exam". The actual exam date is an
///    optional extra, visually secondary.
///  * §9: available time is what the STUDENT says they can give; the
///    screen never suggests "you should study more". 5 min/day is fine.
///  * §30: no percentages anywhere — the budget renders as one plain
///    sentence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_profile_providers.dart';
import 'package:vaanix_app/shared/widgets/error_state_widget.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

const List<int> _dailyMinuteChoices = [10, 15, 20, 30, 45, 60, 90];
const List<int> _daysPerWeekChoices = [2, 3, 4, 5, 6, 7];
const List<int> _durationWeekChoices = [2, 4, 6, 8, 12, 16, 24];

class ExamProfileScreen extends ConsumerStatefulWidget {
  const ExamProfileScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamProfileScreen> createState() => _ExamProfileScreenState();
}

class _ExamProfileScreenState extends ConsumerState<ExamProfileScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(examProfileProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Exam Profile',
      body: profileAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading your profile…'),
        ),
        error: (e, _) => ErrorStateWidget(
          message: 'Your profile couldn\'t be loaded.\nGo back and try again.',
          onRetry: () => ref.invalidate(examProfileProvider(widget.trackId)),
        ),
        data: (profile) => _ProfileForm(
          profile: profile,
          error: _error,
          onPickDate: _pickReadinessDate,
          onPickExamDate: _pickActualExamDate,
          onSave: _onSave,
        ),
      ),
    );
  }

  Future<void> _pickReadinessDate() async {
    final picked = await _pickDate(
      initial: ref
              .read(examProfileProvider(widget.trackId))
              .value
              ?.readinessTargetDate ??
          DateTime.now().add(const Duration(days: 56)),
    );
    if (picked != null) {
      await ref
          .read(examProfileProvider(widget.trackId).notifier)
          .setReadinessTargetDate(picked);
    }
  }

  Future<void> _pickActualExamDate() async {
    final picked = await _pickDate(
      initial:
          ref.read(examProfileProvider(widget.trackId)).value?.actualExamDate ??
              DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      await ref
          .read(examProfileProvider(widget.trackId).notifier)
          .setActualExamDate(picked);
    }
  }

  Future<DateTime?> _pickDate({required DateTime initial}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate:
          initial.isAfter(now) ? initial : now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
  }

  Future<void> _onSave() async {
    setState(() => _error = null);
    final errors =
        await ref.read(examProfileProvider(widget.trackId).notifier).save();
    if (!mounted) return;
    if (errors.isNotEmpty) {
      setState(() => _error = errors.first);
      return;
    }
    // Next step in the flow (M4): the adaptive diagnostic.
    GoRouter.of(context).pushNamedUnique(
      RouteNames.examDiagnosticName,
      pathParameters: {'trackId': widget.trackId},
    );
  }
}

class _ProfileForm extends ConsumerWidget {
  const _ProfileForm({
    required this.profile,
    required this.error,
    required this.onPickDate,
    required this.onPickExamDate,
    required this.onSave,
  });

  final ExamProfile profile;
  final String? error;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onPickExamDate;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(examProfileProvider(profile.trackId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: profile.hasReadinessSource
              ? 'बढ़िया। ${profile.budgetSentence()} — योजना इसी समय में बनेगी।'
              : 'आप कब तक तैयार होना चाहते हैं? तारीख़ चुनें या हफ़्ते बताएँ।',
          state:
              profile.hasReadinessSource ? VanState.achievement : VanState.idle,
        ),
        const SizedBox(height: 8),

        // §8 READINESS TARGET — date (A) and/or duration (B).
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('कब तक तैयारी?', style: AppTextStyles.titleMedium()),
              const SizedBox(height: 4),
              Text(
                'By when do you want to be exam-ready? Date चुनें, हफ़्ते बताएँ, '
                'या दोनों — date primary रहेगी।',
                style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: profile.readinessTargetDate == null
                    ? 'Pick readiness target date'
                    : 'Readiness target date '
                        '${profile.readinessTargetDate!.toLocal().toString().split(' ').first}',
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: profile.readinessTargetDate != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined,
                            color: AppColors.primary,
                            semanticLabel: 'readiness target'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            profile.readinessTargetDate == null
                                ? 'तारीख़ चुनें (target date)'
                                : 'तैयार होना है: '
                                    '${_fmtDate(profile.readinessTargetDate!)}'
                                    ' तक',
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ),
                        if (profile.readinessTargetDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                controller.setReadinessTargetDate(null),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('या हफ़्तों में:',
                  style: AppTextStyles.labelMedium(
                      color: isDark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in _durationWeekChoices) ...[
                    _ChoiceChip(
                      label: '$w हफ़्ते',
                      selected: profile.readinessDurationWeeks == w,
                      onTap: () => controller.setReadinessDurationWeeks(
                          profile.readinessDurationWeeks == w ? null : w),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // §9 AVAILABLE STUDY TIME.
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('प्रतिदिन कितना समय?', style: AppTextStyles.titleMedium()),
              const SizedBox(height: 4),
              Text(
                'जो आप सच में दे सकते हैं, वही चुनें — योजना आपके समय के अंदर '
                'बनेगी, उससे बड़ी नहीं।',
                style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _dailyMinuteChoices) ...[
                    _ChoiceChip(
                      label: '$m मिनट',
                      selected: profile.dailyStudyMinutes == m,
                      onTap: () => controller.setDailyStudyMinutes(m),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text('हफ़्ते में कितने दिन?', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _daysPerWeekChoices) ...[
                    _ChoiceChip(
                      label: '$d दिन',
                      selected: profile.studyDaysPerWeek == d,
                      onTap: () => controller.setStudyDaysPerWeek(d),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // §8 optional ACTUAL EXAM DATE — secondary, never required.
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('असली परीक्षा की तारीख़ (वैकल्पिक)',
                  style: AppTextStyles.titleMedium()),
              const SizedBox(height: 4),
              Text(
                'अगर पता है तो बता दें — यह योजना की एकमात्र आधार नहीं बनेगी।',
                style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: profile.actualExamDate == null
                    ? 'Pick actual exam date, optional'
                    : 'Actual exam date '
                        '${profile.actualExamDate!.toLocal().toString().split(' ').first}',
                child: InkWell(
                  onTap: onPickExamDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: profile.actualExamDate != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            color: AppColors.primary,
                            semanticLabel: 'actual exam date'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            profile.actualExamDate == null
                                ? 'तारीख़ चुनें (optional)'
                                : 'परीक्षा: ${_fmtDate(profile.actualExamDate!)}',
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ),
                        if (profile.actualExamDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => controller.setActualExamDate(null),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('सेशन गति:', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final pace in StudyPace.values) ...[
                    _ChoiceChip(
                      label: switch (pace) {
                        StudyPace.balanced => 'संतुलित',
                        StudyPace.intensive => 'तेज़',
                        StudyPace.light => 'हल्की',
                      },
                      selected: profile.pace == pace,
                      onTap: () => controller.setPace(pace),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(error!,
                style: AppTextStyles.bodySmall(color: AppColors.error)),
          ),
          const SizedBox(height: 12),
        ],

        PrimaryButton(
          label: 'Save Profile',
          icon: const Icon(Icons.check),
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? AppColors.primary
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight)),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium(
                color: selected ? AppColors.primary : null),
          ),
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

String _fmtDate(DateTime d) {
  const months = [
    'जन',
    'फ़र',
    'मार्च',
    'अप्रै',
    'मई',
    'जून',
    'जुल',
    'अग',
    'सित',
    'अक्टू',
    'नव',
    'दिस'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
