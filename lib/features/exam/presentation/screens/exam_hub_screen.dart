/// Exam Mode 2.0 — Exam Hub Screen (M10: HOME + VAN + GAMIFICATION)
///
/// The cohesive exam-mode home. Everything the master plan lists for
/// M10 lives here, each line HONEST (derived from real persisted
/// state, never fabricated):
///
///   * TODAY'S PLAN — the current day of the rolling M5 plan, with
///     real check-marks from finished sessions;
///   * CONTINUE — the first not-done task of today (or a genuine
///     "all done" celebration);
///   * WEAK AREA / REVISION / PYQ / MOCK — one-tap cards with live
///     state lines (M8 §21 findings, §23 due revision, M9 totals and
///     the latest mock band);
///   * XP / LEVEL / STREAK — the app-wide gamification, live from the
///     same providers the Nest uses;
///   * VAN CONTEXT — Van's speech line and mood derive from the real
///     snapshot (recovery day, revision due, all done...), plus the
///     global reactions the gamification chain dispatches.
///
/// Degrades honestly: no plan → a build-plan CTA (never a fake day);
/// no weak evidence → "no weak areas detected yet".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_hub_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/error_state_widget.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_speech_strip.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class ExamHubScreen extends ConsumerStatefulWidget {
  const ExamHubScreen({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<ExamHubScreen> createState() => _ExamHubScreenState();
}

class _ExamHubScreenState extends ConsumerState<ExamHubScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the snapshot on every entry: plan edits, replans and
    // session finishes elsewhere should be reflected immediately (the
    // completions provider refreshes automatically via invalidation;
    // plan/profile reads are cached repository loads, so a manual
    // invalidate on entry is the honest refresh).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(examHubSnapshotProvider(widget.trackId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(examHubSnapshotProvider(widget.trackId));

    return VaaniXScaffold(
      title: 'Exam Home',
      body: snapshotAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading your exam plan…'),
        ),
        error: (e, _) => ErrorStateWidget(
          title: 'Couldn\'t load your plan',
          message:
              'Something went wrong loading your exam home.\n'
              'Your progress is safe — try again in a moment.',
          onRetry: () => ref.invalidate(
            examHubSnapshotProvider(widget.trackId),
          ),
          showVan: true,
        ),
        data: (snapshot) =>
            _HubBody(snapshot: snapshot, trackId: widget.trackId),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.snapshot, required this.trackId});

  final ExamHubSnapshot snapshot;
  final String trackId;

  VanState get _vanState => switch (snapshot.vanMood) {
        ExamHubVanMood.welcome => VanState.happy,
        ExamHubVanMood.focus => VanState.focus,
        ExamHubVanMood.care => VanState.caring,
        ExamHubVanMood.celebrate => VanState.achievement,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        VanSpeechStrip(
          message: snapshot.vanMessage,
          state: _vanState,
        ),
        const SizedBox(height: 12),
        _ReadinessCard(snapshot: snapshot, trackId: trackId),
        const SizedBox(height: 10),
        _TodayPlanCard(snapshot: snapshot, trackId: trackId),
        const SizedBox(height: 10),
        _ContinueSection(snapshot: snapshot, trackId: trackId),
        const SizedBox(height: 10),
        _QuickGrid(snapshot: snapshot, trackId: trackId),
        const SizedBox(height: 10),
        _GamificationCard(trackId: trackId),
        const SizedBox(height: 12),
        PrimaryButton.secondary(
          label: 'पूरा 7-दिन plan देखें',
          icon: const Icon(Icons.calendar_month),
          onPressed: () => GoRouter.of(context).pushNamed(
            RouteNames.examPlanName,
            pathParameters: {'trackId': trackId},
          ),
        ),
      ],
    );
  }
}

