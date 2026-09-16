/// VaaniX V1 Design System — Chapter Study & Modular Vyakhya
///
/// Stitch Design Canvas: Screen 6
/// Structured Academic (#F8FAFC)
///
/// Features:
/// - Breadcrumb Header: CBSE Class 10 Hindi Course A > Kshitij Part 2 • काव्य खंड
/// - Filter Chips: All, Unsolved Doubts (2), High Yield
/// - Chapter Summary Card: Surdas ke Pad (सूरदास के पद), 6 Marks, 75% Readiness, VAN diagnostic
/// - Historical Context Art Carousel: Bhakti Kaal Context & Bhramargeet Saar
/// - Concepts & Vyakhya Core: Pad 1 (Mastered), Pad 2 (In Progress), Pad 3 & 4 (Locked)
/// - Targeted Combat Practice: CBSE 3-Mark Simulator & Rapid Diagnostic
/// - Sticky Bottom Bar: "Complete Pad 2 Vyakhya" + "Begin Drill ⚡"
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';

class ChapterStudyScreen extends ConsumerStatefulWidget {
  const ChapterStudyScreen({
    super.key,
    this.trackId = 'cbse_10_hindi_a',
    this.topicId = 'surdas_ke_pad',
  });

  final String trackId;
  final String topicId;

  @override
  ConsumerState<ChapterStudyScreen> createState() => _ChapterStudyScreenState();
}

