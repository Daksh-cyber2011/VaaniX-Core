/// VaaniX V1 Design System — Learn Home ("The Sanctuary")
///
/// Stitch Design Canvas: Screen 2
/// Clean Editorial Ivory/Slate (#F8FAFC / #FFFFFF)
///
/// Features:
/// - Sticky Header with VaaniXModeSwitch (LEARN active), streak badge, and profile
/// - Active language selector pill: "Learn Hindi • Lv 2 (65%)"
/// - VAN Personalized greeting card with conversational speech bubble
/// - Hero Unit: "Unit 4: Formal vs Informal Introductions (आप vs तुम)" with 68% mastery
/// - Today's Delights: Spaced Repetition (12 due) & Pronunciation Lab with AudioCadenceWaveform
/// - Curriculum Path with unlocked/locked states
/// - Daily Commitment Dial (16/20 min completed)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
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
  String _activeLanguage = 'Hindi';
  int _activeLevel = 2;
  double _languageProgress = 0.65;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final learnerName = profile.resolvedCompanionName.isNotEmpty
        ? profile.resolvedCompanionName
        : 'Learner';
    final streak = profile.currentStreak > 0 ? profile.currentStreak : 14;

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
                        'Ready for Unit 4 conversational nuance? Today we explore respectful address agreements.',
                    onVoiceTap: () {
                      HapticFeedback.lightImpact();
                      context.pushUnique(RouteNames.chat);
                    },
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 3. Hero Concept Card: Unit 4
                  _buildHeroUnitCard(context),
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

          // Bell Notifications
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Notifications: 12 cards due for spaced review!'),
                  duration: Duration(seconds: 2),
                ),
              );
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
              decoration: const BoxDecoration(
                color: VaaniXColors.telemetryEmerald,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Learn $_activeLanguage • Lv $_activeLevel (${(_languageProgress * 100).toInt()}%)',
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

  Widget _buildHeroUnitCard(BuildContext context) {
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
                  'ACTIVE UNIT',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.learnPrimaryViolet,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                '68% Mastery',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VaaniXColors.learnPrimaryViolet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Unit 4: Formal vs Informal Introductions',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'आप (Aap) vs तुम (Tum) — Master grammatical honorifics and colloquial cadence.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: VaaniXColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.68,
              minHeight: 6,
              backgroundColor: VaaniXColors.learnBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VaaniXColors.learnPrimaryViolet,
              ),
            ),
          ),
          const SizedBox(height: 16),

          VaaniXButton(
            label: 'Continue Lesson →',
            onPressed: () {
              // Launches interactive practice session
              context.pushUnique(RouteNames.learnSession);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spaced Repetition Cards',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: VaaniXColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '12 cards due for optimal retention curve',
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
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Radial Gauge for Daily Commitment
              const VaaniXRadialGauge(
                percentage: 80,
                size: 72,
                strokeWidth: 6,
                primaryColor: VaaniXColors.learnPrimaryViolet,
                showPercentage: false,
                subtitle: '16/20m',
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
                      '16 of 20 min completed today. 4 minutes left to extend streak!',
                      style: TextStyle(
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

          // Curriculum Path Preview
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
          _CurriculumStep(
            index: 1,
            title: 'Unit 1: Basic Greetings & Salutations',
            isDone: true,
          ),
          _CurriculumStep(
            index: 2,
            title: 'Unit 2: Personal Pronouns & Honorifics',
            isDone: true,
          ),
          _CurriculumStep(
            index: 3,
            title: 'Unit 3: Asking Questions with Polite Forms',
            isDone: true,
          ),
          _CurriculumStep(
            index: 4,
            title: 'Unit 4: Formal vs Informal Introductions',
            isCurrent: true,
          ),
          _CurriculumStep(
            index: 5,
            title: 'Unit 5: Conversational Pacing & Common Idioms',
            isLocked: true,
          ),
        ],
      ),
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