/// Readiness header: the honest countdown to the M3 anchor + the
/// realistic study budget. No fabricated urgency.
class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.snapshot, required this.trackId});

  final ExamHubSnapshot snapshot;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = snapshot.profile;
    final days = snapshot.readinessDaysLeft;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  days == null
                      ? 'Readiness target नहीं मिला'
                      : snapshot.readinessLine,
                  style: AppTextStyles.titleSmall(),
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                icon:
                    const Icon(Icons.tune, size: 18, color: AppColors.primary),
                onPressed: () => GoRouter.of(context).pushNamed(
                  RouteNames.examProfileName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ],
          ),
          if (profile != null) ...[
            const SizedBox(height: 4),
            Text(
              '${profile.dailyStudyMinutes} मिनट/दिन · '
              'हफ़्ते में ${profile.studyDaysPerWeek} दिन',
              style: AppTextStyles.bodySmall(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's plan with REAL check-marks (finished sessions mark their
/// task type done for the day).
class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({required this.snapshot, required this.trackId});

  final ExamHubSnapshot snapshot;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final tasks = snapshot.todayTasks;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (tasks.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('आज का plan', style: AppTextStyles.titleMedium()),
            const SizedBox(height: 8),
            Text(
              snapshot.plan == null
                  ? 'अभी कोई योजना नहीं बनी है — बनाकर शुरू करें।'
                  : 'आज के लिए कोई काम नियोजित नहीं है।',
              style: AppTextStyles.bodyMedium(),
            ),
            if (snapshot.plan == null) ...[
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'योजना बनाएँ',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => GoRouter.of(context).pushNamed(
                  RouteNames.examPlanName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('आज का plan', style: AppTextStyles.titleMedium()),
              const Spacer(),
              Text(
                snapshot.todayAllDone
                    ? 'सब पूरा ✓'
                    : '${snapshot.todayDoneCount}/${tasks.length} पूरा · '
                        '${snapshot.todayTotalMinutes} मिनट',
                style: AppTextStyles.labelMedium(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final task in tasks) ...[
            _TodayTaskRow(task: task, trackId: trackId),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({required this.task, required this.trackId});

  final ExamHubTask task;
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
    final routeName = switch (task.type) {
      ExamTaskType.learn => RouteNames.examStudyName,
      ExamTaskType.practice => RouteNames.examPracticeName,
      ExamTaskType.weakArea => RouteNames.examWeakAreaName,
      ExamTaskType.review => RouteNames.examWeakAreaName,
      ExamTaskType.pyq => RouteNames.examPyqName,
      ExamTaskType.mock => RouteNames.examMockName,
    };
    return Semantics(
      label: '${task.title}, ${task.minutes} मिनट'
          '${task.done ? ', पूरा' : ''}',
      child: InkWell(
        // §20 freedom preserved: every task stays openable, done or
        // not — the plan is a recommendation.
        onTap: () => GoRouter.of(context).pushNamed(
          routeName,
          pathParameters: task.type == ExamTaskType.learn
              ? {'trackId': trackId, 'topicId': task.topicId}
              : {'trackId': trackId},
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color, semanticLabel: task.type.name),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: AppTextStyles.bodyMedium().copyWith(
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    color: task.done
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.subtextDark
                            : AppColors.subtextLight)
                        : null,
                  ),
                ),
              ),
              Text('${task.minutes}m',
                  style: AppTextStyles.labelSmall(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.subtextDark
                          : AppColors.subtextLight)),
              const SizedBox(width: 6),
              Icon(
                task.done ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: task.done
                    ? AppColors.success
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
                semanticLabel: task.done ? 'पूरा' : 'बाक़ी',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CONTINUE: the first not-done task of today (M10 core), or the
/// genuine all-done state.
class _ContinueSection extends StatelessWidget {
  const _ContinueSection({required this.snapshot, required this.trackId});

  final ExamHubSnapshot snapshot;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final task = snapshot.continueTask;
    if (task == null) {
      if (snapshot.todayAllDone) {
        return _Card(
          child: Row(
            children: [
              const Icon(Icons.celebration, size: 20, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text('आज का plan पूरा हुआ — बेहतरीन!',
                    style: AppTextStyles.titleSmall()),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }
    final (icon, _) = switch (task.type) {
      ExamTaskType.learn => (Icons.menu_book, AppColors.primary),
      ExamTaskType.practice => (Icons.edit_note, AppColors.info),
      ExamTaskType.review => (Icons.history, AppColors.success),
      ExamTaskType.pyq => (Icons.library_books, AppColors.vanOrange),
      ExamTaskType.weakArea => (Icons.priority_high, AppColors.warning),
      ExamTaskType.mock => (Icons.timer, AppColors.streak),
    };
    final routeName = switch (task.type) {
      ExamTaskType.learn => RouteNames.examStudyName,
      ExamTaskType.practice => RouteNames.examPracticeName,
      ExamTaskType.weakArea => RouteNames.examWeakAreaName,
      ExamTaskType.review => RouteNames.examWeakAreaName,
      ExamTaskType.pyq => RouteNames.examPyqName,
      ExamTaskType.mock => RouteNames.examMockName,
    };
    return _Card(
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('जारी रखें',
                    style: AppTextStyles.labelMedium(color: AppColors.primary)),
                const SizedBox(height: 2),
                Text('${task.title} · ${task.minutes} मिनट',
                    style: AppTextStyles.bodyMedium()),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Continue',
            icon: const Icon(Icons.play_arrow, color: AppColors.primary),
            onPressed: () => GoRouter.of(context).pushNamed(
              routeName,
              pathParameters: task.type == ExamTaskType.learn
                  ? {'trackId': trackId, 'topicId': task.topicId}
                  : {'trackId': trackId},
            ),
          ),
        ],
      ),
    );
  }
}

/// One-tap state cards for the M8/M9 subsystems.
class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.snapshot, required this.trackId});

  final ExamHubSnapshot snapshot;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StateCard(
                icon: Icons.healing,
                color:
                    snapshot.recoveryToday ? AppColors.warning : AppColors.info,
                title: snapshot.recoveryToday ? 'आज recovery दिन' : 'Weak area',
                line: snapshot.recoveryToday
                    ? snapshot.weakAreaLine
                    : snapshot.weakAreaLine,
                onTap: () => GoRouter.of(context).pushNamed(
                  RouteNames.examWeakAreaName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StateCard(
                icon: Icons.history,
                color: snapshot.weak.revisionDueCount > 0
                    ? AppColors.success
                    : AppColors.info,
                title: 'दोहराव',
                line: snapshot.revisionLine,
                onTap: () => GoRouter.of(context).pushNamed(
                  RouteNames.examWeakAreaName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StateCard(
                icon: Icons.library_books,
                color: AppColors.vanOrange,
                title: 'PYQ',
                line: snapshot.pyqLine,
                onTap: () => GoRouter.of(context).pushNamed(
                  RouteNames.examPyqName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StateCard(
                icon: Icons.timer,
                color:
                    snapshot.mockCount > 0 ? AppColors.streak : AppColors.info,
                title: 'Mock',
                line: snapshot.mockLine,
                onTap: () => GoRouter.of(context).pushNamed(
                  RouteNames.examMockName,
                  pathParameters: {'trackId': trackId},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '$title: $line',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: AppTextStyles.titleSmall()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                line,
                style: AppTextStyles.bodySmall(
                    color: isDark
                        ? AppColors.subtextDark
                        : AppColors.subtextLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app-wide gamification row (XP / level / streak) — the same live
/// providers the Nest uses, so exam mode and the Nest can never
/// disagree about the learner's state.
class _GamificationCard extends ConsumerWidget {
  const _GamificationCard({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(xpTotalProvider);
    final streak = ref.watch(userProfileProvider).currentStreak;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('आपकी प्रगति', style: AppTextStyles.titleMedium()),
          const SizedBox(height: 10),
          Row(
            children: [
              XpBadge(xpTotal: xp),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Lv ${levelFromXp(xp)}',
                  style: AppTextStyles.labelMedium(color: AppColors.primary),
                ),
              ),
              const Spacer(),
              if (streak > 0) StreakBadge(streakCount: streak),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'अगले level तक ${xpForNextLevel(levelFromXp(xp)) - xpIntoLevel(xp)} XP बाक़ी',
            style: AppTextStyles.bodySmall(
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight),
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
