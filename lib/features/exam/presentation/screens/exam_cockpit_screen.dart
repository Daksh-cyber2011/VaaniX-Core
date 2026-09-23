/// VaaniX V1 Design System — Exam Dashboard ("Tactical Cockpit")
///
/// Stitch Design Canvas: Screen 3
/// High-Contrast Tactical Dark (#090D16 / #131B2E, Cyan #00E5FF, Cobalt #4F46E5)
///
/// Phase 1: every dynamic-looking student metric is derived from real
/// existing state (syllabus, exam scope, exam learner profile, weak-area
/// engine). Where no legitimate source exists we now show an honest
/// empty / not-started state instead of a fabricated number.
///
///  * Header course name: `CourseSyllabus.subjectName / courseName`
///  * Countdown: `ExamHubSnapshot.readinessDaysLeft` (or "—" when unset)
///  * Readiness: window-derived from the real readiness anchor; never a
///    hardcoded percentage / "High Prep Pace"
///  * Mission directive: first official chapter from the active track's
///    prescribed books; chapter title + section title + totalMarks from
///    the canonical syllabus (no fabricated "6-8 Marks" / "1.8m/Ans")
///  * Diagnostic bars: top two findings by attempt volume, only when
///    real evidence exists; honest "No attempts yet" when no evidence
///  * VAN intel: removed (no real per-PYQ trend analysis exists; the
///    shipped PYQ registry is intentionally empty per §25)
///  * System footer: real online status without a fabricated latency
///
/// All state-derivation logic lives in
/// [exam_cockpit_helpers.dart] (pure functions, fully unit-tested).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_loader.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart'
    show ExamLearnerProfile;
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_hub_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_mode_switch.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';

