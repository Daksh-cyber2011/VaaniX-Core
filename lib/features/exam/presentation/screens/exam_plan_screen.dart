/// Exam Mode 2.0 — Plan Screen (M5, §13)
///
/// The personalized plan, explainable and honest: focus summary,
/// per-day task lists with minutes, the plan's rationale, and a
/// source label that NEVER fakes provenance (§63: AI plan / cached
/// plan / offline plan). The student can rebuild (replan) at any
/// time — scope edits and readiness changes make the old plan stale
/// (§33).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_plan_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamPlanScreen extends ConsumerWidget {
  const ExamPlanScreen({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(examPlanProvider(trackId));

    return VaaniXScaffold(
      title: 'Your Plan',
      body: planAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading plan'),
        ),
        error: (e, _) => Center(
          child: Text('Plan unavailable. Try rebuilding.',
              style: AppTextStyles.bodyMedium(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.subtextDark
                      : AppColors.subtextLight)),
        ),
        data: (state) => _PlanBody(state: state, trackId: trackId),
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.state, required this.trackId});

  final ExamPlanState state;
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.building) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(semanticsLabel: 'Building plan'),
            SizedBox(height: 16),
            Text('योजना बन रही है…'),
          ],
        ),
      );
    }

    final plan = state.plan;
    final scope = ref.watch(examScopeProvider(trackId)).valueOrNull;
    final selectedUnits = <ScopeUnit>[
      for (final section in scope?.view?.sections ?? const [])
        for (final unit in section.selectableUnits)
          if (scope!.selection.isSelected(unit.id)) unit,
    ];
    if (plan == null || plan.days.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          VanSpeechStrip(
            message:
                'दायरा और profile तैयार है — अब आपकी निजी योजना बनाते हैं!',
            state: VanState.happy,
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                PrimaryButton(
                  label: 'योजना बनाएँ',
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: () =>
                      ref.read(examPlanProvider(trackId).notifier).buildPlan(),
                ),
              ],
            ),
          ),
          if (state.notice != null) ...[
            const SizedBox(height: 12),
            _NoticeCard(text: state.notice!),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: plan.focusSummary,
          state: VanState.achievement,
        ),
        const SizedBox(height: 12),
        // M8: the weak-area hub (report + revision + recovery) is one
        // tap away from the plan — not buried.
        _Card(
          child: Row(
            children: [
              const Icon(Icons.healing, size: 20, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text('कमज़ोर क्षेत्र और दोहराव',
                    style: AppTextStyles.titleSmall()),
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow, color: AppColors.primary),
                tooltip: 'Weak areas',
                onPressed: () => GoRouter.of(context).pushNamed(
                  RouteNames.examWeakAreaName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SourceBadge(source: plan.source),
        const SizedBox(height: 8),
        PrimaryButton.secondary(
          label: 'Choose a different topic',
          icon: const Icon(Icons.tune),
          onPressed: selectedUnits.isEmpty
              ? null
              : () => _showTopicPicker(
                    context: context,
                    ref: ref,
                    trackId: trackId,
                    units: selectedUnits,
                  ),
        ),
        if (state.notice != null) ...[
          const SizedBox(height: 8),
          _NoticeCard(text: state.notice!),
        ],
        const SizedBox(height: 12),
        for (final day in plan.days) ...[
          _DayCard(day: day, trackId: trackId),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('योजना क्यों ऐसी है?', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 8),
              Text(plan.rationale, style: AppTextStyles.bodyMedium()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton.secondary(
          label: 'Replan',
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              ref.read(examPlanProvider(trackId).notifier).buildPlan(),
        ),
      ],
    );
  }
}

Future<void> _showTopicPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String trackId,
  required List<ScopeUnit> units,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('What would you like to study instead?'),
            subtitle: Text('This stays within your selected official scope.'),
          ),
          for (final unit in units)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(unit.title),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(examPlanProvider(trackId).notifier)
                    .chooseStudentTopic(unit.id);
              },
            ),
        ],
      ),
    ),
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.trackId});

  final ExamDayPlan day;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = day.dayIndex == 0
        ? 'आज'
        : day.dayIndex == 1
            ? 'कल'
            : 'दिन ${day.dayIndex + 1}';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.titleMedium()),
              const Spacer(),
              Text(
                day.tasks.isEmpty ? 'आराम का दिन' : '${day.totalMinutes} मिनट',
                style: AppTextStyles.labelMedium(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final task in day.tasks) ...[
            _TaskRow(
              task: task,
              isToday: day.dayIndex == 0,
              trackId: trackId,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.isToday,
    required this.trackId,
  });

  final ExamPlanTask task;
  final bool isToday;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (task.type) {
      ExamTaskType.learn => (Icons.menu_book, AppColors.primary),
      ExamTaskType.practice => (Icons.edit_note, AppColors.info),
      ExamTaskType.review => (Icons.history, AppColors.success),
      ExamTaskType.pyq => (Icons.library_books, AppColors.vanOrange),
      ExamTaskType.weakArea => (Icons.priority_high, AppColors.warning),
      ExamTaskType.mock => (Icons.timer, AppColors.streak),
    };
    // M8/M9 routing: today's practice → the M6 loop; weakArea /
    // review → the M8 weak-area hub; pyq → the M9 PYQ track; mock →
    // the M9 mock ladder.
    final routeName = switch (task.type) {
      ExamTaskType.practice => RouteNames.examPracticeName,
      ExamTaskType.weakArea => RouteNames.examWeakAreaName,
      ExamTaskType.review => RouteNames.examWeakAreaName,
      ExamTaskType.pyq => RouteNames.examPyqName,
      ExamTaskType.mock => RouteNames.examMockName,
      _ => null,
    };
    final isActionable = isToday && routeName != null;
    return Semantics(
      label: '${task.title}, ${task.minutes} मिनट',
      child: InkWell(
        // Today's actionable tasks jump straight into their session
        // (practice / weak-area / revision / PYQ / mock).
        onTap: isActionable
            ? () => GoRouter.of(context).pushNamed(
                  routeName!,
                  pathParameters: {'trackId': trackId},
                )
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color, semanticLabel: task.type.name),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title, style: AppTextStyles.bodyMedium()),
              ),
              Text('${task.minutes}m',
                  style: AppTextStyles.labelSmall(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
              if (isActionable) ...[
                const SizedBox(width: 6),
                Icon(Icons.play_arrow, size: 18, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final ExamPlanSource source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      ExamPlanSource.ai => ('AI योजना', AppColors.primary),
      ExamPlanSource.cached => ('सहेजी गई योजना', AppColors.info),
      ExamPlanSource.deterministic => ('ऑफ़लाइन योजना', AppColors.success),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: AppTextStyles.labelSmall(color: color)),
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
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall()),
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
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: child,
    );
  }
}
