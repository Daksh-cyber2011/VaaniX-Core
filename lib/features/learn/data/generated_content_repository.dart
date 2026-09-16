/// VaaniX Learn Mode — Generated Content Repository (M5, Master Brief
/// §35/§61)
///
/// Persistence for AI-personalized material, so a generated explanation /
/// example / practice question is paid for ONCE and reused (Master Brief
/// §35 caching, §61 cost control):
///
/// - Key `learn_profile_<iso>_gen` → bounded JSON map of
///   `{"key": cacheKey, "content": {...}}` entries, newest-first, capped
///   at [maxEntries]. Lives inside the M2 `learn_profile_` namespace, so
///   the existing prefix-scoped [clearAll] reset covers it automatically.
/// - Freshness policy matches the M4 plan cache (7 days): personalization
///   older than that is stale — the learner may have moved on.
///
/// Corruption safety (same contract as the profile/diagnostic/plan
/// slots): missing / malformed / wrong-language values degrade to
/// "nothing cached", never crash. And because cached items are restored
/// from disk, the GENERATOR re-validates them through the M5 validator
/// before serving — defence in depth for AI material at rest.
library;

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';

class GeneratedContentRepository {
  GeneratedContentRepository(this._storage);

  final ILocalStorageService _storage;

  /// Cache key for [language] (`learn_profile_<iso>_gen`).
  static String cacheKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_gen';

  /// Stable lookup key for one generated item.
  static String itemKeyFor(
          String conceptId, GeneratedContentKind kind, int difficultyKnob) =>
      '$conceptId|${kind.name}|$difficultyKnob';

  /// How long a cached item stays serveable (matches the M4 plan cache).
  static const Duration kDefaultMaxAge = Duration(days: 7);

  /// Bounded store: personalized material is a nice-to-have, not an
  /// archive — 12 items keeps storage tiny while covering a session.
  static const int maxEntries = 12;

  /// Reads the cached item for [itemKey], or `null` when nothing useful
  /// is stored (missing / malformed / wrong language / not this key).
  GeneratedContent? get(LearnLanguage language, String itemKey) {
    for (final entry in _readAll(language)) {
      if (entry.key == itemKey) return entry.content;
    }
    return null;
  }

  /// True when a readable item exists for [itemKey].
  bool has(LearnLanguage language, String itemKey) =>
      get(language, itemKey) != null;

  /// Persists [content] under [itemKey] (upsert), newest-first, bounded
  /// to [maxEntries] (oldest evicted). Only VALIDATED content reaches
  /// this method — the generator writes through after the parser accepts
  /// it; the repository does no validation of its own.
  Future<void> save(
    LearnLanguage language,
    String itemKey,
    GeneratedContent content,
  ) {
    final entries = _readAll(language).where((e) => e.key != itemKey).toList()
      ..insert(0, _CacheEntry(key: itemKey, content: content));
    // Evict beyond the cap (list is newest-insert-first).
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    return _writeAll(language, entries);
  }

  /// Removes the whole cache for [language].
  Future<void> clear(LearnLanguage language) =>
      _storage.remove(cacheKey(language));

  /// True when [content] is young enough to serve from the cache.
  static bool isFresh(GeneratedContent content, {DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(content.createdAt);
    // A future timestamp (clock skew) is treated as fresh.
    return age <= kDefaultMaxAge;
  }

  // ── Storage plumbing (corruption-safe by contract) ──

  List<_CacheEntry> _readAll(LearnLanguage language) {
    final raw = _storage.getString(cacheKey(language));
    if (raw == null || raw.isEmpty) return const <_CacheEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <_CacheEntry>[];
      final spec = learnLanguageSpec(language);
      final items = decoded['items'];
      if (items is! List<dynamic>) return const <_CacheEntry>[];
      final entries = <_CacheEntry>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final key = item['key'];
        final contentJson = item['content'];
        if (key is! String || contentJson is! Map<String, dynamic>) continue;
        final content = GeneratedContent.fromJson(contentJson);
        if (content == null) continue;
        // Defence in depth: a stored item for another language is unset.
        if (content.languageCode != spec.code) continue;
        entries.add(_CacheEntry(key: key, content: content));
      }
      return entries;
    } catch (_) {
      return const <_CacheEntry>[];
    }
  }

  Future<void> _writeAll(LearnLanguage language, List<_CacheEntry> entries) {
    return _storage.setString(
      cacheKey(language),
      jsonEncode({
        'version': 1,
        'items': [
          for (final e in entries)
            {'key': e.key, 'content': e.content.toJson()},
        ],
      }),
    );
  }
}

class _CacheEntry {
  const _CacheEntry({required this.key, required this.content});

  final String key;
  final GeneratedContent content;
}
