/// Sanskrit Curriculum — Seed Data (V1)
///
/// Static, curriculum-aligned content for CBSE Classes 6–10. This file now
/// serves two purposes:
///   1. Fallback data for [CurriculumLoader] when JSON parsing fails.
///   2. Source of lesson content strings (merged into JSON-loaded lessons).
///
/// The [curriculumProvider] has moved to [CurriculumLoader] (Segment 8) and
/// is now an AsyncNotifierProvider that loads from assets/curriculum/v1.json.
/// This file no longer exports a curriculumProvider — import from
/// curriculum_loader.dart instead.
///
/// Lesson content strings are defined in [sanskrit_lesson_content.dart].

import 'package:vaanix_app/features/learn/data/sanskrit_lesson_content.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// The full V1 curriculum, ordered by chapter → lesson.
/// Used as fallback by [CurriculumLoader] when JSON parsing fails.
final List<Chapter> sanskritCurriculum = [
  Chapter(
    id: 'ch_alphabet',
    title: 'देवनागरी · The Alphabet',
    subtitle: 'Svar (vowels) and Vyanjana (consonants)',
    order: 0,
    lessons: [
      Lesson(
        id: 'ls_alphabet_vowels',
        chapterId: 'ch_alphabet',
        title: 'स्वराः · Vowels',
        subtitle: 'Learn the 13 Sanskrit vowels (अ आ इ ई ...)',
        xpReward: 15,
        order: 0,
        content: kVowelsContent,
      ),
      Lesson(
        id: 'ls_alphabet_consonants',
        chapterId: 'ch_alphabet',
        title: 'व्यञ्जनानि · Consonants',
        subtitle: 'The 33 consonants and their sounds',
        difficulty: Difficulty.beginner,
        xpReward: 15,
        order: 1,
        content: kConsonantsContent,
      ),
      Lesson(
        id: 'ls_alphabet_barakhadi',
        chapterId: 'ch_alphabet',
        title: 'बाराखड़ी · Consonant + Vowel',
        subtitle: 'Combine consonants with each vowel',
        difficulty: Difficulty.intermediate,
        xpReward: 20,
        order: 2,
        content: kBarakhadiContent,
      ),
    ],
  ),
  Chapter(
    id: 'ch_words',
    title: 'शब्दाः · Words & Vocabulary',
    subtitle: 'Everyday Sanskrit words',
    order: 1,
    lessons: [
      Lesson(
        id: 'ls_words_greetings',
        chapterId: 'ch_words',
        title: 'अभिवादनम् · Greetings',
        subtitle: 'नमस्ते, सुप्रभातम्, शुभरात्रिः',
        xpReward: 10,
        order: 0,
        content: kGreetingsContent,
      ),
      Lesson(
        id: 'ls_words_family',
        chapterId: 'ch_words',
        title: 'परिवारः · Family',
        subtitle: 'माता, पिता, भ्राता, भगिनी',
        xpReward: 10,
        order: 1,
        content: kFamilyContent,
      ),
      Lesson(
        id: 'ls_words_numbers',
        chapterId: 'ch_words',
        title: 'सङ्ख्याः · Numbers 1–20',
        subtitle: 'एकम्, द्वे, त्रीणि ...',
        difficulty: Difficulty.intermediate,
        xpReward: 15,
        order: 2,
        content: kNumbersContent,
      ),
    ],
  ),
  Chapter(
    id: 'ch_sentences',
    title: 'वाक्यानि · Simple Sentences',
    subtitle: 'Form basic sentences',
    order: 2,
    lessons: [
      Lesson(
        id: 'ls_sentences_intro',
        chapterId: 'ch_sentences',
        title: 'परिचयः · Introducing Yourself',
        subtitle: 'मम नाम ... (My name is ...)',
        difficulty: Difficulty.intermediate,
        xpReward: 20,
        order: 0,
        content: kIntroContent,
      ),
      Lesson(
        id: 'ls_sentences_questions',
        chapterId: 'ch_sentences',
        title: 'प्रश्नाः · Asking Questions',
        subtitle: 'किम्? कुत्र? कदा?',
        difficulty: Difficulty.advanced,
        xpReward: 25,
        order: 1,
        content: kQuestionsContent,
      ),
    ],
  ),
];

/// A starter quiz for each chapter (7 questions total across the set).
/// Used as fallback by [CurriculumLoader] when JSON parsing fails.
final Map<String, List<QuizQuestion>> chapterQuizzes = {
  'ch_alphabet': [
    QuizQuestion(
      id: 'q_alpha_1',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'Which vowel is "आ"?',
      options: const ['a (short)', 'ā (long)', 'i (short)', 'u (short)'],
      correctIndex: 1,
      explanation: 'आ is the long "ā" vowel.',
    ),
    QuizQuestion(
      id: 'q_alpha_2',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'How many vowels are in the Sanskrit alphabet?',
      options: const ['10', '13', '16', '20'],
      correctIndex: 1,
      explanation: 'Sanskrit has 13 vowels (स्वराः).',
    ),
    QuizQuestion(
      id: 'q_alpha_3',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'Which is a consonant (व्यञ्जन)?',
      options: const ['अ', 'क', 'आ', 'ई'],
      correctIndex: 1,
      explanation: 'क (ka) is a velar consonant.',
    ),
  ],
  'ch_words': [
    QuizQuestion(
      id: 'q_words_1',
      chapterId: 'ch_words',
      difficulty: Difficulty.beginner,
      prompt: '"माता" means?',
      options: const ['Father', 'Mother', 'Sister', 'Brother'],
      correctIndex: 1,
    ),
    QuizQuestion(
      id: 'q_words_2',
      chapterId: 'ch_words',
      difficulty: Difficulty.intermediate,
      prompt: 'How do you say "one" in Sanskrit?',
      options: const ['द्वे', 'त्रीणि', 'एकम्', 'चत्वारि'],
      correctIndex: 2,
    ),
  ],
  'ch_sentences': [
    QuizQuestion(
      id: 'q_sent_1',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt: '"मम नाम" means?',
      options: const ['Your name', 'My name', 'His name', 'Our name'],
      correctIndex: 1,
    ),
    QuizQuestion(
      id: 'q_sent_2',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.advanced,
      prompt: '"किम्" is used to ask?',
      options: const ['Where', 'When', 'What', 'Why'],
      correctIndex: 2,
    ),
  ],
};

/// chapterQuizzesProvider has moved to [CurriculumLoader] (Segment 8).
/// Import from curriculum_loader.dart for the async chapterQuizProvider.
