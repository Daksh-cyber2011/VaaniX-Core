/// VaaniX Learn Mode — Gemini AI Planner (M4, Master Brief §13/§36/§60)
///
/// The Gemini-backed [LearningPlanner]. Composition per call:
///
///   PlannerContext
///     → structured prompts (spine/planner_prompt.dart, §62 sections)
///     → [PlannerTextClient] (the ONLY network hop, Gemini chat-free)
///     → AiPlanParser (untrusted text → validated grounded plan, §14)
///     → write-through plan cache (feeds the fallback chain)
///     → Right(plan) — or Left(Failure), NEVER a throw
///
/// Failure handling is the heart of the design (Master Brief §36/§60):
/// this planner never throws for expected failure modes (no API key,
/// outage, timeout, rate limit, garbage output). Every failure is a
/// `Left`, and the provider wiring wraps this planner in the
/// [ValidatingPlanner] facade with the cached-plan → deterministic
/// chain behind it, so Learn Mode keeps working when AI does not.
///
/// Cost control (§61): the planner runs ONLY where a plan is actually
/// needed (the app consumes [learningPlannerProvider]); unconfigured
/// API keys short-circuit before any network call, and every accepted
/// plan is cached so replanning is rare. Rate limiting SHARES the chat
/// adapter's 15 RPM budget ([aiRateLimiterProvider]) — one app-wide
/// Gemini budget, no accidental doubling.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_output.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';

/// The raw-text boundary between the planner and any LLM backend.
///
/// Contract:
/// - `isAvailable == false` → the planner short-circuits to a Left
///   WITHOUT calling [complete] (offline / unconfigured key path).
/// - [complete] THROWS on failure (network, quota, safety block) — the
///   planner catches everything and converts to Left. Keeping the client
///   throw-based keeps it trivially fake-able in tests.
abstract class PlannerTextClient {
  /// True when the backend is configured and reachable-in-principle.
  bool get isAvailable;

  /// One completion for the planner request. Throws on any failure.
  Future<String> complete({
    required String system,
    required String user,
  });
}

/// Gemini implementation of [PlannerTextClient].
///
/// Mirrors the chat adapter's discipline (single model client, system
/// instruction, rate-limit slot) but is a SEPARATE, planner-specific
/// path: no chat transcript, no persona pipeline, no safety-filter prose
/// wrapping — the planner's system prompt IS the contract, and its JSON
/// output is validated structurally instead of moderated as prose.
class GeminiPlannerTextClient implements PlannerTextClient {
  GeminiPlannerTextClient({AiRateLimiter? rateLimiter})
      : _rateLimiter = rateLimiter ?? AiRateLimiter();

  /// Hard ceiling for one planning request. Plans must feel instant:
  /// past this the fallback chain serves the learner instead.
  @visibleForTesting
  static const Duration requestTimeout = Duration(seconds: 15);

  final AiRateLimiter _rateLimiter;
  GenerativeModel? _model;
  String? _modelSystem;

  @override
  bool get isAvailable => AppEnvironment.isGeminiConfigured;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    // One rate-limit slot per attempt, shared with the chat adapter's
    // budget when wired through [aiRateLimiterProvider].
    await _rateLimiter.awaitSlot();

    final model = _modelFor(system);
    final response = await model
        .generateContent([Content.text(user)])
        .timeout(requestTimeout);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const AiContentFilterFailure();
    }
    return text;
  }

  /// Lazily builds the Gemini model; rebuilt only when the system prompt
  /// genuinely changes (the planner prompt varies only with the build's
  /// supported activity kinds, so the client is reused across calls).
  GenerativeModel _modelFor(String system) {
    if (_model != null && _modelSystem == system) return _model!;

    final apiKey = AppEnvironment.geminiApiKey;
    if (apiKey.isEmpty) {
      throw StateError('Gemini API key not configured');
    }
    _model = GenerativeModel(
      model: AppEnvironment.geminiModel,
      apiKey: apiKey,
      systemInstruction: Content.system(system),
      generationConfig: const GenerationConfig(
        temperature: 0.3, // structured output — keep it conservative
        maxOutputTokens: 1024,
      ),
    );
    _modelSystem = system;
    return _model!;
  }

  /// The model name in use (diagnostics only).
  String get modelName => AppEnvironment.geminiModel;
}

