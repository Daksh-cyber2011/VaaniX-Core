/// VaaniX V1 Design System — Learn Home ("The Sanctuary")
///
/// Stitch Design Canvas: Screen 2
/// Clean Editorial Ivory/Slate (#F8FAFC / #FFFFFF)
///
/// Features (all state TRUTHFUL — every number comes from a real
/// provider, an honest zero, or an explicit unavailable state):
/// - Sticky Header with VaaniXModeSwitch (LEARN active), live streak badge
///   (0 shows 0), and profile
/// - Active language selector pill from the persisted Learn language
///   ("Pick a language" when none is selected)
/// - VAN greeting card with a neutral, non-state message
/// - Hero card: an honest practice entry (no fabricated unit/mastery)
/// - Today's Delights: Spaced Repetition & Pronunciation Lab with
///   AudioCadenceWaveform
/// - Curriculum Path rendered from the active curriculum + the real
///   completed-lesson records
/// - Daily Commitment Dial wired to the real daily-XP goal state
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/personalized_course_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/daily_activity_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/shared/widgets/audio_cadence_waveform.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_mode_switch.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';
import 'package:vaanix_app/shared/widgets/van_companion_bubble.dart';

class LearnHomeScreen extends ConsumerStatefulWidget {
  const LearnHomeScreen({super.key});

  @override
  ConsumerState<LearnHomeScreen> createState() => _LearnHomeScreenState();
}

