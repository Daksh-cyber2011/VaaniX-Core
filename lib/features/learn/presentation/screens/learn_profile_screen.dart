/// VaaniX Learn Mode — Learner Profile Screen (M2)
///
/// Lets the learner tell VAN who they are as a language learner, per
/// Learn language (Master Brief §10/§28/§29):
///
/// - self-reported starting point (coarse — the M3 diagnostic still
///   estimates the real level; this never pretends to be one),
/// - learning goal (general / conversation / reading / writing / travel /
///   school / culture / mastery),
/// - desired level (clearly-labelled VaaniX internal levels — no CEFR
///   claims),
/// - pace and practice style,
/// - daily goal in minutes (flexible, non-punitive).
///
/// Everything is saved in one explicit action (persist-first), so partial
/// edits never leak into planning. The system never forces this screen:
/// with no saved profile the planner runs on honest defaults, and the
/// Learn screen shows a gentle prompt card instead of a wall.
///
/// Design: mirrors [LearnLanguageSelectionScreen] (VaaniXScaffold, VAN
/// intro, card tiles with check/radio affordances) so the flow feels like
/// one product.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/presentation/providers/diagnostic_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/personalized_course_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/spine_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_plan_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/shared/widgets/empty_state_widget.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

/// Daily-goal choices in minutes (Master Brief §27/§58 — short sessions
/// are first-class; consistency beats marathon guilt).
const List<int> kDailyGoalChoices = <int>[5, 10, 15, 20, 30];

class LearnProfileScreen extends ConsumerStatefulWidget {
  const LearnProfileScreen({super.key});

  @override
  ConsumerState<LearnProfileScreen> createState() => _LearnProfileScreenState();
}

class _LearnProfileScreenState extends ConsumerState<LearnProfileScreen> {
  SelfReport _selfReport = SelfReport.almostNothing;
  LearningGoal _goal = LearningGoal.general;
  DesiredLevel _desiredLevel = DesiredLevel.beginner;
  LearningPace _pace = LearningPace.steady;
  PracticeStyle _practiceStyle = PracticeStyle.mixed;
  int _dailyGoalMinutes = LearnerProfile.kDefaultDailyGoalMinutes;

