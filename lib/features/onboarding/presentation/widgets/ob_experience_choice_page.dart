/// Onboarding Step 3 of 6 — Experience Choice
///
/// Stitch Design Canvas: Screen 1
/// Presents the dual-engine choice:
/// 1. LEARN MODE ("The Sanctuary") — 10 Indic languages immersion
/// 2. EXAM MODE ("Tactical Cockpit") — CBSE Board Precision (Class 9 & 10)
///
/// Synchronization Guarantee: "Dual-Engine, Single Account. You can switch
/// anytime in 1 tap without losing progress."
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/providers/app_mode_provider.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/shared/widgets/van_companion_bubble.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';

class ObExperienceChoicePage extends ConsumerStatefulWidget {
  const ObExperienceChoicePage({super.key});

  @override
  ConsumerState<ObExperienceChoicePage> createState() =>
      _ObExperienceChoicePageState();
}

class _ObExperienceChoicePageState
    extends ConsumerState<ObExperienceChoicePage> {
  AppMode _selectedChoice = AppMode.learn;

  static const _indicLanguages = [
    'Hindi',
    'Bengali',
    'Marathi',
    'Telugu',
    'Tamil',
    'Gujarati',
    'Urdu',
    'Kannada',
    'Malayalam',
    'Odia'
  ];

  static const _examScopes = [
    'CBSE Class 10',
    'CBSE Class 9',
    'Hindi Course A',
    'Hindi Course B',
    'Sanskrit'
  ];

  void _proceed() {
    ref.read(appModeProvider.notifier).setMode(_selectedChoice);
    final notifier = ref.read(onboardingProvider.notifier);
    // Ensure default class is selected so downstream onboarding validators succeed
    notifier.selectClass(CbseClass.class10);
    notifier.confirmSubjectSetup();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: VaaniXSpacing.screenMarginWide,
        vertical: VaaniXSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 3 of 6 indicator
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.1),
                  borderRadius: VaaniXRadius.borderPill,
                ),
                child: const Text(
                  'STEP 3 OF 6 • EXPERIENCE CHOICE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.learnPrimaryViolet,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VaaniXSpacing.md),

          // Heading
          const Text(
            'How will you explore with VAN today?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryLight,
              height: 1.25,
            ),
          ),
          const SizedBox(height: VaaniXSpacing.lg),

          // VAN Speech Card
          const VanCompanionBubble(
            vanState: VanState.thinking,
            badgeLabel: 'VAN WHISPERS',
            message:
                'Pick your primary journey! You can switch anytime in 1 tap without losing progress.',
          ),
          const SizedBox(height: VaaniXSpacing.xl),

          // ── Option 1: LEARN MODE ("The Sanctuary") ──────────
          _JourneyCard(
            title: 'LEARN MODE',
            subtitle: 'The Sanctuary • 10 Living Indic Languages',
            description:
                'Curiosity-driven immersion, conversational nuance, authentic phonetics, and native idioms at your pace.',
            isSelected: _selectedChoice == AppMode.learn,
            isTactical: false,
            chips: _indicLanguages,
            ctaLabel: 'Enter Learn Sanctuary →',
            onTap: () => setState(() => _selectedChoice = AppMode.learn),
            onCtaTap: () {
              setState(() => _selectedChoice = AppMode.learn);
              _proceed();
            },
          ),
          const SizedBox(height: VaaniXSpacing.lg),

          // ── Option 2: EXAM MODE ("Tactical Cockpit") ─────────
          _JourneyCard(
            title: 'EXAM MODE',
            subtitle: 'Tactical Cockpit • CBSE Board Precision',
            description:
                'High-yield syllabus mastery, timed mocks, speed diagnostics, formula telemetries, and CBSE step-marking guidelines.',
            isSelected: _selectedChoice == AppMode.exam,
            isTactical: true,
            chips: _examScopes,
            ctaLabel: 'Activate Exam Cockpit ⚡ →',
            onTap: () => setState(() => _selectedChoice = AppMode.exam),
            onCtaTap: () {
              setState(() => _selectedChoice = AppMode.exam);
              _proceed();
            },
          ),
          const SizedBox(height: VaaniXSpacing.xl),

          // ── Footer Guarantee ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VaaniXColors.learnSurfaceElevated,
              borderRadius: VaaniXRadius.borderLg,
              border: Border.all(color: VaaniXColors.learnBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_lock_rounded,
                  size: 20,
                  color: VaaniXColors.learnPrimaryViolet,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dual-Engine, Single Account',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: VaaniXColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Your streaks, achievements, and XP synchronize between modes seamlessly.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: VaaniXColors.textSecondaryLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VaaniXSpacing.xxl),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.isSelected,
    required this.isTactical,
    required this.chips,
    required this.ctaLabel,
    required this.onTap,
    required this.onCtaTap,
  });

  final String title;
  final String subtitle;
  final String description;
  final bool isSelected;
  final bool isTactical;
  final List<String> chips;
  final String ctaLabel;
  final VoidCallback onTap;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isTactical
        ? VaaniXColors.examSurfaceCard
        : VaaniXColors.learnSurfaceCard;
    final borderColor = isSelected
        ? (isTactical ? VaaniXColors.examCyanAccent : VaaniXColors.learnPrimaryViolet)
        : (isTactical ? VaaniXColors.examBorder : VaaniXColors.learnBorder);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: VaaniXRadius.borderLg,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isTactical
                      ? VaaniXColors.examCyanAccent
                      : VaaniXColors.learnPrimaryViolet)
                  .withValues(alpha: isSelected ? 0.12 : 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTactical
                        ? VaaniXColors.examCyanAccent.withValues(alpha: 0.15)
                        : VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.1),
                    borderRadius: VaaniXRadius.borderPill,
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isTactical
                          ? VaaniXColors.examCyanAccent
                          : VaaniXColors.learnPrimaryViolet,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? (isTactical
                          ? VaaniXColors.examCyanAccent
                          : VaaniXColors.learnPrimaryViolet)
                      : (isTactical
                          ? VaaniXColors.textTertiaryDark
                          : VaaniXColors.textTertiaryLight),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isTactical
                    ? VaaniXColors.textPrimaryDark
                    : VaaniXColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                color: isTactical
                    ? VaaniXColors.textSecondaryDark
                    : VaaniXColors.textSecondaryLight,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),

            // Scope / Language Tag Cloud
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.take(6).map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTactical
                        ? VaaniXColors.examSurfaceElevated
                        : VaaniXColors.learnSurfaceElevated,
                    borderRadius: VaaniXRadius.borderPill,
                    border: Border.all(
                      color: isTactical
                          ? VaaniXColors.examBorder
                          : VaaniXColors.learnBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: isTactical
                          ? VaaniXColors.textSecondaryDark
                          : VaaniXColors.textSecondaryLight,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Mode CTA
            VaaniXButton(
              label: ctaLabel,
              variant: isTactical
                  ? VaaniXButtonVariant.cyan
                  : VaaniXButtonVariant.primary,
              height: 42,
              onPressed: onCtaTap,
            ),
          ],
        ),
      ),
    );
  }
}
