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
///  * Readiness: aggregate qualitative band from real `TopicMastery`
///    evidence; never a hardcoded percentage
///  * Mission directive: first official chapter from the active track's
///    prescribed books; chapter title + section title + totalMarks from
///    the canonical syllabus (no fabricated "6-8 Marks" / "1.8m/Ans")
///  * Diagnostic bars: top two findings by attempt volume, only when
///    real evidence exists; honest "—" when no evidence
///  * VAN intel: removed (no real per-PYQ trend analysis exists; the
///    shipped PYQ registry is intentionally empty per §25)
///  * System footer: real online status without a fabricated latency
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
    show TopicMastery, TopicStage;
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_hub_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/vaanix_mode_switch.dart';
import 'package:vaanix_app/shared/widgets/vaanix_radial_gauge.dart';

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

    final topicLookup = _TopicLookup.build(
      syllabus: syllabusAsync.valueOrNull,
    );

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
                    topicLookup,
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
        : '${_boardLabel(syllabus.board.value)} • '
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
    final readiness = _ExamCockpitHelpers.readinessFromHub(hubSnapshot);

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
                  percentage: readiness.percent,
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
    final mission = _ExamCockpitHelpers.primaryChapter(syllabus);

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
    _TopicLookup topicLookup,
  ) {
    final bars = _ExamCockpitHelpers.diagnosticBars(
      overview: overview,
      learner: learner,
      topicLookup: topicLookup,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.terminal_rounded,
            size: 14,
            color: VaaniXColors.examCyanAccent,
          ),
          const SizedBox(width: 8),
          const Text(
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

// ─── helpers (pure functions, unit-testable) ──────────────────────────────────

class _TopicLookup {
  const _TopicLookup(this._byId);

  final Map<String, SyllabusItem> _byId;

  static _TopicLookup build({CourseSyllabus? syllabus}) {
    if (syllabus == null) return const _TopicLookup({});
    return _TopicLookup({
      for (final item in syllabus.allItems) item.id: item,
    });
  }

  String titleFor(String topicId) {
    final item = _byId[topicId];
    if (item == null) return topicId;
    return item.title.isNotEmpty ? item.title : topicId;
  }
}

/// Translates the active readiness-band into a number for the radial gauge
/// and an honest headline/subline for the student. All numbers come from
/// real existing state — `hubSnapshot?.profile` (per `ExamHubSnapshot`)
/// or fall through to "—".
@visibleForTesting
class ReadinessSummary {
  const ReadinessSummary({
    required this.percent,
    required this.headline,
    required this.subline,
    required this.deltaText,
  });

  /// 0..100 (clamped, integer). 0 when no evidence.
  final int percent;

  /// Qualitative headline.
  final String headline;

  /// Honest context line ("Based on N drills" or "No drills yet — start your first session").
  final String subline;

  /// Optional small label shown inside the radial gauge.
  final String? deltaText;
}

@visibleForTesting
ReadinessSummary readinessSummaryFromHub(ExamHubSnapshot? hub) =>
    _ExamCockpitHelpers.readinessFromHub(hub);

@visibleForTesting
List<DiagnosticBarDatum> diagnosticBarsFromOverview({
  required WeakAreaOverview? overview,
  required ExamLearnerProfile? learner,
  CourseSyllabus? syllabus,
}) =>
    _ExamCockpitHelpers.diagnosticBars(
      overview: overview,
      learner: learner,
      topicLookup: _TopicLookup.build(syllabus: syllabus),
    );

@visibleForTesting
PrimaryChapter? primaryChapterFromSyllabus(CourseSyllabus? syllabus) =>
    _ExamCockpitHelpers.primaryChapter(syllabus);

@visibleForTesting
String boardLabelOf(String boardId) =>
    _ExamCockpitHelpers.boardLabel(boardId);

class _ExamCockpitHelpers {
  static ReadinessSummary readinessFromHub(ExamHubSnapshot? hub) {
    // The hub has no per-attempt evidence: derive an honest day-aware
    // summary from the readiness anchor / plan only. Numerical drill
    // counts live on `ExamLearnerProfile`, exposed through the cockpit
    // by wiring it explicitly when desired (see [TopicMastery]).
    final daysLeft = hub?.readinessDaysLeft;
    if (hub == null || hub.profile == null) {
      return const ReadinessSummary(
        percent: 0,
        headline: 'No data yet',
        subline: 'Start your first session',
        deltaText: '—',
      );
    }
    if (daysLeft == null) {
      return const ReadinessSummary(
        percent: 0,
        headline: 'Set a readiness anchor',
        subline: 'Tell VaaniX when you want to be exam-ready',
        deltaText: '—',
      );
    }
    if (daysLeft < 0) {
      return ReadinessSummary(
        percent: 0,
        headline: 'Anchor has passed',
        subline: 'Re-set your readiness anchor in Profile',
        deltaText: 'overdue',
      );
    }
    // The hub tracks plans and PYQ/mock counts as evidence of activity.
    final pyq = hub.pyqAttemptedTotal;
    final mock = hub.mockCount;
    final activityLines = <String>[];
    if (pyq > 0) activityLines.add('$pyq PYQ attempt${pyq == 1 ? '' : 's'}');
    if (mock > 0) activityLines.add('$mock mock${mock == 1 ? '' : 's'}');
    final evidenceLine = activityLines.isEmpty
        ? 'No graded attempts yet'
        : activityLines.join(' · ');
    return ReadinessSummary(
      percent: 0, // No qualitative %: readiness is window-derived, not %.
      headline: daysLeft == 0
          ? 'Readiness target is today'
          : '$daysLeft day${daysLeft == 1 ? '' : 's'} to readiness',
      subline: evidenceLine,
      deltaText: '${daysLeft}d',
    );
  }

  static List<DiagnosticBarDatum> diagnosticBars({
    required WeakAreaOverview? overview,
    required ExamLearnerProfile? learner,
    required _TopicLookup topicLookup,
  }) {
    if (overview == null) return const [];
    // Build evidence rows from the engine's findings + the matching
    // TopicMastery (real attempt / correct counts). Findings without
    // learner evidence are intentionally skipped — §21 needs ≥ 2 attempts.
    final rows = <_BarRow>[];
    for (final finding in overview.report.findings) {
      final mastery = learner?.topics[finding.topicId];
      if (mastery == null || mastery.attemptCount < 2) continue;
      final pct = mastery.attemptCount == 0
          ? 0
          : ((mastery.correctCount / mastery.attemptCount) * 100)
              .round()
              .clamp(0, 100);
      rows.add(_BarRow(
        topicTitle: topicLookup.titleFor(finding.topicId),
        percent: pct,
        attempts: mastery.attemptCount,
        stage: mastery.stage,
      ));
    }
    // Order by most-attempted first — the bars reflect real evidence
    // order, not a fabricated rank.
    rows.sort((a, b) => b.attempts.compareTo(a.attempts));
    return [
      for (final r in rows.take(2))
        DiagnosticBarDatum(
          topicTitle: r.topicTitle,
          percent: r.percent,
          stageLabel: _stageLabel(r.stage),
          attempts: r.attempts,
          isAlert: r.stage == TopicStage.needsAttention ||
              r.stage == TopicStage.needsReview,
        ),
    ];
  }

  static PrimaryChapter? primaryChapter(CourseSyllabus? syllabus) {
    if (syllabus == null) return null;
    for (final book in syllabus.books) {
      if (book.chapters.isEmpty) continue;
      final chapter = book.chapters.first;
      final section = _findSectionForBook(syllabus, book.id);
      final marks = section == null ? null : section.marks;
      return PrimaryChapter(
        chapter: chapter,
        bookTitle: book.title,
        sectionTitle: section?.title ?? '',
        sectionMarks: marks,
      );
    }
    // Fall back: if no chapters are published yet, surface the first
    // official syllabus item as the primary scope (Class 9 pending-
    // official literature path uses this).
    final items = syllabus.allItems;
    if (items.isNotEmpty) {
      final first = items.first;
      final section = syllabus.sections.firstWhere(
        (s) => s.id == first.sectionId,
        orElse: () => syllabus.sections.isNotEmpty
            ? syllabus.sections.first
            : const _EmptySection(),
      );
      final marks = section is _EmptySection ? null : section.marks;
      return PrimaryChapter(
        chapter: SyllabusChapter(
          id: first.id,
          number: 0,
          title: first.title.isNotEmpty ? first.title : first.id,
          type: 'item',
        ),
        bookTitle: section is _EmptySection ? '' : section.title,
        sectionTitle: section is _EmptySection ? '' : section.title,
        sectionMarks: marks,
      );
    }
    return null;
  }

  static SyllabusSection? _findSectionForBook(
      CourseSyllabus syllabus, String bookId) {
    // Books do not have a direct section mapping in the canonical
    // syllabus JSON; the chapters are inside the book and the marks
    // are derived from the section that contains the SAME prefix as
    // the chapter ids (e.g. kshitij_01 → kshitij section).
    final id = bookId.toLowerCase();
    for (final s in syllabus.sections) {
      final sid = s.id.toLowerCase();
      if (sid.contains(id) || id.contains(sid)) return s;
    }
    return syllabus.sections.isNotEmpty ? syllabus.sections.first : null;
  }

  static String boardLabel(String boardId) {
    switch (boardId) {
      case 'cbse':
        return 'CBSE';
      case 'icse':
        return 'ICSE';
      default:
        return boardId.toUpperCase();
    }
  }

  static String _stageLabel(TopicStage stage) {
    switch (stage) {
      case TopicStage.learning:
        return 'Learning';
      case TopicStage.practicing:
        return 'Practicing';
      case TopicStage.strong:
        return 'Strong';
      case TopicStage.mastered:
        return 'Mastered';
      case TopicStage.needsAttention:
        return 'Needs attention';
      case TopicStage.needsReview:
        return 'Needs review';
    }
  }
}

class _BarRow {
  const _BarRow({
    required this.topicTitle,
    required this.percent,
    required this.attempts,
    required this.stage,
  });

  final String topicTitle;
  final int percent;
  final int attempts;
  final TopicStage stage;
}

String _boardLabel(String boardId) => _ExamCockpitHelpers.boardLabel(boardId);

/// One row in the diagnostic radar — derived from a real
/// [WeakTopicFinding] + matching [TopicMastery].
@visibleForTesting
class DiagnosticBarDatum {
  const DiagnosticBarDatum({
    required this.topicTitle,
    required this.percent,
    required this.stageLabel,
    required this.attempts,
    required this.isAlert,
  });

  final String topicTitle;

  /// 0..100, rounded. 0 when no attempts have been recorded.
  final int percent;

  /// Honest qualitative band label.
  final String stageLabel;

  /// Real attempt count behind the band.
  final int attempts;

  /// True when the student should focus on this topic next.
  final bool isAlert;
}

/// The cockpit's primary chapter — first prescribed-book chapter of the
/// active track.
@visibleForTesting
class PrimaryChapter {
  const PrimaryChapter({
    required this.chapter,
    required this.bookTitle,
    required this.sectionTitle,
    required this.sectionMarks,
  });

  final SyllabusChapter chapter;
  final String bookTitle;
  final String sectionTitle;
  final dynamic sectionMarks;

  String get title => chapter.title;

  String get subtitle {
    final parts = <String>[];
    if (bookTitle.isNotEmpty) parts.add(bookTitle);
    if (sectionTitle.isNotEmpty && sectionTitle != bookTitle) {
      parts.add(sectionTitle);
    }
    if (sectionMarks is num) {
      final m = (sectionMarks as num).toInt();
      if (m > 0) parts.add('$m marks board scope');
    }
    return parts.isEmpty
        ? 'No metadata yet — open syllabus for chapter details'
        : parts.join(' • ');
  }
}

class _EmptySection extends SyllabusSection {
  const _EmptySection()
      : super(
          id: '',
          stableKey: '',
          title: '',
          titleEn: '',
          marks: 0,
          assessmentType: AssessmentType.board,
        );
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