class _ChapterStudyScreenState extends ConsumerState<ChapterStudyScreen> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaaniXColors.learnCanvasBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Breadcrumb Header ──────────────────────────
            _buildBreadcrumbHeader(context),

            // ── Scrollable Chapter Study Body ──────────────────
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: VaaniXSpacing.screenMarginWide,
                  vertical: VaaniXSpacing.md,
                ),
                children: [
                  // 1. Filter Chips Tray
                  _buildFilterTray(),
                  const SizedBox(height: VaaniXSpacing.md),

                  // 2. Chapter Overview Card
                  _buildChapterOverviewCard(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 3. Historical Artifact Thumbnails
                  _buildHistoricalContextArtifacts(),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 4. Concepts & Vyakhya Core (Modular Breakdown)
                  _buildConceptsVyakhyaCore(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 5. Targeted Combat Practice
                  _buildTargetedCombatPractice(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Sticky Bottom Recommended Step ────────────────
            _buildStickyBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbHeader(BuildContext context) {
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
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: VaaniXColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CBSE Class 10 Hindi Course A > Kshitij Part 2',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: VaaniXColors.learnPrimaryViolet,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'काव्य खंड • सूरदास के पद',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search Topic',
            icon: const Icon(Icons.search_rounded, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTray() {
    final filters = ['All', 'Unsolved Doubts (2)', 'High Yield'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              labelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? Colors.white : VaaniXColors.textSecondaryLight,
              ),
              selectedColor: VaaniXColors.learnPrimaryViolet,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? VaaniXColors.learnPrimaryViolet
                    : VaaniXColors.learnBorder,
              ),
              onSelected: (val) {
                if (val) setState(() => _activeFilter = f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChapterOverviewCard(BuildContext context) {
    return VaaniXCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VaaniXColors.examSurface,
                        borderRadius: VaaniXRadius.borderPill,
                      ),
                      child: const Text(
                        'BOARD WEIGHTAGE: 6 MARKS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: VaaniXColors.examPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Surdas ke Pad',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: VaaniXColors.textPrimaryLight,
                      ),
                    ),
                    const Text(
                      'भ्रमरगीत सार से चयनित चार पद',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: VaaniXColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const VaaniXRadialGauge(
                percentage: 75,
                size: 64,
                strokeWidth: 6,
                primaryColor: VaaniXColors.telemetryEmerald,
                subtitle: 'Prep: 75%',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Diagnostic Callout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VaaniXColors.learnSurfaceElevated,
              borderRadius: VaaniXRadius.borderMd,
              border: Border.all(color: VaaniXColors.learnBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: VaaniXColors.telemetryAmber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VAN Alert: Focus on Virodhabhas Alankar in Pad 2 for full 3-mark CBSE step-scoring.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      color: VaaniXColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalContextArtifacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historical & Literary Context',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: VaaniXColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ContextArtifactTile(
                title: 'Bhakti Kaal Context',
                subtitle: 'Sagun vs Nirgun Bhakti traditions',
                icon: Icons.auto_stories_rounded,
                tintColor: VaaniXColors.learnSoftPurple,
                primaryColor: VaaniXColors.learnPrimaryViolet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContextArtifactTile(
                title: 'Bhramargeet Saar',
                subtitle: 'Gopi-Uddhav dialogue dynamics',
                icon: Icons.psychology_alt_rounded,
                tintColor: VaaniXColors.telemetryAmberBg,
                primaryColor: VaaniXColors.telemetryAmber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConceptsVyakhyaCore(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Concepts & Vyakhya Core',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: VaaniXColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),

        // Pad 1 (Mastered)
        _PadModuleCard(
          title: 'Pad 1: उधौ, तुम हौ अति बड़भागी',
          subtitle: 'Kamal patra & Tel ki gaagar analogies',
          isMastered: true,
          statusText: 'Mastered ✓',
          actionLabel: 'Review Notes',
          onTap: () {},
        ),
        const SizedBox(height: 8),

        // Pad 2 (In Progress)
        _PadModuleCard(
          title: 'Pad 2: मन की मन ही माँझ रही',
          subtitle: 'Virah vedna & Maryada na lahi concept',
          isInProgress: true,
          statusText: 'In Progress • 12m drill left',
          actionLabel: 'Continue Drill →',
          onTap: () {
            context.pushNamed(
              RouteNames.examPracticeName,
              pathParameters: {'trackId': widget.trackId},
              queryParameters: {'topic': 'pad_2'},
            );
          },
        ),
        const SizedBox(height: 8),

        // Pad 3 & 4 (Locked)
        _PadModuleCard(
          title: 'Pad 3 & 4: हमारैं हरि हारिल की लकरी',
          subtitle: 'Karam man vachan nandanandan ur',
          isLocked: true,
          statusText: 'Locked • Complete Pad 2 first',
          actionLabel: 'Locked',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildTargetedCombatPractice(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Targeted Combat Practice',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: VaaniXColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        VaaniXCard(
          padding: const EdgeInsets.all(14),
          onTap: () {
            context.pushNamed(
              RouteNames.examPracticeName,
              pathParameters: {'trackId': widget.trackId},
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VaaniXColors.examSurface,
                  borderRadius: VaaniXRadius.borderMd,
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: VaaniXColors.examPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CBSE 3-Mark Question Simulator',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Step-marking calibrated with live feedback',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
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
        const SizedBox(height: 8),
        VaaniXCard(
          padding: const EdgeInsets.all(14),
          onTap: () {
            context.pushNamed(
              RouteNames.examPracticeName,
              pathParameters: {'trackId': widget.trackId},
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VaaniXColors.telemetryEmeraldBg,
                  borderRadius: VaaniXRadius.borderMd,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: VaaniXColors.telemetryEmerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapid Grammatical Diagnostic',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Vakya Rachna & Sandhi quick diagnostic',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
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
      ],
    );
  }

  Widget _buildStickyBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: VaaniXColors.learnBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Recommended Next Step',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: VaaniXColors.textSecondaryLight,
                  ),
                ),
                Text(
                  'Complete Pad 2 Vyakhya',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          VaaniXButton(
            label: 'Begin Drill ⚡',
            isFullWidth: false,
            height: 40,
            onPressed: () {
              context.pushNamed(
                RouteNames.examPracticeName,
                pathParameters: {'trackId': widget.trackId},
                queryParameters: {'topic': 'pad_2'},
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContextArtifactTile extends StatelessWidget {
  const _ContextArtifactTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tintColor,
    required this.primaryColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tintColor;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: VaaniXRadius.borderMd,
        border: Border.all(color: VaaniXColors.learnBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tintColor,
              borderRadius: VaaniXRadius.borderSm,
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: VaaniXColors.textSecondaryLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PadModuleCard extends StatelessWidget {
  const _PadModuleCard({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.actionLabel,
    required this.onTap,
    this.isMastered = false,
    this.isInProgress = false,
    this.isLocked = false,
  });

  final String title;
  final String subtitle;
  final String statusText;
  final String actionLabel;
  final VoidCallback onTap;
  final bool isMastered;
  final bool isInProgress;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Widget statusIcon;

    if (isMastered) {
      statusColor = VaaniXColors.telemetryEmerald;
      statusIcon = const Icon(Icons.check_circle_rounded,
          color: VaaniXColors.telemetryEmerald, size: 18);
    } else if (isInProgress) {
      statusColor = VaaniXColors.learnPrimaryViolet;
      statusIcon = const Icon(Icons.play_circle_fill_rounded,
          color: VaaniXColors.learnPrimaryViolet, size: 18);
    } else {
      statusColor = VaaniXColors.textTertiaryLight;
      statusIcon = const Icon(Icons.lock_rounded,
          color: VaaniXColors.textTertiaryLight, size: 16);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: VaaniXRadius.borderMd,
        border: Border.all(
          color: isInProgress
              ? VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.4)
              : VaaniXColors.learnBorder,
          width: isInProgress ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statusIcon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isLocked
                        ? VaaniXColors.textTertiaryLight
                        : VaaniXColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: VaaniXColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isLocked)
            TextButton(
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VaaniXColors.learnPrimaryViolet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
