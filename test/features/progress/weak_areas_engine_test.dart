/// Weak-Area Engine + Exam Performance Tests
///
/// Pure derivations used by the Progress screen (listWeakLessons,
/// bestExamFractionForChapter) plus the provider-level wiring
/// (weakLessonsProvider, chapterBestFractionProvider) against seeded
/// persisted state - all real repository data, no fixtures in production.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

const Lesson kL1 = Lesson(
  id: 'ls_1',
  chapterId: 'ch_1',
  title: 'Lesson One',
  order: 0,
);
const Lesson kL2 = Lesson(
  id: 'ls_2',
  chapterId: 'ch_1',
  title: 'Lesson Two',
  order: 1,
);
const Lesson kL3 = Lesson(
  id: 'ls_3',
  chapterId: 'ch_2',
  title: 'Lesson Three',
  order: 2,
);
const Chapter kCh1 = Chapter(
  id: 'ch_1',
  title: 'Chapter One',
  lessons: [kL1, kL2],
);
const Chapter kCh2 = Chapter(
  id: 'ch_2',
  title: 'Chapter Two',
  lessons: [kL3],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('listWeakLessons (pure)', () {
    test('returns completed lessons with unmastered exercises in order', () {
      final weak = listWeakLessons(
        curriculum: const [kCh1, kCh2],
        completedLessons: {'ls_1', 'ls_2', 'ls_3'},
        masteredExerciseIdsByLesson: const {
          'ls_1': ['a', 'b'],
          'ls_2': <String>[],
          'ls_3': ['x', 'y', 'z'],
        },
        exerciseCountByLesson: const {
          'ls_1': 4,
          'ls_2': 4,
          'ls_3': 3,
        },
      );
      expect(weak.map((l) => l.id).toList(), ['ls_1', 'ls_2']);
    });

    test('skips not-completed lessons and lessons without exercises', () {
      final weak = listWeakLessons(
        curriculum: const [kCh1, kCh2],
        completedLessons: {'ls_1', 'ls_3'},
        masteredExerciseIdsByLesson: const {
          'ls_1': ['a'],
        },
        exerciseCountByLesson: const {
          'ls_1': 4,
          'ls_3': 0, // no exercises authored
        },
      );
      expect(weak.map((l) => l.id).toList(), ['ls_1']);
    });

    test('empty when everything is mastered', () {
      final weak = listWeakLessons(
        curriculum: const [kCh1, kCh2],
        completedLessons: {'ls_1', 'ls_2', 'ls_3'},
        masteredExerciseIdsByLesson: const {
          'ls_1': ['a', 'b', 'c', 'd'],
          'ls_2': ['e', 'f', 'g', 'h'],
          'ls_3': ['i', 'j', 'k'],
        },
        exerciseCountByLesson: const {
          'ls_1': 4,
          'ls_2': 4,
          'ls_3': 3,
        },
      );
      expect(weak, isEmpty);
    });

    test('empty for a fresh learner', () {
      final weak = listWeakLessons(
        curriculum: const [kCh1, kCh2],
        completedLessons: const {},
        masteredExerciseIdsByLesson: const {},
        exerciseCountByLesson: const {},
      );
      expect(weak, isEmpty);
    });
  });

  group('bestExamFractionForChapter (pure)', () {
    const quizIdsByChapter = {
      'ch_1': ['quiz_ch_1_beginner', 'quiz_ch_1_intermediate'],
    };

    test('best fraction across all quizzes of the chapter', () {
      final best = bestExamFractionForChapter(
        'ch_1',
        quizIdsByChapter,
        const {
          'quiz_ch_1_beginner': [
            QuizResult(
              quizId: 'quiz_ch_1_beginner',
              score: 3,
              total: 5,
              xpEarned: 30,
            ),
            QuizResult(
              quizId: 'quiz_ch_1_beginner',
              score: 5,
              total: 5,
              xpEarned: 50,
            ),
          ],
          'quiz_ch_1_intermediate': [
            QuizResult(
              quizId: 'quiz_ch_1_intermediate',
              score: 4,
              total: 5,
              xpEarned: 40,
            ),
          ],
        },
      );
      expect(best, 1.0);
    });

    test('zero when no attempts exist', () {
      expect(
        bestExamFractionForChapter('ch_1', quizIdsByChapter, const {}),
        0.0,
      );
    });

    test('zero for unknown chapter', () {
      expect(
        bestExamFractionForChapter('ch_nope', quizIdsByChapter, const {}),
        0.0,
      );
    });
  });

  group('provider wiring (real repository chain)', () {
    Future<ProviderContainer> makeContainer(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await container.read(curriculumProvider.future);
      return container;
    }

    test('weakLessonsProvider surfaces seeded mastery shortfalls', () async {
      final container = await makeContainer({
        'completed_lesson_ids': <String>[
          'ls_alphabet_vowels',
          'ls_alphabet_consonants',
        ],
        // Vowels mastered fully; consonants only 2 of 4.
        'mastered_exercises_ls_alphabet_vowels': jsonEncode(<String>[
          'ex_ls_alphabet_vowels_1',
          'ex_ls_alphabet_vowels_2',
          'ex_ls_alphabet_vowels_3',
          'ex_ls_alphabet_vowels_4',
        ]),
        'mastered_exercises_ls_alphabet_consonants': jsonEncode(<String>[
          'ex_ls_alphabet_consonants_1',
          'ex_ls_alphabet_consonants_2',
        ]),
      });
      addTearDown(container.dispose);
      final weak = container.read(weakLessonsProvider);
      expect(weak.map((l) => l.id).toList(), ['ls_alphabet_consonants']);
    });

    test('chapterBestFractionProvider reflects seeded attempts', () async {
      final container = await makeContainer({
        'quiz_attempts_quiz_ch_alphabet_beginner': jsonEncode([
          {
            'quizId': 'quiz_ch_alphabet_beginner',
            'score': 5,
            'total': 5,
            'xpEarned': 50
          },
        ]),
      });
      addTearDown(container.dispose);
      final best = container.read(chapterBestFractionProvider);
      expect(best['ch_alphabet'], 1.0);
      expect(best.containsKey('ch_words'), isFalse,
          reason: 'chapters without attempts must stay absent');
    });

    test('fresh learner has no weak lessons and no exam performance', () async {
      final container = await makeContainer(<String, Object>{});
      addTearDown(container.dispose);
      expect(container.read(weakLessonsProvider), isEmpty);
      expect(container.read(chapterBestFractionProvider), isEmpty);
    });
  });
}
