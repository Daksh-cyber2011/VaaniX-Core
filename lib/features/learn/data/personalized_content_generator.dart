/// VaaniX Learn Mode — Personalized Content Generator (M5, Master Brief
/// §15/§16/§34/§35/§45/§46/§61)
///
/// The §34 priority ladder, implemented for ONE concept at a time:
///
///   1. trusted content           — the caller reads it straight from
///                                  [TrustedContentRegistry] (always
///                                  preferred when available);
///   2. cached personalization    — a previously validated item for this
///                                  (concept, kind, difficulty), served
///                                  with ZERO network calls;
///   3. AI generation when safe   — ONE Gemini call grounded in the
///                                  trusted excerpt, validated through
///                                  [GeneratedContentParser];
///   4. fallback                  — a typed Left; the UI keeps showing
///                                  the trusted material (§46 "never
///                                  show broken exercise UI").
///
/// The AI hop reuses the M4 [PlannerTextClient] boundary — in production
/// that is the SAME Gemini client configuration with the SAME app-wide
/// 15 RPM budget (§36), so Learn Mode's planner and material maker
/// together never exceed one Gemini budget.
///
/// Contract notes (mirroring the M4 planner):
/// - unconfigured / offline → Left BEFORE any network call;
/// - every expected failure (timeout, rate limit, garbage, decline) is a
///   typed Left, NEVER a throw;
/// - accepted material is cached write-through; a cache failure can
///   never fail good material;
/// - cached material is RE-VALIDATED before serving (it is AI output at
///   rest — trust nothing twice).
library;

import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_prompt.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content_parser.dart';

/// One generated-material result: the validated content plus honest
/// provenance (Master Brief §63 — the UI labels cached vs fresh).
class GeneratedContentResult {
  const GeneratedContentResult({
    required this.content,
    required this.fromCache,
  });

  final GeneratedContent content;
  final bool fromCache;
}

class PersonalizedContentGenerator {
  PersonalizedContentGenerator({
    required PlannerTextClient textClient,
    GeneratedContentRepository? cache,
  })  : _textClient = textClient,
        _cache = cache;

  final PlannerTextClient _textClient;
  final GeneratedContentRepository? _cache;

  /// Generates (or serves from cache) ONE personalized item of [kind]
  /// for [concept], grounded in [excerpt].
  Future<Either<Failure, GeneratedContentResult>> generate({
    required LearnLanguageSpec spec,
    required String conceptId,
    required String conceptTitle,
    required String? conceptSubtitle,
    required TrustedKnowledgeExcerpt excerpt,
    required GeneratedContentKind kind,
    required int difficultyKnob,
    required Map<String, Object?> learnerDigest,
    bool useCache = true,
  }) {
    return _guard(() async {
      // An empty excerpt means there is nothing trusted to ground on —
      // refuse WITHOUT calling the model (§16: never guess; §61: never
      // pay for a call that must be rejected anyway).
      if (excerpt.isEmpty) {
        return Left(const AiServiceFailure(
          'No trusted material to ground personalization on',
        ));
      }

      final itemKey = GeneratedContentRepository.itemKeyFor(
        conceptId,
        kind,
        difficultyKnob,
      );

      // ── Hop 2: cached personalization (zero network) ──
      if (useCache && _cache != null) {
        final cached = _cache.get(spec.language, itemKey);
        if (cached != null && GeneratedContentRepository.isFresh(cached)) {
          final revalidation = GeneratedContentValidator.validate(
            raw: cached.toJson(),
            requestedKind: kind,
            languageCode: spec.code,
            isRTL: spec.isRTL,
            scriptCode: spec.scriptCode,
            conceptId: conceptId,
            lessonId: excerpt.lessonId,
            difficultyKnob: difficultyKnob,
            excerpt: excerpt,
            freshId: () => cached.id,
          );
          if (revalidation.isValid) {
            // Serve the ORIGINAL cached item (its own createdAt — the
            // freshness clock keeps ticking, so personalization is
            // eventually refreshed with real generation).
            return Right(GeneratedContentResult(
              content: cached,
              fromCache: true,
            ));
          }
          // A stored item that no longer validates is discarded — the
          // cache write below will replace it.
        }
      }

      // ── Unconfigured / offline → Left BEFORE any network call ──
      if (!_textClient.isAvailable) {
        return Left(const AiServiceFailure(
          'AI material generation is not available',
        ));
      }

      // ── Hop 3: one grounded, validated Gemini call ──
      final raw = await _textClient.complete(
        system: buildContentSystemPrompt(kind: kind),
        user: buildContentUserPrompt(
          languageName: spec.englishName,
          languageCode: spec.code,
          isRTL: spec.isRTL,
          scriptName: spec.scriptName,
          conceptId: conceptId,
          conceptTitle: conceptTitle,
          conceptSubtitle: conceptSubtitle,
          excerpt: excerpt,
          learnerDigest: learnerDigest,
          kind: kind,
          difficultyKnob: difficultyKnob,
        ),
      );

      var idCounter = 0;
      String freshId() => 'gen-${conceptId}-${kind.name}-'
          '${DateTime.now().millisecondsSinceEpoch}-${idCounter++}';

      final result = GeneratedContentParser.parse(
        raw,
        requestedKind: kind,
        languageCode: spec.code,
        isRTL: spec.isRTL,
        scriptCode: spec.scriptCode,
        conceptId: conceptId,
        lessonId: excerpt.lessonId,
        difficultyKnob: difficultyKnob,
        excerpt: excerpt,
        freshId: freshId,
      );

      return result.fold(
        (failure) => Left(failure), // declined / invalid → trusted fallback
        (content) async {
          // Write-through cache: the NEXT request for this exact item is
          // free. Storage failure must never fail good material — the
          // await keeps a storage throw inside the guard's catch.
          try {
            await _cache?.save(spec.language, itemKey, content);
          } catch (_) {
            // Cache write is best-effort by contract.
          }
          return Right(GeneratedContentResult(
            content: content,
            fromCache: false,
          ));
        },
      );
    });
  }

  /// Contract guard: NOTHING escapes this generator as a throw. Any
  /// exception becomes a mapped Left so the UI keeps its trusted content.
  Future<Either<Failure, GeneratedContentResult>> _guard(
    Future<Either<Failure, GeneratedContentResult>> Function() body,
  ) async {
    try {
      return await body();
    } on TimeoutException {
      return Left(const TimeoutFailure());
    } catch (e) {
      // The Failure message is documented as human-readable and can reach
      // UI surfaces — never interpolate the raw exception into it.
      return Left(AiServiceFailure(
          'VAN could not personalize just now. The trusted material is '
          'still available.'));
    }
  }
}
