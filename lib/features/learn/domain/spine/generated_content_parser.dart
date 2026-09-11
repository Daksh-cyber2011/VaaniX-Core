/// Learn Mode 2.0 — Generated Content Parser (M5, Master Brief §15/§45/§46)
///
/// The ONLY path from raw model text to a [GeneratedContent]. The model's
/// output is UNTRUSTED — exactly as with the M4 planner output:
///
///   1. the JSON object is extracted (tolerating fences/prose — the same
///      `extractPlanJson` scanner the planner uses);
///   2. an honest {"kind":"none"} reply is a typed "declined" Left — the
///      caller falls back to trusted content (§34/§46), never an error
///      dialog;
///   3. everything else runs through [GeneratedContentValidator], which
///      enforces §45's validation list, the §47/§48 script guards, and
///      forces the trusted concept/lesson anchors;
///   4. invalid material is DISCARDED (never fixed, never thrown — §46)
///      as a typed Left with every rejection reason attached.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:dartz/dartz.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner_prompt.dart';

/// Parses + validates raw model text into grounded [GeneratedContent].
abstract final class GeneratedContentParser {
  /// Parses [rawText] — the model's reply — for ONE [requestedKind] item
  /// about [conceptId], grounded in [excerpt].
  static Either<Failure, GeneratedContent> parse(
    String rawText, {
    required GeneratedContentKind requestedKind,
    required String languageCode,
    required bool isRTL,
    required String scriptCode,
    required String conceptId,
    required String lessonId,
    required int difficultyKnob,
    required TrustedKnowledgeExcerpt excerpt,
    required String Function() freshId,
  }) {
    final json = extractPlanJson(rawText);
    if (json == null) {
      return Left(const AiServiceFailure(
        'Generated content was not decodable JSON',
      ));
    }

    // The honest decline: the schema's escape hatch (Master Brief §16
    // "if confidence is insufficient: fallback to trusted content").
    final kindName = json['kind'];
    if (kindName is String &&
        (kindName.trim() == 'none' || kindName.trim().isEmpty)) {
      return Left(const AiServiceFailure(
        'The model declined to generate grounded material',
      ));
    }

    final validation = GeneratedContentValidator.validate(
      raw: json,
      requestedKind: requestedKind,
      languageCode: languageCode,
      isRTL: isRTL,
      scriptCode: scriptCode,
      conceptId: conceptId,
      lessonId: lessonId,
      difficultyKnob: difficultyKnob,
      excerpt: excerpt,
      freshId: freshId,
    );

    if (!validation.isValid) {
      final reasons = validation.rejections
          .map((r) => r.explanation)
          .join('; ');
      return Left(AiServiceFailure(
        'Generated material rejected: $reasons',
      ));
    }

    return Right(validation.content!);
  }
}