import 'exam_cockpit_helpers.dart';

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

  String _resolveTrackId() {
    final storeAsync = ref.read(examScopeStoreProvider);
    return storeAsync.valueOrNull?.activeTrackId ??
        widget.trackId ??
        'cbse_10_hindi_a';
  }

  void _launchTopic(BuildContext context, String topicId) {
    context.pushNamedUnique(
      RouteNames.examStudyName,
      pathParameters: {'trackId': _resolveTrackId(), 'topicId': topicId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final learnerName = profile.resolvedDisplayName;
    final candidateLabel = learnerName.isEmpty
        ? 'ACTIVE CANDIDATE'
        : '$learnerName • ACTIVE CANDIDATE';

    final trackId = _resolveTrackId();
    final syllabusAsync = ref.watch(courseSyllabusProvider(trackId));
    final hubSnapshotAsync = ref.watch(examHubSnapshotProvider(trackId));
    final learnerAsync = ref.watch(examLearnerProfileProvider(trackId));
    final weakOverviewAsync = ref.watch(weakAreaOverviewProvider(trackId));

    return Scaffold(
      backgroundColor: VaaniXColors.examCanvasBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTacticalHeader(
              context,
              candidateLabel,
              syllabusAsync.valueOrNull,
            ),

            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: VaaniXSpacing.screenMarginWide,
                  vertical: VaaniXSpacing.md,
                ),
                children: [
                  _buildTwinTelemetry(hubSnapshotAsync.valueOrNull),
                  const SizedBox(height: VaaniXSpacing.lg),
                  _buildMissionDirectiveHero(
                    context,
                    syllabusAsync.valueOrNull,
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),
                  _buildDiagnosticRadar(
                    weakOverviewAsync.valueOrNull,
                    learnerAsync.valueOrNull,
                    syllabusAsync.valueOrNull,
                  ),
                  const SizedBox(height: VaaniXSpacing.lg),
                  _buildSimulatorTrays(context),
                  const SizedBox(height: VaaniXSpacing.lg),
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

  Widget _buildTacticalHeader(
    BuildContext context,
    String candidateLabel,
    CourseSyllabus? syllabus,
  ) {
    final courseLine = syllabus == null
        ? 'Loading syllabus…'
        : '${boardLabel(syllabus.board.value)} • '
            'Class ${syllabus.klass} • '
            '${syllabus.subjectName}'
            '${syllabus.courseName.isNotEmpty ? ' ${syllabus.courseName}' : ''}';

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
              Flexible(
                child: Text(
                  candidateLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.examCyanAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 140,
                child: VaaniXModeSwitch(compact: true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            courseLine,
            style: const TextStyle(
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

  Widget _buildTwinTelemetry(ExamHubSnapshot? hubSnapshot) {
    final daysLeft = hubSnapshot?.readinessDaysLeft;
    final readiness = readinessFromHub(hubSnapshot);

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
                const Text(
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
                    Text(
                      daysLeft == null ? '—' : '$daysLeft',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: VaaniXColors.textPrimaryDark,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
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
                  daysLeft == null
                      ? 'Set your exam date in Profile to see countdown'
                      : 'Until board exam',
                  style: const TextStyle(
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

        // Right: Readiness Gauge (real aggregate, qualitative)
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
                VaaniXRadialGauge(
                  percentage: readiness.percent.toDouble(),
                  size: 64,
                  strokeWidth: 6,
                  primaryColor: VaaniXColors.examCyanAccent,
                  deltaText: readiness.deltaText,
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
                      Text(
                        readiness.headline,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: VaaniXColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        readiness.subline,
                        style: const TextStyle(
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

  Widget _buildMissionDirectiveHero(
    BuildContext context,
    CourseSyllabus? syllabus,
  ) {
    final mission = primaryChapter(syllabus);

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
                  'PRIMARY CHAPTER',
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
              if (mission != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: VaaniXColors.telemetryAmber.withValues(alpha: 0.15),
                    borderRadius: VaaniXRadius.borderPill,
                  ),
                  child: const Text(
                    'Board scope',
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
          Text(
            mission?.title ?? 'No prescribed chapter available yet',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VaaniXColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mission?.subtitle ?? 'Syllabus is still loading.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: VaaniXColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          VaaniXButton.cyan(
            label: mission == null
                ? 'Open syllabus'
                : 'Open ${mission.title}',
            onPressed: () {
              if (mission != null) {
                _launchTopic(context, mission.chapter.id);
              } else {
                context.pushNamedUnique(
                  RouteNames.examScopeName,
                  pathParameters: {'trackId': _resolveTrackId()},
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRadar(
    WeakAreaOverview? overview,
    ExamLearnerProfile? learner,
    CourseSyllabus? syllabus,
  ) {
    final bars = diagnosticBars(
      overview: overview,
      learner: learner,
      syllabus: syllabus,
    );

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
                bars.isEmpty ? 'AWAITING DATA' : 'EVIDENCE-BACKED',
                style: const TextStyle(
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
          if (bars.isEmpty)
            const _DiagnosticEmpty()
          else ...[
            for (var i = 0; i < bars.length; i++) ...[
              _DiagnosticBar(
                topic: bars[i].topicTitle,
                percent: bars[i].percent,
                stageLabel: bars[i].stageLabel,
                attempts: bars[i].attempts,
                isAlert: bars[i].isAlert,
              ),
              if (i != bars.length - 1) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSimulatorTrays(BuildContext context) {
    final activeTrack = _resolveTrackId();

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
        _SimulatorTile(
          icon: Icons.timer_outlined,
          title: 'Timed Mock Board Simulator',
          subtitle: 'Official CBSE Step-marking scheme (+4 / -1 rules)',
          tag: 'Calibrated',
          onTap: () {
            context.pushNamedUnique(RouteNames.examMockName,
                pathParameters: {'trackId': activeTrack});
          },
        ),
        const SizedBox(height: 8),
        _SimulatorTile(
          icon: Icons.history_edu_rounded,
          title: 'Board Question Bank (PYQ patterns)',
          subtitle: 'Grounded in the official exam pattern registry',
          tag: 'PYQ patterns',
          onTap: () {
            context.pushNamedUnique(RouteNames.examPyqName,
                pathParameters: {'trackId': activeTrack});
          },
        ),
        const SizedBox(height: 8),
        _SimulatorTile(
          icon: Icons.menu_book_rounded,
          title: 'Grammar & Kavyansh Cheat Sheet',
          subtitle: 'Ras, Alankar, and Samas quick diagnostic notes',
          tag: 'High Yield',
          onTap: () {
            context.pushNamedUnique(RouteNames.examPlanName,
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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal_rounded,
            size: 14,
            color: VaaniXColors.examCyanAccent,
          ),
          SizedBox(width: 8),
          Text(
            'System Status: Cockpit Engine Online',
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
    required this.percent,
    required this.stageLabel,
    required this.attempts,
    required this.isAlert,
  });

  final String topic;
  final int percent;
  final String stageLabel;
  final int attempts;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final color =
        isAlert ? VaaniXColors.telemetryRose : VaaniXColors.examCyanAccent;
    final safePercent = percent.clamp(0, 100);
    final safeAttempts = attempts.clamp(0, 1 << 30);

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
              '$stageLabel · $safePercent% on $safeAttempts '
              'attempt${safeAttempts == 1 ? '' : 's'}',
              textAlign: TextAlign.right,
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
            value: safePercent / 100.0,
            minHeight: 5,
            backgroundColor: VaaniXColors.examSurfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticEmpty extends StatelessWidget {
  const _DiagnosticEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: VaaniXColors.examSurfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'No topic attempts yet — start a PYQ or mock session to see '
        'your real diagnostic radar.',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: VaaniXColors.textSecondaryDark,
          height: 1.4,
        ),
      ),
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
              decoration: const BoxDecoration(
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
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: VaaniXColors.textPrimaryDark,
                          ),
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
                    style: const TextStyle(
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
