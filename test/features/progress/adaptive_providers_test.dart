/// Adaptive Provider Integration Tests
///
/// Proves the FULL production chain outside the widget tree: persisted
/// SharedPreferences seed -> progress providers -> adaptive engine output.
/// Plain (real-async) tests so the curriculum asset load settles for real.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

const List<String> kFirstThreeLessons = [
  'ls_alphabet_vowels',
  'ls_alphabet_consonants',
  'ls_alphabet_barakhadi',
];

const List<String> kAllLessonIds = [
  'ls_alphabet_vowels',
  'ls_alphabet_consonants',
  'ls_alphabet_barakhadi',
  'ls_alphabet_conjuncts',
  'ls_words_greetings',
  'ls_words_family',
  'ls_words_numbers',
  'ls_sentences_intro',
  'ls_sentences_questions',
  'ls_sentences_translation',
  'ls_grammar_nouns_cases',
  'ls_grammar_pronouns',
  'ls_grammar_verbs',
];

const List<String> kAllQuizIds = [
  'quiz_ch_alphabet_beginner',
  'quiz_ch_alphabet_intermediate',
  'quiz_ch_words_beginner',
  'quiz_ch_words_intermediate',
  'quiz_ch_sentences_intermediate',
  'quiz_ch_sentences_advanced',
  'quiz_ch_grammar_beginner',
  'quiz_ch_grammar_intermediate',
];

Future<ProviderContainer> _makeContainer(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Let the REAL curriculum load settle (plain test zone = real async).
  // The quiz-id catalog derives from the same JSON asset — the single
  // Phase 2 source — so it must be settled too before any read.
  await container.read(curriculumProvider.future);
  await container.read(quizBankProvider.future);
  return container;
}

Future<NextAction> _actionFor(Map<String, Object> seed) async {
  final container = await _makeContainer(seed);
  addTearDown(container.dispose);
  return container.read(adaptiveNextActionProvider);
}

Map<String, Object> _passingAttempts() {
  final prefs = <String, Object>{};
  for (final id in kAllQuizIds) {
    prefs['quiz_attempts_$id'] = jsonEncode([
      {'quizId': id, 'score': 5, 'total': 5, 'xpEarned': 50},
    ]);
  }
  return prefs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh learner gets startJourney with the first lesson', () async {
    final action = await _actionFor(<String, Object>{});
    expect(action.action, AdaptiveAction.startJourney);
    expect(action.label, 'Start Learning');
    expect(action.lessonId, 'ls_alphabet_vowels');
    expect(action.vanMessage, contains('Namaste'));
  });

  test('part-way learner with unmastered exercises gets practiceWeakTopic',
      () async {
    // Completing lessons without mastering their exercises must surface
    // practice BEFORE continuing - the mastered-exercise read path runs
    // against the real curriculum here.
    final action = await _actionFor(
      {AppConstants.keyCompletedLessonIds: kFirstThreeLessons},
    );
    expect(action.action, AdaptiveAction.practiceWeakTopic);
    expect(action.lessonId, 'ls_alphabet_vowels');
    expect(action.label, contains('Practice'));
    expect(action.subtitle, contains('0 of'));
  });

  test('part-way learner with everything mastered gets continueLesson',
      () async {
    final action = await _actionFor(
      {
        AppConstants.keyCompletedLessonIds: kFirstThreeLessons,
        // Mastery is persisted as a JSON-encoded string list.
        'mastered_exercises_ls_alphabet_vowels': jsonEncode(<String>[
          'ex_ls_alphabet_vowels_1',
          'ex_ls_alphabet_vowels_2',
          'ex_ls_alphabet_vowels_3',
          'ex_ls_alphabet_vowels_4',
        ]),
        'mastered_exercises_ls_alphabet_consonants': jsonEncode(<String>[
          'ex_ls_alphabet_consonants_1',
          'ex_ls_alphabet_consonants_2',
          'ex_ls_alphabet_consonants_3',
          'ex_ls_alphabet_consonants_4',
        ]),
        'mastered_exercises_ls_alphabet_barakhadi': jsonEncode(<String>[
          'ex_ls_alphabet_barakhadi_1',
          'ex_ls_alphabet_barakhadi_2',
          'ex_ls_alphabet_barakhadi_3',
          'ex_ls_alphabet_barakhadi_4',
        ]),
      },
    );
    expect(action.action, AdaptiveAction.continueLesson);
    expect(action.lessonId, 'ls_alphabet_conjuncts');
    expect(action.label, contains('Continue'));
  });

  test('syllabus complete but no exam passed gets takeChapterExam', () async {
    final action = await _actionFor(
      {AppConstants.keyCompletedLessonIds: kAllLessonIds},
    );
    expect(action.action, AdaptiveAction.takeChapterExam);
    expect(action.chapterId, 'ch_alphabet');
    expect(action.title, 'Exam time!');
  });

  test('syllabus complete AND all exams passed gets allDone', () async {
    final action = await _actionFor(
      {
        AppConstants.keyCompletedLessonIds: kAllLessonIds,
        ..._passingAttempts(),
      },
    );
    expect(action.action, AdaptiveAction.allDone);
    expect(action.label, 'Revise with VAN');
  });
}
