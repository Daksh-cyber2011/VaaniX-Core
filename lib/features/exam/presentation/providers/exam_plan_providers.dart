/// Exam Mode 2.0 — Plan Providers (M5, §17/§33; M8 weak-area feed)
///
/// The §17 fallback chain, wired:
///
///   GeminiExamPlanner  →  cached plan  →  DeterministicExamPlanner
///   (AI, validated)       (fresh+same     (always available,
///                          revision)       honest source label)
///
/// Every accepted plan is persisted (write-through cache). Replanning
/// triggers (§33): scope revision changed, plan older than the rolling
/// window, or an explicit student request.
///
/// M8: when weak-area evidence exists, both planner hops receive it —
/// the Gemini prompt gets a bounded §21/§22/§23 digest, and the
/// deterministic planner gets the full decision + revision schedule
/// (recovery-day reservation + spaced review tasks).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/planner/deterministic_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/planner/exam_plan_repository.dart';
import 'package:vaanix_app/features/exam/data/planner/gemini_exam_planner.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/planner/exam_plan_models.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_profile_providers.dart'
    show examProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart'
    show WeakAreaOverview, computeWeakAreaOverview;
import 'package:vaanix_app/features/learn/data/gemini_planner.dart'
    show GeminiPlannerTextClient;

final examPlanRepositoryProvider = Provider<ExamPlanRepository>((ref) {
  return ExamPlanRepository(ref.watch(localStorageServiceProvider));
});

/// Live plan state for one track.
class ExamPlanState {
  const ExamPlanState({
    required this.plan,
    required this.building,
    required this.notice,
  });

  final ExamPlan? plan;
  final bool building;

  /// Honest status line (§63): "AI plan", "offline plan", "cached
  /// plan" — never a fake "AI" label on deterministic output.
  final String? notice;

  bool get hasPlan => plan != null && plan!.days.isNotEmpty;
}

class ExamPlanController extends FamilyAsyncNotifier<ExamPlanState, String> {
  late ExamPlanRepository _planRepo;
  late GeminiExamPlanner _aiPlanner;

  @override
  Future<ExamPlanState> build(String trackId) async {
    _planRepo = ref.watch(examPlanRepositoryProvider);
    _aiPlanner = GeminiExamPlanner(
      textClient: GeminiPlannerTextClient(),
      onPlanAccepted: (plan) {
        // Write-through cache: the NEXT outage serves this plan (§17).
        try {
          _planRepo.save(plan, markCached: true);
        } catch (_) {
          // Best-effort by contract.
        }
      },
    );
    final cached = await _planRepo.load(trackId);
    return ExamPlanState(plan: cached, building: false, notice: null);
  }

  /// Builds a plan through the fallback chain. Requires scope (M2) +
  /// exam profile (M3); uses the diagnostic when present (M4) and
  /// works honestly without it (marks-weighted ordering).
  Future<void> buildPlan() async {
    final trackId = arg;
    final scope = await ref.read(examScopeProvider(trackId).future);
    final syllabus = await ref.read(courseSyllabusProvider(trackId).future);
    final profileRepo = ref.read(examProfileRepositoryProvider);
    final profile = await profileRepo.load(trackId);

    if (syllabus == null || scope.selection.isEmpty) {
      state = AsyncData(ExamPlanState(
        plan: state.value?.plan,
        building: false,
        notice: 'पहले syllabus का दायरा चुनें — उसके बिना योजना नहीं बनती।',
      ));
      return;
    }
    if (profile == null || !profile.isValid) {
      state = AsyncData(ExamPlanState(
        plan: state.value?.plan,
        building: false,
        notice: 'पहले exam profile पूरा करें (readiness + समय) — योजना उसी '
            'समय में बनेगी।',
      ));
      return;
    }

    state = AsyncData(ExamPlanState(
      plan: state.value?.plan,
      building: true,
      notice: null,
    ));

    final learner = await ref.read(examLearnerProfileProvider(trackId).future);

    // M8: the weak-area overview (best-effort — a storage hiccup must
    // never block planning; the plan degrades to the pre-M8 behavior).
    WeakAreaOverview? overview;
    try {
      overview = await computeWeakAreaOverview(ref, trackId);
    } catch (_) {
      overview = null;
    }
    final digest = <String>[];
    if (overview != null) {
      for (final f in overview.report.findings) {
        digest.add(
            '- weak topic ${f.topicId}: ${f.severity.name} '
            '(${f.signals.map((s) => s.name).join('+')})');
      }
      if (overview.decision.shouldRecover) {
        digest.add(
            '- recommended recovery day: dayIndex ${overview.decision.dayIndex} '
            '(focus topic ${overview.decision.focusTopicId})');
      }
      final due = overview.dueRevision(limit: 5);
      if (due.isNotEmpty) {
        digest.add(
            '- due revision topics: ${due.map((d) => d.topicId).join(', ')}');
      }
    }

    final ctx = ExamPlannerContext(
      trackId: trackId,
      view: scope.view!,
      selection: scope.selection,
      profile: profile,
      learner: learner,
      scopeRevision: scope.selection.revision,
      weakAreaDigest: digest,
    );

    // Hop 1: Gemini (validated inside, §16 checks).
    ExamPlan? aiPlan;
    final aiResult = await _aiPlanner.buildPlan(ctx);
    aiResult.fold(
      (_) {},
      (plan) => aiPlan = plan,
    );
    if (aiPlan != null) {
      state = AsyncData(ExamPlanState(
        plan: aiPlan,
        building: false,
        notice: null,
      ));
      return;
    }

    // Hop 2: cached plan (fresh + same revision, §33 trigger).
    final cached =
        await _planRepo.loadUsableCached(trackId, scope.selection.revision);
    if (cached != null) {
      state = AsyncData(ExamPlanState(
        plan: cached,
        building: false,
        notice: 'AI इस समय उपलब्ध नहीं — पहले की गई योजना दिखाई जा रही है।',
      ));
      return;
    }

    // Hop 3: deterministic (always available — the floor, §17).
    final plan = DeterministicExamPlanner.build(DeterministicExamContext(
      trackId: trackId,
      view: scope.view!,
      selection: scope.selection,
      profile: profile,
      learner: learner,
      scopeRevision: scope.selection.revision,
      weakArea: overview == null
          ? null
          : WeakAreaPlannerInput(
              decision: overview.decision,
              revisionItems: overview.revisionItems,
              findings: overview.report.findings
                  .map((f) => f.topicId)
                  .toList(),
            ),
    ));
    try {
      await _planRepo.save(plan, markCached: true);
    } catch (_) {}
    state = AsyncData(ExamPlanState(
      plan: plan,
      building: false,
      notice: 'ऑफ़लाइन योजना — बिना AI, आपके दायरे और समय के अनुसार।',
    ));
  }
}

final examPlanProvider =
    AsyncNotifierProvider.family<ExamPlanController, ExamPlanState, String>(
  ExamPlanController.new,
);
