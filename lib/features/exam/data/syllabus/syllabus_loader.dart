/// Exam Mode 2.0 — Syllabus Loader & Providers (M1)
///
/// Loads the canonical official syllabus from the bundled assets
/// (`assets/syllabus/<board>/index.json` + course files) into the typed
/// domain models. Follows the project's loader conventions
/// (`curriculum_loader.dart`): async load with a strict fallback story and
/// Riverpod providers for screens.
///
/// Failure contract:
///  * The index/catalog load returns `SyllabusIndex.empty()` on any asset
///    problem (bundled assets cannot go missing in a release build, but the
///    app must never crash on a malformed file — same philosophy as the
///    Learn curriculum loader).
///  * A course load returns `null` on malformed data instead of throwing,
///    so callers treat it as "course unavailable" rather than an error UI.
///    Validation failures are logged via the debug log so bad data is
///    visible in development builds.
///
/// Caching: one loaded [CourseSyllabus] per track id (memoized) — the data
/// is immutable and small (a few KB per course), so a simple in-memory map
/// is enough for V1; no Gemini call is ever involved in Layer 1.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus_index.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';

const String _kIndexAssetPath = 'assets/syllabus/cbse/index.json';
const String _kBoardDir = 'assets/syllabus/cbse';

/// Loads the course catalog (board → class → subject → course).
///
/// Never throws: returns an empty index on malformed/missing asset.
Future<SyllabusIndex> loadSyllabusIndex() async {
  try {
    final raw = await rootBundle.loadString(_kIndexAssetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SyllabusIndex.fromJson(json);
  } catch (e) {
    debugPrint('[SyllabusLoader] index load failed: $e');
    return SyllabusIndex(
      board: BoardId.cbse,
      syllabusVersion: '',
      classes: const [],
    );
  }
}

/// Loads one course's canonical syllabus by track id.
///
/// Returns `null` when the asset is missing/malformed OR when the loaded
/// data fails [CourseSyllabus.validate] — Layer 1 data integrity is
/// non-negotiable (master plan: correctness first).
Future<CourseSyllabus?> loadCourseSyllabus(String trackId) async {
  try {
    final assetPath = '$_kBoardDir/$trackId.json';
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final syllabus = CourseSyllabus.fromJson(json);
    final errors = syllabus.validate();
    if (errors.isNotEmpty) {
      debugPrint('[SyllabusLoader] $trackId failed validation: $errors');
      return null;
    }
    return syllabus;
  } catch (e) {
    debugPrint('[SyllabusLoader] course load failed for $trackId: $e');
    return null;
  }
}

/// Memoized in-memory course cache (immutable data; tiny footprint).
class SyllabusRepository {
  final Map<String, CourseSyllabus> _cache = {};
  final Map<String, SyllabusIndex> _indexCache = {};

  /// Catalog, loaded at most once per repository instance.
  Future<SyllabusIndex> index() async {
    if (!_indexCache.containsKey(_kIndexAssetPath)) {
      _indexCache[_kIndexAssetPath] = await loadSyllabusIndex();
    }
    return _indexCache[_kIndexAssetPath]!;
  }

  /// One course, cached per track id.
  Future<CourseSyllabus?> course(String trackId) async {
    if (_cache.containsKey(trackId)) return _cache[trackId];
    final syllabus = await loadCourseSyllabus(trackId);
    if (syllabus != null) _cache[trackId] = syllabus;
    return syllabus;
  }

  /// All V1 courses, eagerly loaded (used by tests and future dashboards).
  Future<List<CourseSyllabus>> allCourses() async {
    final idx = await index();
    final results = <CourseSyllabus>[];
    for (final entry in idx.allCourses) {
      final s = await course(entry.id);
      if (s != null) results.add(s);
    }
    return results;
  }

  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _indexCache.clear();
  }
}

/// Shared repository provider (singleton; immutable data cached in memory).
final syllabusRepositoryProvider = Provider<SyllabusRepository>((ref) {
  return SyllabusRepository();
});

/// The catalog as an async provider for the M2 selection flow.
final syllabusIndexProvider = FutureProvider<SyllabusIndex>((ref) async {
  return ref.watch(syllabusRepositoryProvider).index();
});

/// One course syllabus per track id (async family for M2+ screens).
final courseSyllabusProvider =
    FutureProvider.family<CourseSyllabus?, String>((ref, trackId) async {
  return ref.watch(syllabusRepositoryProvider).course(trackId);
});
