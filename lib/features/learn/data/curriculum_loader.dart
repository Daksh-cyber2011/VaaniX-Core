/// VaaniX Curriculum Loader (Segment 8)
///
/// Loads the curriculum from a JSON asset file (assets/curriculum/v1.json)
/// with fallback to the hardcoded Dart constants from sanskrit_curriculum.dart.
///
/// This is a transitional approach: the JSON file defines the curriculum
/// structure (chapters, lessons, quizzes, metadata) while the lesson
/// content strings remain in Dart (sanskrit_lesson_content.dart) to
/// avoid Devanagari encoding issues in JSON. A future milestone can
/// move content to JSON once the encoding is verified end-to-end.
///
/// The loader is exposed as an AsyncNotifierProvider so the Learn screen
/// can show loading/error states while the curriculum is being parsed.
///
/// Part 0 extension: [loadLearnCurriculum] + [LearnCurriculumNotifier]
/// add a parallel path that dispatches by Learn Mode language. The
/// legacy Sanskrit path ([loadCurriculum], [CurriculumNotifier]) is
/// preserved unchanged for Exam Mode and for the unselected-state
/// fallback on the Learn screen.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_lesson_content.dart';
import 'package:vaanix_app/features/learn/data/unit2_lesson_content.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Loads chapters from JSON, falls back to hardcoded Dart on any error.
Future<List<Chapter>> loadCurriculum() async {
  try {
    final raw = await rootBundle.loadString('assets/curriculum/v1.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final chaptersJson = json['chapters'] as List<dynamic>? ?? [];

    final chapters = chaptersJson
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList();

    // Merge in lesson content from the existing Dart constants.
    // The JSON defines structure; the Dart constants provide content.
    // This avoids Devanagari encoding issues in JSON while still
    // making the curriculum data-driven for structure.
    final contentMap = _buildContentMap();
    final merged = chapters.map((ch) {
      final updatedLessons = ch.lessons.map((lesson) {
        final content = contentMap[lesson.id];
        if (content != null &&
            (lesson.content == null || lesson.content!.isEmpty)) {
          return lesson.copyWith(content: content);
        }
        return lesson;
      }).toList();
      return Chapter(
        id: ch.id,
        title: ch.title,
        subtitle: ch.subtitle,
        lessons: updatedLessons,
        order: ch.order,
      );
    }).toList();

    return merged;
  } catch (e) {
    // Fallback to the hardcoded Dart curriculum on any JSON parse error.
    return sanskritCurriculum;
  }
}

/// Loads ALL quiz questions from the JSON curriculum as one flat bank.
///
/// Phase 2 single-source: the exam bank and the adaptive quiz-id maps read
/// THIS loader — the hardcoded Dart bank (`chapterQuizzes`) is now only an
/// offline fallback for a malformed/missing JSON asset, never the primary
/// path. Each question's `chapterId` comes from its quiz group in the JSON.
///
/// The returned list is empty only if BOTH the JSON and the compiled-in
/// Dart fallback are empty (practically unreachable).
Future<List<QuizQuestion>> loadAllQuizQuestions() async {
  try {
    final raw = await rootBundle.loadString('assets/curriculum/v1.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final quizzesJson = json['quizzes'] as List<dynamic>? ?? [];

    final bank = <QuizQuestion>[];
    for (final quiz in quizzesJson) {
      final quizMap = quiz as Map<String, dynamic>;
      final chapterId = quizMap['chapterId'] as String? ?? '';
      final questions = quizMap['questions'] as List<dynamic>? ?? [];
      bank.addAll(questions
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)
              .copyWith(chapterId: chapterId))
          .toList());
    }
    if (bank.isNotEmpty) return bank;
  } catch (e) {
    // Fall through to the hardcoded Dart bank on any JSON problem.
  }
  return chapterQuizzes.values.expand((q) => q).toList();
}

/// Maps lesson IDs to their content strings from the Dart constants.
/// Used to merge content into JSON-loaded lessons.
Map<String, String> _buildContentMap() {
  return {
    'ls_alphabet_vowels': kVowelsContent,
    'ls_alphabet_consonants': kConsonantsContent,
    'ls_alphabet_barakhadi': kBarakhadiContent,
    'ls_words_greetings': kGreetingsContent,
    'ls_words_family': kFamilyContent,
    'ls_words_numbers': kNumbersContent,
    'ls_sentences_intro': kIntroContent,
    'ls_sentences_questions': kQuestionsContent,
    ...unit2LessonContent,
  };
}

// ─── Riverpod Providers ─────────────────────────────────────────────────────

/// AsyncNotifier that loads the curriculum from JSON on first access.
class CurriculumNotifier extends AsyncNotifier<List<Chapter>> {
  @override
  Future<List<Chapter>> build() async {
    return loadCurriculum();
  }

  /// Force a reload (e.g., after CBSE class changes).
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(loadCurriculum);
  }
}

/// The curriculum provider — now async with loading/error states.
final curriculumProvider =
    AsyncNotifierProvider<CurriculumNotifier, List<Chapter>>(
  CurriculumNotifier.new,
);

// ─── Learn Mode Per-Language Curriculum (Part 0 Foundation) ────────────────
//
// Parallel curriculum path for the 10 VaaniX Learn Mode languages.
// Distinct from [curriculumProvider] (the legacy Sanskrit / Exam Mode
// curriculum) so the two never collide: Exam Mode keeps reading
// [loadAllQuizQuestions] + [curriculumProvider], while Learn Mode reads
// [learnCurriculumProvider(language)] once the learner has picked a
// language from the catalogue.
//
// Part 0 ships ONLY the infrastructure. All 10 languages return an
// empty chapter list (the stub JSON files in assets/curriculum/learn/
// parse successfully but contain zero chapters). Parts A–J replace
// each stub with a real curriculum; the loader contract stays identical.