/// The M4 AI planner behind the M1 [LearningPlanner] contract.
class GeminiPlanner implements LearningPlanner {
  GeminiPlanner({
    required PlannerTextClient textClient,
    LearnPlanRepository? planCache,
  })  : _textClient = textClient,
        _planCache = planCache;

  final PlannerTextClient _textClient;
  final LearnPlanRepository? _planCache;

  @override
  String get id => 'gemini-planner-v1';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(PlannerContext context) {
    return _guard(() async {
      // Unconfigured / offline → immediate Left, zero network, zero
      // cost. The provider chain falls through to cached/deterministic.
      if (!_textClient.isAvailable) {
        return Left(const AiServiceFailure('AI planner is not available'));
      }

      final raw = await _textClient.complete(
        system: buildPlannerSystemPrompt(
          supportedActivityTypes: context.supportedActivityTypes,
        ),
        user: buildPlannerUserPrompt(context),
      );

      final result = AiPlanParser.parse(raw, context);
      return result.fold(
        (failure) => Left(failure), // malformed / ungrounded → chain falls back
        (plan) async {
          // Write-through cache: the NEXT outage serves this plan. A
          // storage failure must never fail a good plan — swallow it.
          try {
            await _planCache?.savePlan(plan);
          } catch (_) {
            // Cache write is best-effort by contract.
          }
          return Right(plan);
        },
      );
    });
  }

  /// Contract guard: NOTHING escapes this planner as a throw. Any
  /// exception becomes a mapped Left so the facade can fall back.
  Future<Either<Failure, LearningPlan>> _guard(
    Future<Either<Failure, LearningPlan>> Function() body,
  ) async {
    try {
      return await body();
    } on TimeoutException {
      return Left(const TimeoutFailure());
    } catch (e) {
      // The Failure message is documented as human-readable and can reach
      // UI surfaces — never interpolate the raw exception into it.
      return Left(AiServiceFailure(
          'VAN could not reach the planner just now. The deterministic '
          'plan takes over automatically.'));
    }
  }
}

/// The "cached plan" hop of the Master Brief §36/§60 fallback chain.
///
/// Serves the last ACCEPTED AI plan (marked [PlanSource.cached] so the
/// UI can be honest about it). Rejects — with a Left, so the chain
/// continues to the deterministic planner — when: nothing cached, cache
/// belongs to another language, the plan is stale, or it is empty.
///
/// The provider wiring wraps this planner in its own [ValidatingPlanner]
/// so even a cached plan is re-checked against the CURRENT graph before
/// it reaches the learner.
class CachedPlanPlanner implements LearningPlanner {
  const CachedPlanPlanner({required LearnPlanRepository repository});

  final LearnPlanRepository repository;

  @override
  String get id => 'cached-plan-v1';

  @override
  Future<Either<Failure, LearningPlan>> buildPlan(PlannerContext context) async {
    final language = learnLanguageForCode(context.languageCode);
    if (language == null) {
      // Legacy Sanskrit track: no plan cache exists by design.
      return Left(AiServiceFailure(
        'No plan cache for "${context.languageCode}"',
      ));
    }

    final cached = repository.getPlan(language);
    if (cached == null || cached.isEmpty) {
      return Left(const AiServiceFailure('No cached plan available'));
    }
    if (cached.languageCode != context.languageCode) {
      return Left(const AiServiceFailure('Cached plan is for another language'));
    }
    if (!LearnPlanRepository.isFresh(cached)) {
      return Left(const AiServiceFailure('Cached plan has expired'));
    }

    // Honest provenance: the learner gets the SAME steps, but the plan
    // is labelled cached, not AI-fresh (Master Brief §63 honesty).
    return Right(
      LearningPlan(
        id: cached.id,
        languageCode: cached.languageCode,
        source: PlanSource.cached,
        activities: cached.activities,
        focusSummary: cached.focusSummary,
        createdAt: cached.createdAt,
      ),
    );
  }
}
