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

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
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
        if (content != null && (lesson.content == null || lesson.content!.isEmpty)) {
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

/// Loads quiz questions for a specific chapter from the JSON.
/// Falls back to the hardcoded chapterQuizzes map.
Future<List<QuizQuestion>> loadQuizForChapter(String chapterId) async {
  try {
    final raw = await rootBundle.loadString('assets/curriculum/v1.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final quizzesJson = json['quizzes'] as List<dynamic>? ?? [];

    for (final quiz in quizzesJson) {
      final quizMap = quiz as Map<String, dynamic>;
      if (quizMap['chapterId'] as String? == chapterId) {
        final questions = quizMap['questions'] as List<dynamic>? ?? [];
        return questions
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // No quiz found for this chapter in JSON — fall back to hardcoded.
    return chapterQuizzes[chapterId] ?? const [];
  } catch (e) {
    return chapterQuizzes[chapterId] ?? const [];
  }
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

/// Quiz questions for a specific chapter (async family provider).
final chapterQuizProvider =
    FutureProvider.family<List<QuizQuestion>, String>(
  (ref, chapterId) => loadQuizForChapter(chapterId),
);
