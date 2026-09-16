/// Marathi Exercises — VaaniX Learn Mode Part C
///
/// Practice exercises for the Marathi curriculum
/// (assets/curriculum/learn/mr.json). Keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically. Each lesson
/// has 3-4 exercises covering MCQ, fillBlank, matching, and translation.
///
/// Content note: every exercise is grounded in the actual lesson content.
/// Marathi examples are natural (not machine-translated from Hindi).
/// Marathi-specific features (ळ, three genders, नाही/नको, षण्ण) are
/// explicitly tested.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Marathi exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `mr_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode curriculum.
final Map<String, List<Exercise>> marathiExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Devanagari Script (ch_mr_script)
  // ════════════════════════════════════════════════════════════════════

  'mr_script_vowels': const [
    Exercise(
      id: 'ex_mr_vowels_1',
      lessonId: 'mr_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'मराठी कोणत्या लिपीत लिहिली जाते?',
      options: ['बंगाली', 'देवनागरी', 'गुरमुखी', 'तमिळ'],
      correctIndex: 1,
      explanation:
          'मराठी देवनागरी लिपीत लिहिली जाते — हीच लिपी हिंदी आणि संस्कृत मध्ये वापरली जाते. पण मराठी एक स्वतंत्र भाषा आहे.',
    ),
    Exercise(
      id: 'ex_mr_vowels_2',
      lessonId: 'mr_script_vowels',
      type: ExerciseType.mcq,
      prompt: '"आई" शब्दाचा अर्थ काय?',
      options: ['mother', 'father', 'sister', 'grandmother'],
      correctIndex: 0,
      explanation:
          'आई (āī) = mother. हा मराठीत "mother" साठी सर्वात सामान्य शब्द आहे — हिंदीच्या माँ पेक्षा वेगळा.',
    ),
    Exercise(
      id: 'ex_mr_vowels_3',
      lessonId: 'mr_script_vowels',
      type: ExerciseType.matching,
      prompt: 'स्वरांना उदाहरण शब्दांसोबत जोडा (Match vowels to example words)',
      pairs: [
        (left: 'अ', right: 'अन्न'),
        (left: 'आ', right: 'आई'),
        (left: 'ए', right: 'एक'),
        (left: 'ओ', right: 'ओढ'),
      ],
      explanation:
          'प्रत्येक स्वराचा स्वतःचा उदाहरण शब्द आहे. अन्न मध्ये अ, आई मध्ये आ, एक मध्ये ए, ओढ मध्ये ओ.',
    ),
  ],

  'mr_script_consonants': const [
    Exercise(
      id: 'ex_mr_consonants_1',
      lessonId: 'mr_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'मराठीतील विशेष व्यंजन कोणते हिंदीत नाही?',
      options: ['ळ (ḷ)', 'श (ś)', 'ष (ṣ)', 'क (k)'],
      correctIndex: 0,
      explanation:
          'ळ (ḷ) — retroflex lateral — हा मराठीतील विशेष ध्वनी आहे जो हिंदीत नाही. काळ (time), फळ (fruit), बाळ (child) मध्ये हा ध्वनी आहे.',
    ),
    Exercise(
      id: 'ex_mr_consonants_2',
      lessonId: 'mr_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'काळ शब्दात कोणता ध्वनी आहे जो हिंदीत नाही?',
      options: ['क', 'ळ', 'आ', 'none'],
      correctIndex: 1,
      explanation:
          'काळ मध्ये ळ (ḷ) आहे — retroflex lateral. हिंदीत काल (ळ नाही, ल आहे). हा मराठीचा ओळखचिन्ह आहे.',
    ),
    Exercise(
      id: 'ex_mr_consonants_3',
      lessonId: 'mr_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'हिंदीचे फल → मराठीत काय?',
      options: ['फल', 'फळ', 'फलं', 'फळं'],
      correctIndex: 1,
      explanation:
          'हिंदी फल → मराठी फळ. हिंदीतील अनेक ल शब्द मराठीत ळ होतात: काल→काळ, बाल→बाळ, फल→फळ.',
    ),
    Exercise(
      id: 'ex_mr_consonants_4',
      lessonId: 'mr_script_consonants',
      type: ExerciseType.matching,
      prompt:
          'हिंदी शब्दांना मराठी प्रतिरूपांसोबत जोडा (Match Hindi to Marathi)',
      pairs: [
        (left: 'काल', right: 'काळ'),
        (left: 'फल', right: 'फळ'),
        (left: 'बाल', right: 'बाळ'),
        (left: 'माल', right: 'माळ'),
      ],
      explanation:
          'हिंदीतील अनेक ल शब्द मराठीत ळ होतात. हे मराठीचे वैशिष्ट्य आहे — ळ मराठी ओळखण्याचा सोपा मार्ग आहे.',
    ),
  ],

  'mr_script_matras': const [
    Exercise(
      id: 'ex_mr_matras_1',
      lessonId: 'mr_script_matras',
      type: ExerciseType.mcq,
      prompt: 'पोळी शब्दात कोणती मात्रा आहे?',
      options: ['ी (ई)', 'ो (ओ)', 'ु (उ)', 'े (ए)'],
      correctIndex: 1,
      explanation:
          'पोळी मध्ये ो (ओ) मात्रा आहे — प + ो + ळ + ी = पोळी (poḷī). मराठीत पोळी म्हणजे flatbread (हिंदी: रोटी).',
    ),
    Exercise(
      id: 'ex_mr_matras_2',
      lessonId: 'mr_script_matras',
      type: ExerciseType.mcq,
      prompt: 'भाजी शब्दाचा अर्थ काय?',
      options: ['bread', 'vegetable', 'fruit', 'water'],
      correctIndex: 1,
      explanation:
          'भाजी (bhājī) = vegetable. हिंदीच्या सब्ज़ी च्या ऐवजी मराठीत भाजी वापरतात.',
    ),
    Exercise(
      id: 'ex_mr_matras_3',
      lessonId: 'mr_script_matras',
      type: ExerciseType.translation,
      prompt: 'Romanize: नमस्कार',
      acceptedAnswers: ['namaskār', 'namaskar', 'namaskaar'],
      explanation:
          'नमस्कार = namaskār. हा मराठीचा मुख्य अभिवादन आहे. हिंदी नमस्ते च्या ऐवजी मराठीत नमस्कार वापरतात.',
    ),
  ],

  'mr_script_barakhadi': const [
    Exercise(
      id: 'ex_mr_barakhadi_1',
      lessonId: 'mr_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'क + ा = ?',
      options: ['कि', 'का', 'के', 'को'],
      correctIndex: 1,
      explanation: 'क + ा (आ मात्रा) = का. आ मात्रा व्यंजनाच्या उजवीकडे येते.',
    ),
    Exercise(
      id: 'ex_mr_barakhadi_2',
      lessonId: 'mr_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: काळ',
      acceptedAnswers: ['kāḷ', 'kaal', 'kal'],
      explanation:
          'काळ = kāḷ (time). ळ मराठीचा विशेष ध्वनी आहे — retroflex lateral. हिंदीत काल (ळ नाही).',
    ),
    Exercise(
      id: 'ex_mr_barakhadi_3',
      lessonId: 'mr_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: शाळा',
      acceptedAnswers: ['shāḷā', 'shala', 'shaalaa'],
      explanation:
          'शाळा = shāḷā (school). ळ मराठीचा विशेष ध्वनी आहे. हिंदीत शाला (ळ नाही).',
    ),
  ],

  'mr_script_conjuncts': const [
    Exercise(
      id: 'ex_mr_conjuncts_1',
      lessonId: 'mr_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'नमस्कार शब्दात कोणता संयुक्त व्यंजन आहे?',
      options: ['क्ष', 'स्क', 'त्र', 'ज्ञ'],
      correctIndex: 1,
      explanation:
          'नमस्कार मध्ये स्क (स + ् + क) संयुक्त व्यंजन आहे. न + म + स + ् + क + ा + र = नमस्कार.',
    ),
    Exercise(
      id: 'ex_mr_conjuncts_2',
      lessonId: 'mr_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'मराठीत ज्ञ कसा उच्चारला जातो?',
      options: [
        '/gy/ (हिंदीसारखा)',
        '/dʒɲ/ (jñ)',
        '/ggyo/ (बंगालीसारखा)',
        '/ña/'
      ],
      correctIndex: 1,
      explanation:
          'मराठीत ज्ञ = /dʒɲ/ (jñ) — संस्कृत उच्चाराच्या जवळ. ज्ञान = jñān. हिंदीत ज्ञ = /gy/ (gyān).',
    ),
    Exercise(
      id: 'ex_mr_conjuncts_3',
      lessonId: 'mr_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'अन्न शब्दात कोणता चिन्ह आहे?',
      options: ['अनुस्वार (ं)', 'हलंत (्)', 'विसर्ग (ः)', 'चंद्रबिंदु (ँ)'],
      correctIndex: 1,
      explanation:
          'अन्न मध्ये हलंत (्) आहे — न + ् + न = न्न. हलंत पहिल्या व्यंजनाचा अ स्वर काढून टाकतो आणि दुसऱ्या व्यंजनाशी जोडतो.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_mr_greet)
  // ════════════════════════════════════════════════════════════════════

  'mr_greet_namaskar': const [
    Exercise(
      id: 'ex_mr_namaskar_1',
      lessonId: 'mr_greet_namaskar',
      type: ExerciseType.mcq,
      prompt: 'मराठीतील सर्वात सामान्य अभिवादन कोणते?',
      options: ['नमस्ते', 'नमस्कार', 'हाय', 'बाय'],
      correctIndex: 1,
      explanation:
          'नमस्कार हे मराठीतील सर्वात सामान्य अभिवादन आहे. हिंदी नमस्ते च्या ऐवजी मराठीत नमस्कार वापरतात (कार अंत).',
    ),
    Exercise(
      id: 'ex_mr_namaskar_2',
      lessonId: 'mr_greet_namaskar',
      type: ExerciseType.mcq,
      prompt: '"तुम्ही कसे आहात?" चा अर्थ काय?',
      options: [
        'What is your name?',
        'How are you? (respectful, to male)',
        'Where are you?',
        'Who are you?'
      ],
      correctIndex: 1,
      explanation:
          'तुम्ही कसे आहात? = How are you? (respectful, to male). तुम्ही = you (respectful), कसे = how, आहात = are.',
    ),
    Exercise(
      id: 'ex_mr_namaskar_3',
      lessonId: 'mr_greet_namaskar',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "you" चे किती स्तर आहेत?',
      options: ['2 (तू, तुम्ही)', '3 (तू, तुम्ही, आपण)', '1 (तू)', '4'],
      correctIndex: 1,
      explanation:
          'मराठीत 3 स्तर आहेत: तू (intimate), तुम्ही (familiar/respectful), आपण (very formal). हिंदीप्रमाणेच पण वेगळे शब्द.',
    ),
    Exercise(
      id: 'ex_mr_namaskar_4',
      lessonId: 'mr_greet_namaskar',
      type: ExerciseType.matching,
      prompt: 'अभिवादनांना अर्थांसोबत जोडा (Match greetings to meanings)',
      pairs: [
        (left: 'नमस्कार', right: 'Hello / Greetings'),
        (left: 'शुभ सकाळ', right: 'Good morning'),
        (left: 'शुभ रात्री', right: 'Good night'),
        (left: 'पुन्हा भेटूया', right: 'See you again'),
      ],
      explanation:
          'प्रत्येक अभिवादनाचा स्वतःचा अर्थ आणि वेळ आहे. नमस्कार सार्वत्रिक, शुभ सकाळ सकाळी, शुभ रात्री रात्री, पुन्हा भेटूया विदाईत.',
    ),
  ],

  'mr_greet_intro': const [
    Exercise(
      id: 'ex_mr_intro_1',
      lessonId: 'mr_greet_intro',
      type: ExerciseType.translation,
      prompt: 'Translate: माझं नाव राहुल आहे।',
      acceptedAnswers: [
        'My name is Rahul',
        'My name is Rahul.',
      ],
      explanation:
          'माझं नाव राहुल आहे = My name is Rahul. माझं = my (neuter, कारण नाव neuter), नाव = name, आहे = is.',
    ),
    Exercise(
      id: 'ex_mr_intro_2',
      lessonId: 'mr_greet_intro',
      type: ExerciseType.mcq,
      prompt: '"तुम्ही कोठून आहात?" चा अर्थ काय?',
      options: [
        'What is your name?',
        'Where are you from?',
        'How are you?',
        'When are you coming?'
      ],
      correctIndex: 1,
      explanation:
          'तुम्ही कोठून आहात? = Where are you from? कोठून = from where. -हून हा "from" चा मराठी postposition आहे (हिंदी से च्या ऐवजी).',
    ),
    Exercise(
      id: 'ex_mr_intro_3',
      lessonId: 'mr_greet_intro',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "I am a student" (male) कसं म्हणतात?',
      options: [
        'मी विद्यार्थी आहे।',
        'मी विद्यार्थिनी आहे।',
        'मी शिक्षक आहे।',
        'मी शिक्षिका आहे।'
      ],
      correctIndex: 0,
      explanation:
          'पुरुष student = विद्यार्थी (vidyārthī). स्त्री = विद्यार्थिनी (vidyārthinī). मी विद्यार्थी आहे = I am a student.',
    ),
  ],

  'mr_greet_family': const [
    Exercise(
      id: 'ex_mr_family_1',
      lessonId: 'mr_greet_family',
      type: ExerciseType.mcq,
      prompt: 'मराठीत आई चा अर्थ काय?',
      options: ['father', 'mother', 'sister', 'grandmother'],
      correctIndex: 1,
      explanation:
          'आई (āī) = mother. हा मराठीत "mother" साठी सर्वात सामान्य शब्द आहे — हिंदीच्या माँ पेक्षा वेगळा.',
    ),
    Exercise(
      id: 'ex_mr_family_2',
      lessonId: 'mr_greet_family',
      type: ExerciseType.mcq,
      prompt: 'मराठीत बाबा चा अर्थ काय?',
      options: ['mother', 'father', 'grandfather', 'uncle'],
      correctIndex: 1,
      explanation:
          'बाबा (bābā) = father (affectionate). वडील (vaḍīl) हे formal शब्द आहे. बाबा रोजच्या वापरात आहे.',
    ),
    Exercise(
      id: 'ex_mr_family_3',
      lessonId: 'mr_greet_family',
      type: ExerciseType.mcq,
      prompt: 'मराठीत grandfather ला काय म्हणतात?',
      options: ['दादा', 'आजोबा', 'नाना', 'काका'],
      correctIndex: 1,
      explanation:
          'मराठीत आजोबा (ājobā) = grandfather — both paternal and maternal. हिंदीत दादा/नाना असे वेगळे आहेत, पण मराठीत आजोबा दोन्हीसाठी.',
    ),
    Exercise(
      id: 'ex_mr_family_4',
      lessonId: 'mr_greet_family',
      type: ExerciseType.matching,
      prompt: 'कुटुंब शब्दांना अर्थांसोबत जोडा (Match kinship to meaning)',
      pairs: [
        (left: 'आई', right: 'mother'),
        (left: 'बाबा', right: 'father'),
        (left: 'आजी', right: 'grandmother'),
        (left: 'आजोबा', right: 'grandfather'),
      ],
      explanation:
          'मराठी कुटुंब शब्द हिंदीपेक्षा वेगळे आहेत: आई (mother, हिंदी: माँ), बाबा (father, हिंदी: पापा), आजी (grandmother, हिंदी: दादी/नानी).',
    ),
  ],

  'mr_greet_numbers': const [
    Exercise(
      id: 'ex_mr_numbers_1',
      lessonId: 'mr_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'मराठीत 6 ला काय म्हणतात?',
      options: ['छह', 'षण्ण', 'सहा', 'चह'],
      correctIndex: 1,
      explanation:
          'मराठीत 6 = षण्ण (ṣaṇṇ). हिंदीत छह. हा मराठीचा विशेष आकडा आहे — हिंदीपेक्षा पूर्ण वेगळा.',
    ),
    Exercise(
      id: 'ex_mr_numbers_2',
      lessonId: 'mr_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'मराठीत 100 ला काय म्हणतात?',
      options: ['सौ', 'शंभर', 'कोटी', 'लाख'],
      correctIndex: 1,
      explanation:
          'मराठीत 100 = शंभर (śambhar). हिंदीत सौ (sau). हा मराठीचा विशेष आकडा आहे.',
    ),
    Exercise(
      id: 'ex_mr_numbers_3',
      lessonId: 'mr_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'मराठीत 2 ला काय म्हणतात?',
      options: ['दो', 'दोन', 'दुई', 'द्वे'],
      correctIndex: 1,
      explanation: 'मराठीत 2 = दोन (don). हिंदीत दो (do). मराठीत -न अंत आहे.',
    ),
    Exercise(
      id: 'ex_mr_numbers_4',
      lessonId: 'mr_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'आकड्यांना मराठी नावांसोबत जोडा (Match numbers to Marathi names)',
      pairs: [
        (left: '5', right: 'पंच'),
        (left: '6', right: 'षण्ण'),
        (left: '10', right: 'दहा'),
        (left: '100', right: 'शंभर'),
      ],
      explanation:
          'मराठी आकडे हिंदीपेक्षा वेगळे: 5=पंच (हिंदी: पाँच), 6=षण्ण (हिंदी: छह), 10=दहा (हिंदी: दस), 100=शंभर (हिंदी: सौ).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_mr_daily)
  // ════════════════════════════════════════════════════════════════════

  'mr_daily_sentences': const [
    Exercise(
      id: 'ex_mr_sentences_1',
      lessonId: 'mr_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'मराठीत वाक्य रचनाचा क्रम काय?',
      options: ['SVO', 'SOV', 'VSO', 'OSV'],
      correctIndex: 1,
      explanation:
          'मराठीत Subject-Object-Verb (SOV) क्रम आहे — हिंदीप्रमाणेच. मी (S) भात (O) खातो (V).',
    ),
    Exercise(
      id: 'ex_mr_sentences_2',
      lessonId: 'mr_daily_sentences',
      type: ExerciseType.translation,
      prompt: 'Translate: मी भात खातो।',
      acceptedAnswers: [
        'I eat rice',
        'I eat rice.',
      ],
      explanation:
          'मी भात खातो = I eat rice (male speaker). मी भात खाते = female speaker. क्रिया लिंगानुसार बदलते.',
    ),
    Exercise(
      id: 'ex_mr_sentences_3',
      lessonId: 'mr_daily_sentences',
      type: ExerciseType.mcq,
      prompt: '"मी भात खाते" — हे कोण बोलेल?',
      options: ['पुरुष', 'स्त्री', 'दोन्ही', 'कोणीही नाही'],
      correctIndex: 1,
      explanation:
          'मी भात खाते = female speaker. पुरुष: मी भात खातो. क्रिया लिंगानुसार बदलते: -तो (male), -ते (female).',
    ),
  ],

  'mr_daily_questions': const [
    Exercise(
      id: 'ex_mr_questions_1',
      lessonId: 'mr_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"कोठे" चा अर्थ काय?',
      options: ['What', 'Who', 'Where', 'When'],
      correctIndex: 2,
      explanation:
          'कोठे (koṭhe) = where. उदा: तुम्ही कोठे जाता? = Where do you go?',
    ),
    Exercise(
      id: 'ex_mr_questions_2',
      lessonId: 'mr_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"कधी" चा अर्थ काय?',
      options: ['How', 'Why', 'What', 'When'],
      correctIndex: 3,
      explanation:
          'कधी (kadhī) = when. उदा: तुम्ही कधी येणार? = When will you come?',
    ),
    Exercise(
      id: 'ex_mr_questions_3',
      lessonId: 'mr_daily_questions',
      type: ExerciseType.translation,
      prompt: 'Translate: तुम्ही कोठून आहात?',
      acceptedAnswers: [
        'Where are you from',
        'Where are you from?',
      ],
      explanation:
          'तुम्ही कोठून आहात? = Where are you from? कोठून = from where. -हून हा "from" चा मराठी postposition आहे.',
    ),
  ],

  'mr_daily_negation': const [
    Exercise(
      id: 'ex_mr_negation_1',
      lessonId: 'mr_daily_negation',
      type: ExerciseType.mcq,
      prompt: 'मराठीत नाही कोठे येते?',
      options: [
        'क्रियापूर्व (हिंदीप्रमाणे)',
        'वाक्याच्या शेवटी (क्रियानंतर)',
        'वाक्याच्या सुरुवातीला',
        'कोठेही नाही',
      ],
      correctIndex: 1,
      explanation:
          'मराठीत नाही वाक्याच्या शेवटी येते: मी जात नाही. हिंदीत नहीं क्रियापूर्व येते: मैं नहीं जाता. ही गुरुत्वपूर्ण रचना फरक आहे.',
    ),
    Exercise(
      id: 'ex_mr_negation_2',
      lessonId: 'mr_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"चहा नको" चा अर्थ काय?',
      options: [
        'I don\'t drink tea',
        'I don\'t want tea',
        'Tea is not good',
        'No tea here',
      ],
      correctIndex: 1,
      explanation:
          'नको = don\'t want / don\'t need. चहा नको = I don\'t want tea. नको हा मराठीचा विशेष शब्द आहे — हिंदीत असा शब्द नाही.',
    ),
    Exercise(
      id: 'ex_mr_negation_3',
      lessonId: 'mr_daily_negation',
      type: ExerciseType.translation,
      prompt: 'Make negative: मी जातो।',
      acceptedAnswers: [
        'मी जात नाही',
        'मी जात नाही।',
      ],
      explanation:
          'मी जातो → मी जात नाही. नाही वाक्याच्या शेवटी येते (हिंदीपेक्षा वेगळे).',
    ),
    Exercise(
      id: 'ex_mr_negation_4',
      lessonId: 'mr_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"जाऊ नको!" चा अर्थ काय?',
      options: [
        'I am not going',
        'Don\'t go! (command)',
        'He is not going',
        'No going',
      ],
      correctIndex: 1,
      explanation:
          'जाऊ नको! = Don\'t go! (negative command). नको हा negative command साठी देखील वापरतात — हिंदीच्या मत च्या ऐवजी.',
    ),
  ],

  'mr_daily_routine': const [
    Exercise(
      id: 'ex_mr_routine_1',
      lessonId: 'mr_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"मी रोज सकाळी सहाला उठतो" — हे कोणते काळ?',
      options: ['भूत काळ', 'वर्तमान काळ', 'भविष्य काळ', 'आज्ञार्थ'],
      correctIndex: 1,
      explanation:
          'हे वर्तमान काळ आहे (present habitual). "रोज" (daily) दर्शवते की ही नियमित क्रिया आहे. उठतो = I wake up (regularly, male).',
    ),
    Exercise(
      id: 'ex_mr_routine_2',
      lessonId: 'mr_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"आंघोळ करणे" चा अर्थ काय?',
      options: ['To eat', 'To bathe', 'To sleep', 'To study'],
      correctIndex: 1,
      explanation:
          'आंघोळ करणे (ānghoḷ karaṇe) = to bathe. आंघोळ करतो = I bathe.',
    ),
    Exercise(
      id: 'ex_mr_routine_3',
      lessonId: 'mr_daily_routine',
      type: ExerciseType.matching,
      prompt: 'क्रियांना अर्थांसोबत जोडा (Match activities to meanings)',
      pairs: [
        (left: 'शाळेत जाणे', right: 'to go to school'),
        (left: 'भात खाणे', right: 'to eat rice'),
        (left: 'झोपणे', right: 'to sleep'),
        (left: 'अभ्यास करणे', right: 'to study'),
      ],
      explanation:
          'हे दैनंदिन जीवनातील मूलभूत क्रिया आहेत. शाळेत जाणे, भात खाणे, झोपणे, अभ्यास करणे.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_mr_grammar)
  // ════════════════════════════════════════════════════════════════════

  'mr_grammar_pronouns': const [
    Exercise(
      id: 'ex_mr_pronouns_1',
      lessonId: 'mr_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "you" चे किती स्तर आहेत?',
      options: ['2', '3 (तू, तुम्ही, आपण)', '1', '4'],
      correctIndex: 1,
      explanation:
          'मराठीत 3 स्तर आहेत: तू (intimate), तुम्ही (familiar/respectful), आपण (very formal). हिंदीप्रमाणेच पण वेगळे शब्द.',
    ),
    Exercise(
      id: 'ex_mr_pronouns_2',
      lessonId: 'mr_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: '"मला" कशाचे समतुल्य आहे?',
      options: ['मी + ला (to me)', 'तू + ला', 'तो + ला', 'आम्ही + ला'],
      correctIndex: 0,
      explanation:
          'मला = मी + ला (to me). उदा: मला चहा द्या (Give me tea). ला हा "to" चा मराठी postposition आहे.',
    ),
    Exercise(
      id: 'ex_mr_pronouns_3',
      lessonId: 'mr_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "ते" (te) काय दर्शवते?',
      options: [
        'केवळ पुरुष (he)',
        'केवळ स्त्री (she)',
        'neuter (it) किंवा plural (they)',
        'केवळ बहुवचन',
      ],
      correctIndex: 2,
      explanation:
          'ते (te) = it (neuter singular) किंवा they (plural). मराठीचे neuter लिंग हे विशेष आहे — हिंदीत नाही.',
    ),
  ],

  'mr_grammar_gender': const [
    Exercise(
      id: 'ex_mr_gender_1',
      lessonId: 'mr_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'मराठीत किती लिंग आहेत?',
      options: [
        '2 (masculine, feminine)',
        '3 (masculine, feminine, neuter)',
        '1',
        '4'
      ],
      correctIndex: 1,
      explanation:
          'मराठीत 3 लिंग आहेत: पुल्लिंग (masculine), स्त्रीलिंग (feminine), नपुंसकलिंग (neuter). हिंदीत फक्त 2 आहेत — neuter मराठीचे वैशिष्ट्य!',
    ),
    Exercise(
      id: 'ex_mr_gender_2',
      lessonId: 'mr_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "पुस्तक" कोणत्या लिंगात आहे?',
      options: [
        'पुल्लिंग (masculine)',
        'स्त्रीलिंग (feminine)',
        'नपुंसकलिंग (neuter)'
      ],
      correctIndex: 2,
      explanation:
          'मराठीत पुस्तक = नपुंसकलिंग (neuter)! हिंदीत पुस्तक = स्त्रीलिंग. हा मराठीचा मोठा फरक आहे — हिंदी शिकणाऱ्यांना हे नवीन शिकावे लागते.',
    ),
    Exercise(
      id: 'ex_mr_gender_3',
      lessonId: 'mr_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'मराठीत "घर" कोणत्या लिंगात आहे?',
      options: ['पुल्लिंग', 'स्त्रीलिंग', 'नपुंसकलिंग'],
      correctIndex: 2,
      explanation:
          'मराठीत घर = नपुंसकलिंग (neuter)! हिंदीत घर = पुल्लिंग. हा मराठीचा वैशिष्ट्य आहे — अनेक हिंदी masculine/feminine शब्द मराठीत neuter आहेत.',
    ),
    Exercise(
      id: 'ex_mr_gender_4',
      lessonId: 'mr_grammar_gender',
      type: ExerciseType.matching,
      prompt:
          'संज्ञांना त्यांच्या मराठी लिंगांसोबत जोडा (Match nouns to Marathi genders)',
      pairs: [
        (left: 'मुलगा (boy)', right: 'पुल्लिंग'),
        (left: 'मुलगी (girl)', right: 'स्त्रीलिंग'),
        (left: 'पुस्तक (book)', right: 'नपुंसकलिंग'),
        (left: 'घर (house)', right: 'नपुंसकलिंग'),
      ],
      explanation:
          'मराठीत 3 लिंग आहेत. मुलगा=पुरुष, मुलगी=स्त्री, पुस्तक आणि घर=नपुंसक. नपुंसकलिंग हे मराठीचे वैशिष्ट्य आहे — हिंदीत नाही.',
    ),
  ],

  'mr_grammar_tenses': const [
    Exercise(
      id: 'ex_mr_tenses_1',
      lessonId: 'mr_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"मी गेलो" — हे कोणते काळ?',
      options: ['वर्तमान', 'भूत', 'भविष्य', 'आज्ञार्थ'],
      correctIndex: 1,
      explanation:
          'मी गेलो = I went (past, male). भूत काळात -लो (-lo) अंत पुरुष पहिल्या पुरुषात. वर्तमान: मी जातो, भविष्य: मी जेन.',
    ),
    Exercise(
      id: 'ex_mr_tenses_2',
      lessonId: 'mr_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"मी जेन" — हे कोणते काळ?',
      options: ['वर्तमान', 'भूत', 'भविष्य', 'हाल'],
      correctIndex: 2,
      explanation:
          'मी जेन = I will go (future). -एन (-en) हा भविष्य काळाचा पहिला पुरुष अंत आहे.',
    ),
    Exercise(
      id: 'ex_mr_tenses_3',
      lessonId: 'mr_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'मराठीत हिंदीच्या ने चिन्हाचे समतुल्य आहे का?',
      options: [
        'नाही, ने चिन्ह नाही',
        'होय, ने आहे (त्याने)',
        'फक्त भूत काळात',
        'फक्त भविष्य काळात',
      ],
      correctIndex: 1,
      explanation:
          'मराठीत ने आहे — त्याने (he, agent), तिने (she, agent), मीने (I, agent). हे भूत काळात सकर्मक क्रियांच्या कर्त्यासोबत वापरतात.',
    ),
  ],

  'mr_grammar_postpositions': const [
    Exercise(
      id: 'ex_mr_post_1',
      lessonId: 'mr_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"घरामध्ये" चा अर्थ काय?',
      options: [
        'on the house',
        'in the house',
        'from the house',
        'to the house'
      ],
      correctIndex: 1,
      explanation:
          'मध्ये (madhye) = in/inside. घरामध्ये = in the house. postposition संज्ञानंतर येते.',
    ),
    Exercise(
      id: 'ex_mr_post_2',
      lessonId: 'mr_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"मुंबईहून" चा अर्थ काय?',
      options: ['to Mumbai', 'in Mumbai', 'from Mumbai', 'near Mumbai'],
      correctIndex: 2,
      explanation:
          'हून (hūn) = from. मुंबईहून = from Mumbai. हिंदीच्या से च्या ऐवजी मराठीत हून.',
    ),
    Exercise(
      id: 'ex_mr_post_3',
      lessonId: 'mr_grammar_postpositions',
      type: ExerciseType.translation,
      prompt: 'Translate: टेबलावर',
      acceptedAnswers: [
        'on the table',
        'On the table',
      ],
      explanation:
          'टेबलावर = on the table. वर (var) = on. टेबल + वर = on the table.',
    ),
    Exercise(
      id: 'ex_mr_post_4',
      lessonId: 'mr_grammar_postpositions',
      type: ExerciseType.matching,
      prompt:
          'Postpositions ना अर्थांसोबत जोडा (Match postpositions to meanings)',
      pairs: [
        (left: 'मध्ये', right: 'in'),
        (left: 'वर', right: 'on'),
        (left: 'हून', right: 'from'),
        (left: 'ला', right: 'to'),
      ],
      explanation:
          'मध्ये=in, वर=on, हून=from, ला=to. हे चार मूलभूत postpositions मराठीत सर्वात जास्त वापरले जातात.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_mr_reading)
  // ════════════════════════════════════════════════════════════════════

  'mr_reading_conversation': const [
    Exercise(
      id: 'ex_mr_conv_1',
      lessonId: 'mr_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"भाऊ, बटाटे कितीला?" — हे कोणत्या परिस्थितीत बोलले जाते?',
      options: [
        'मित्राशी भेटताना',
        'भाजी खरेदी करताना दुकानदाराशी',
        'घरी स्वयंपाक करताना',
        'रेस्टॉरंटमध्ये ऑर्डर करताना',
      ],
      correctIndex: 1,
      explanation:
          'भाऊ (brother) हे दुकानदाराला संबोधित करण्याचा मार्ग आहे. बटाटे कितीला? = How much are the potatoes? बाजारात दरदाम अपेक्षित.',
    ),
    Exercise(
      id: 'ex_mr_conv_2',
      lessonId: 'mr_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"चलूया" चा अर्थ काय?',
      options: [
        'Let\'s walk',
        'Shall we go?',
        'Are you walking?',
        'Walk!',
      ],
      correctIndex: 1,
      explanation:
          'चलूया (chalūyā) = Shall we go? / Let\'s go. शिरडीला चलूया? = Shall we go to Shirdi? हा सुचना देण्याचा मराठी मार्ग आहे.',
    ),
    Exercise(
      id: 'ex_mr_conv_3',
      lessonId: 'mr_reading_conversation',
      type: ExerciseType.translation,
      prompt: 'Translate: सकाळी सहाला भेटूया।',
      acceptedAnswers: [
        'See you at six in the morning',
        'See you at 6 AM',
        'Let\'s meet at six in the morning',
      ],
      explanation:
          'सकाळी सहाला भेटूया = See you at six in the morning / Let\'s meet at six. भेटूया = let\'s meet.',
    ),
  ],

  'mr_reading_paragraph': const [
    Exercise(
      id: 'ex_mr_para_1',
      lessonId: 'mr_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 1 नुसार मुंबईला काय म्हणतात?',
      options: [
        'हरित नगरी',
        'आर्थिक राजधानी',
        'सफेद नगरी',
        'नील नगरी',
      ],
      correctIndex: 1,
      explanation:
          'Passage 1 म्हणते: "मुंबईला आर्थिक राजधानी देखील म्हणतात." कारण हे भारताचे आर्थिक केंद्र आहे.',
    ),
    Exercise(
      id: 'ex_mr_para_2',
      lessonId: 'mr_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 2 नुसार गणेशोत्सव कोणत्या महिन्यात असतो?',
      options: ['चैत्र', 'भाद्रपद', 'कार्तिक', 'माघ'],
      correctIndex: 1,
      explanation:
          'Passage 2 म्हणते: "भाद्रपद महिन्यात हा सण साजरा केला जातो." भाद्रपद हा हिंदू कॅलेंडरमधील एक महिना आहे (सप्टेंबर-ऑक्टोबर).',
    ),
    Exercise(
      id: 'ex_mr_para_3',
      lessonId: 'mr_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 3 नुसार मराठी जेवणाचे मुख्य पदार्थ काय?',
      options: ['रोटी', 'भात आणि भाकरी', 'पाव', 'नान'],
      correctIndex: 1,
      explanation:
          'Passage 3 म्हणते: "भात आणि भाकरी हे मराठी जेवणाचे मुख्य पदार्थ आहेत." भाकरी हे मराठी वैशिष्ट्य आहे — हिंदी रोटी च्या ऐवजी.',
    ),
  ],

  'mr_reading_review': const [
    Exercise(
      id: 'ex_mr_review_1',
      lessonId: 'mr_reading_review',
      type: ExerciseType.mcq,
      prompt: 'मराठीत वाक्य रचनेचा क्रम काय?',
      options: ['SVO', 'SOV', 'VSO', 'OVS'],
      correctIndex: 1,
      explanation:
          'Subject-Object-Verb (SOV). मी (S) भात (O) खातो (V). हा मराठीतील सर्वात महत्त्वाचा व्याकरण नियम आहे.',
    ),
    Exercise(
      id: 'ex_mr_review_2',
      lessonId: 'mr_reading_review',
      type: ExerciseType.mcq,
      prompt: 'मराठीचे सर्वात मोठे वैशिष्ट्य काय हिंदीपेक्षा?',
      options: [
        '3 लिंग (neuter सहित)',
        'कोणतेही काळ नाही',
        'कोणतेही postposition नाही',
        'कोणतेही सर्वनाम नाही',
      ],
      correctIndex: 0,
      explanation:
          'मराठीत 3 लिंग आहेत (पुल्लिंग, स्त्रीलिंग, नपुंसकलिंग). हिंदीत फक्त 2. neuter हे मराठीचे वैशिष्ट्य आहे — पुस्तक, घर, पाणी हे सर्व neuter आहेत.',
    ),
    Exercise(
      id: 'ex_mr_review_3',
      lessonId: 'mr_reading_review',
      type: ExerciseType.mcq,
      prompt: 'मराठीचा विशेष ध्वनी कोणता हिंदीत नाही?',
      options: ['ल', 'ळ (ḷ)', 'श', 'क'],
      correctIndex: 1,
      explanation:
          'ळ (ḷ) — retroflex lateral — हा मराठीचा विशेष ध्वनी आहे जो हिंदीत नाही. काळ (time), फळ (fruit), शाळा (school) मध्ये हा ध्वनी आहे.',
    ),
    Exercise(
      id: 'ex_mr_review_4',
      lessonId: 'mr_reading_review',
      type: ExerciseType.translation,
      prompt: 'Translate: माझं नाव _____ आहे।',
      acceptedAnswers: [
        'My name is _____',
      ],
      explanation:
          'माझं नाव _____ आहे = My name is _____. हा बेसिक परिचय वाक्य आहे जो प्रत्येक मराठी शिकणारा जाणतो.',
    ),
  ],
};
