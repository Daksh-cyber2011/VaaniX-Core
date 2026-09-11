/// VaaniX Learn Mode — Learning Plan Repository (M4)
///
/// Persistence for the last AI-generated learning plan, used by the
/// Master Brief §36/§60 fallback chain:
///
///   AI plan → [cached plan] → deterministic → empty-but-valid
///
/// Storage contract (generic string storage via [ILocalStorageService]):
/// - Key `learn_profile_<iso>_plan` → last validated AI plan JSON
///   (e.g. `learn_profile_hi_plan`). Lives inside the M2
///   `learn_profile_` namespace, so the existing prefix-scoped
///   [clearAll] reset covers it automatically — no key list to sync.
///
/// Corruption safety (same contract as the profile/diagnostic slots):
/// - missing / empty value      → treated as unset (returns null)
/// - malformed JSON             → treated as unset (returns null)
/// - stored plan for another
///   language                   → treated as unset (defence in depth —
///                                the plan JSON carries its language)
///
/// Privacy (Master Brief §35): the cache stores learner-specific plans
/// locally only, one user per device store — cached plans are never
/// shared across users and never uploaded.
library;

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';

/// Resolves the catalogue [LearnLanguage] for an ISO 639-1 code, or
/// `null` when the code is not a Learn Mode language (e.g. the legacy
/// Sanskrit `'sa'` track, which intentionally has no plan cache).
LearnLanguage? learnLanguageForCode(String code) {
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.code == code) return spec.language;
  }
  return null;
}

class LearnPlanRepository {
  LearnPlanRepository(this._storage);

  final ILocalStorageService _storage;

  /// Plan-cache key for [language] (`learn_profile_<iso>_plan`).
  static String planKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_plan';

  /// How long a cached plan stays serveable in the fallback chain.
  /// A week balances "still relevant" against "stale focus" — the chain
  /// re-validates every activity against the CURRENT graph anyway, so
  /// staleness here is about pedagogical freshness, not safety.
  static const Duration kDefaultMaxAge = Duration(days: 7);

  /// Reads the cached [LearningPlan] for [language], or `null` when no
  /// plan was cached (or the stored value is unreadable — corrupt
  /// storage degrades to "no cache", never crashes).
  LearningPlan? getPlan(LearnLanguage language) {
    final raw = _storage.getString(planKey(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final plan = LearningPlan.fromJson(decoded);
      if (plan.languageCode != learnLanguageSpec(language).code) {
        return null;
      }
      return plan;
    } catch (_) {
      return null;
    }
  }

  /// True when a readable, non-empty plan exists for [language].
  bool hasPlan(LearnLanguage language) =>
      getPlan(language)?.isNotEmpty ?? false;

  /// Persists [plan] under its own language's key. Only VALIDATED plans
  /// reach this method (the Gemini planner writes through after the
  /// parser accepts them); the repository does no validation of its own.
  Future<void> savePlan(LearningPlan plan) {
    final language = learnLanguageForCode(plan.languageCode);
    if (language == null) {
      // Non-catalogue language (legacy Sanskrit) — nothing to cache.
      return Future.value();
    }
    return _storage.setString(
      planKey(language),
      jsonEncode(plan.toJson()),
    );
  }

  /// Removes the cached plan for [language].
  Future<void> clearPlan(LearnLanguage language) =>
      _storage.remove(planKey(language));

  /// True when [plan] is young enough to serve from the cache.
  static bool isFresh(LearningPlan plan, {DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(plan.createdAt);
    // A future timestamp (clock skew) is treated as fresh — the plan is
    // still the newest thing we have.
    return age <= kDefaultMaxAge;
  }
}
