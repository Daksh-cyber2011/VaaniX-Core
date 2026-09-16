/// VaaniX Learn Mode — AI Planner Providers (M4)
///
/// Riverpod wiring for the Gemini planner hop of the fallback chain:
///
/// - [learnPlanRepositoryProvider] — plan-cache persistence accessor
/// - [plannerTextClientProvider]   — the raw-text LLM boundary
///   (Gemini in production; fakes override this in tests)
/// - [geminiPlannerProvider]       — the AI planner (writes through the
///   plan cache when the parser accepts a plan)
/// - [cachedPlanPlannerProvider]   — the cached-plan hop
///
/// [spine_providers] composes these into the runtime chain:
///
///   ValidatingPlanner(
///     delegate: gemini,
///     fallback: ValidatingPlanner(delegate: cached, fallback: deterministic),
///   )
///
/// ...so the app keeps consuming [learningPlannerProvider] unchanged and
/// an AI outage degrades one hop at a time (Master Brief §36/§60).
///
/// Rate limiting note (§36): the Gemini text client shares the chat
/// adapter's [aiRateLimiterProvider] instance — one app-wide 15 RPM
/// Gemini budget, planner included.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';

/// The M4 plan-cache persistence accessor.
final learnPlanRepositoryProvider = Provider<LearnPlanRepository>(
  (ref) => LearnPlanRepository(ref.watch(localStorageServiceProvider)),
);

/// The raw-text boundary for the planner. Gemini when configured; the
/// planner short-circuits to its fallback chain when it is not. Tests
/// override this provider with a fake client — no network anywhere.
final plannerTextClientProvider = Provider<PlannerTextClient>(
  (ref) => GeminiPlannerTextClient(
    rateLimiter: ref.watch(aiRateLimiterProvider),
  ),
);

/// The AI planner delegate (Master Brief §13 "the heart of Learn Mode").
final geminiPlannerProvider = Provider<GeminiPlanner>(
  (ref) => GeminiPlanner(
    textClient: ref.watch(plannerTextClientProvider),
    planCache: ref.watch(learnPlanRepositoryProvider),
  ),
);

/// The cached-plan fallback hop (last good AI plan, ≤7 days old).
final cachedPlanPlannerProvider = Provider<CachedPlanPlanner>(
  (ref) =>
      CachedPlanPlanner(repository: ref.watch(learnPlanRepositoryProvider)),
);
