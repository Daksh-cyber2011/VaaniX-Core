/// VaaniX Learn Mode — Learner Profile Repository (M2, extended in M3)
///
/// Persistence for the per-language learning profile, learning state
/// extras, and the placement (diagnostic) result (Master Brief §10/§11;
/// M0 audit M2 recommendation: storage namespaced `learn_profile_<lang>_…`).
///
/// Storage contract (generic string storage via [ILocalStorageService]):
/// - Key `learn_profile_<iso>`              → profile JSON
///   (e.g. `learn_profile_hi`, `learn_profile_ur`)
/// - Key `learn_profile_<iso>_state`        → learning-state JSON
///   (review queue + recent performance extras; M3/M6 fill these)
/// - Key `learn_profile_<iso>_diagnostic`   → last DiagnosticResult JSON
///   (M3 placement flow; repeatable — a retake overwrites it)
///
/// Corruption safety (matches the Learn language repository contract):
/// - missing / empty value      → treated as unset (returns null)
/// - malformed JSON             → treated as unset (returns null)
/// - stored profile for another
///   language                   → treated as unset (defence in depth —
///                                the profile JSON carries its language)
///
/// Privacy (Master Brief §35): learning data only, local-only storage,
/// one user per device store — never shared across users.
library;

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';

class LearnProfileRepository {
  LearnProfileRepository(this._storage);

  final ILocalStorageService _storage;

  /// Profile key for [language] (`learn_profile_<iso>`).
  static String profileKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}';

  /// Learning-state key for [language] (`learn_profile_<iso>_state`).
  static String stateKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_state';

  /// Last-placement key for [language] (`learn_profile_<iso>_diagnostic`).
  static String diagnosticKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_diagnostic';

  /// Applied curriculum content revision for [language]. This is deliberately
  /// distinct from the curriculum JSON schema version.
  static String curriculumRevisionKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_curriculum_revision';

  /// Namespace prefix shared by every M2 key (used by [clearAll] and
  /// reset flows).
  static const String kNamespacePrefix = 'learn_profile_';

  // ── Profile ────────────────────────────────────────────────────────────

  /// Reads the persisted profile for [language], or `null` when unset or
  /// unreadable (never throws — corrupt storage degrades to "unset").
  LearnerProfile? getProfile(LearnLanguage language) {
    final raw = _storage.getString(profileKey(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final profile = LearnerProfile.fromJson(decoded);
      if (profile.language != language) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// True when a readable profile exists for [language].
  bool hasProfile(LearnLanguage language) => getProfile(language) != null;

  /// Persists [profile] under its own language's key.
  Future<void> saveProfile(LearnerProfile profile) {
    return _storage.setString(
      profileKey(profile.language),
      jsonEncode(profile.toJson()),
    );
  }

  /// Removes the profile for [language] (back to defaults).
  Future<void> clearProfile(LearnLanguage language) =>
      _storage.remove(profileKey(language));

  // ── Learning state extras (review queue / recent performance) ─────────

  /// Reads the persisted learning-state extras for [language], or `null`
  /// when unset / unreadable. The M1 derivation from real progress data
  /// stays the primary evidence source; this slot adds what cannot be
  /// derived (review scheduling, rolling performance) and is filled by
  /// M3 (diagnostic) and M6 (sessions).
  LearningState? getLearningState(LearnLanguage language) {
    final raw = _storage.getString(stateKey(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final state = LearningState.fromJson(decoded);
      if (state.languageCode != learnLanguageSpec(language).code) {
        return null;
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  /// Persists the learning-state extras for [language].
  Future<void> saveLearningState(
    LearnLanguage language,
    LearningState state,
  ) {
    return _storage.setString(
      stateKey(language),
      jsonEncode(state.toJson()),
    );
  }

  /// Removes the learning-state extras for [language].
  Future<void> clearLearningState(LearnLanguage language) =>
      _storage.remove(stateKey(language));

  // ── Placement result (M3) ──────────────────────────────────────────────

  /// Reads the last [DiagnosticResult] for [language], or `null` when the
  /// learner has not been placed yet (or the stored value is unreadable —
  /// corrupt storage degrades to "not placed", never crashes).
  ///
  /// A language mismatch is rejected like the profile above: the stored
  /// JSON carries its own language, and a hit under another language's
  /// key would mean storage corruption.
  DiagnosticResult? getDiagnostic(LearnLanguage language) {
    final raw = _storage.getString(diagnosticKey(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final result = DiagnosticResult.fromJson(decoded);
      if (result.language != language) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Persists the placement result for [language]. Repeatable by design:
  /// a retake overwrites the previous result (the review queue and
  /// performance extras seeded by the previous run are refreshed the
  /// same way by the session notifier).
  Future<void> saveDiagnostic(DiagnosticResult result) {
    return _storage.setString(
      diagnosticKey(result.language),
      jsonEncode(result.toJson()),
    );
  }

  /// Removes the placement result for [language].
  Future<void> clearDiagnostic(LearnLanguage language) =>
      _storage.remove(diagnosticKey(language));

  int? getCurriculumRevision(LearnLanguage language) {
    final raw = _storage.getString(curriculumRevisionKey(language));
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveCurriculumRevision(
    LearnLanguage language,
    int revision,
  ) =>
      _storage.setString(curriculumRevisionKey(language), revision.toString());

  // ── Namespace maintenance ──────────────────────────────────────────────

  /// Removes EVERY `learn_profile_*` key (all languages, profile + state
  /// + diagnostic). The prefix rule covers the M3 diagnostic slot
  /// automatically — no key list to keep in sync.
  /// Used by profile reset flows (mirrors the progress repository's
  /// prefix-based reset pattern).
  Future<void> clearAll() async {
    final doomed =
        _storage.keys.where((k) => k.startsWith(kNamespacePrefix)).toList();
    for (final key in doomed) {
      await _storage.remove(key);
    }
  }
}