  @override
  void initState() {
    super.initState();
    // Read ONCE into local editable state; the save button persists the
    // whole set in a single action, so partial edits never leak into
    // planning. (Watching the profile in build would clobber in-progress
    // edits on every rebuild.)
    final language = ref.read(selectedLearnLanguageProvider);
    final profile =
        language == null ? null : ref.read(learnerProfileProvider(language));
    if (profile != null) {
      _selfReport = profile.selfReport;
      _goal = profile.goal;
      _desiredLevel = profile.desiredLevel;
      _pace = profile.pace;
      _practiceStyle = profile.practiceStyle;
      _dailyGoalMinutes = profile.dailyGoalMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(selectedLearnLanguageProvider);
    if (language == null) {
      return VaaniXScaffold(
        title: 'Personalize',
        body: EmptyStateWidget(
          icon: Icons.person_search_rounded,
          title: 'Choose a language first',
          description:
              'Your learning profile is per language — pick the language '
              'you want to study and this screen will shape itself around '
              'it.',
          actionLabel: 'Choose a language',
          onActionPressed: () => context.go(RouteNames.learnLanguageSelection),
        ),
      );
    }

    return VaaniXScaffold(
      title: 'Personalize',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // VAN intro — friendly, not exam-like (Master Brief §43/§70).
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VanWidget(
                  state: VanState.happy,
                  size: 84,
                  showSpeechBubble: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Let\u2019s plan around YOU',
                          style: AppTextStyles.titleMedium()),
                      const SizedBox(height: 4),
                      Text(
                        'A few quick choices so your path fits your goal. '
                        'VAN uses them to decide what you do next — and '
                        'you can change them anytime.',
                        style: AppTextStyles.bodyMedium(
                          color: _subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Level check status (M3) ──
          // The diagnostic's currentLevel, shown only as the friendly
          // internal level name — raw scores stay internal (Master Brief
          // §11/§44). Undiagnosed learners get a quiet invitation.
          _LevelCheckCard(
            result: ref.watch(lastDiagnosticProvider(language)),
          ),

          // ── 1. Self-reported starting point (coarse, honest) ──
          _SectionHeader(
            title: 'Where are you starting from?',
            caption: 'A rough feel is enough — the placement game will '
                'pin down your level.',
          ),
          for (final report in SelfReport.values)
            _OptionTile(
              title: report.label,
              isSelected: _selfReport == report,
              onTap: () => setState(() => _selfReport = report),
            ),

          // ── 2. Goal ──
          _SectionHeader(title: 'What do you want to achieve?'),
          for (final goal in LearningGoal.values)
            _OptionTile(
              title: goal.label,
              isSelected: _goal == goal,
              onTap: () => setState(() => _goal = goal),
            ),

          // ── 3. Desired level ──
          _SectionHeader(
            title: 'How far do you want to go?',
            caption: 'VaaniX levels — a friendly path, not a formal '
                'certificate.',
          ),
          for (final level in DesiredLevel.values)
            _OptionTile(
              title: level.label,
              isSelected: _desiredLevel == level,
              onTap: () => setState(() => _desiredLevel = level),
            ),

          // ── 4. Pace ──
          _SectionHeader(title: 'How do you like to practice?'),
          for (final pace in LearningPace.values)
            _OptionTile(
              title: pace.label,
              isSelected: _pace == pace,
              onTap: () => setState(() => _pace = pace),
            ),

          // ── 5. Practice style ──
          _SectionHeader(title: 'What sticks best for you?'),
          for (final style in PracticeStyle.values)
            _OptionTile(
              title: style.label,
              isSelected: _practiceStyle == style,
              onTap: () => setState(() => _practiceStyle = style),
            ),

          // ── 6. Daily goal ──
          _SectionHeader(
            title: 'Daily goal',
            caption: 'Small and steady wins. Missing a day never breaks '
                'anything.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in kDailyGoalChoices)
                  _MinuteChip(
                    minutes: minutes,
                    isSelected: _dailyGoalMinutes == minutes,
                    onTap: () => setState(() => _dailyGoalMinutes = minutes),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save my profile',
            onPressed: () => _save(context),
          ),
          const SizedBox(height: 8),
          Center(
            child: PrimaryButton.text(
              label: 'Reset to defaults',
              onPressed: () => _reset(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _subtext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.subtextDark
          : AppColors.subtextLight;

  Future<void> _save(BuildContext context) async {
    final language = ref.read(selectedLearnLanguageProvider);
    if (language == null) return;
    // Capture router BEFORE the async gap (satisfies use_build_context_synchronously).
    final router = GoRouter.of(context);
    await ref.read(learnerProfileProvider(language).notifier).update(
          (p) => p.copyWith(
            selfReport: _selfReport,
            goal: _goal,
            desiredLevel: _desiredLevel,
            pace: _pace,
            practiceStyle: _practiceStyle,
            dailyGoalMinutes: _dailyGoalMinutes,
          ),
        );
    if (!mounted) return;
    router.go(RouteNames.learn);
  }

  Future<void> _reset(BuildContext context) async {
    final language = ref.read(selectedLearnLanguageProvider);
    if (language == null) return;
    
    // 1. Wipe Learn-specific generated state (profile, course, diagnostic, etc)
    await ref.read(learnerProfileProvider(language).notifier).resetToDefaults();
    
    // 2. Wipe mastery/progress for this language (wait, it's global)
    await ref.read(progressRepositoryProvider).reset();
    
    // 3. Invalidate providers to force a clean rebuild from the newly emptied state
    ref.invalidate(personalizedCourseProvider);
    ref.invalidate(diagnosticSessionProvider);
    ref.invalidate(learningPlannerProvider);
    ref.invalidate(activeLearningStateProvider);
    ref.invalidate(learnStateExtrasProvider);

    if (!mounted) return;
    setState(() {
      _selfReport = SelfReport.almostNothing;
      _goal = LearningGoal.general;
      _desiredLevel = DesiredLevel.beginner;
      _pace = LearningPace.steady;
      _practiceStyle = PracticeStyle.mixed;
      _dailyGoalMinutes = LearnerProfile.kDefaultDailyGoalMinutes;
    });
  }
}

/// Section heading + optional caption (small, calm — no analytics wall).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final subtext = Theme.of(context).brightness == Brightness.dark
        ? AppColors.subtextDark
        : AppColors.subtextLight;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium()),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: AppTextStyles.bodySmall(color: subtext)),
          ],
        ],
      ),
    );
  }
}

/// A single selectable option card (same affordance language as the
/// language picker tiles: bordered card, check/radio on the right).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Semantics(
      button: true,
      selected: isSelected,
      label: title,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTextStyles.bodyMedium()),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primary : subtext,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact chip for the daily-goal minutes row.
class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$minutes minutes a day',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: AppDimens.minTouchTarget),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              '$minutes min',
              style: AppTextStyles.bodyMedium(
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// M3: the level-check status card. Diagnosed learners see their friendly
/// internal level name plus a retake entry (repeatable by design);
/// undiagnosed learners see a quiet invitation. Raw scores are never
/// rendered here (Master Brief §11/§44).
class _LevelCheckCard extends StatelessWidget {
  const _LevelCheckCard({required this.result});

  final DiagnosticResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    final diagnosed = result != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        button: true,
        container: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            onTap: () => context.go(RouteNames.learnDiagnostic),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: diagnosed
                    ? AppColors.success.withValues(alpha: 0.07)
                    : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                border: Border.all(
                  color: diagnosed
                      ? AppColors.success.withValues(alpha: 0.5)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    diagnosed ? Icons.verified_rounded : Icons.explore_rounded,
                    color: diagnosed
                        ? AppColors.success
                        : Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diagnosed
                              ? 'Level check: ${result!.levelLabel}'
                              : 'Level check not played yet',
                          style: AppTextStyles.titleSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          diagnosed
                              ? 'VAN re-checks your level whenever you like — '
                                  'the path updates itself.'
                              : 'Play the short discovery game and VAN will '
                                  'size your path to fit.',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: subtext, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
