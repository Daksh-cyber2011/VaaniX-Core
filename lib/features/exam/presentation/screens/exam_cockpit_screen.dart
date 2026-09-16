/// VaaniX V1 Design System — Exam Dashboard ("Tactical Cockpit")
///
/// Stitch Design Canvas: Screen 3
/// High-Contrast Tactical Dark (#090D16 / #131B2E, Cyan #00E5FF, Cobalt #4F46E5)
///
/// Features:
/// - Candidate Header with pulsing LIVE dot (CBSE Class 10 Hindi Course A)
/// - Twin Telemetry Grid: 74 Days Left & 78% Readiness (+3.6%/wk gauge)
/// - Mission Directive: Surdas ke Pad (सूरदास के पद) 6-8 Marks | 1.8m/Ans
/// - VAN Tactical Intel: Tactical Helmet with 93% match confidence warning
/// - Diagnostic Radar: High-risk alert vs stable topic zones
/// - Simulator & Revision Trays: Timed Mock, 2018-2024 Solved Papers, Rules
/// - Telemetry Status Strip: System Online | Latency: 18ms
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_mode_switch.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';
import 'package:vaanix_app/shared/widgets/van_companion_bubble.dart';

class ExamCockpitScreen extends ConsumerStatefulWidget {
  const ExamCockpitScreen({super.key, this.trackId});

  final String? trackId;

  @override
  ConsumerState<ExamCockpitScreen> createState() => _ExamCockpitScreenState();
}

