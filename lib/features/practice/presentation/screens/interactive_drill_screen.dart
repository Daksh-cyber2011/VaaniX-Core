/// VaaniX V1 Design System — Interactive Applied Drill
///
/// Stitch Design Canvas: Screen 5
/// Focus Light (#FFFFFF) with Emerald Validation (#10B981)
///
/// Features:
/// - Stepper Header: Segmented progress (3 of 5), Streak badge, audio toggle
/// - VAN Insight: Compact mascot prompt detailing honorific grammar agreements
/// - Knowledge Reference Cards: Formal vs Informal contrast tables
/// - Interactive AudioCadenceWaveform player
/// - Applied Drill: 3 Options with selection states, Emerald validation, +20 XP reward
/// - Sticky Bottom CTA: "Continue Lesson →"
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/shared/widgets/audio_cadence_waveform.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/van_companion_bubble.dart';

class InteractiveDrillScreen extends ConsumerStatefulWidget {
  const InteractiveDrillScreen({super.key});

  @override
  ConsumerState<InteractiveDrillScreen> createState() =>
      _InteractiveDrillScreenState();
}

class _InteractiveDrillScreenState
    extends ConsumerState<InteractiveDrillScreen> {
  int? _selectedOption = 1; // Option B selected as in Stitch spec
  bool _submitted = true;
  bool _xpAwarded = false;

  final List<Map<String, String>> _options = const [
    {
      'label': 'A',
      'devanagari': 'तू कैसा है?',
      'transliteration': 'Tu kaisa hai?',
      'note':
          'Very informal / intimate form — inappropriate for elders or teachers.',
    },
    {
      'label': 'B',
      'devanagari': 'आप कैसे हैं?',
      'transliteration': 'Aap kaise hain?',
      'note':
          'Correct! "आप" expresses honorific respect with plural verb agreement.',
    },
    {
      'label': 'C',
      'devanagari': 'तुम कैसे हो?',
      'transliteration': 'Tum kaise ho?',
      'note':
          'Semi-formal / friendly form — suitable for peers and younger friends.',
    },
  ];

  void _onSelect(int index) {
    if (_submitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOption = index;
    });
  }

  void _checkAnswer() {
    HapticFeedback.lightImpact();
    setState(() {
      _submitted = true;
      if (_selectedOption == 1 && !_xpAwarded) {
        _xpAwarded = true;
        ref.read(userProfileProvider.notifier).recordDailyActivity();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Stepper Header ─────────────────────────────────
            _buildTopStepper(context),

            // ── Drill Content ──────────────────────────────────
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: VaaniXSpacing.screenMarginWide,
                  vertical: VaaniXSpacing.md,
                ),
                children: [
                  // 1. VAN Insight Speech Card
                  const VanCompanionBubble(
                    vanState: VanState.focus,
                    badgeRole: VanBadgeRole.mentor,
                    badgeLabel: 'VAN • GRAMMAR INTEL',
                    message:
                        'Remember: "आप" always requires the plural verb agreement "हैं", whereas "तुम" agrees with "हो".',
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 2. Knowledge Contrast Cards
                  const Text(
                    'Reference Formats',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: VaaniXColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildReferenceCard(
                    title: 'Respectful / Formal (आप)',
                    devanagari: 'आप कैसे हैं?',
                    transliteration: 'Aap kaise hain?',
                    isHighlighted: true,
                  ),
                  const SizedBox(height: 8),
                  _buildReferenceCard(
                    title: 'Familiar / Informal (तुम)',
                    devanagari: 'तुम कैसे हो?',
                    transliteration: 'Tum kaise ho?',
                    isHighlighted: false,
                  ),
                  const SizedBox(height: VaaniXSpacing.md),

                  // 3. Audio Cadence Waveform Player
                  const AudioCadenceWaveform(
                    phrase: 'नमस्ते, आप कैसे हैं?',
                    transliteration: 'Cadence: Respectful Elder Tone',
                    durationLabel: '0:03',
                  ),
                  const SizedBox(height: VaaniXSpacing.xl),

                  // 4. Applied Drill Question
                  const Text(
                    'Applied Drill Question',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: VaaniXColors.learnPrimaryViolet,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the appropriate polite phrase to address an elder or teacher:',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: VaaniXColors.textPrimaryLight,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Options
                  for (int i = 0; i < _options.length; i++) ...[
                    _buildOptionTile(i),
                    const SizedBox(height: 10),
                  ],

                  // 6. Inline Feedback Card (When Submitted & Correct)
                  if (_submitted && _selectedOption == 1) ...[
                    const SizedBox(height: 6),
                    _buildRewardFeedbackCard(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Sticky Bottom CTA ──────────────────────────────
            _buildBottomCta(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStepper(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: VaaniXColors.learnBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: VaaniXColors.learnSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: VaaniXColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Segmented Progress (Step 3 of 5)
          Expanded(
            child: Row(
              children: List.generate(5, (index) {
                final isDone = index < 3;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: isDone
                          ? VaaniXColors.learnPrimaryViolet
                          : VaaniXColors.learnBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 14),

          // Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VaaniXColors.telemetryAmber.withValues(alpha: 0.12),
              borderRadius: VaaniXRadius.borderPill,
            ),
            child: const Row(
              children: [
                Text('🔥', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text(
                  '14',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.telemetryAmber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCard({
    required String title,
    required String devanagari,
    required String transliteration,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? VaaniXColors.learnSoftPurple
            : VaaniXColors.learnSurfaceElevated,
        borderRadius: VaaniXRadius.borderMd,
        border: Border.all(
          color: isHighlighted
              ? VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.3)
              : VaaniXColors.learnBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? VaaniXColors.learnPrimaryViolet
                        : VaaniXColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  devanagari,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.textPrimaryLight,
                  ),
                ),
                Text(
                  transliteration,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: VaaniXColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(int index) {
    final opt = _options[index];
    final isSelected = _selectedOption == index;
    final isCorrect = index == 1;

    Color borderColor;
    Color bgColor;

    if (_submitted && isSelected) {
      borderColor = isCorrect
          ? VaaniXColors.telemetryEmerald
          : VaaniXColors.telemetryRose;
      bgColor = isCorrect
          ? VaaniXColors.telemetryEmeraldBg
          : VaaniXColors.telemetryRoseBg;
    } else if (isSelected) {
      borderColor = VaaniXColors.learnPrimaryViolet;
      bgColor = VaaniXColors.learnSoftPurple;
    } else {
      borderColor = VaaniXColors.learnBorder;
      bgColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => _onSelect(index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: VaaniXRadius.borderLg,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.05 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Letter Avatar (A, B, C)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? VaaniXColors.telemetryEmerald
                    : VaaniXColors.learnSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSelected && _submitted
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text(
                        opt['label']!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : VaaniXColors.textPrimaryLight,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Option details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        opt['devanagari']!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: VaaniXColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${opt['transliteration']!})',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: VaaniXColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: VaaniXColors.telemetryEmerald,
                            borderRadius: VaaniXRadius.borderPill,
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_submitted && isSelected) ...[
                    const SizedBox(height: 6),
                    Text(
                      opt['note']!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: isCorrect
                            ? const Color(0xFF065F46)
                            : VaaniXColors.telemetryRose,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VaaniXColors.telemetryEmeraldBg,
        borderRadius: VaaniXRadius.borderLg,
        border: Border.all(
          color: VaaniXColors.telemetryEmerald.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VaaniXColors.telemetryEmerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: VaaniXColors.telemetryEmerald,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+20 Mastery XP Earned!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                Text(
                  'Honorific verb agreement accurately recognized.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: VaaniXColors.learnBorder, width: 1),
        ),
      ),
      child: VaaniXButton(
        label: _submitted ? 'Continue Lesson →' : 'Submit Answer',
        onPressed: () {
          if (!_submitted) {
            _checkAnswer();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}