/// Schema version for Learn Mode curriculum JSON.
///
/// Bumped on every breaking schema change in `assets/curriculum/learn/`.
/// The loader validates the version field and refuses to load a newer
/// schema than it understands (returns empty + logs) so a mismatched
/// asset never silently produces a corrupted UI.
const int kLearnCurriculumSchemaVersion = 1;

/// Loads the curriculum for one Learn Mode language.
///
/// Reads `assets/curriculum/learn/<code>.json` (where `<code>` is the
/// language's ISO 639-1 code from [LearnLanguageSpec.code]) and parses
/// it into a list of [Chapter] objects.
///
/// Part 0 contract: the stub JSON files ship with `chapters: []`, so
/// this returns an empty list for every language. The loader is still
/// fully exercised end-to-end (asset read → JSON parse → schema check
/// → chapter map) so Parts A–J only need to swap the asset contents.
///
/// Failure modes (all return an empty list rather than throwing):
/// - asset missing → caught by the outer try/catch
/// - JSON malformed → caught by jsonDecode
/// - schema version newer than [kLearnCurriculumSchemaVersion] → refused
/// - chapters array missing → defaults to `[]`
///
/// The Learn screen treats an empty list as "curriculum coming in
/// Part X" — never as an error, because the absence is expected in
/// Part 0 and the picker must keep working.
Future<List<Chapter>> loadLearnCurriculum(LearnLanguage language) async {
  final spec = learnLanguageSpec(language);
  print('DEBUG loadLearnCurriculum: starting for ${spec.code}');
  try {
    print('DEBUG loadLearnCurriculum: awaiting rootBundle.loadString for ${spec.curriculumAssetPath}');
    final raw = await rootBundle.loadString(spec.curriculumAssetPath);
    print('DEBUG loadLearnCurriculum: loaded raw string, length: ${raw.length}');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    print('DEBUG loadLearnCurriculum: decoded json');

    // Schema guard: refuse to load a newer schema than we understand.
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version > kLearnCurriculumSchemaVersion) {
      // Future schema — leave to a newer app build. Returning empty
      // keeps the picker alive; the Learn screen shows "coming soon".
      return const [];
    }

    final chaptersJson = json['chapters'] as List<dynamic>? ?? [];
    return chaptersJson
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (error) {
    // Asset missing or malformed — expected for languages whose
    // curriculum hasn't shipped yet (Parts A–J). Empty list, not error.
    debugPrint('[LearnCurriculum] Could not load ${spec.code}: $error');
    return const [];
  }
}

/// AsyncNotifier that loads ONE Learn Mode language's curriculum.
///
/// Family-keyed by [LearnLanguage] so each language's curriculum loads
/// lazily and independently. The notifier is intentionally minimal —
/// it delegates to [loadLearnCurriculum] and exposes a [reload] hook
/// for future cache invalidation (e.g., after an asset hot-reload
/// during development, or a remote curriculum update later).
class LearnCurriculumNotifier
    extends FamilyAsyncNotifier<List<Chapter>, LearnLanguage> {
  @override
  Future<List<Chapter>> build(LearnLanguage language) async {
    return loadLearnCurriculum(language);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => loadLearnCurriculum(arg));
  }
}

/// Per-language Learn Mode curriculum provider.
///
/// Returns an empty list for every language in Part 0 (no curricula
/// authored yet). Parts A–J replace each stub asset with real content
/// without changing this provider's contract.
final learnCurriculumProvider = AsyncNotifierProvider.family<
    LearnCurriculumNotifier, List<Chapter>, LearnLanguage>(
  LearnCurriculumNotifier.new,
);

// ─── Active Curriculum (Part A integration) ────────────────────────────────
//
// The "active" curriculum is what the Learn screen, lesson content route,
// and exercise route actually render. It dispatches by the learner's
// currently selected Learn language:
//   - null (no selection) → legacy Sanskrit curriculum (curriculumProvider)
//   - LearnLanguage.hindi → learnCurriculumProvider(hindi)
//   - any other language → learnCurriculumProvider(that language)
//
// This indirection lets the Learn screen read ONE provider regardless of
// whether the learner is in the legacy Sanskrit path or a Learn Mode
// language, without the screens needing to know about the dispatch.
//
// Part A (Hindi) is the first language to ship real content. All other
// languages still return empty (their stubs are unchanged) — the Learn
// screen shows the "curriculum in development" banner for those.

/// FutureProvider that returns the active curriculum chapters.
///
/// Watches [selectedLearnLanguageProvider] and delegates to either the
/// legacy [curriculumProvider] or the per-language [learnCurriculumProvider]
/// family. Re-fetches automatically when the selection changes.
///
/// Returns an empty list (not an error) when:
/// - a Learn language is selected but its curriculum hasn't shipped yet
/// - the per-language asset fails to load (missing, malformed, schema mismatch)
///
/// The Learn screen treats an empty list as "no content available" and
/// shows the appropriate empty state.
final activeCurriculumProvider = FutureProvider<List<Chapter>>((ref) async {
  print('DEBUG activeCurriculumProvider: started');
  final selected = ref.watch(selectedLearnLanguageProvider);
  if (selected == null) {
    print('DEBUG activeCurriculumProvider: no language selected');
    return ref.watch(curriculumProvider.future);
  }
  print('DEBUG activeCurriculumProvider: language is ${selected}, awaiting learnCurriculumProvider');
  final result = await ref.watch(learnCurriculumProvider(selected).future);
  print('DEBUG activeCurriculumProvider: learnCurriculumProvider returned');
  return result;
});