class _ExamCockpitScreenState extends ConsumerState<ExamCockpitScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final candidateName = profile.resolvedCompanionName.isNotEmpty
        ? profile.resolvedCompanionName
        : 'Daksh Sharma';

    return Scaffold(
      backgroundColor: VaaniXColors.examCanvasBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Tactical Header ────────────────────────────
            _buildTacticalHeader(context, candidateName),

            // ── Scrollable Cockpit Engine ──────────────────────
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: VaaniXSpacing.screenMarginWide,
                  vertical: VaaniXSpacing.md,
                ),
                children: [
                  // 1. Twin Telemetry Grid
                  _buildTwinTelemetry(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 2. Primary Mission Directive Hero Card
                  _buildMissionDirectiveHero(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 3. VAN Tactical Intel Card
                  VanCompanionBubble(
                    isTactical: true,
                    vanState: VanState.focus,
                    badgeRole: VanBadgeRole.tacticalIntel,
                    badgeLabel: 'VAN • TACTICAL INTEL (93% MATCH)',
                    title: 'Past 5-Year Trend Alert',
                    message:
                        'Pada 3 has appeared in 4 out of the last 5 CBSE board papers with 6-mark weightage. Focus on Virodhabhas Alankar analysis.',
                    actionLabel: 'Load Pada 3 Analysis',
                    onActionTap: () {
                      _launchTopic(context, 'pada_3');
                    },
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 4. Diagnostic Status & Radar
                  _buildDiagnosticRadar(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 5. Simulator & Revision Trays
                  _buildSimulatorTrays(context),
                  const SizedBox(height: VaaniXSpacing.lg),

                  // 6. Telemetry System Online Strip
                  _buildSystemTelemetryFooter(),
                  const SizedBox(height: VaaniXSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchTopic(BuildContext context, String topicId) {
    final storeAsync = ref.read(examScopeStoreProvider);
    final activeTrack = storeAsync.valueOrNull?.activeTrackId ??
        widget.trackId ??
        'cbse_10_hindi_a';
    context.pushNamed(
      RouteNames.examStudyName,
      pathParameters: {'trackId': activeTrack, 'topicId': topicId},
    );
  }

  Widget _buildTacticalHeader(BuildContext context, String candidateName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: VaaniXColors.examSurfaceCard,
        border: Border(
          bottom: BorderSide(color: VaaniXColors.examBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Candidate Live Badge
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: VaaniXColors.examCyanAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: VaaniXColors.examCyanAccent.withValues(
                              alpha: 0.3 + (_pulseController.value * 0.5)),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                '$candidateName • ACTIVE CANDIDATE',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VaaniXColors.examCyanAccent,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),

              // Sliding Mode Switch Pill
              const SizedBox(
                width: 140,
                child: VaaniXModeSwitch(compact: true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'CBSE Class 10 Hindi Course A',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: VaaniXColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwinTelemetry(BuildContext context) {
    return Row(
      children: [
        // Left: Exam Countdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VaaniXColors.examSurfaceCard,
              borderRadius: VaaniXRadius.borderLg,
              border: Border.all(color: VaaniXColors.examBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXAM COUNTDOWN',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.textTertiaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '74',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: VaaniXColors.textPrimaryDark,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DAYS LEFT',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: VaaniXColors.examCyanAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Target Readiness: 98%+',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: VaaniXColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right: Readiness Gauge
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VaaniXColors.examSurfaceCard,
              borderRadius: VaaniXRadius.borderLg,
              border: Border.all(color: VaaniXColors.examBorder),
            ),
            child: Row(
              children: [
                const VaaniXRadialGauge(
                  percentage: 78,
                  size: 64,
                  strokeWidth: 6,
                  primaryColor: VaaniXColors.examCyanAccent,
                  deltaText: '+3.6%/wk',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'READINESS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: VaaniXColors.examCyanAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'High Prep Pace',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: VaaniXColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        'Based on 32 drills',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          color: VaaniXColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMissionDirectiveHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VaaniXColors.examSurfaceCard,
        borderRadius: VaaniXRadius.borderLg,
        border: Border.all(
          color: VaaniXColors.examCyanAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: VaaniXColors.examCyanAccent.withValues(alpha: 0.08),
            blurRadius: 16,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VaaniXColors.examCyanAccent.withValues(alpha: 0.15),
                  borderRadius: VaaniXRadius.borderPill,
                ),
                child: const Text(
                  'MISSION DIRECTIVE • HIGH YIELD',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.examCyanAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: VaaniXColors.telemetryAmber.withValues(alpha: 0.15),
                  borderRadius: VaaniXRadius.borderPill,
                ),
                child: const Text(
                  'Unfinished',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: VaaniXColors.telemetryAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'सूरदास के पद (Surdas ke Pad)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kshitij Part 2 • काव्य खंड • Weightage: 6-8 Marks • Target Speed: 1.8m/Ans',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: VaaniXColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // High Contrast Cyan CTA
          VaaniXButton.cyan(
            label: '⚡ Launch Mission Session →',
            onPressed: () {
              _launchTopic(context, 'surdas_ke_pad');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRadar(BuildContext context) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Diagnostic Radar',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: VaaniXColors.textPrimaryDark,
                ),
              ),
              const Spacer(),
              Text(
                'LIVE TELEMETRY',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: VaaniXColors.examCyanAccent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Red Alert Zone
          _DiagnosticBar(
            topic: 'संधि एवं समास (Sandhi & Samas)',
            accuracy: 62,
            isAlert: true,
            statusLabel: 'Critical Attention',
          ),
          const SizedBox(height: 10),

          // Stable Zone
          _DiagnosticBar(
            topic: 'वाक्य भेद (Vakya Bhed)',
            accuracy: 78,
            isAlert: false,
            statusLabel: 'Stable Pace',
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorTrays(BuildContext context) {
    final activeTrack = widget.trackId ?? 'cbse_10_hindi_a';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Simulator & Revision Trays',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: VaaniXColors.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 10),

        // Tray 1: Timed Mock Board Simulator
        _SimulatorTile(
          icon: Icons.timer_outlined,
          title: 'Timed Mock Board Simulator',
          subtitle: 'Official CBSE Step-marking scheme (+4 / -1 rules)',
          tag: 'Calibrated',
          onTap: () {
            context.pushNamed(RouteNames.examMockName,
                pathParameters: {'trackId': activeTrack});
          },
        ),
        const SizedBox(height: 8),

        // Tray 2: Board Question Bank (2018-2024)
        _SimulatorTile(
          icon: Icons.history_edu_rounded,
          title: 'Board Question Bank (2018–2024)',
          subtitle: 'Categorized by weightage & frequency trends',
          tag: 'Official PYQs',
          onTap: () {
            context.pushNamed(RouteNames.examPyqName,
                pathParameters: {'trackId': activeTrack});
          },
        ),
        const SizedBox(height: 8),

        // Tray 3: Grammar & Kavyansh Rule Cheat Sheet
        _SimulatorTile(
          icon: Icons.menu_book_rounded,
          title: 'Grammar & Kavyansh Cheat Sheet',
          subtitle: 'Ras, Alankar, and Samas quick diagnostic notes',
          tag: 'High Yield',
          onTap: () {
            context.pushNamed(RouteNames.examPlanName,
                pathParameters: {'trackId': activeTrack});
          },
        ),
      ],
    );
  }

  Widget _buildSystemTelemetryFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VaaniXColors.examSurfaceCard,
        borderRadius: VaaniXRadius.borderMd,
        border: Border.all(color: VaaniXColors.examBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.terminal_rounded,
            size: 14,
            color: VaaniXColors.examCyanAccent,
          ),
          const SizedBox(width: 8),
          Text(
            'System Status: Cockpit Engine Online | LATENCY: 18ms',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: VaaniXColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticBar extends StatelessWidget {
  const _DiagnosticBar({
    required this.topic,
    required this.accuracy,
    required this.isAlert,
    required this.statusLabel,
  });

  final String topic;
  final int accuracy;
  final bool isAlert;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final color =
        isAlert ? VaaniXColors.telemetryRose : VaaniXColors.examCyanAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                topic,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: VaaniXColors.textPrimaryDark,
                ),
              ),
            ),
            Text(
              '$accuracy% · $statusLabel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracy / 100.0,
            minHeight: 5,
            backgroundColor: VaaniXColors.examSurfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SimulatorTile extends StatelessWidget {
  const _SimulatorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: VaaniXColors.examSurfaceCard,
          borderRadius: VaaniXRadius.borderMd,
          border: Border.all(color: VaaniXColors.examBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VaaniXColors.examSurfaceElevated,
                borderRadius: VaaniXRadius.borderSm,
              ),
              child: Icon(icon, size: 20, color: VaaniXColors.examCyanAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: VaaniXColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: VaaniXColors.examCyanAccent
                              .withValues(alpha: 0.15),
                          borderRadius: VaaniXRadius.borderPill,
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: VaaniXColors.examCyanAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: VaaniXColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: VaaniXColors.textTertiaryDark,
            ),
          ],
        ),
      ),
    );
  }
}
