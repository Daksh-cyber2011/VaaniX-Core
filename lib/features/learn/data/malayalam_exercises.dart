/// Malayalam Exercises — VaaniX Learn Mode Part I (M9)
///
/// Practice exercises for the Malayalam curriculum
/// (assets/curriculum/learn/ml.json). Keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically. Each lesson
/// has 3 exercises covering mcq, fillBlank, ordering, translation and
/// matching types.
///
/// Content note: every exercise is grounded in the actual lesson
/// content. Malayalam examples are natural (not machine-translated).
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Malayalam exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `ml_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode
/// curriculum.
final Map<String, List<Exercise>> malayalamExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Malayalam Script (ch_ml_script)
  // ════════════════════════════════════════════════════════════════════

  'ml_script_vowels': const [
    Exercise(
      id: 'ex_ml_vowels_1',
      lessonId: 'ml_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'മലയാളം എഴുത്ത് എന്തുകൊണ്ട് വൃത്താകൃതിയിലാണ്? '
          '(Why is Malayalam script famously ROUND?)',
      options: [
        'It was carved on palm leaves (straight cuts split the leaf)',
        'It copied Latin letters',
        'It is a modern design choice',
        'Nobody knows',
      ],
      correctIndex: 0,
      explanation:
          'Letters were carved on palm leaves with an iron stylus — straight cuts split the leaf, so curves won. History shapes writing.',
    ),
    Exercise(
      id: 'ex_ml_vowels_2',
      lessonId: 'ml_script_vowels',
      type: ExerciseType.matching,
      prompt: 'സ്വരങ്ങൾ അർത്ഥവുമായി ചേർക്കുക (Match vowels to example words)',
      pairs: [
        (left: 'അമ്മ', right: 'a — mother'),
        (left: 'ആന', right: 'ā — elephant'),
        (left: 'ഏഴ്', right: 'ē — seven'),
        (left: 'ഔഷധം', right: 'au — medicine'),
      ],
      explanation:
          'Each word carries one vowel: അമ്മ opens with അ, ആന with long ആ, ഏഴ് ends in the chillu of ഏ, ഔഷധം opens with ഔ.',
    ),
    Exercise(
      id: 'ex_ml_vowels_3',
      lessonId: 'ml_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'കാലം (time) vs കലം (pot) — എന്ത് വ്യത്യാസം? '
          '(കാലം vs കലം differ only in…)',
      options: ['the consonant', 'the vowel LENGTH', 'nothing', 'the ending'],
      correctIndex: 1,
      explanation:
          'കാലം (kālaṃ) has the long ആ; കലം (kalaṃ) the short അ. Vowel length is meaning-bearing everywhere in Malayalam.',
    ),
  ],

  'ml_script_consonants': const [
    Exercise(
      id: 'ex_ml_cons_1',
      lessonId: 'ml_script_consonants',
      type: ExerciseType.matching,
      prompt: 'വ്യഞ്ജനങ്ങൾ ശബ്ദവുമായി ചേർക്കുക (Match consonants to sounds)',
      pairs: [
        (left: 'ക', right: 'ka'),
        (left: 'ഗ', right: 'ga'),
        (left: 'മ', right: 'ma'),
        (left: 'ഴ', right: 'the famous zh'),
      ],
      explanation:
          'A bare consonant reads with built-in അ: ക = ka. ഴ is the sound outsiders cannot make first try — halfway between l and r.',
    ),
    Exercise(
      id: 'ex_ml_cons_2',
      lessonId: 'ml_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'മലയാളം എന്ന വാക്കിൽ ഏത് പ്രത്യേക ലിപിയാണ്? '
          '(Which special letter appears in മലയാളം itself?)',
      options: [
        'ല (dental la)',
        'ള (retroflex ḷa)',
        'ഴ (zh)',
        'റ (alveolar ra)'
      ],
      correctIndex: 1,
      explanation:
          'മലയാളം ends in ള (retroflex l). The even rarer ഴ appears in പഴം (fruit) and വഴി (way) — both everyday words.',
    ),
    Exercise(
      id: 'ex_ml_cons_3',
      lessonId: 'ml_script_consonants',
      type: ExerciseType.ordering,
      prompt:
          'മൂന്ന് l-ശബ്ദങ്ങൾ ക്രമീകരിക്കുക (Order the three l-sounds: dental → retroflex → zh)',
      items: ['ല (dental l)', 'ള (retroflex ḷ)', 'ഴ (zh)'],
      explanation:
          'ല → ള → ഴ is the difficulty ladder of the mouth: teeth → curled tongue → fully-back zh. Drill with കലം, കളം, കഴി.',
    ),
  ],

  'ml_script_signs': const [
    Exercise(
      id: 'ex_ml_signs_1',
      lessonId: 'ml_script_signs',
      type: ExerciseType.mcq,
      prompt: 'ക + ി എങ്ങനെ വായിക്കും? (How is ക + the sign ി read?)',
      options: ['ka', 'kā', 'ki', 'ku'],
      correctIndex: 2,
      explanation:
          'ി changes ക (ka) to കി (ki) — written LEFT of the consonant, spoken AFTER it. The classic visual trap.',
    ),
    Exercise(
      id: 'ex_ml_signs_2',
      lessonId: 'ml_script_signs',
      type: ExerciseType.matching,
      prompt: 'ഗുണിതാക്ഷരങ്ങൾ ചേർക്കുക (Match the developed letters)',
      pairs: [
        (left: 'കാ', right: 'kā'),
        (left: 'കി', right: 'ki'),
        (left: 'കൂ', right: 'kū'),
        (left: 'കൈ', right: 'kai'),
      ],
      explanation:
          'One sign per vowel: ാ = ā, ി = i, ൂ = ū (below), ൈ = ai. The consonant ക never changes.',
    ),
    Exercise(
      id: 'ex_ml_signs_3',
      lessonId: 'ml_script_signs',
      type: ExerciseType.mcq,
      prompt: 'മലയാളം, കാലം, വർഷം — ഇവയുടെ പൊതു അന്ത്യം? '
          '(What ending do മലയാളം, കാലം and വർഷം share?)',
      options: [
        '് (virama)',
        'ം (anusvāra, "m")',
        'ൻ (chillu n)',
        'ാ (ā sign)'
      ],
      correctIndex: 1,
      explanation:
          'The final ം adds "m" — the most common word ending in Malayalam. പുസ്തകം (book) has it too.',
    ),
  ],

  'ml_script_chillu': const [
    Exercise(
      id: 'ex_ml_chillu_1',
      lessonId: 'ml_script_chillu',
      type: ExerciseType.matching,
      prompt: 'ചില്ല് അക്ഷരങ്ങൾ ചേർക്കുക (Match chillu letters to words)',
      pairs: [
        (left: 'അവൻ', right: 'he (ൻ)'),
        (left: 'അവൾ', right: 'she (ൽ)'),
        (left: 'അവർ', right: 'they (ർ)'),
        (left: 'കാൽ', right: 'leg (ൽ)'),
      ],
      explanation:
          'Chillu = bare consonant ending with no vowel. ൻ n, ൽ l, ർ r, ൺ ṇ, ൾ ḷ. He/she/they are the natural trio to learn them.',
    ),
    Exercise(
      id: 'ex_ml_chillu_2',
      lessonId: 'ml_script_chillu',
      type: ExerciseType.mcq,
      prompt: 'അമ്മ, പട്ടം, വെള്ളം — പൊതുവായി എന്ത്? '
          '(What do അമ്മ, പട്ടം and വെള്ളം share?)',
      options: [
        'A chillu ending',
        'A DOUBLED consonant (gemination)',
        'The vowel ആ',
        'Nothing',
      ],
      correctIndex: 1,
      explanation:
          'മ്മ, ട്ട, ള്ള — doubled letters held for two beats. പത്ത് (ten) carries one too. Holding (or not) changes meaning.',
    ),
    Exercise(
      id: 'ex_ml_chillu_3',
      lessonId: 'ml_script_chillu',
      type: ExerciseType.mcq,
      prompt: 'സ്കൂൾ എങ്ങനെ പിരിക്കാം? (How does സ്കൂൾ — school — split?)',
      options: [
        'സ് + കൂ + ൾ',
        'സ + ക + ല്',
        'സ്ക + ല്',
        'സു + കൂ + ല്',
      ],
      explanation:
          'സ്കൂൾ = സ് (bare s via virama) + കൂ + ൾ (chillu l). Clusters break into their letters — read slowly, left to right.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_ml_greet)
  // ════════════════════════════════════════════════════════════════════

  'ml_greet_namaskaram': const [
    Exercise(
      id: 'ex_ml_greet_1',
      lessonId: 'ml_greet_namaskaram',
      type: ExerciseType.mcq,
      prompt: 'സുഖമാണോ? എന്നതിന്റെ അർത്ഥം: (What does സുഖമാണോ? ask?)',
      options: [
        'Are you well?',
        'Where are you?',
        'What is your name?',
        'Did you eat?'
      ],
      correctIndex: 0,
      explanation:
          'സുഖമാണോ? = "are you well?" — with the -ോ question tag. The classic reply: സുഖമാണ്, നന്ദി (well, thanks).',
    ),
    Exercise(
      id: 'ex_ml_greet_2',
      lessonId: 'ml_greet_namaskaram',
      type: ExerciseType.matching,
      prompt: 'വാക്കുകൾ അർത്ഥവുമായി (Match phrases to meanings)',
      pairs: [
        (left: 'നന്ദി', right: 'thank you'),
        (left: 'ക്ഷമിക്കണം', right: 'sorry / excuse me'),
        (left: 'പോയി വരാം', right: "I'll go and come back"),
        (left: 'വരൂ', right: 'please come (reply)'),
      ],
      explanation:
          'Malayalam frames leaving as returning: പോയി വരാം answered by വരൂ. A final "goodbye" is rare outside films.',
    ),
    Exercise(
      id: 'ex_ml_greet_3',
      lessonId: 'ml_greet_namaskaram',
      type: ExerciseType.mcq,
      prompt:
          'സുഖമാണോ? എന്ന ചോദ്യത്തിന്റെ ഉത്തരം ഏത്? (Which answers സുഖമാണോ?)',
      options: ['സുഖമാണ്, നന്ദി', 'നമസ്കാരം', 'എന്റെ പേര്', 'ശരി'],
      correctIndex: 0,
      explanation:
          'സുഖമാണ്, നന്ദി — "well, thank you". The full Kerala exchange adds the follow-up: അതു സുഖമാണോ? (and is THAT well?).',
    ),
  ],

  'ml_greet_intro': const [
    Exercise(
      id: 'ex_ml_intro_1',
      lessonId: 'ml_greet_intro',
      type: ExerciseType.translation,
      prompt: 'മലയാളത്തിൽ പറയുക: "My name is Meera."',
      acceptedAnswers: ['എന്റെ പേര് മീര', 'ente peru meera'],
      explanation:
          'എന്റെ (my) + പേര് (name) + മീര. Ask back politely: നിങ്ങളുടെ പേരെന്ത്?',
    ),
    Exercise(
      id: 'ex_ml_intro_2',
      lessonId: 'ml_greet_intro',
      type: ExerciseType.ordering,
      prompt: 'വാക്യം ക്രമീകരിക്കുക (Arrange: "I am from Kochi")',
      items: ['ഞാൻ (I)', 'കൊച്ചിയിൽ (Kochi-in)', 'നിന്നാണ് (from)'],
      explanation:
          'ഞാൻ കൊച്ചിയിൽ നിന്നാണ് — subject → place → source. The -ിൽ നിന്ന് unit does the "from" work.',
    ),
    Exercise(
      id: 'ex_ml_intro_3',
      lessonId: 'ml_greet_intro',
      type: ExerciseType.mcq,
      prompt: "'പതുക്കെ പറയാമോ?' എന്നതിന്റെ അർത്ഥം: "
          '(What does പതുക്കെ പറയാമോ? mean?)',
      options: [
        'Can you say it slowly?',
        'Can you write it?',
        'Can you repeat loudly?',
        'Can you spell it?',
      ],
      correctIndex: 0,
      explanation:
          'പതുക്കെ = slowly, -ാമോ = can you? Together with വീണ്ടും പറയൂ (say it again), it is the learner\'s lifeline.',
    ),
  ],

  'ml_greet_family': const [
    Exercise(
      id: 'ex_ml_family_1',
      lessonId: 'ml_greet_family',
      type: ExerciseType.matching,
      prompt: 'കുടുംബ വാക്കുകൾ (Match the family words)',
      pairs: [
        (left: 'അമ്മ', right: 'mother'),
        (left: 'അച്ഛൻ', right: 'father'),
        (left: 'ചേട്ടൻ', right: 'elder brother / any older male'),
        (left: 'ചേച്ചി', right: 'elder sister / any older female'),
      ],
      explanation:
          'ചേട്ടൻ/ചേച്ചി double as respectful addresses for strangers — Kerala\'s built-in politeness chip.',
    ),
    Exercise(
      id: 'ex_ml_family_2',
      lessonId: 'ml_greet_family',
      type: ExerciseType.mcq,
      prompt: "'എനിക്ക് രണ്ട് സഹോദരന്മാരുണ്ട്' എന്നതിന്റെ അർത്ഥം: "
          '(എനിക്ക് രണ്ട് സഹോദരന്മാരുണ്ട് means…)',
      options: [
        'I have two brothers',
        'I have two sisters',
        'I had two brothers',
        'We have two brothers',
      ],
      correctIndex: 0,
      explanation:
          'എനിക്ക് (to-me) + രണ്ട് + സഹോദരന്മാർ (brothers, plural) + ഉണ്ട് (there is). Possession = dative + ഉണ്ട്.',
    ),
    Exercise(
      id: 'ex_ml_family_3',
      lessonId: 'ml_greet_family',
      type: ExerciseType.translation,
      prompt: 'മലയാളത്തിൽ പറയുക: "This is my mother."',
      acceptedAnswers: [
        'ഇത് എന്റെ അമ്മയാണ്',
        'ithu ente ammayaanu',
        'ithu ente ammayāṇu'
      ],
      explanation:
          'ഇത് എന്റെ അമ്മയാണ് — note the fusion: അമ്മ + ആണ് → അമ്മയാണ് (the glue യ appears).',
    ),
  ],

  'ml_greet_numbers': const [
    Exercise(
      id: 'ex_ml_num_1',
      lessonId: 'ml_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'സംഖ്യകൾ ചേർക്കുക (Match the numbers)',
      pairs: [
        (left: 'ഒന്ന്', right: '1'),
        (left: 'രണ്ട്', right: '2'),
        (left: 'അഞ്ച്', right: '5'),
        (left: 'പത്ത്', right: '10'),
      ],
      explanation:
          '1–10 end in chillus: ഒന്ന്, രണ്ട്, മൂന്ന്, നാല്, അഞ്ച്, ആറ്, ഏഴ്, എട്ട്, ഒൻപത്, പത്ത്.',
    ),
    Exercise(
      id: 'ex_ml_num_2',
      lessonId: 'ml_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'നൂറ് എത്ര? (How much is നൂറ്?)',
      options: ['10', '50', '100', '1000'],
      correctIndex: 2,
      explanation:
          'നൂറ് = 100. Tens: ഇരുപത് 20, മുപ്പത് 30, അമ്പത് 50 — irregular words to memorise, like English "eleven".',
    ),
    Exercise(
      id: 'ex_ml_num_3',
      lessonId: 'ml_greet_numbers',
      type: ExerciseType.translation,
      prompt: 'ചായക്കടയിൽ: "How much?" എന്ന് മലയാളത്തിൽ',
      acceptedAnswers: ['എത്ര', 'etra'],
      explanation:
          'എത്ര? = how many/how much. Pair: എത്ര രൂപ? (how many rupees?). The whole order: രണ്ട് ചായ, എത്ര?',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_ml_daily)
  // ════════════════════════════════════════════════════════════════════

  'ml_daily_sentences': const [
    Exercise(
      id: 'ex_ml_daily1_1',
      lessonId: 'ml_daily_sentences',
      type: ExerciseType.ordering,
      prompt: 'വാക്യം ക്രമീകരിക്കുക (Arrange: "I drink tea")',
      items: ['ഞാൻ (I)', 'ചായ (tea)', 'കുടിക്കുന്നു (drink)'],
      explanation:
          'SOV: ഞാൻ ചായ കുടിക്കുന്നു. The verb always closes the sentence.',
    ),
    Exercise(
      id: 'ex_ml_daily1_2',
      lessonId: 'ml_daily_sentences',
      type: ExerciseType.mcq,
      prompt: "'ഇത് പുസ്തകമാണ്' vs 'പുസ്തകം ഉണ്ട്' — വ്യത്യാസം? "
          '(ആണ് vs ഉണ്ട് — what is the difference?)',
      options: [
        'ആണ് = identity ("is a"), ഉണ്ട് = existence ("there is")',
        'Both mean the same',
        'ആണ് is past tense',
        'ഉണ്ട് is polite',
      ],
      correctIndex: 0,
      explanation:
          'ഇത് പുസ്തകമാണ് = this IS a book (identity). പുസ്തകം ഉണ്ട് = there IS a book (existence). Two tiny words, two claims.',
    ),
    Exercise(
      id: 'ex_ml_daily1_3',
      lessonId: 'ml_daily_sentences',
      type: ExerciseType.fillBlank,
      prompt: 'അമ്മ അടുക്കള___ ആണ്. '
          '(Mother is IN the kitchen — fill the fused locative unit.)',
      options: ['-ിൽ നിന്ന്', '-ിൽ + ആണ് → -ിലാണ്', '-ിലേക്ക്', '-ിന്റെ'],
      correctIndex: 1,
      explanation:
          'അടുക്കള + ിൽ (in) + ആണ് (is) → അടുക്കളയിലാണ്. Location + is fuse into one ending.',
    ),
  ],

  'ml_daily_questions': const [
    Exercise(
      id: 'ex_ml_daily2_1',
      lessonId: 'ml_daily_questions',
      type: ExerciseType.matching,
      prompt: 'ചോദ്യവാക്കുകൾ (Match the question words)',
      pairs: [
        (left: 'എന്ത്', right: 'what'),
        (left: 'ആര്', right: 'who'),
        (left: 'എവിടെ', right: 'where'),
        (left: 'എപ്പോൾ', right: 'when'),
      ],
      explanation:
          'Also എത്ര (how much), എങ്ങനെ (how). Question words sit where the answer sits — no shuffling.',
    ),
    Exercise(
      id: 'ex_ml_daily2_2',
      lessonId: 'ml_daily_questions',
      type: ExerciseType.mcq,
      prompt: "'ബസ് എവിടെ?' എന്നതിന്റെ അർത്ഥം: (What does ബസ് എവിടെ? ask?)",
      options: [
        'When is the bus?',
        'Where is the bus?',
        'How much is the bus?',
        'Who is on the bus?'
      ],
      correctIndex: 1,
      explanation:
          'എവിടെ = where. "Bus where?" — the question word holds the answer\'s slot.',
    ),
    Exercise(
      id: 'ex_ml_daily2_3',
      lessonId: 'ml_daily_questions',
      type: ExerciseType.mcq,
      prompt: 'Yes/No ചോദ്യം എങ്ങനെ? (How is a yes/no question formed?)',
      options: [
        'Add -ോ to the last word (സുഖമാണോ? വരുമോ?)',
        'Move the verb to the front',
        'Add a question mark only',
        'Use എന്ത്',
      ],
      correctIndex: 0,
      explanation:
          'The -ോ tag flips statements into questions: വരുമോ? (will you come?), ശരിയാണോ? (is it okay?). Intonation does the rest.',
    ),
  ],

  'ml_daily_negation': const [
    Exercise(
      id: 'ex_ml_daily3_1',
      lessonId: 'ml_daily_negation',
      type: ExerciseType.matching,
      prompt: 'നിഷേധങ്ങൾ അവയുടെ ജോലിയുമായി (Match each no to its job)',
      pairs: [
        (left: 'അല്ല', right: 'it is not (identity)'),
        (left: 'ഇല്ല', right: 'isn\'t there / don\'t have'),
        (left: '-ില്ല', right: 'verb negation'),
        (left: 'വേണ്ട', right: "don't want"),
      ],
      explanation:
          'Four no\'s, four jobs: identity, existence, verb action, refusal. വേണ്ട, നന്ദി is the polite shop refusal.',
    ),
    Exercise(
      id: 'ex_ml_daily3_2',
      lessonId: 'ml_daily_negation',
      type: ExerciseType.mcq,
      prompt: "'ഇത് ചായ അല്ല' — എന്ത് നിഷേധം? (Why അല്ല in ഇത് ചായ അല്ല?)",
      options: [
        'It rejects identity: "this is NOT tea"',
        'It rejects existence',
        'It negates a verb',
        'It means maybe',
      ],
      correctIndex: 0,
      explanation:
          'അല്ല rejects what something IS. Existence takes ഇല്ല (പണം ഇല്ല), verbs take -ില്ല (വരുന്നില്ല).',
    ),
    Exercise(
      id: 'ex_ml_daily3_3',
      lessonId: 'ml_daily_negation',
      type: ExerciseType.fillBlank,
      prompt: 'അവൻ ___ (He does NOT go — പോകുന്നു → fill the negative)',
      options: ['പോകുന്നു', 'പോകുന്നില്ല', 'പോയി', 'പോകും'],
      correctIndex: 1,
      explanation:
          'Present-tense negation swaps the ending: പോകുന്നു → പോകുന്നില്ല. Future: പോകും → പോകില്ല.',
    ),
  ],

  'ml_daily_routine': const [
    Exercise(
      id: 'ex_ml_daily4_1',
      lessonId: 'ml_daily_routine',
      type: ExerciseType.matching,
      prompt: 'ദിവസത്തിന്റെ ഭാഗങ്ങൾ (Match the day-parts)',
      pairs: [
        (left: 'രാവിലെ', right: 'morning'),
        (left: 'ഉച്ചയ്ക്ക്', right: 'afternoon'),
        (left: 'വൈകുന്നേരം', right: 'evening'),
        (left: 'രാത്രി', right: 'night'),
      ],
      explanation:
          'Day-parts prefix clock times: രാവിലെ ആറരയ്ക്ക് = at six-thirty in the morning.',
    ),
    Exercise(
      id: 'ex_ml_daily4_2',
      lessonId: 'ml_daily_routine',
      type: ExerciseType.mcq,
      prompt: "'എത്ര മണിയായി?' എന്നതിന്റെ അർത്ഥം: "
          '(What does എത്ര മണിയായി? mean?)',
      options: [
        'What time is it? (how-much hour became)',
        'How many people came?',
        'When did you sleep?',
        'Is the food ready?',
      ],
      correctIndex: 0,
      explanation:
          'എത്ര മണി + ആയി (became) → "what hour has it become?" — the standard clock question. Reply: ആറ് മണിയായി.',
    ),
    Exercise(
      id: 'ex_ml_daily4_3',
      lessonId: 'ml_daily_routine',
      type: ExerciseType.ordering,
      prompt: 'ദിനചര്യ ക്രമീകരിക്കുക (Arrange a morning in order)',
      items: [
        'എഴുന്നേൽക്കുന്നു (wake)',
        'ചായ കുടിക്കുന്നു (drink tea)',
        'ജോലിക്ക് പോകുന്നു (go to work)',
      ],
      explanation:
          'A routine is a verb chain: wake → drink → go. Five verbs with times narrate a full day.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_ml_grammar)
  // ════════════════════════════════════════════════════════════════════

  'ml_grammar_pronouns': const [
    Exercise(
      id: 'ex_ml_gram1_1',
      lessonId: 'ml_grammar_pronouns',
      type: ExerciseType.matching,
      prompt: 'സർവനാമങ്ങൾ (Match the pronouns)',
      pairs: [
        (left: 'ഞാൻ', right: 'I'),
        (left: 'നിങ്ങൾ', right: 'you (respectful)'),
        (left: 'അവൾ', right: 'she'),
        (left: 'അവർ', right: 'they / respected he-she'),
      ],
      explanation:
          'നിങ്ങൾ for everyone outside the closest circle; അവർ is the honorific third person.',
    ),
    Exercise(
      id: 'ex_ml_gram1_2',
      lessonId: 'ml_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'നമ്മൾ vs ഞങ്ങൾ — വ്യത്യാസം? (നമ്മൾ vs ഞങ്ങൾ — what differs?)',
      options: [
        'നമ്മൾ includes the listener; ഞങ്ങൾ excludes them',
        'ഞങ്ങൾ is plural only',
        'നമ്മൾ is feminine',
        'No difference',
      ],
      correctIndex: 0,
      explanation:
          'Inviting someone? നമ്മൾ പോകാം ("shall WE — you included — go?"). Reporting without them? ഞങ്ങൾ പോയി.',
    ),
    Exercise(
      id: 'ex_ml_gram1_3',
      lessonId: 'ml_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt:
          'പുസ്തകത്തിന് ലിംഗഭേദമുണ്ടോ? (Does a book have grammatical gender in Malayalam?)',
      options: [
        'No — objects are all അത് (it)',
        'Yes — masculine',
        'Yes — feminine',
        'Only in poetry',
      ],
      correctIndex: 0,
      explanation:
          'Only humans take അവൻ/അവൾ. Tables, books, cities — all അത്/അവ. Noun gender simply does not exist.',
    ),
  ],

  'ml_grammar_tenses': const [
    Exercise(
      id: 'ex_ml_gram2_1',
      lessonId: 'ml_grammar_tenses',
      type: ExerciseType.matching,
      prompt: 'കാലങ്ങൾ ചേർക്കുക (Match the tense forms of വരിക)',
      pairs: [
        (left: 'വരുന്നു', right: 'comes / is coming'),
        (left: 'വന്നു', right: 'came'),
        (left: 'വരും', right: 'will come'),
        (left: 'വരണം', right: 'must come / please come'),
      ],
      explanation:
          'Present -ുന്നു, future -ും, past is its own word (വന്നു). The -ണം obligation form appears in invitations.',
    ),
    Exercise(
      id: 'ex_ml_gram2_2',
      lessonId: 'ml_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'കാണുക (see) യുടെ ഭൂതകാലം: (The past of കാണുക — see — is…)',
      options: ['കാണുന്നു', 'കണ്ടു', 'കാണും', 'കാണില്ല'],
      correctIndex: 1,
      explanation:
          'കാണുക → കണ്ടു (saw). Past forms are irregular but short — learn them as partner-words.',
    ),
    Exercise(
      id: 'ex_ml_gram2_3',
      lessonId: 'ml_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: "'നാളെ' എന്നതിന്റെ അർത്ഥം: (What does നാളെ mean?)",
      options: ['today', 'yesterday', 'tomorrow', 'every day'],
      correctIndex: 2,
      explanation:
          'ഇന്ന് today, ഇന്നലെ yesterday, നാളെ tomorrow, ദിവസവും every day. Anchors half-do the tense work.',
    ),
  ],

  'ml_grammar_cases': const [
    Exercise(
      id: 'ex_ml_gram3_1',
      lessonId: 'ml_grammar_cases',
      type: ExerciseType.matching,
      prompt: 'വിഭക്തികൾ (Match the case endings)',
      pairs: [
        (left: '-ിന്', right: 'to (dative)'),
        (left: '-ിൽ നിന്ന്', right: 'from'),
        (left: '-ിന്റെ', right: "'s (possessive)"),
        (left: '-ിൽ', right: 'in/at'),
      ],
      explanation:
          'Nouns wear endings, no prepositions: വീടിന് (home-to), കൊച്ചിയിൽ നിന്ന് (from Kochi), രവിയുടെ പുസ്തകം (Ravi\'s book).',
    ),
    Exercise(
      id: 'ex_ml_gram3_2',
      lessonId: 'ml_grammar_cases',
      type: ExerciseType.mcq,
      prompt: "'എനിക്ക് ബൈക്ക് ഉണ്ട്' — എനിക്ക് എന്തിന്? "
          '(In എനിക്ക് ബൈക്ക് ഉണ്ട് (I have a bike), why the dative എനിക്ക്?)',
      options: [
        'Possession is dative + ഉണ്ട് ("to-me bike is")',
        'It is past tense',
        'It marks the object',
        'It is polite',
      ],
      correctIndex: 0,
      explanation:
          'The dative -ിന് also marks wants (എനിക്ക് വേണം) and likes (എനിക്ക് ഇഷ്ടമാണ്) — the busiest ending in Malayalam.',
    ),
    Exercise(
      id: 'ex_ml_gram3_3',
      lessonId: 'ml_grammar_cases',
      type: ExerciseType.fillBlank,
      prompt: 'ഞാൻ കട___ പോകുന്നു. (I go TO THE SHOP — fill: കട + ending)',
      options: ['-ിൽ', '-യ്ക്ക്', '-ിന്റെ', '-ോട്'],
      correctIndex: 1,
      explanation:
          'കട + യ്ക്ക് → കടയ്ക്ക് — dative for direction. ഞാൻ കടയ്ക്ക് പോകുന്നു.',
    ),
  ],

  'ml_grammar_politeness': const [
    Exercise(
      id: 'ex_ml_gram4_1',
      lessonId: 'ml_grammar_politeness',
      type: ExerciseType.matching,
      prompt: 'മര്യാദ രൂപങ്ങൾ (Match intimate to polite)',
      pairs: [
        (left: 'വാ', right: 'വരൂ (please come)'),
        (left: 'ഇരി', right: 'ഇരിക്കൂ (please sit)'),
        (left: 'താ', right: 'തരൂ (please give)'),
        (left: 'പറ', right: 'പറയൂ (please say)'),
      ],
      explanation:
          'The soft imperative ladder: വാ → വരൂ → വരിക (formal). Shop line: വരൂ, ഇരിക്കൂ, എന്ത് വേണം?',
    ),
    Exercise(
      id: 'ex_ml_gram4_2',
      lessonId: 'ml_grammar_politeness',
      type: ExerciseType.mcq,
      prompt:
          "Respect മൂന്നാം പേർക്ക്: (How is a respected third person referred to?)",
      options: [
        'With അവർ (they) + plural verb',
        'With അത്',
        'With ഞാൻ',
        'Malayalam has no respect forms',
      ],
      correctIndex: 0,
      explanation:
          'അദ്ധ്യാപകർ വന്നു — the teacher (honored) came. The -ർ plural-of-respect is the standard honorific.',
    ),
    Exercise(
      id: 'ex_ml_gram4_3',
      lessonId: 'ml_grammar_politeness',
      type: ExerciseType.mcq,
      prompt: "'പതുക്കെ പറയൂ' എന്നതിന്റെ അർത്ഥം: "
          '(What does പതുക്കെ പറയൂ mean?)',
      options: [
        'Please speak slowly',
        'Please speak louder',
        'Please stop',
        'Please repeat in English',
      ],
      correctIndex: 0,
      explanation:
          'പതുക്കെ = slowly + പറയൂ (please say). Add ഒരു നിമിഷം (one moment) and ദയവായി (please, formal) for the full kit.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_ml_reading)
  // ════════════════════════════════════════════════════════════════════

  'ml_reading_conversation': const [
    Exercise(
      id: 'ex_ml_read1_1',
      lessonId: 'ml_reading_conversation',
      type: ExerciseType.mcq,
      prompt: 'ചായക്കട: "രണ്ട് ചായ, എത്ര?" — എന്ത് ചോദിക്കുന്നു? '
          '(In the tea-shop dialogue, what is being asked?)',
      options: [
        'Two teas — how much?',
        'Two people — who?',
        'Tea or coffee?',
        'Where is the tea shop?',
      ],
      correctIndex: 0,
      explanation:
          'രണ്ട് ചായ, എത്ര? — the complete Kerala order: quantity + item + price question. Reply: പത്ത് രൂപ.',
    ),
    Exercise(
      id: 'ex_ml_read1_2',
      lessonId: 'ml_reading_conversation',
      type: ExerciseType.mcq,
      prompt:
          "'പോകണം' എന്ത് സൂചിപ്പിക്കുന്നു? (What does -ണം express in പോകണം?)",
      options: [
        'must / have to',
        'past tense',
        'a question',
        'politeness only',
      ],
      correctIndex: 0,
      explanation:
          'പോകണം = must go. From the dialogue: ഇപ്പോൾ ജോലിക്ക് പോകണം — I have to go to work now.',
    ),
    Exercise(
      id: 'ex_ml_read1_3',
      lessonId: 'ml_reading_conversation',
      type: ExerciseType.mcq,
      prompt: "'പോയി വരിക!' എന്തിന്റെ സൂചന? (പോയി വരിക! signals…)",
      options: [
        'The goodbye that promises return',
        'Anger',
        'An invitation to dinner',
        'A question about buses',
      ],
      correctIndex: 0,
      explanation:
          '"Go and come back (politely)" — Kerala\'s goodbye. Informal: പോയി വരാം; reply: വരൂ / ശരി.',
    ),
  ],

  'ml_reading_paragraph': const [
    Exercise(
      id: 'ex_ml_read2_1',
      lessonId: 'ml_reading_paragraph',
      type: ExerciseType.mcq,
      prompt:
          'കൊച്ചി യാത്ര: എങ്ങനെ യാത്ര ചെയ്തു? (In the paragraph, how did they travel?)',
      options: [
        'ട്രെയിനിൽ (by train)',
        'ബസ്സിൽ (by bus)',
        'കാറിൽ (by car)',
        'കാൽനടയായി (on foot)'
      ],
      correctIndex: 0,
      explanation:
          'ബാംഗ്ലൂരിൽ നിന്ന് ട്രെയിനിൽ പത്ത് മണിക്കൂർ — ten hours by train from Bengaluru.',
    ),
    Exercise(
      id: 'ex_ml_read2_2',
      lessonId: 'ml_reading_paragraph',
      type: ExerciseType.matching,
      prompt: 'പാഠഭാഗത്തെ വാക്കുകൾ (Match words from the paragraph)',
      pairs: [
        (left: 'കടൽ', right: 'sea'),
        (left: 'കപ്പൽ', right: 'ship'),
        (left: 'മീൻ ചോറ്', right: 'fish-rice meal'),
        (left: 'സൂര്യാസ്തമയം', right: 'sunset'),
      ],
      explanation:
          'All from the Kochi paragraph: കടലും കപ്പലും കാറ്റും (sea, ships, wind), മീൻ ചോറ് കഴിച്ചു, സൂര്യാസ്തമയം കണ്ടു.',
    ),
    Exercise(
      id: 'ex_ml_read2_3',
      lessonId: 'ml_reading_paragraph',
      type: ExerciseType.mcq,
      /*
      prompt: "'-ഉം' എത്ര തവണ? (How many "and"s (-ഉം) appear in കടലും കപ്പലും കാറ്റും?)",
      */
      prompt:
          'How many times does the Malayalam conjunction appear in the sentence?',
      options: ['1', '2', '3', '0'],
      correctIndex: 2,
      explanation:
          'Three: കടലും, കപ്പലും, കാറ്റും — the -ഉം tag chains nouns as "and". A neat pattern for lists.',
    ),
  ],

  'ml_reading_proverbs': const [
    Exercise(
      id: 'ex_ml_read3_1',
      lessonId: 'ml_reading_proverbs',
      type: ExerciseType.matching,
      prompt: 'പഴഞ്ചൊല്ലുകൾ (Match proverbs to meanings)',
      pairs: [
        (
          left: 'കൈയിലുള്ളത് കൈമാറരുത്',
          right: "don't hand over what's in your hand"
        ),
        (
          left: 'ആനയില്ലാത്ത ഊരിൽ',
          right: 'buffalo is the elephant (where no elephant)'
        ),
        (left: 'കൈ', right: 'hand'),
        (left: 'ആന', right: 'elephant'),
      ],
      explanation:
          'Two classics: bird-in-hand wisdom, and the blind-village proverb. Note the fusion കൈ+ഇൽ+ഉള്ളത്.',
    ),
    Exercise(
      id: 'ex_ml_read3_2',
      lessonId: 'ml_reading_proverbs',
      type: ExerciseType.mcq,
      prompt: "'അടുക്കളയിൽ നിന്നാണ് സംസ്കാരം തുടങ്ങുന്നത്' — അർത്ഥം: "
          '(What does the kitchen proverb claim?)',
      options: [
        'Culture begins from the kitchen',
        'Kitchens are dirty',
        'Never cook at home',
        'Food is expensive',
      ],
      correctIndex: 0,
      explanation:
          'അടുക്കള kitchen + സംസ്കാരം culture — Kerala\'s beloved modern saying (think sadya on a banana leaf).',
    ),
    Exercise(
      id: 'ex_ml_read3_3',
      lessonId: 'ml_reading_proverbs',
      type: ExerciseType.mcq,
      prompt:
          'പഴഞ്ചൊല്ലുകളിലെ വാക്യക്രമം: (Word order inside Malayalam proverbs is…)',
      options: ['SVO', 'SOV (same as sentences)', 'random', 'VSO'],
      correctIndex: 1,
      explanation:
          'Proverbs keep SOV too. Read each aloud twice — the rhythm is half the memory.',
    ),
  ],

  'ml_reading_review': const [
    Exercise(
      id: 'ex_ml_read4_1',
      lessonId: 'ml_reading_review',
      type: ExerciseType.mcq,
      prompt: 'പൂർണ്ണ യാത്ര: വാക്യം എന്തുകൊണ്ട് അവസാനിക്കുന്നു? '
          '(Full recap: what closes EVERY Malayalam sentence?)',
      options: ['the subject', 'the verb', 'a question word', 'the object'],
      correctIndex: 1,
      explanation:
          'SOV — the verb lands last in statements, routines, dialogues and proverbs alike.',
    ),
    Exercise(
      id: 'ex_ml_read4_2',
      lessonId: 'ml_reading_review',
      type: ExerciseType.translation,
      prompt: 'സ്വയം പരിശോധന: "എന്റെ പേര് ___" — complete it (type any name)',
      acceptedAnswers: ['എന്റെ പേര്', 'ente peru'],
      explanation:
          'എന്റെ പേര് + [your name]. The first sentence every learner says — ten more now build around it.',
    ),
    Exercise(
      id: 'ex_ml_read4_3',
      lessonId: 'ml_reading_review',
      type: ExerciseType.mcq,
      prompt: 'വായിക്കുക: മലയാളം, വഴി, പഴം — ഏതിൽ അല്ല ഴ? '
          '(Of മലയാളം / വഴി / പഴം — which does NOT contain ഴ?)',
      options: ['മലയാളം', 'വഴി', 'പഴം', 'all three do'],
      correctIndex: 0,
      explanation:
          'മലയാളം has ള (retroflex l), not ഴ. വഴി (way) and പഴം (fruit) carry the famous zh. The three-l ladder in action.',
    ),
  ],
};
