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
import 'package:vaanix_app/features/learn/data/unit2_lesson_content.dart';
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
      Lesson(
        id: 'ls_alphabet_conjuncts',
        chapterId: 'ch_alphabet',
        title:
            '\u0938\u0902\u092F\u0941\u0915\u094D\u0924\u093E\u0915\u094D\u0937\u0930 – Conjunct Consonants',
        subtitle:
            'Join consonants: \u0915\u094D\u0937, \u0924\u094D\u0930, \u091C\u094D\u091E',
        difficulty: Difficulty.intermediate,
        xpReward: 20,
        order: 3,
        content: kConjunctsContent,
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
      Lesson(
        id: 'ls_sentences_translation',
        chapterId: 'ch_sentences',
        title: '\u0905\u0928\u0941\u0935\u093E\u0926 – Translation Practice',
        subtitle: 'Subject-Object-Verb sentences',
        difficulty: Difficulty.intermediate,
        xpReward: 20,
        order: 2,
        content: kTranslationContent,
      ),
    ],
  ),
  Chapter(
    id: 'ch_grammar',
    title:
        '\u0935\u094D\u092F\u093E\u0915\u0930\u0928\u092E\u094D – Basic Grammar',
    subtitle: 'Nouns, pronouns and verbs',
    order: 3,
    lessons: [
      Lesson(
        id: 'ls_grammar_nouns_cases',
        chapterId: 'ch_grammar',
        title: '\u0935\u093F\u092D\u0915\u094D\u0924\u093F – Nouns & Cases',
        subtitle: 'The 8 cases of a noun',
        difficulty: Difficulty.beginner,
        xpReward: 20,
        order: 0,
        content: kNounCasesContent,
      ),
      Lesson(
        id: 'ls_grammar_pronouns',
        chapterId: 'ch_grammar',
        title: '\u0938\u0930\u094D\u0935\u0928\u093E\u092E – Pronouns',
        subtitle:
            '\u0905\u0939\u0902, \u0924\u094D\u0935\u092E\u094D, \u0938\u0903, \u0938\u093E, \u0924\u0924\u094D',
        difficulty: Difficulty.beginner,
        xpReward: 15,
        order: 1,
        content: kPronounsContent,
      ),
      Lesson(
        id: 'ls_grammar_verbs',
        chapterId: 'ch_grammar',
        title: '\u0932\u0915\u093E\u0930 – Basic Verbs',
        subtitle: 'The present tense (\u0932\u0924\u094D)',
        difficulty: Difficulty.intermediate,
        xpReward: 20,
        order: 2,
        content: kVerbsContent,
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
    QuizQuestion(
      id: 'q_alpha_4',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'Which of these is a vowel?',
      options: const ['\u0915', '\u0906', '\u092A', '\u092E'],
      correctIndex: 1,
      explanation: '\u0906 (aa) is the long vowel "a".',
    ),
    QuizQuestion(
      id: 'q_alpha_5',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'How many consonants does Sanskrit have?',
      options: const ['23', '33', '43', '53'],
      correctIndex: 1,
      explanation:
          'Sanskrit has 33 consonants organized into 5 groups (vargas).',
    ),
    QuizQuestion(
      id: 'q_alpha_6',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.intermediate,
      prompt: 'Which speech group does \u0915 (ka) belong to?',
      options: const ['Dentals', 'Velars', 'Labials', 'Retroflex'],
      correctIndex: 1,
      explanation:
          '\u0915 (ka) is a velar - produced at the back of the throat.',
    ),
    QuizQuestion(
      id: 'q_alpha_7',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.intermediate,
      prompt: 'In barakhadi, which matra attaches on the LEFT of a consonant?',
      options: const [
        'Long a (\u093E)',
        'Short i (\u093F)',
        'Short u (\u0941)',
        'Long u (\u0942)'
      ],
      correctIndex: 1,
      explanation:
          'The short-i matra (\u093F) is the only one written on the left of a consonant.',
    ),
    QuizQuestion(
      id: 'q_alpha_11',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.beginner,
      prompt: 'Which of these is a conjunct consonant?',
      options: const ['\u0915\u094D\u0937', '\u0915', '\u0906', '\u0924'],
      correctIndex: 0,
      explanation:
          '\u0915\u094D\u0937 = \u0915 + \u0937 joined into one letter with the \u0939\u0932\u094D\u0905\u0928\u094D\u0924.',
    ),
    QuizQuestion(
      id: 'q_alpha_12',
      chapterId: 'ch_alphabet',
      difficulty: Difficulty.intermediate,
      prompt: '\u0924\u094D\u0930 is formed from?',
      options: const [
        '\u0924 + \u0930',
        '\u0915 + \u0937',
        '\u091C + \u091E',
        '\u0938 + \u0935'
      ],
      correctIndex: 0,
      explanation:
          '\u0924\u094D\u0930 = \u0924 + \u0930, as in \u0924\u094D\u0930\u092F\u0903 (three) and \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D (field).',
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
    QuizQuestion(
      id: 'q_words_3',
      chapterId: 'ch_words',
      difficulty: Difficulty.beginner,
      prompt: 'How do you say "good morning" in Sanskrit?',
      options: const [
        '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924\u092E\u094D',
        '\u0927\u0928\u094D\u092F\u0935\u093E\u0926\u0903',
        '\u0915\u0943\u092A\u092F\u093E',
        '\u0928\u092E\u0938\u094D\u0924\u0947',
      ],
      correctIndex: 0,
      explanation:
          '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924\u092E\u094D (suprabhatam) means "good morning".',
    ),
    QuizQuestion(
      id: 'q_words_4',
      chapterId: 'ch_words',
      difficulty: Difficulty.beginner,
      prompt: 'Which word means "mother"?',
      options: const [
        '\u092A\u093F\u0924\u093E',
        '\u092A\u0941\u0924\u094D\u0930\u0903',
        '\u092E\u093E\u0924\u093E',
        '\u092D\u0917\u093F\u0928\u0940',
      ],
      correctIndex: 2,
      explanation: '\u092E\u093E\u0924\u093E (maataa) means mother.',
    ),
    QuizQuestion(
      id: 'q_words_5',
      chapterId: 'ch_words',
      difficulty: Difficulty.intermediate,
      prompt:
          '\u092E\u093E\u0924\u0941\u0932\u0903 (maatulah) refers to which relative?',
      options: const [
        "Mother's brother",
        "Father's brother",
        "Mother's sister",
        'Grandfather',
      ],
      correctIndex: 0,
      explanation:
          "\u092E\u093E\u0924\u0941\u0932\u0903 (maatulah) is the mother's brother.",
    ),
    QuizQuestion(
      id: 'q_words_6',
      chapterId: 'ch_words',
      difficulty: Difficulty.intermediate,
      prompt: 'What number is \u0926\u094D\u0935\u093E\u0926\u0936 (dvadasha)?',
      options: const ['10', '11', '12', '20'],
      correctIndex: 2,
      explanation:
          '\u0926\u094D\u0935\u093E\u0926\u0936 = dve (two) + dasha (ten) = 12.',
    ),
    QuizQuestion(
      id: 'q_words_7',
      chapterId: 'ch_words',
      difficulty: Difficulty.intermediate,
      prompt: 'Which word means "twenty"?',
      options: const [
        '\u0935\u093F\u0902\u0936\u0924\u093F\u0903',
        '\u0936\u0924\u092E\u094D',
        '\u0928\u0935',
        '\u0926\u0936',
      ],
      correctIndex: 0,
      explanation:
          '\u0935\u093F\u0902\u0936\u0924\u093F\u0903 (vimshatih) means twenty; \u0936\u0924\u092E\u094D (satam) is a hundred.',
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
    QuizQuestion(
      id: 'q_sent_3',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt: 'Which word means "I" in Sanskrit?',
      options: const [
        '\u0905\u0939\u092E\u094D',
        '\u092E\u092E',
        '\u0928\u093E\u092E',
        '\u0915\u093F\u092E\u094D',
      ],
      correctIndex: 0,
      explanation: '\u0905\u0939\u092E\u094D (aham) means "I".',
    ),
    QuizQuestion(
      id: 'q_sent_4',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt: 'Which question word means "where"?',
      options: const [
        '\u0915\u0941\u0924\u094D\u0930',
        '\u0915\u0926\u093E',
        '\u0915\u0925\u092E\u094D',
        '\u0915\u093F\u092E\u0930\u094D\u0925\u092E\u094D',
      ],
      correctIndex: 0,
      explanation: '\u0915\u0941\u0924\u094D\u0930 (kutra) means "where".',
    ),
    QuizQuestion(
      id: 'q_sent_5',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt: 'How do you say "My name is ..." in Sanskrit?',
      options: const [
        '\u092E\u092E \u0928\u093E\u092E ...',
        '\u0928\u093E\u092E \u092E\u092E ...',
        '\u0905\u0939\u092E\u094D \u091B\u093E\u0924\u094D\u0930\u0903',
        '\u0915\u093F\u092E\u094D \u090F\u0924\u0924\u094D',
      ],
      correctIndex: 0,
      explanation:
          '\u092E\u092E \u0928\u093E\u092E ... (mama nama ...) means "My name is ...".',
    ),
    QuizQuestion(
      id: 'q_sent_6',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.advanced,
      prompt:
          'What does \u0915\u093F\u092E\u0930\u094D\u0925\u092E\u094D (kimartham) ask for?',
      options: const ['Why', 'How', 'Where', 'When'],
      correctIndex: 0,
      explanation:
          '\u0915\u093F\u092E\u0930\u094D\u0925\u092E\u094D (kimartham) means "why".',
    ),
    QuizQuestion(
      id: 'q_sent_7',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt:
          '"\u092E\u093E\u0924\u093E \u0905\u0928\u094D\u0928\u092E\u094D \u092A\u091A\u0924\u093F" means?',
      options: const [
        'Mother cooks food',
        'Mother reads a book',
        'The girl drinks water',
        'Mother goes to school'
      ],
      correctIndex: 0,
      explanation:
          '\u092E\u093E\u0924\u093E (mother) + \u0905\u0928\u094D\u0928\u092E\u094D (food) + \u092A\u091A\u0924\u093F (cooks): mother cooks food.',
    ),
    QuizQuestion(
      id: 'q_sent_8',
      chapterId: 'ch_sentences',
      difficulty: Difficulty.intermediate,
      prompt: 'Which word order does a Sanskrit sentence follow?',
      options: const [
        'Subject-Object-Verb',
        'Subject-Verb-Object',
        'Verb-Subject-Object',
        'Object-Verb-Subject'
      ],
      correctIndex: 0,
      explanation:
          'SOV: "\u0930\u093E\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u093E\u0926\u0924\u093F" – Ram a fruit eats.',
    ),
  ],
  'ch_grammar': [
    QuizQuestion(
      id: 'q_gram_1',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.beginner,
      prompt: 'How many cases does a Sanskrit noun have?',
      options: const ['6', '7', '8', '10'],
      correctIndex: 2,
      explanation:
          'Sanskrit has 8 cases, from \u092A\u094D\u0930\u0925\u092E\u093E (nominative) to \u0938\u092E\u094D\u092C\u094B\u0927\u0928 (vocative).',
    ),
    QuizQuestion(
      id: 'q_gram_2',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.beginner,
      prompt: 'Which case marks the subject (\u0915\u0930\u094D\u0924\u093E)?',
      options: const [
        '\u092A\u094D\u0930\u0925\u092E\u093E',
        '\u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E',
        '\u0937\u0937\u094D\u0920\u0940',
        '\u0938\u092A\u094D\u0924\u092E\u0940'
      ],
      correctIndex: 0,
      explanation:
          '\u092A\u094D\u0930\u0925\u092E\u093E (nominative) is the subject case: \u092C\u093E\u0932\u0915\u0903 - the boy.',
    ),
    QuizQuestion(
      id: 'q_gram_3',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.beginner,
      prompt: 'Which pronoun means "I"?',
      options: const [
        '\u0905\u0939\u0902',
        '\u0924\u094D\u0935\u092E\u094D',
        '\u0938\u0903',
        '\u0938\u093E'
      ],
      correctIndex: 0,
      explanation:
          '\u0905\u0939\u0902 = I. \u0905\u0939\u0902 \u092A\u0920\u093E\u092E\u093F - I read.',
    ),
    QuizQuestion(
      id: 'q_gram_4',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.beginner,
      prompt: 'Which pronoun means "she"?',
      options: const [
        '\u0938\u093E',
        '\u0938\u0903',
        '\u0924\u0924\u094D',
        '\u0924\u094D\u0935\u092E\u094D'
      ],
      correctIndex: 0,
      explanation:
          '\u0938\u093E = she; \u0938\u0903 = he; \u0924\u0924\u094D = it.',
    ),
    QuizQuestion(
      id: 'q_gram_5',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.intermediate,
      prompt:
          'In "\u0930\u093E\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u093E\u0926\u0924\u093F", what is the object (\u0915\u0930\u094D\u092E)?',
      options: const [
        '\u092B\u0932\u092E\u094D',
        '\u0930\u093E\u092E\u0903',
        '\u0916\u093E\u0926\u0924\u093F',
        '\u0905\u0939\u0902'
      ],
      correctIndex: 0,
      explanation:
          '\u092B\u0932\u092E\u094D (fruit) receives the action - it is \u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E, the object case.',
    ),
    QuizQuestion(
      id: 'q_gram_6',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.intermediate,
      prompt:
          'Which is the third-person singular present form of \u092A\u0920\u094D?',
      options: const [
        '\u092A\u0920\u0924\u093F',
        '\u092A\u0920\u0928\u094D\u0924\u093F',
        '\u092A\u0920\u093E\u092E\u093F',
        '\u092A\u0920\u0938\u093F'
      ],
      correctIndex: 0,
      explanation:
          '\u092A\u0920\u0924\u093F = he/she reads. The ending -\u0924\u093F marks he/she/it.',
    ),
    QuizQuestion(
      id: 'q_gram_7',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.intermediate,
      prompt: '\u092C\u093E\u0932\u0915\u0938\u094D\u092F means?',
      options: const ['of the boy', 'to the boy', 'by the boy', 'from the boy'],
      correctIndex: 0,
      explanation:
          '\u092C\u093E\u0932\u0915\u0938\u094D\u092F is \u0937\u0937\u094D\u0920\u0940 (genitive): "of the boy" - \u092C\u093E\u0932\u0915\u0938\u094D\u092F \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D, the boy\'s book.',
    ),
    QuizQuestion(
      id: 'q_gram_8',
      chapterId: 'ch_grammar',
      difficulty: Difficulty.intermediate,
      prompt: 'Which sentence means "I go to school"?',
      options: const [
        '\u0905\u0939\u0902 \u0935\u093F\u0926\u094D\u092F\u093E\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u093E\u092E\u093F',
        '\u0905\u0939\u0902 \u092B\u0932\u092E\u094D \u0916\u093E\u0926\u093E\u092E\u093F',
        '\u0924\u094D\u0935\u092E\u094D \u0935\u093F\u0926\u094D\u092F\u093E\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u093E\u092E\u093F',
        '\u0938\u0903 \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D \u092A\u0920\u0924\u093F'
      ],
      correctIndex: 0,
      explanation:
          '\u0905\u0939\u0902 \u0935\u093F\u0926\u094D\u092F\u093E\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u093E\u092E\u093F - I / to school / go: subject-object-verb.',
    ),
  ],
};

/// chapterQuizzesProvider has moved to [CurriculumLoader] (Segment 8).
/// Import from curriculum_loader.dart for the async chapterQuizProvider.
