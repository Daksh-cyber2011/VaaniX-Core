/// Odia Exercises — VaaniX Learn Mode Part J (M9)
///
/// Practice exercises for the Odia curriculum
/// (assets/curriculum/learn/or.json). Keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically. Each lesson
/// has 3 exercises covering mcq, fillBlank, ordering, translation and
/// matching types.
///
/// Content note: every exercise is grounded in the actual lesson
/// content. Odia examples are natural (not machine-translated).
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Odia exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `or_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode
/// curriculum.
final Map<String, List<Exercise>> odiaExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Odia Script (ch_or_script)
  // ════════════════════════════════════════════════════════════════════

  'or_script_vowels': const [
    Exercise(
      id: 'ex_or_vowels_1',
      lessonId: 'or_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'ଓଡ଼ିଆ ଲିପି କାହିଁକି ଏତେ ଗୋଲାକାର? '
          '(Why is the Odia script the ROUNDEST of Indian scripts?)',
      options: [
        'It evolved from writing on palm leaves with an iron stylus',
        'It copied Latin letters',
        'It is a modern design choice',
        'Nobody knows',
      ],
      correctIndex: 0,
      explanation:
          'Curves never split a palm leaf; straight lines did. The stylus shaped the script — the roundest in India.',
    ),
    Exercise(
      id: 'ex_or_vowels_2',
      lessonId: 'or_script_vowels',
      type: ExerciseType.matching,
      prompt: 'ସ୍ୱରକୁ ଅର୍ଥ ସହ ମେଳାଅ (Match vowels to example words)',
      pairs: [
        (left: 'ଅମ୍ବ', right: 'a — mango'),
        (left: 'ଆମେ', right: 'ā — we'),
        (left: 'ଉଷା', right: 'u — dawn'),
        (left: 'ଓଡ଼ିଆ', right: 'o — the language itself'),
      ],
      explanation:
          'Each word showcases one vowel: ଅମ୍ବ opens with ଅ, ଆମେ with ଆ, ଉଷା with ଉ, and ଓଡ଼ିଆ with ଓ.',
    ),
    Exercise(
      id: 'ex_or_vowels_3',
      lessonId: 'or_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'ମାନେ vs ମନେ — ପାର୍ଥକ୍ୟ କଣ? (ମାନେ vs ମନେ differ in…)',
      options: [
        'the consonant',
        'the vowel LENGTH (ଆ vs ଅ)',
        'nothing',
        'the ending'
      ],
      correctIndex: 1,
      explanation:
          'ମାନେ (māne, means) holds the long ଆ; ମନେ (mane, to the mind) the short ଅ. Eleven vowels, one held-beat rule.',
    ),
  ],

  'or_script_consonants': const [
    Exercise(
      id: 'ex_or_cons_1',
      lessonId: 'or_script_consonants',
      type: ExerciseType.matching,
      prompt: 'ବ୍ୟଞ୍ଜନ ଧ୍ୱନି ସହ ମେଳାଅ (Match consonants to sounds)',
      pairs: [
        (left: 'କ', right: 'ka'),
        (left: 'ଗ', right: 'ga'),
        (left: 'ମ', right: 'ma'),
        (left: 'ଡ଼', right: 'the dotted flap ṛa'),
      ],
      explanation:
          'A bare consonant reads with built-in ଅ: କ = ka. ଡ଼ is the flapped r-sound — different from ର (tooth-r).',
    ),
    Exercise(
      id: 'ex_or_cons_2',
      lessonId: 'or_script_consonants',
      type: ExerciseType.mcq,
      prompt: "'ଓଡ଼ିଆ' ରେ କେଉଁ ବିଶେଷ ଅକ୍ଷର ଅଛି? "
          '(Which special letter appears in ଓଡ଼ିଆ itself?)',
      options: ['ର (ra)', 'ଡ଼ (ṛa — the dotted flap)', 'ଲ (la)', 'ଵ (va)'],
      correctIndex: 1,
      explanation:
          'The dotted ଡ଼! Dropping the dot changes it to ଡ and the meaning goes wrong. It also appears in ଡ଼ାଲି (ladle), ଢ଼େଣୁ (fly).',
    ),
    Exercise(
      id: 'ex_or_cons_3',
      lessonId: 'or_script_consonants',
      type: ExerciseType.mcq,
      prompt:
          'ରାଜା vs ଓଡ଼ିଆ — ଦୁଇ r-ଧ୍ୱନି: (ରାଜା vs ଓଡ଼ିଆ — the two r-sounds are…)',
      options: [
        'ର = plain tooth-r; ଡ଼ = curled flap',
        'Both identical',
        'One is silent',
        'One is English',
      ],
      correctIndex: 0,
      explanation:
          'ର (ra in ରାଜା) and ଡ଼ (ṛa in ଓଡ଼ିଆ) are two different letters. Two r-sounds, both essential.',
    ),
  ],

  'or_script_matras': const [
    Exercise(
      id: 'ex_or_matras_1',
      lessonId: 'or_script_matras',
      type: ExerciseType.mcq,
      prompt: 'କ + ି କିପରି ପଢ଼ାଯାଏ? (How is କ + the sign ି read?)',
      options: ['ka', 'kā', 'ki', 'ku'],
      correctIndex: 2,
      explanation:
          'The ି sign makes କ (ka) into କି (ki) — written LEFT of the consonant, spoken AFTER it. Sign order ≠ reading order.',
    ),
    Exercise(
      id: 'ex_or_matras_2',
      lessonId: 'or_script_matras',
      type: ExerciseType.matching,
      prompt: 'ମାତ୍ରା ମେଳାଅ (Match the matra forms)',
      pairs: [
        (left: 'କା', right: 'kā'),
        (left: 'କି', right: 'ki'),
        (left: 'କୁ', right: 'ku'),
        (left: 'କୋ', right: 'ko'),
      ],
      explanation:
          'One sign per vowel: ା = ā, ି = i, ୁ = u (below), ୋ = o. The consonant କ stays constant.',
    ),
    Exercise(
      id: 'ex_or_matras_3',
      lessonId: 'or_script_matras',
      type: ExerciseType.mcq,
      prompt: "'ଦୁଃଖ' ରେ ଥିବା ଚିହ୍ନ: (The mark in ଦୁଃଖ (sorrow) is the…)",
      options: ['anusvāra ଂ', 'visarga ଃ', 'virama ୍', 'matra ା'],
      correctIndex: 1,
      explanation:
          'ଃ (visarga) is a faint h: ଦୁଃଖ. The anusvāra ଂ adds a nasal m/n (ଅଂଶ); the virama ୍ kills the vowel.',
    ),
  ],

  'or_script_conjuncts': const [
    Exercise(
      id: 'ex_or_conj_1',
      lessonId: 'or_script_conjuncts',
      type: ExerciseType.matching,
      prompt: 'ଯୁକ୍ତାକ୍ଷର ମେଳାଅ (Match conjuncts to words)',
      pairs: [
        (left: 'ଉତ୍ତର', right: 'answer (ତ୍ତ)'),
        (left: 'ଆନନ୍ଦ', right: 'joy (ନ୍ଦ)'),
        (left: 'ବିଜ୍ଞାନ', right: 'science (ଜ୍ଞ)'),
        (left: 'କାର୍ଯ୍ୟ', right: 'work (ର୍ଯ)'),
      ],
      explanation:
          'High-frequency conjuncts: ତ୍ତ, ନ୍ଦ, ଜ୍ଞ, ର୍ଯ. They become sight-shapes fast — you have seen ତ୍ତ twice already.',
    ),
    Exercise(
      id: 'ex_or_conj_2',
      lessonId: 'or_script_conjuncts',
      type: ExerciseType.mcq,
      prompt:
          "'ଧର୍ମ' ରେ ର କେମିତି ଲେଖାଯାଏ? (How does ର appear in ଧର୍ମ (dharma)?)",
      options: [
        'As a diagonal ର୍ ABOVE the next consonant',
        'Below the consonant',
        'It disappears',
        'It doubles',
      ],
      explanation:
          'ର before a consonant rides on top as ର୍ (ଧର୍ମ); after a consonant it sits below as ୍ର (ପ୍ରେମ).',
    ),
    Exercise(
      id: 'ex_or_conj_3',
      lessonId: 'or_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'ବିରାମ (୍) କଣ କରେ? (What does the virama ୍ do?)',
      options: [
        "Removes the consonant's built-in 'a'",
        'Doubles the letter',
        'Lengthens the vowel',
        'Nothing',
      ],
      correctIndex: 0,
      explanation:
          '୍ kills the vowel: କ୍ is bare "k". So ଉତ୍ତର = ଉ + ତ୍ + ତ + ର.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_or_greet)
  // ════════════════════════════════════════════════════════════════════

  'or_greet_namaskara': const [
    Exercise(
      id: 'ex_or_greet_1',
      lessonId: 'or_greet_namaskara',
      type: ExerciseType.mcq,
      prompt: 'ସମ୍ମାନର ସହ "କେମିତି ଅଛନ୍ତି?" — କାହା ସହ? '
          '(The respectful କେମିତି ଅଛନ୍ତି? is used with…)',
      options: ['elders and strangers', 'small children', 'animals', 'nobody'],
      correctIndex: 0,
      explanation:
          'କେମିତି ଅଛନ୍ତି? is the respectful how-are-you (-ନ୍ତି ending). Friends get କେମନ ଅଛ?',
    ),
    Exercise(
      id: 'ex_or_greet_2',
      lessonId: 'or_greet_namaskara',
      type: ExerciseType.matching,
      prompt: 'ଅର୍ଥ ମେଳାଅ (Match phrases to meanings)',
      pairs: [
        (left: 'ଧନ୍ୟବାଦ', right: 'thank you'),
        (left: 'ମାଫ କରନ୍ତୁ', right: 'sorry / excuse me'),
        (left: 'ଆସିବି', right: 'I will come (farewell)'),
        (left: 'ମୁଁ ଭଲ ଅଛି', right: 'I am well'),
      ],
      explanation:
          'The Odia goodbye ଆସିବି frames leaving as returning. Reply: ଆସନ୍ତୁ ଆସନ୍ତୁ (come, come!).',
    ),
    Exercise(
      id: 'ex_or_greet_3',
      lessonId: 'or_greet_namaskara',
      type: ExerciseType.mcq,
      prompt: 'ଓଡ଼ିଶା ଘରକୁ ପ୍ରବେଶ କଲେ ପ୍ରଥମେ କଣ ମିଳେ? '
          '(Entering an Odia home, what comes FIRST — before hello?)',
      options: [
        'ପାଣି (water)',
        'ଭୋଜନ (a full meal)',
        'ଚା (tea)',
        'ଉପହାର (a gift)'
      ],
      correctIndex: 0,
      explanation:
          'ପାଣି ପିଅନ୍ତୁ (please drink water) is offered before anything — Odia hospitality\'s famous first move.',
    ),
  ],

  'or_greet_intro': const [
    Exercise(
      id: 'ex_or_intro_1',
      lessonId: 'or_greet_intro',
      type: ExerciseType.translation,
      prompt: 'ଓଡ଼ିଆରେ କୁହ: "My name is Rahul."',
      acceptedAnswers: ['ମୋର ନାମ ରାହୁଲ', 'mora nama rahul'],
      explanation:
          'ମୋର (my) + ନାମ (name) + ରାହୁଲ. Ask back respectfully: ଆପଣଙ୍କ ନାମ କଣ?',
    ),
    Exercise(
      id: 'ex_or_intro_2',
      lessonId: 'or_greet_intro',
      type: ExerciseType.ordering,
      prompt: 'ବାକ୍ୟ ସଜାଅ (Arrange: "I have come from Bhubaneswar")',
      items: ['ମୁଁ (I)', 'ଭୁବନେଶ୍ୱରରୁ (from Bhubaneswar)', 'ଆସିଛି (have come)'],
      explanation:
          'ମୁଁ ଭୁବନେଶ୍ୱରରୁ ଆସିଛି — subject → source (-ରୁ) → verb. Note the glue: ଭୁବନେଶ୍ୱର + ରୁ → ଭୁବନେଶ୍ୱରରୁ.',
    ),
    Exercise(
      id: 'ex_or_intro_3',
      lessonId: 'or_greet_intro',
      type: ExerciseType.mcq,
      prompt: "'ଧୀରେ କହନ୍ତୁ' ର ଅର୍ଥ: (What does ଧୀରେ କହନ୍ତୁ mean?)",
      options: [
        'Please say (it) slowly',
        'Please say it loudly',
        'Please stop talking',
        'Please repeat in English',
      ],
      correctIndex: 0,
      explanation:
          'ଧୀରେ = slowly + କହନ୍ତୁ (please say, resp.). Its partner: ମୁଁ ବୁଝିପାରିଲି ନାହିଁ (I didn\'t understand).',
    ),
  ],

  'or_greet_family': const [
    Exercise(
      id: 'ex_or_family_1',
      lessonId: 'or_greet_family',
      type: ExerciseType.matching,
      prompt: 'ପରିବାର ଶବ୍ଦ (Match the family words)',
      pairs: [
        (left: 'ମାଆ', right: 'mother'),
        (left: 'ବାପା', right: 'father'),
        (left: 'ଭଉଣୀ', right: 'sister'),
        (left: 'ଆଜି', right: 'grandmother'),
      ],
      explanation:
          'Brothers/sisters take age modifiers: ବଡ଼ ଭାଇ (elder brother), ସାନ ଭାଇ (younger). ଆଜା/ଆଜି = grandfather/grandmother.',
    ),
    Exercise(
      id: 'ex_or_family_2',
      lessonId: 'or_greet_family',
      type: ExerciseType.mcq,
      prompt:
          'ଦୋକାନୀକୁ କିପରି ସମ୍ବୋଧନ? (How would you warmly address a shopkeeper?)',
      options: [
        'ଭାଇ (brother)',
        'ଶତ୍ରୁ',
        'କିଛି ନୁହେଁ (nothing — no address)',
        'ଗଛ'
      ],
      correctIndex: 0,
      explanation:
          'ଭାଇ (brother) and ମାଉସୀ (auntie) are warm addresses for strangers — kinship as politeness.',
    ),
    Exercise(
      id: 'ex_or_family_3',
      lessonId: 'or_greet_family',
      type: ExerciseType.translation,
      prompt: 'ଓଡ଼ିଆରେ କୁହ: "I have one sister."',
      acceptedAnswers: [
        'ମୋର ଜଣେ ଭଉଣୀ ଅଛି',
        'mora jane bhhauni achhi',
        'mora jana bhhauni achhi'
      ],
      explanation:
          'ମୋର (my) + ଜଣେ (one, for people) + ଭଉଣୀ + ଅଛି. ଜଣେ is the human-counter — things take ଟିଏ instead.',
    ),
  ],

  'or_greet_numbers': const [
    Exercise(
      id: 'ex_or_num_1',
      lessonId: 'or_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'ସଂଖ୍ୟା ମେଳାଅ (Match the numbers)',
      pairs: [
        (left: 'ଏକ', right: '1'),
        (left: 'ତିନି', right: '3'),
        (left: 'ପାଞ୍ଚ', right: '5'),
        (left: 'ଦଶ', right: '10'),
      ],
      explanation:
          'ଏକ, ଦୁଇ, ତିନି, ଚାରି, ପାଞ୍ଚ, ଛଅ, ସାତ, ଆଠ, ନଅ, ଦଶ. Digits ୧–୯ appear on bus boards and market slates.',
    ),
    Exercise(
      id: 'ex_or_num_2',
      lessonId: 'or_greet_numbers',
      type: ExerciseType.mcq,
      prompt: "'କୁଡ଼ି' କେତେ? (How much is କୁଡ଼ି?)",
      options: ['10', '20', '50', '100'],
      correctIndex: 1,
      explanation:
          'କୁଡ଼ି = 20. The tens are irregular: ତିରିଶ 30, ଚାଳିଶ 40, ପଚାଶ 50, ଶହ 100 — memorise them as words.',
    ),
    Exercise(
      id: 'ex_or_num_3',
      lessonId: 'or_greet_numbers',
      type: ExerciseType.translation,
      prompt: 'ବଜାରରେ: "How much?" ଓଡ଼ିଆରେ କଣ?',
      acceptedAnswers: ['କେତେ', 'kete'],
      explanation:
          'କେତେ? = how much/how many. Full pair: କେତେ ଦାମ? (how much price?) → ପଚାଶ ଟଙ୍କା (fifty rupees).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_or_daily)
  // ════════════════════════════════════════════════════════════════════

  'or_daily_sentences': const [
    Exercise(
      id: 'ex_or_daily1_1',
      lessonId: 'or_daily_sentences',
      type: ExerciseType.ordering,
      prompt: 'ବାକ୍ୟ ସଜାଅ (Arrange: "I am eating rice")',
      items: ['ମୁଁ (I)', 'ଭାତ (rice)', 'ଖାଉଛି (eating)'],
      explanation: 'SOV: ମୁଁ ଭାତ ଖାଉଛି. The verb always closes the sentence.',
    ),
    Exercise(
      id: 'ex_or_daily1_2',
      lessonId: 'or_daily_sentences',
      type: ExerciseType.mcq,
      prompt: "'ମୋର ସମୟ ଅଛି' ର ଅର୍ଥ: (What does ମୋର ସମୟ ଅଛି mean?)",
      options: ['I have time', 'I had time', 'I want time', 'Time is money'],
      correctIndex: 0,
      explanation:
          'ମୋର (to-me) + ସମୟ (time) + ଅଛି (is). Possession = dative + ଅଛି. Negative: ମୋର ସମୟ ନାହିଁ.',
    ),
    Exercise(
      id: 'ex_or_daily1_3',
      lessonId: 'or_daily_sentences',
      type: ExerciseType.mcq,
      prompt:
          "'ମାଆ ଘରେ ଅଛନ୍ତି' — '-ନ୍ତି' କଣ ସୂଚାଏ? (In ମାଆ ଘରେ ଅଛନ୍ତି, what does -ନ୍ତି mark?)",
      options: [
        'respect (mother honored)',
        'past tense',
        'a question',
        'plural objects'
      ],
      correctIndex: 0,
      explanation:
          '-ନ୍ତି is the respectful verb ending — ଅଛନ୍ତି (is, hon.). Odia marks respect right in the verb.',
    ),
  ],

  'or_daily_questions': const [
    Exercise(
      id: 'ex_or_daily2_1',
      lessonId: 'or_daily_questions',
      type: ExerciseType.matching,
      prompt: 'ପ୍ରଶ୍ନ ଶବ୍ଦ (Match the question words)',
      pairs: [
        (left: 'କଣ', right: 'what'),
        (left: 'କିଏ', right: 'who'),
        (left: 'କେଉଁଠି', right: 'where'),
        (left: 'କେବେ', right: 'when'),
      ],
      explanation:
          'Also କେତେ (how much), କିପରି (how). They stay in place — "you where-going?" is normal Odia.',
    ),
    Exercise(
      id: 'ex_or_daily2_2',
      lessonId: 'or_daily_questions',
      type: ExerciseType.mcq,
      prompt: "'ବସ୍ କେଉଁଠି?' ର ଅର୍ଥ: (What does ବସ୍ କେଉଁଠି? ask?)",
      options: [
        'When is the bus?',
        'Where is the bus?',
        'How much is the bus?',
        'Who is on the bus?'
      ],
      correctIndex: 1,
      explanation:
          'କେଉଁଠି = where. Question word holds the answer\'s slot: "bus where?"',
    ),
    Exercise(
      id: 'ex_or_daily2_3',
      lessonId: 'or_daily_questions',
      type: ExerciseType.mcq,
      prompt: 'Yes/No ପ୍ରଶ୍ନ କିପରି? (How is a yes/no question tagged?)',
      options: [
        'Add -କି (ଆସିବ କି? — will you come?)',
        'Move the verb first',
        'Add କଣ at the start',
        'Odia has no yes/no questions',
      ],
      correctIndex: 0,
      explanation:
          '-କି flips statements: ଠିକ୍ ଅଛି ତା? (it\'s okay, right?). Intonation completes it.',
    ),
  ],

  'or_daily_negation': const [
    Exercise(
      id: 'ex_or_daily3_1',
      lessonId: 'or_daily_negation',
      type: ExerciseType.matching,
      prompt: 'ନିଷେଧ ଶବ୍ଦ (Match each no to its job)',
      pairs: [
        (left: 'ନାହିଁ', right: 'is not there / don\'t have'),
        (left: 'ନୁହେଁ', right: 'is not (identity)'),
        (left: 'ଯାଉନାହିଁ', right: 'am not going (verb negation)'),
        (left: 'ଦରକାର ନାହିଁ', right: 'not needed'),
      ],
      explanation:
          'Three no\'s, three jobs: existence (ନାହିଁ), identity (ନୁହେଁ), verb action (verb + ନାହିଁ/ନିନି).',
    ),
    Exercise(
      id: 'ex_or_daily3_2',
      lessonId: 'or_daily_negation',
      type: ExerciseType.mcq,
      prompt: "'ଇହା ଦୁଧ ନୁହେଁ' — କାହିଁକି ନୁହେଁ? (Why ନୁହେଁ in ଇହା ଦୁଧ ନୁହେଁ?)",
      options: [
        'It rejects identity: "this is NOT milk"',
        'It rejects existence',
        'It negates a verb',
        'It is polite',
      ],
      correctIndex: 0,
      explanation:
          'ନୁହେଁ rejects what something IS. Existence takes ନାହିଁ (ପାଣି ନାହିଁ).',
    ),
    Exercise(
      id: 'ex_or_daily3_3',
      lessonId: 'or_daily_negation',
      type: ExerciseType.fillBlank,
      prompt: 'ପାଣି ___ (There is NO water — fill the negative)',
      options: ['ଅଛି', 'ନାହିଁ', 'ନୁହେଁ', 'ଅଛନ୍ତି'],
      correctIndex: 1,
      explanation:
          'ପାଣି ନାହିଁ — the positive would be ପାଣି ଅଛି. The polite shop refusal: ନା, ଦରକାର ନାହିଁ.',
    ),
  ],

  'or_daily_routine': const [
    Exercise(
      id: 'ex_or_daily4_1',
      lessonId: 'or_daily_routine',
      type: ExerciseType.matching,
      prompt: 'ଦିନର ଭାଗ (Match the day-parts)',
      pairs: [
        (left: 'ସକାଳ', right: 'morning'),
        (left: 'ମଧ୍ୟାହ୍ନ', right: 'noon'),
        (left: 'ସନ୍ଧ୍ୟା', right: 'evening'),
        (left: 'ରାତି', right: 'night'),
      ],
      explanation:
          'Day-parts prefix clock times: ସକାଳ ସାତ ଟାରେ = at seven in the morning.',
    ),
    Exercise(
      id: 'ex_or_daily4_2',
      lessonId: 'or_daily_routine',
      type: ExerciseType.mcq,
      prompt: "'କେତେ ସମୟ ହେଲା?' ର ଅର୍ଥ: (What does କେତେ ସମୟ ହେଲା? mean?)",
      options: [
        'What time is it? (how-much time became)',
        'How long did you stay?',
        'When did you wake?',
        'Is dinner ready?',
      ],
      correctIndex: 0,
      explanation:
          'The clock question. Reply: ଛଅ ଟା ହେଲା — it\'s six. The -ଟା is the clock-tap ending.',
    ),
    Exercise(
      id: 'ex_or_daily4_3',
      lessonId: 'or_daily_routine',
      type: ExerciseType.mcq,
      prompt:
          'ଗ୍ରୀଷ୍ମର ଓଡ଼ିଶା ଖାଦ୍ୟ ଆଇକନ୍: (Odisha\'s summer food icon, fermented water-rice, is…)',
      options: ['ପଖାଳ (pakhāḷa)', 'ଦୋସା', 'ପିଜ୍ଜା', 'ଚାପ'],
      correctIndex: 0,
      explanation:
          'ପଖାଳ — fermented water-rice, the beloved summer dish. Others: ଭାତ (rice), ମାଛ ଭଜା (fried fish).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_or_grammar)
  // ════════════════════════════════════════════════════════════════════

  'or_grammar_pronouns': const [
    Exercise(
      id: 'ex_or_gram1_1',
      lessonId: 'or_grammar_pronouns',
      type: ExerciseType.matching,
      prompt: 'ସର୍ବନାମ (Match the pronouns)',
      pairs: [
        (left: 'ମୁଁ', right: 'I'),
        (left: 'ଆପଣ', right: 'you (respectful)'),
        (left: 'ସେ', right: 'he/she'),
        (left: 'ଆମେ', right: 'we'),
      ],
      explanation:
          'The you-ladder: ତୁ (intimate) → ତୁମେ (friendly) → ଆପଣ (respect). When in doubt, ଆପଣ never insults.',
    ),
    Exercise(
      id: 'ex_or_gram1_2',
      lessonId: 'or_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: "'ସେ' କେଉଁପାଇଁ? (What does ସେ cover?)",
      options: [
        'Both he and she (gender-free)',
        'Only males',
        'Only females',
        'Only objects',
      ],
      correctIndex: 0,
      explanation:
          'ସେ is gender-free; objects are all ଏହା. Odia has no grammatical gender — a genuine relief for learners.',
    ),
    Exercise(
      id: 'ex_or_gram1_3',
      lessonId: 'or_grammar_pronouns',
      type: ExerciseType.fillBlank,
      prompt: 'ସେମାନେ କରୁ___. (They are doing — fill the ending)',
      options: ['-ଛି', '-ଛ', '-ଛନ୍ତି', '-ଛୁ'],
      correctIndex: 2,
      explanation:
          'Endings: ମୁଁ -କରୁଛି, ସେ -କରୁଛି, ଆମେ -କରୁଛୁ, ସେମାନେ -କରୁଛନ୍ତି. Five endings, all regular.',
    ),
  ],

  'or_grammar_tenses': const [
    Exercise(
      id: 'ex_or_gram2_1',
      lessonId: 'or_grammar_tenses',
      type: ExerciseType.matching,
      prompt: 'କାଳ ମେଳାଅ (Match the tense forms of ଖାଇବା)',
      pairs: [
        (left: 'ଖାଉଛି', right: 'I am eating'),
        (left: 'ଖାଏ', right: '(he/she) eats'),
        (left: 'ଖାଇଲି', right: 'I ate'),
        (left: 'ଖାଇବି', right: '(I) will eat'),
      ],
      explanation:
          'Four tenses: progressive -ଉଛି, habitual -ଏ, past -ିଲି, future -ିବି. The pattern slots onto every verb.',
    ),
    Exercise(
      id: 'ex_or_gram2_2',
      lessonId: 'or_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'ଯିବା (go) ର ଅତୀତ: (The past of ଯିବା — go — is…)',
      options: ['ଯାଉଛି', 'ଗଲି', 'ଯିବି', 'ଯାଏ'],
      correctIndex: 1,
      explanation:
          'ଯିବା → ଗଲି (went) — a twist. Other pairs: ଆସିବା → ଆସିଲି, କରିବା → କଲି, ଖାଇବା → ଖାଇଲି.',
    ),
    Exercise(
      id: 'ex_or_gram2_3',
      lessonId: 'or_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: "'ଆସନ୍ତାକାଲି' ର ଅର୍ଥ: (What does ଆସନ୍ତାକାଲି mean?)",
      options: ['today', 'yesterday', 'tomorrow', 'every day'],
      correctIndex: 2,
      explanation:
          'ଆଜି today, ଗତକାଲ yesterday, ଆସନ୍ତାକାଲି tomorrow, ପ୍ରତିଦିନ every day.',
    ),
  ],

  'or_grammar_cases': const [
    Exercise(
      id: 'ex_or_gram3_1',
      lessonId: 'or_grammar_cases',
      type: ExerciseType.matching,
      prompt: 'କାରକ ପ୍ରତ୍ୟୟ (Match the case endings)',
      pairs: [
        (left: '-କୁ', right: 'to'),
        (left: '-ରୁ', right: 'from'),
        (left: '-ରେ', right: 'in/at'),
        (left: '-ର', right: "'s (possessive)"),
      ],
      explanation:
          'Nouns wear endings: ପୁରୀକୁ (to Puri), ଭୁବନେଶ୍ୱରରୁ (from Bhubaneswar), ରାହୁଲର ବହି (Rahul\'s book).',
    ),
    Exercise(
      id: 'ex_or_gram3_2',
      lessonId: 'or_grammar_cases',
      type: ExerciseType.mcq,
      prompt: "'ମୁଁ ବଜାରକୁ ଯାଉଛି' ର ଅର୍ଥ: (What does ମୁଁ ବଜାରକୁ ଯାଉଛି mean?)",
      options: [
        'I am going TO the market',
        'I am going FROM the market',
        'I am IN the market',
        'I am WITH the market',
      ],
      correctIndex: 0,
      explanation:
          '-କୁ marks direction: ବଜାର + କୁ → ବଜାରକୁ. From would be -ରୁ, in would be -ରେ.',
    ),
    Exercise(
      id: 'ex_or_gram3_3',
      lessonId: 'or_grammar_cases',
      type: ExerciseType.mcq,
      prompt:
          'ସମ୍ମାନର ଅଧିକାରଣ: (The HONORIFIC possessive ("mother\'s", respected) is…)',
      options: ['ମାଆର', 'ମାଆଙ୍କ', 'ମାଆକୁ', 'ମାଆରୁ'],
      correctIndex: 1,
      explanation:
          'ମାଆଙ୍କ (also ମାଆଙ୍କର) — the -ଙ୍କ attach marks respected owners: ମାଆଙ୍କ ନାମ, ଆପଣଙ୍କ ନାମ.',
    ),
  ],

  'or_grammar_politeness': const [
    Exercise(
      id: 'ex_or_gram4_1',
      lessonId: 'or_grammar_politeness',
      type: ExerciseType.matching,
      prompt: 'ଆଦର ରୂପ (Match intimate to respectful)',
      pairs: [
        (left: 'ଆସ', right: 'ଆସନ୍ତୁ (please come)'),
        (left: 'ବସ', right: 'ବସନ୍ତୁ (please sit)'),
        (left: 'କହ', right: 'କହନ୍ତୁ (please say)'),
        (left: 'ଖାଅ', right: 'ଖାଆନ୍ତୁ (please eat)'),
      ],
      explanation:
          'Respect = the -ନ୍ତୁ imperative + ଆପଣ pronoun. Shop line: ଆସନ୍ତୁ, ବସନ୍ତୁ, କଣ ଦରକାର?',
    ),
    Exercise(
      id: 'ex_or_gram4_2',
      lessonId: 'or_grammar_politeness',
      type: ExerciseType.mcq,
      prompt: "'ଧୀରେ ଧୀରେ' ର ଅର୍ଥ: (What does ଧୀରେ ଧୀରେ mean?)",
      options: ['slowly, slowly', 'quickly', 'loudly', 'never'],
      correctIndex: 0,
      explanation:
          'ଧୀରେ = slowly. Doubled for rhythm: ଧୀରେ ଧୀରେ ଶିଖନ୍ତୁ — learn slowly, slowly (the honest way).',
    ),
    Exercise(
      id: 'ex_or_gram4_3',
      lessonId: 'or_grammar_politeness',
      type: ExerciseType.mcq,
      prompt:
          'ଦୋକାନରେ ଦାମ୍ କମ୍ କରିବା: (The polite "reduce (the price) a little" is…)',
      options: ['ଅଳ୍ପ କମ୍ କରନ୍ତୁ', 'ମହଙ୍ଗା!', 'ଦିଅ ଦିଅ!', 'ଚୁପ୍'],
      correctIndex: 0,
      explanation:
          'ଅଳ୍ପ (a little) + କମ୍ (less) + କରନ୍ତୁ (please do). Softeners: ଦୟାକରି (please), ଏକ ମୁହୂର୍ତ୍ତ (one moment).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_or_reading)
  // ════════════════════════════════════════════════════════════════════

  'or_reading_conversation': const [
    Exercise(
      id: 'ex_or_read1_1',
      lessonId: 'or_reading_conversation',
      type: ExerciseType.mcq,
      prompt:
          'ବଜାର: "କଣ ଦରକାର?" ର ଅର୍ଥ: (The standard shop opener କଣ ଦରକାର? means…)',
      options: [
        'What is needed? / What do you need?',
        'What is this?',
        'Who are you?',
        'Where from?'
      ],
      correctIndex: 0,
      explanation:
          'କଣ (what) + ଦରକାର (needed) — every Odia shop opens with it. Answer: ଟମାଟୋ ଦରକାର (I need tomatoes).',
    ),
    Exercise(
      id: 'ex_or_read1_2',
      lessonId: 'or_reading_conversation',
      type: ExerciseType.mcq,
      prompt:
          "'ଅଳ୍ପ କମ୍ କରନ୍ତୁ!' — କେଉଁ ପରିସ୍ଥିତି? (Where does ଅଳ୍ପ କମ୍ କରନ୍ତୁ! belong?)",
      options: [
        'Bargaining at the market',
        'Ordering food',
        'Greeting elders',
        'Asking directions',
      ],
      correctIndex: 0,
      explanation:
          '"Please reduce a little!" — the haggle line. The vendor replies ସରି (okay) with a new price.',
    ),
    Exercise(
      id: 'ex_or_read1_3',
      lessonId: 'or_reading_conversation',
      type: ExerciseType.mcq,
      prompt: "'ଆସିବି ଆସିବି!' କଣ ସୂଚାଏ? (ଆସିବି ଆସିବି! signals…)",
      options: [
        'The farewell that promises return',
        'Anger',
        'A question about trains',
        'An apology',
      ],
      correctIndex: 0,
      explanation:
          '"I\'ll come, I\'ll come" — the Odia goodbye. From the dialogue: ପରେ ଆସିବି (I\'ll come later).',
    ),
  ],

  'or_reading_paragraph': const [
    Exercise(
      id: 'ex_or_read2_1',
      lessonId: 'or_reading_paragraph',
      type: ExerciseType.mcq,
      prompt:
          'ପୁରୀ ଯାତ୍ରା: ଟ୍ରେନ୍ ଯାତ୍ରା କେତେ ସମୟ? (In the paragraph, how long is the train ride?)',
      options: ['ଏକ ଘଣ୍ଟା', 'ତିନି ଘଣ୍ଟା', 'ଦଶ ଘଣ୍ଟା', 'ଅଧ ଘଣ୍ଟା'],
      correctIndex: 0,
      explanation:
          'ଭୁବନେଶ୍ୱରରୁ ଟ୍ରେନରେ ଏକ ଘଣ୍ଟା — one hour by train from Bhubaneswar.',
    ),
    Exercise(
      id: 'ex_or_read2_2',
      lessonId: 'or_reading_paragraph',
      type: ExerciseType.matching,
      prompt: 'ପାଠର ଶବ୍ଦ (Match words from the paragraph)',
      pairs: [
        (left: 'ସମୁଦ୍ର', right: 'sea'),
        (left: 'ଢେଉ', right: 'wave'),
        (left: 'ମନ୍ଦିର', right: 'temple'),
        (left: 'ସୂର୍ଯ୍ୟାସ୍ତ', right: 'sunset'),
      ],
      explanation:
          'All from the Puri paragraph: ସମୁଦ୍ର କୂଳରେ ଚାଲିଲି, ଢେଉ ଆଉ ବାଲି!, ମନ୍ଦିର ଦର୍ଶନ, ସୂର୍ଯ୍ୟାସ୍ତ ଦେଖିଲି.',
    ),
    Exercise(
      id: 'ex_or_read2_3',
      lessonId: 'or_reading_paragraph',
      type: ExerciseType.mcq,
      prompt:
          'ମନ୍ଦିର ପାଇଁ ସଠିକ୍ ଶବ୍ଦ: (The culturally correct verb for viewing a temple is…)',
      options: ['ଦର୍ଶନ କଲି', 'ଦେଖିଲି only', 'ଛୁଅଁଲି', 'ଖାଇଲି'],
      correctIndex: 0,
      explanation:
          'ଦର୍ଶନ — the holy viewing. ମନ୍ଦିର ଦର୍ଶନ କଲି is the culturally right phrasing; ଦେଖିଲି sounds flat for temples.',
    ),
  ],

  'or_reading_proverbs': const [
    Exercise(
      id: 'ex_or_read3_1',
      lessonId: 'or_reading_proverbs',
      type: ExerciseType.matching,
      prompt: 'ପ୍ରବାଦ ମେଳାଅ (Match proverbs to meanings)',
      pairs: [
        (left: 'ନିଜ ଘର ତୁଳନାରେ', right: 'compared to one\'s own house'),
        (left: 'ଯାହା କାମ, ସେହି ସାଜ', right: 'what is useful is adornment'),
        (left: 'ଅଳ୍ପ ଜ୍ଞାନ', right: 'a little knowledge'),
        (left: 'ବିଷ', right: 'poison'),
      ],
      explanation:
          'Four classics: the grass-is-greener, function-is-beauty, half-knowledge-is-poison, and fruit-falls-downward.',
    ),
    Exercise(
      id: 'ex_or_read3_2',
      lessonId: 'or_reading_proverbs',
      type: ExerciseType.mcq,
      prompt:
          "'ଅଳ୍ପ ଜ୍ଞାନ ବିଷ ସମ' — କେଉଁଠି ଲାଗେ? (When does ଅଳ୍ପ ଜ୍ଞାନ ବିଷ ସମ apply?)",
      options: [
        'When half-learning misleads someone',
        'When cooking rice',
        'When greeting elders',
        'When counting money',
      ],
      correctIndex: 0,
      explanation:
          'A little knowledge is equal to poison — the studying proverb. Lesson: finish the ladder before claiming the rung.',
    ),
    Exercise(
      id: 'ex_or_read3_3',
      lessonId: 'or_reading_proverbs',
      type: ExerciseType.mcq,
      prompt:
          "'ଗଛରୁ ଫଳ ତଳକୁ ଖସେ' — ଅର୍ଥ: (The fruit-falls-downward proverb teaches…)",
      options: [
        'Things settle naturally; rising needs effort',
        'Fruit is expensive',
        'Trees are tall',
        'Never eat fruit',
      ],
      correctIndex: 0,
      explanation:
          'ଗଛ tree, ଫଳ fruit, ତଳ down, ଉପର up. Everything naturally settles — which is exactly why the review scheduler exists.',
    ),
  ],

  'or_reading_review': const [
    Exercise(
      id: 'ex_or_read4_1',
      lessonId: 'or_reading_review',
      type: ExerciseType.mcq,
      prompt:
          'ସମ୍ପୂର୍ଣ୍ଣ ଯାତ୍ରା: ବାକ୍ୟ କେଉଁଠୁ ଶେଷ? (Full recap: what closes EVERY Odia sentence?)',
      options: ['the subject', 'the object', 'the verb', 'a question word'],
      correctIndex: 2,
      explanation:
          'SOV — the verb lands last in statements, routines, dialogues and proverbs alike. One rule, whole language.',
    ),
    Exercise(
      id: 'ex_or_read4_2',
      lessonId: 'or_reading_review',
      type: ExerciseType.translation,
      prompt: 'ସ୍ୱ-ପରୀକ୍ଷା: "ମୋର ନାମ ___" — complete it (type any name)',
      acceptedAnswers: ['ମୋର ନାମ', 'mora nama'],
      explanation:
          'ମୋର ନାମ + [your name]. The first sentence every learner says — ten more now build around it.',
    ),
    Exercise(
      id: 'ex_or_read4_3',
      lessonId: 'or_reading_review',
      type: ExerciseType.mcq,
      prompt: 'ପଢ଼: ଓଡ଼ିଆ, ସ୍ୱାଗତ, କାର୍ଯ୍ୟ — ବିନ୍ଦୁକିତ ଅକ୍ଷର କେଉଁଟିରେ? '
          '(Of ଓଡ଼ିଆ / ସ୍ୱାଗତ / କାର୍ଯ୍ୟ — which carries the dotted ଡ଼?)',
      options: ['ଓଡ଼ିଆ', 'ସ୍ୱାଗତ', 'କାର୍ଯ୍ୟ', 'none'],
      correctIndex: 0,
      explanation:
          'ଓଡ଼ିଆ carries the dotted flap ଡ଼ in its own name. ସ୍ୱାଗତ has the ସ୍ୱ cluster; କାର୍ଯ୍ୟ the top-diagonal ର୍.',
    ),
  ],
};
