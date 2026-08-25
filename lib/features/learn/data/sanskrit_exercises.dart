/// Sanskrit Exercises — Learn V1 practice content.
///
/// Every exercise is grounded in the actual lesson content strings in
/// [sanskrit_lesson_content.dart] (vocabulary tables, word breakdowns,
/// and examples). Exercises are keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically.
///
/// Content note: this is a starter practice set (3-4 exercises per
/// lesson). The same structure supports arbitrary scaling.

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Exercises keyed by lesson id.
final Map<String, List<Exercise>> exercisesByLesson = {
  // ---------------------------------------------------------------
  // Chapter 1: The Alphabet
  // ---------------------------------------------------------------
  'ls_alphabet_vowels': const [
    Exercise(
      id: 'ex_ls_alphabet_vowels_1',
      hint:
          'The 13 vowels count short and long forms (a/aa, i/ii, u/uu) as separate letters, plus e, ai, o, au.',
      lessonId: 'ls_alphabet_vowels',
      type: ExerciseType.mcq,
      prompt: 'How many vowels (svara) does Sanskrit have?',
      options: ['10', '13', '16', '20'],
      correctIndex: 1,
      explanation:
          'Sanskrit has 13 vowels: the short and long forms plus e, ai, o, au.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_vowels_2',
      lessonId: 'ls_alphabet_vowels',
      type: ExerciseType.mcq,
      prompt: 'Which of these is a LONG vowel?',
      options: ['a', 'ā', 'i', 'u'],
      correctIndex: 1,
      explanation:
          'ā (आ) is the long form of a (अ). The vertical stroke marks length.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_vowels_3',
      hint:
          'Fire in Sanskrit is agni; the first sound is the short a, like the a in the word about.',
      lessonId: 'ls_alphabet_vowels',
      type: ExerciseType.mcq,
      prompt: 'The word अग्नि (agni) starts with which vowel sound?',
      options: ['short a', 'long ā', 'short i', 'short u'],
      correctIndex: 0,
      explanation: 'agni (fire) begins with short a.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_vowels_4',
      lessonId: 'ls_alphabet_vowels',
      type: ExerciseType.fillBlank,
      prompt: 'आ (ā) is the ___ version of अ (a).',
      options: ['long', 'short', 'nasal', 'aspirated'],
      correctIndex: 0,
      explanation: 'The extra stroke turns the short vowel into the long one.',
    ),
  ],

  'ls_alphabet_consonants': const [
    Exercise(
      id: 'ex_ls_alphabet_consonants_1',
      lessonId: 'ls_alphabet_consonants',
      type: ExerciseType.mcq,
      prompt: 'क (ka), ख (kha), ग (ga) belong to which group?',
      options: ['Velars', 'Palatals', 'Dentals', 'Labials'],
      correctIndex: 0,
      explanation: 'Velars (kaṇṭhya) are produced at the back of the throat.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_consonants_2',
      hint:
          'The consonants are arranged in five groups of five (ka, ca, ta, tha, pa), plus a few more at the end.',
      lessonId: 'ls_alphabet_consonants',
      type: ExerciseType.mcq,
      prompt: 'How many consonants does Sanskrit have?',
      options: ['23', '33', '43', '53'],
      correctIndex: 1,
      explanation: 'Sanskrit has 33 consonants, organised into 5 groups.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_consonants_3',
      lessonId: 'ls_alphabet_consonants',
      type: ExerciseType.mcq,
      prompt: 'Which of these is a NASAL consonant?',
      options: ['ङ (ṅa)', 'क (ka)', 'प (pa)', 'त (ta)'],
      correctIndex: 0,
      explanation: 'Each group ends with a nasal; ṅa is the velar nasal.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_consonants_4',
      lessonId: 'ls_alphabet_consonants',
      type: ExerciseType.fillBlank,
      prompt: 'ख (kha) is the ___ version of क (ka).',
      options: ['aspirated', 'voiced', 'nasal', 'retroflex'],
      correctIndex: 0,
      explanation: 'Aspirated consonants are said with an extra puff of air.',
    ),
  ],

  'ls_alphabet_barakhadi': const [
    Exercise(
      id: 'ex_ls_alphabet_barakhadi_1',
      lessonId: 'ls_alphabet_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'Which matra attaches on the LEFT of a consonant?',
      options: ['ि (short i)', 'ा (long ā)', 'े (e)', 'ु (u)'],
      correctIndex: 0,
      explanation: 'The short-i matra is the only left-attaching matra.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_barakhadi_2',
      hint:
          'A matra is a vowel sign. Question marks stand for a consonant, a vowel sign, and their combination.',
      lessonId: 'ls_alphabet_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'क + आ = ?',
      options: ['क (ka)', 'का (kā)', 'कि (ki)', 'कु (ku)'],
      correctIndex: 1,
      explanation: 'Adding the ā-stroke to ka gives kā.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_barakhadi_3',
      lessonId: 'ls_alphabet_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'कमल (kamala) means?',
      options: ['lotus', 'name', 'song', 'book'],
      correctIndex: 0,
      explanation: 'kamala = lotus; nāma = name; gītā = song; pustaka = book.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_barakhadi_4',
      lessonId: 'ls_alphabet_barakhadi',
      type: ExerciseType.ordering,
      prompt: 'Arrange the barakhadi forms of क in the correct order:',
      items: ['क (ka)', 'का (kā)', 'कि (ki)', 'की (kī)'],
      explanation: 'The vowel sounds progress in alphabet order: a, ā, i, ī.',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 2: Words & Vocabulary
  // ---------------------------------------------------------------
  'ls_words_greetings': const [
    Exercise(
      id: 'ex_ls_words_greetings_1',
      lessonId: 'ls_words_greetings',
      type: ExerciseType.mcq,
      prompt: 'नमस्ते (namaste) literally means?',
      options: ['I bow to you', 'Good morning', 'Thank you', 'Please'],
      correctIndex: 0,
      explanation: 'namaḥ "bow" + te "to you".',
    ),
    Exercise(
      id: 'ex_ls_words_greetings_2',
      hint:
          'This greeting is used in the morning; su means good and prabhata relates to dawn.',
      lessonId: 'ls_words_greetings',
      type: ExerciseType.mcq,
      prompt: 'सुप्रभातम् (suprabhātam) means?',
      options: ['Good morning', 'Good night', 'Thank you', 'Goodbye'],
      correctIndex: 0,
      explanation: 'su "good" + prabhāta "dawn".',
    ),
    Exercise(
      id: 'ex_ls_words_greetings_3',
      hint: 'It is what you say after someone helps you - a thank-you.',
      lessonId: 'ls_words_greetings',
      type: ExerciseType.mcq,
      prompt: 'धन्यवादः (dhanyavādaḥ) means?',
      options: ['Thank you', 'Please', 'Excuse me', 'Welcome'],
      correctIndex: 0,
      explanation: 'dhanya "grateful" + vāda "speech".',
    ),
    Exercise(
      id: 'ex_ls_words_greetings_4',
      lessonId: 'ls_words_greetings',
      type: ExerciseType.ordering,
      prompt: 'Order these greetings by time of day (morning first):',
      items: [
        'सुप्रभातम् (suprabhātam)',
        'शुभ सायम् (śubha sāyam)',
        'शुभरात्रिः (śubharātriḥ)'
      ],
      explanation: 'Morning → evening → night.',
    ),
  ],

  'ls_words_family': const [
    Exercise(
      id: 'ex_ls_words_family_1',
      lessonId: 'ls_words_family',
      type: ExerciseType.mcq,
      prompt: 'मातृ (mātṛ) means?',
      options: ['Mother', 'Father', 'Sister', 'Wife'],
      correctIndex: 0,
      explanation: 'mātṛ = mother.',
    ),
    Exercise(
      id: 'ex_ls_words_family_2',
      lessonId: 'ls_words_family',
      type: ExerciseType.mcq,
      prompt: 'पितृ (pitṛ) means?',
      options: ['Father', 'Brother', 'Uncle', 'Son'],
      correctIndex: 0,
      explanation: 'pitṛ = father.',
    ),
    Exercise(
      id: 'ex_ls_words_family_3',
      hint:
          'The root mat tells you this relative is from the mother side of the family.',
      lessonId: 'ls_words_family',
      type: ExerciseType.mcq,
      prompt: 'Who is a मातुल (mātula)?',
      options: [
        'Mother\u2019s brother',
        'Father\u2019s brother',
        'Mother\u2019s sister',
        'Grandfather'
      ],
      correctIndex: 0,
      explanation: 'mātula is specifically the maternal uncle.',
    ),
    Exercise(
      id: 'ex_ls_words_family_4',
      lessonId: 'ls_words_family',
      type: ExerciseType.fillBlank,
      prompt: 'भगिनी (bhaginī) means ___.',
      options: ['Sister', 'Daughter', 'Aunt', 'Wife'],
      correctIndex: 0,
      explanation: 'bhaginī = sister.',
    ),
  ],

  'ls_words_numbers': const [
    Exercise(
      id: 'ex_ls_words_numbers_1',
      lessonId: 'ls_words_numbers',
      type: ExerciseType.mcq,
      prompt: 'How do you say ONE in Sanskrit?',
      options: ['ekam', 'dve', 'trīṇi', 'catvāri'],
      correctIndex: 0,
      explanation: 'ekam = one, dve = two, trīṇi = three, catvāri = four.',
    ),
    Exercise(
      id: 'ex_ls_words_numbers_2',
      hint: 'Think of chatur, the number that comes just before five.',
      lessonId: 'ls_words_numbers',
      type: ExerciseType.mcq,
      prompt: 'चत्वारि (catvāri) means?',
      options: ['Four', 'Five', 'Six', 'Seven'],
      correctIndex: 0,
      explanation: 'catvāri = four.',
    ),
    Exercise(
      id: 'ex_ls_words_numbers_3',
      hint: 'eka means one and dasa means ten; the word for 11 joins them.',
      lessonId: 'ls_words_numbers',
      type: ExerciseType.mcq,
      prompt: 'The word एकादश (ekādaśa) for 11 combines:',
      options: [
        'eka "one" + daśa "ten"',
        'daśa "ten" + eka "one"',
        'dve "two" + daśa "ten"',
        'eka "one" + śata "hundred"'
      ],
      correctIndex: 0,
      explanation: '11 = "one-ten", just like seventeen = seven + ten.',
    ),
    Exercise(
      id: 'ex_ls_words_numbers_4',
      lessonId: 'ls_words_numbers',
      type: ExerciseType.fillBlank,
      prompt: 'शतम् (śatam) means ___.',
      options: ['one hundred', 'one thousand', 'ten', 'twenty'],
      correctIndex: 0,
      explanation: 'śatam = 100; sahasram = 1000.',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 3: Simple Sentences
  // ---------------------------------------------------------------
  'ls_sentences_intro': const [
    Exercise(
      id: 'ex_ls_sentences_intro_1',
      hint:
          'mama means my and nama means name; it is how you introduce yourself.',
      lessonId: 'ls_sentences_intro',
      type: ExerciseType.mcq,
      prompt: 'मम नाम (mama nāma) means?',
      options: ['my name', 'your name', 'his name', 'her name'],
      correctIndex: 0,
      explanation: 'mama = my; nāma = name.',
    ),
    Exercise(
      id: 'ex_ls_sentences_intro_2',
      lessonId: 'ls_sentences_intro',
      type: ExerciseType.mcq,
      prompt: 'अहम् (aham) means?',
      options: ['I', 'you', 'he', 'we'],
      correctIndex: 0,
      explanation: 'aham = I, the first-person pronoun.',
    ),
    Exercise(
      id: 'ex_ls_sentences_intro_3',
      lessonId: 'ls_sentences_intro',
      type: ExerciseType.mcq,
      prompt: 'To ask a male respectfully "What is your name?", say:',
      options: [
        'bhavataḥ nāma kim?',
        'bhavatyāḥ nāma kim?',
        'mama nāma kim?',
        'aham nāma kim?'
      ],
      correctIndex: 0,
      explanation: 'bhavataḥ nāma kim?; use bhavatyāḥ for a female.',
    ),
    Exercise(
      id: 'ex_ls_sentences_intro_4',
      lessonId: 'ls_sentences_intro',
      type: ExerciseType.fillBlank,
      prompt: 'अहं छात्रः (aham chātraḥ) means "I am a ___".',
      options: ['student', 'teacher', 'Indian', 'doctor'],
      correctIndex: 0,
      explanation: 'chātraḥ = student.',
    ),
  ],

  'ls_sentences_questions': const [
    Exercise(
      id: 'ex_ls_sentences_questions_1',
      lessonId: 'ls_sentences_questions',
      type: ExerciseType.mcq,
      prompt: 'किम् (kim) asks?',
      options: ['What?', 'Where?', 'When?', 'How?'],
      correctIndex: 0,
      explanation: 'kim = what.',
    ),
    Exercise(
      id: 'ex_ls_sentences_questions_2',
      hint:
          'When you lose your book you ask this word to find out where it is.',
      lessonId: 'ls_sentences_questions',
      type: ExerciseType.mcq,
      prompt: 'कुत्र (kutra) asks?',
      options: ['Where?', 'Who?', 'Why?', 'How many?'],
      correctIndex: 0,
      explanation: 'kutra = where.',
    ),
    Exercise(
      id: 'ex_ls_sentences_questions_3',
      lessonId: 'ls_sentences_questions',
      type: ExerciseType.mcq,
      prompt: 'कदा (kadā) asks?',
      options: ['When?', 'What?', 'How?', 'Who?'],
      correctIndex: 0,
      explanation: 'kadā = when.',
    ),
    Exercise(
      id: 'ex_ls_sentences_questions_4',
      hint:
          'It begins a question about the way something is done - the how question word.',
      lessonId: 'ls_sentences_questions',
      type: ExerciseType.fillBlank,
      prompt: 'कथम् (katham) asks ___?',
      options: ['How?', 'Where?', 'What?', 'Why?'],
      correctIndex: 0,
      explanation: 'katham = how.',
    ),
  ],
};
