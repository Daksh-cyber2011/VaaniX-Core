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
  // ---------------------------------------------------------------
  // Chapter 1 (expanded): Conjunct Consonants
  // ---------------------------------------------------------------
  'ls_alphabet_conjuncts': const [
    Exercise(
      id: 'ex_ls_alphabet_conjuncts_1',
      hint:
          'It is the small diagonal mark under a consonant that removes its built-in "a".',
      lessonId: 'ls_alphabet_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'What does the halanta \u094D do to a consonant?',
      options: [
        'Removes its built-in vowel',
        'Adds a long vowel',
        'Doubles the consonant',
        'Makes it an independent letter'
      ],
      correctIndex: 0,
      explanation:
          'Every consonant hides an "a" (ka, ta...). The halanta \u094D removes it: \u0915\u094D = k only, so \u0915\u094D + \u0937 can blend into \u0915\u094D\u0937.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_conjuncts_2',
      hint: 'A conjunct is two consonants written as ONE unit.',
      lessonId: 'ls_alphabet_conjuncts',
      type: ExerciseType.mcq,
      prompt:
          'Which of these is a conjunct consonant (\u0938\u0902\u092F\u0941\u0915\u094D\u0924\u093E\u0915\u094D\u0937\u0930)?',
      options: ['\u0915\u094D\u0937', '\u0915', '\u0906', '\u0924'],
      correctIndex: 0,
      explanation:
          '\u0915\u094D\u0937 is \u0915\u094D + \u0937 joined into one letter. \u0915, \u0906 and \u0924 are single letters, not conjuncts.',
    ),
    Exercise(
      id: 'ex_ls_alphabet_conjuncts_3',
      hint:
          '\u0924\u094D\u0930 starts with \u0924\u094D (the "t" without a vowel).',
      lessonId: 'ls_alphabet_conjuncts',
      type: ExerciseType.fillBlank,
      prompt: '\u0924\u094D\u0930 = \u0924\u094D + which letter?',
      options: ['\u0930', '\u0935', '\u0923', '\u0928'],
      correctIndex: 0,
      explanation:
          '\u0924\u094D\u0930 = \u0924\u094D + \u0930. Examples: \u0924\u094D\u0930\u092F\u0903 (three), \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D (field).',
    ),
    Exercise(
      id: 'ex_ls_alphabet_conjuncts_4',
      hint:
          '\u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D is a three-part word: the conjunct with -\u0947, then \u0924\u094D\u0930, then -\u092E\u094D.',
      lessonId: 'ls_alphabet_conjuncts',
      type: ExerciseType.ordering,
      prompt:
          'Arrange the parts to spell \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D (field).',
      items: ['\u0915\u094D\u0937\u0947', '\u0924\u094D\u0930', '\u092E\u094D'],
      explanation:
          '\u0915\u094D\u0937\u0947 + \u0924\u094D\u0930 + \u092E\u094D = \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D, exactly as in the lesson table.',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 4: Basic Grammar - Nouns & Cases
  // ---------------------------------------------------------------
  'ls_grammar_nouns_cases': const [
    Exercise(
      id: 'ex_ls_grammar_nouns_cases_1',
      hint:
          'Nominative, accusative, instrumental, dative, ablative, genitive, locative, vocative.',
      lessonId: 'ls_grammar_nouns_cases',
      type: ExerciseType.mcq,
      prompt:
          'How many cases (\u0935\u093F\u092D\u0915\u094D\u0924\u093F) does a Sanskrit noun have?',
      options: ['6', '7', '8', '10'],
      correctIndex: 2,
      explanation:
          'Sanskrit has 8 cases: \u092A\u094D\u0930\u0925\u092E\u093E to \u0938\u092E\u094D\u092C\u094B\u0927\u0928. The ending of the noun shows its job.',
    ),
    Exercise(
      id: 'ex_ls_grammar_nouns_cases_2',
      hint: 'It is the case that does the action - the subject.',
      lessonId: 'ls_grammar_nouns_cases',
      type: ExerciseType.mcq,
      prompt: 'Which case marks the SUBJECT (\u0915\u0930\u094D\u0924\u093E)?',
      options: [
        '\u092A\u094D\u0930\u0925\u092E\u093E (nominative)',
        '\u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E (accusative)',
        '\u0937\u0937\u094D\u0920\u0940 (genitive)',
        '\u0938\u092A\u094D\u0924\u092E\u0940 (locative)'
      ],
      correctIndex: 0,
      explanation:
          '\u092A\u094D\u0930\u0925\u092E\u093E (nominative) is the subject case: \u092C\u093E\u0932\u0915\u0903 \u0916\u093E\u0926\u0924\u093F - the boy eats.',
    ),
    Exercise(
      id: 'ex_ls_grammar_nouns_cases_3',
      hint:
          'The object form of \u092C\u093E\u0932\u0915 ends like \u092B\u0932\u092E\u094D - with -\u092E\u094D.',
      lessonId: 'ls_grammar_nouns_cases',
      type: ExerciseType.fillBlank,
      prompt:
          '\u092C\u093E\u0932\u0915\u0903 is nominative. The ACCUSATIVE (object) form is ___',
      options: [
        '\u092C\u093E\u0932\u0915\u092E\u094D',
        '\u092C\u093E\u0932\u0915\u0947\u0928',
        '\u092C\u093E\u0932\u0915\u093E\u0924\u094D',
        '\u092C\u093E\u0932\u0915\u0938\u094D\u092F'
      ],
      correctIndex: 0,
      explanation:
          '\u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E adds -\u092E\u094D: \u092C\u093E\u0932\u0915\u092E\u094D. \u0930\u093E\u092E\u0903 \u092C\u093E\u0932\u0915\u092E\u094D pasyati - Ram sees the boy.',
    ),
    Exercise(
      id: 'ex_ls_grammar_nouns_cases_4',
      hint: 'They run 1-4 in the lesson table order.',
      lessonId: 'ls_grammar_nouns_cases',
      type: ExerciseType.ordering,
      prompt: 'Order the first four cases as they appear in the lesson.',
      items: [
        '\u092A\u094D\u0930\u0925\u092E\u093E',
        '\u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E',
        '\u0924\u0943\u0924\u0940\u092F\u093E',
        '\u091A\u0924\u0941\u0930\u094D\u0925\u0940'
      ],
      explanation:
          '1 \u092A\u094D\u0930\u0925\u092E\u093E (subject), 2 \u0926\u094D\u0935\u093F\u0924\u0940\u092F\u093E (object), 3 \u0924\u0943\u0924\u0940\u092F\u093E (with/by), 4 \u091A\u0924\u0941\u0930\u094D\u0925\u0940 (to/for).',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 4: Basic Grammar - Pronouns
  // ---------------------------------------------------------------
  'ls_grammar_pronouns': const [
    Exercise(
      id: 'ex_ls_grammar_pronouns_1',
      hint: 'It is the first person singular pronoun.',
      lessonId: 'ls_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'Which Sanskrit word means "I"?',
      options: [
        '\u0905\u0939\u0902',
        '\u0924\u094D\u0935\u092E\u094D',
        '\u0938\u0903',
        '\u0938\u093E'
      ],
      correctIndex: 0,
      explanation:
          '\u0905\u0939\u0902 = I. With a verb: \u0905\u0939\u0902 \u092A\u0920\u093E\u092E\u093F - I read.',
    ),
    Exercise(
      id: 'ex_ls_grammar_pronouns_2',
      hint: 'It is the feminine third person singular pronoun.',
      lessonId: 'ls_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'Which word means "she"?',
      options: [
        '\u0938\u093E',
        '\u0938\u0903',
        '\u0924\u0924\u094D',
        '\u0905\u0939\u0902'
      ],
      correctIndex: 0,
      explanation:
          '\u0938\u093E = she (\u0938\u0903 = he, \u0924\u0924\u094D = it). \u0938\u093E \u092A\u0920\u0924\u093F - she reads.',
    ),
    Exercise(
      id: 'ex_ls_grammar_pronouns_3',
      hint: 'He/she/it all take the same verb form in this lesson.',
      lessonId: 'ls_grammar_pronouns',
      type: ExerciseType.fillBlank,
      prompt: '___ \u092A\u0920\u0924\u093F means "He reads".',
      options: [
        '\u0938\u0903',
        '\u0938\u093E',
        '\u0905\u0939\u0902',
        '\u0924\u094D\u0935\u092E\u094D'
      ],
      correctIndex: 0,
      explanation:
          '\u0938\u0903 = he: \u0938\u0903 \u092A\u0920\u0924\u093F. \u0938\u093E \u092A\u0920\u0924\u093F = she reads.',
    ),
    Exercise(
      id: 'ex_ls_grammar_pronouns_4',
      hint:
          'Start with yourself, then the person you are talking to, then he, she, it.',
      lessonId: 'ls_grammar_pronouns',
      type: ExerciseType.ordering,
      prompt: 'Arrange the pronouns in the order of the lesson table.',
      items: [
        '\u0905\u0939\u0902',
        '\u0924\u094D\u0935\u092E\u094D',
        '\u0938\u0903',
        '\u0938\u093E',
        '\u0924\u0924\u094D'
      ],
      explanation:
          '\u0905\u0939\u0902 (I), \u0924\u094D\u0935\u092E\u094D (you), \u0938\u0903 (he), \u0938\u093E (she), \u0924\u0924\u094D (it) - the pronoun set from the lesson.',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 4: Basic Grammar - Verbs
  // ---------------------------------------------------------------
  'ls_grammar_verbs': const [
    Exercise(
      id: 'ex_ls_grammar_verbs_1',
      hint: 'The tense used for "I read / you read / he reads".',
      lessonId: 'ls_grammar_verbs',
      type: ExerciseType.mcq,
      prompt:
          '\u0932\u0924\u094D \u0932\u0915\u093E\u0930 expresses which tense?',
      options: ['Present', 'Past', 'Future', 'Imperative'],
      correctIndex: 0,
      explanation:
          '\u0932\u0924\u094D is the present tense: \u092A\u0920\u0924\u093F - he reads / is reading.',
    ),
    Exercise(
      id: 'ex_ls_grammar_verbs_2',
      hint:
          'They = \u0924\u0947, and the plural ending is -\u0928\u094D\u0924\u093F.',
      lessonId: 'ls_grammar_verbs',
      type: ExerciseType.mcq,
      prompt: 'Which form means "They read"?',
      options: [
        '\u092A\u0920\u0928\u094D\u0924\u093F',
        '\u092A\u0920\u0924\u093F',
        '\u092A\u0920\u093E\u092E\u093F',
        '\u092A\u0920\u0925'
      ],
      correctIndex: 0,
      explanation:
          '\u092A\u0920\u0928\u094D\u0924\u093F = they read (3rd person plural, ending -\u0928\u094D\u0924\u093F).',
    ),
    Exercise(
      id: 'ex_ls_grammar_verbs_3',
      hint: 'He takes the -\u0924\u093F ending.',
      lessonId: 'ls_grammar_verbs',
      type: ExerciseType.fillBlank,
      prompt: '\u0938\u0903 ___ (He reads).',
      options: [
        '\u092A\u0920\u0924\u093F',
        '\u092A\u0920\u0928\u094D\u0924\u093F',
        '\u092A\u0920\u0938\u093F',
        '\u092A\u0920\u093E\u092E\u0903'
      ],
      correctIndex: 0,
      explanation:
          '\u0938\u0903 \u092A\u0920\u0924\u093F - he reads. The -\u0924\u093F ending marks he/she/it.',
    ),
    Exercise(
      id: 'ex_ls_grammar_verbs_4',
      hint:
          'Start with "I", end with "they": -\u092E\u093F, -\u0938\u093F, -\u0924\u093F, -\u092E\u0903, -\u0925, -\u0928\u094D\u0924\u093F.',
      lessonId: 'ls_grammar_verbs',
      type: ExerciseType.ordering,
      prompt:
          'Arrange the six forms of \u092A\u0920\u094D in \u0932\u0924\u094D exactly as in the lesson.',
      items: [
        '\u092A\u0920\u093E\u092E\u093F',
        '\u092A\u0920\u0938\u093F',
        '\u092A\u0920\u0924\u093F',
        '\u092A\u0920\u093E\u092E\u0903',
        '\u092A\u0920\u0925',
        '\u092A\u0920\u0928\u094D\u0924\u093F'
      ],
      explanation:
          '\u092A\u0920\u093E\u092E\u093F, \u092A\u0920\u0938\u093F, \u092A\u0920\u0924\u093F, \u092A\u0920\u093E\u092E\u0903, \u092A\u0920\u0925, \u092A\u0920\u0928\u094D\u0924\u093F - the full present-tense chant.',
    ),
  ],

  // ---------------------------------------------------------------
  // Chapter 3 (expanded): Translation Practice
  // ---------------------------------------------------------------
  'ls_sentences_translation': const [
    Exercise(
      id: 'ex_ls_sentences_translation_1',
      hint:
          '\u0930\u093E\u092E\u0903 eats something - the fruit is the object.',
      lessonId: 'ls_sentences_translation',
      type: ExerciseType.mcq,
      prompt:
          '"\u0930\u093E\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u093E\u0926\u0924\u093F" means?',
      options: [
        'Ram eats a fruit',
        'Ram reads a book',
        'Sita drinks water',
        'Ram goes to school'
      ],
      correctIndex: 0,
      explanation:
          '\u0930\u093E\u092E\u0903 (Ram) + \u092B\u0932\u092E\u094D (fruit) + \u0916\u093E\u0926\u0924\u093F (eats): Subject-Object-Verb.',
    ),
    Exercise(
      id: 'ex_ls_sentences_translation_2',
      hint:
          'I = \u0905\u0939\u0902, book = \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D, read = \u092A\u0920\u093E\u092E\u093F.',
      lessonId: 'ls_sentences_translation',
      type: ExerciseType.mcq,
      prompt: 'How do you say "I read a book"?',
      options: [
        '\u0905\u0939\u0902 \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D \u092A\u0920\u093E\u092E\u093F',
        '\u092E\u092E \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D',
        '\u0905\u0939\u0902 \u092B\u0932\u092E\u094D \u0916\u093E\u0926\u093E\u092E\u093F',
        '\u0924\u094D\u0935\u092E\u094D \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D \u092A\u0920\u0938\u093F'
      ],
      correctIndex: 0,
      explanation:
          '\u0905\u0939\u0902 (I) + \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D (book) + \u092A\u0920\u093E\u092E\u093F (read). Verb last!',
    ),
    Exercise(
      id: 'ex_ls_sentences_translation_3',
      hint: 'Sanskrit puts the verb at the END of the sentence.',
      lessonId: 'ls_sentences_translation',
      type: ExerciseType.fillBlank,
      prompt: 'Sanskrit word order is Subject - ___ - Verb.',
      options: ['Object', 'Adjective', 'Question word', 'Conjunction'],
      correctIndex: 0,
      explanation:
          'SOV: Subject - Object - Verb. English says "Ram eats a fruit"; Sanskrit says "Ram a fruit eats".',
    ),
    Exercise(
      id: 'ex_ls_sentences_translation_4',
      hint: 'I / school / go - in SOV order.',
      lessonId: 'ls_sentences_translation',
      type: ExerciseType.ordering,
      prompt: 'Order the words to say "I go to school".',
      items: [
        '\u0905\u0939\u0902',
        '\u0935\u093F\u0926\u094D\u092F\u093E\u0932\u092F\u092E\u094D',
        '\u0917\u091A\u094D\u091B\u093E\u092E\u093F'
      ],
      explanation:
          '\u0905\u0939\u0902 \u0935\u093F\u0926\u094D\u092F\u093E\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u093E\u092E\u093F - subject, object, verb.',
    ),
  ],
};