class _LearnHomeScreenState extends ConsumerState<LearnHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final learnerName = profile.resolvedCompanionName.isNotEmpty
        ? profile.resolvedCompanionName
        : 'Learner';
    // Truthful streak: 0 days shows 0 — no fabricated default.
    final streak = profile.currentStreak;

    return Scaffold(
      backgroundColor: VaaniXColors.learnCanvasBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Sticky Header ──────────────────────────────────
            _buildTopBar(context, streak),

            // ── Scrollable Sanctuary Body ──────────────────────
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: VaaniXSpacing.screenMarginWide,
                  vertical: VaaniXSpacing.md,
                ),
                children: [
                  // 1. Language Selector Pill
                  _buildLanguageSelector(context),
                  const SizedBox(height: VaaniXSpacing.md),

                  // 2. VAN Personalized Greeting
                  VanCompanionBubble(
                    vanState: VanState.happy,
                    badgeRole: VanBadgeRole.mentor,
                    badgeLabel: 'VAN • MENTOR',
                    title: 'Namaste, $learnerName!',
                    message:
                        'This screen doesn\u2019t track where you are in the '
                        'curriculum — start a practice below and it adapts '
                        'to what you know.',
                    onVoiceTap: () {
                      HapticFeedback.lightImpact();
                      context.pushUnique(RouteNames.chat);
                    },
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 3. Honest Practice Entry Card
                  _buildPracticeEntryCard(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 4. Today's Delights (Micro-doses)
                  _buildTodaysDelightsSection(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 5. Daily Commitment Dial & Curriculum Path
                  _buildCommitmentAndCurriculum(context),
                  const SizedBox(height: VaaniXSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: VaaniXColors.learnCanvasBg,
        border: Border(
          bottom: BorderSide(color: VaaniXColors.learnBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Sliding Mode Switch Pill
          const SizedBox(
            width: 140,
            child: VaaniXModeSwitch(compact: true),
          ),
          const Spacer(),

          // Streak Counter Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: VaaniXColors.telemetryAmber.withValues(alpha: 0.12),
              borderRadius: VaaniXRadius.borderPill,
              border: Border.all(
                color: VaaniXColors.telemetryAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.telemetryAmber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Bell Notifications (haptic only — there is no real
          // notifications source yet, so nothing is announced).
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: VaaniXColors.learnSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: VaaniXColors.learnBorder),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: VaaniXColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Profile Avatar
          GestureDetector(
            onTap: () => context.pushUnique(RouteNames.vanProfile),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: VaaniXColors.learnPrimaryViolet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    // Real selection from the persisted Learn-language store; when no
    // language has been picked yet the pill says so honestly. No level or
    // progress percentage exists anywhere in the app, so none is shown.
    final selected = ref.watch(selectedLearnLanguageProvider);
    final label = selected == null
        ? 'Pick a language'
        : 'Learn ${learnLanguageSpec(selected).englishName}';

    return GestureDetector(
      onTap: () => context.pushUnique(RouteNames.learnLanguageSelection),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: VaaniXColors.learnSurfaceCard,
          borderRadius: VaaniXRadius.borderPill,
          border: Border.all(color: VaaniXColors.learnBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selected == null
                    ? VaaniXColors.textTertiaryLight
                    : VaaniXColors.telemetryEmerald,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: VaaniXColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: VaaniXColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: VaaniXColors.learnSoftPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 14,
                color: VaaniXColors.learnPrimaryViolet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeEntryCard(BuildContext context) {
    return VaaniXCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.1),
                  borderRadius: VaaniXRadius.borderPill,
                ),
                child: const Text(
                  'PRACTICE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.learnPrimaryViolet,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Continue learning',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A short focused session — read a little, drill a little, '
            'review a little.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: VaaniXColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          VaaniXButton(
            label: 'Start today\u2019s practice',
            onPressed: () {
              // Launches the smart practice session.
              context.pushUnique(RouteNames.learnSmartPractice);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysDelightsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Today's Delights",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: VaaniXColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            Text(
              'MICRO-DOSES',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VaaniXColors.textTertiaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Spaced Repetition Card
        VaaniXCard(
          padding: const EdgeInsets.all(14),
          onTap: () {
            context.pushUnique(RouteNames.learnSmartPractice);
          },
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: VaaniXColors.telemetryAmberBg,
                  borderRadius: VaaniXRadius.borderMd,
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: VaaniXColors.telemetryAmber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spaced Repetition Cards',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: VaaniXColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Review what needs practice',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: VaaniXColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: VaaniXColors.textTertiaryLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Pronunciation Lab with Waveform
        const AudioCadenceWaveform(
          phrase: 'नमस्ते, आप कैसे हैं?',
          transliteration: 'Namaste, aap kaise hain?',
          durationLabel: '0:03',
        ),
      ],
    );
  }

  Widget _buildCommitmentAndCurriculum(BuildContext context) {
    final goal = ref.watch(dailyGoalStateProvider);
    final target = goal.xpTarget;
    final xp = goal.xpEarnedToday;
    // Divide-by-zero safe: an unset goal shows 0 progress, never a
    // fabricated percentage.
    final percent = target > 0 ? ((xp * 100) / target).clamp(0.0, 100.0) : 0.0;
    final goalSentence = xp == 0
        ? 'No XP earned yet today — your goal is $target XP.'
        : 'You have earned $xp of your $target XP goal today.';

    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Radial Gauge for Daily Commitment — real daily XP state.
              VaaniXRadialGauge(
                percentage: percent,
                size: 72,
                strokeWidth: 6,
                primaryColor: VaaniXColors.learnPrimaryViolet,
                showPercentage: false,
                subtitle: '$xp/$target XP',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Commitment',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: VaaniXColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goalSentence,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: VaaniXColors.textSecondaryLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: VaaniXColors.learnBorder),

          // Curriculum Path Preview — real chapters + real completions.
          const Text(
            'Curriculum Path',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          _buildCurriculumSteps(),
        ],
      ),
    );
  }

  Widget _buildCurriculumSteps() {
    // When a personalized course exists, show IT as the curriculum path
    // preview — the personalized course IS the real learning roadmap.
    final courseAsync = ref.watch(personalizedCourseProvider);
    final completedLessonIds = ref.watch(completedLessonIdsProvider);

    return courseAsync.when(
      loading: () => const Text(
        'Building your learning path…',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12.5,
          color: VaaniXColors.textSecondaryLight,
        ),
      ),
      error: (_, __) => _buildStaticCurriculumSteps(completedLessonIds),
      data: (course) {
        if (course == null || course.isEmpty) {
          return _buildStaticCurriculumSteps(completedLessonIds);
        }

        // Show the personalized course units as curriculum steps
        final completed = completedLessonIds.toSet();
        final shown = course.units.take(5).toList();
        final steps = <Widget>[];
        var foundCurrent = false;

        for (var i = 0; i < shown.length; i++) {
          final unit = shown[i];
          // A unit is done when ALL its lessons' anchor IDs are completed
          final done = unit.lessons.isNotEmpty &&
              unit.lessons.every((l) {
                final lid = l.lessonId ?? l.conceptId;
                return completed.contains(lid) ||
                    completed.contains(l.conceptId);
              });
          // The first not-done unit is current
          final isCurrent = !done && !foundCurrent;
          if (isCurrent) foundCurrent = true;

          steps.add(
            _CurriculumStep(
              index: i + 1,
              title: unit.title,
              isDone: done,
              isCurrent: isCurrent,
              isLocked: !done && !isCurrent,
            ),
          );
        }
        return Column(children: steps);
      },
    );
  }

  /// Fallback: static curriculum steps when no personalized course exists.
  Widget _buildStaticCurriculumSteps(List<String> completedLessonIds) {
    final curriculumAsync = ref.watch(activeCurriculumProvider);

    return curriculumAsync.when(
      loading: () => const Text(
        'Loading curriculum…',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12.5,
          color: VaaniXColors.textSecondaryLight,
        ),
      ),
      error: (_, __) => const Text(
        'Curriculum unavailable',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12.5,
          color: VaaniXColors.textSecondaryLight,
        ),
      ),
      data: (chapters) {
        if (chapters.isEmpty) {
          return const Text(
            'Curriculum unavailable',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: VaaniXColors.textSecondaryLight,
            ),
          );
        }

        final completed = completedLessonIds.toSet();
        bool isDone(Chapter c) =>
            c.lessons.isNotEmpty &&
            c.lessons.every((l) => completed.contains(l.id));
        final currentIndex = chapters.indexWhere((c) => !isDone(c));

        final steps = <Widget>[];
        final shown = chapters.take(5).toList();
        for (var i = 0; i < shown.length; i++) {
          final chapter = shown[i];
          final done = isDone(chapter);
          final isCurrent = !done && i == currentIndex;
          steps.add(
            _CurriculumStep(
              index: i + 1,
              title: chapter.title,
              isDone: done,
              isCurrent: isCurrent,
              isLocked: !done && !isCurrent,
            ),
          );
        }
        return Column(children: steps);
      },
    );
  }
}

class _CurriculumStep extends StatelessWidget {
  const _CurriculumStep({
    required this.index,
    required this.title,
    this.isDone = false,
    this.isCurrent = false,
    this.isLocked = false,
  });

  final int index;
  final String title;
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    if (isDone) {
      icon = const Icon(Icons.check_circle_rounded,
          color: VaaniXColors.telemetryEmerald, size: 20);
    } else if (isCurrent) {
      icon = const Icon(Icons.play_circle_fill_rounded,
          color: VaaniXColors.learnPrimaryViolet, size: 20);
    } else {
      icon = const Icon(Icons.lock_rounded,
          color: VaaniXColors.textTertiaryLight, size: 18);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isLocked
                    ? VaaniXColors.textTertiaryLight
                    : VaaniXColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
