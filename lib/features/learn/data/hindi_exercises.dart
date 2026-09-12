/// Hindi Exercises — VaaniX Learn Mode Part A
///
/// Practice exercises for the Hindi curriculum (assets/curriculum/learn/hi.json).
/// Keyed by lesson id; the engine ([exercise_models.dart]) renders them
/// deterministically. Each lesson has 3–4 exercises covering MCQ,
/// fillBlank, ordering, translation, and matching types.
///
/// Content note: every exercise is grounded in the actual lesson content.
/// Hindi examples are natural (not machine-translated). Explanations
/// teach WHY an answer is correct or wrong, per the VaaniX feedback
/// quality standard.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Hindi exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `hi_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode curriculum.
final Map<String, List<Exercise>> hindiExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Devanagari Script (ch_hi_script)
  // ════════════════════════════════════════════════════════════════════

  'hi_script_vowels': const [
    Exercise(
      id: 'ex_hi_vowels_1',
      lessonId: 'hi_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'हिन्दी में कितने स्वर (vowels) हैं?',
      options: ['10', '11', '13', '20'],
      correctIndex: 1,
      explanation:
          'हिन्दी में 11 स्वर हैं: अ आ इ ई उ ऊ ए ऐ ओ औ और ऋ। ऋ मुख्य रूप से संस्कृत के शब्दों में आता है।',
    ),
    Exercise(
      id: 'ex_hi_vowels_2',
      lessonId: 'hi_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'इनमें से कौन सा लंबा स्वर है?',
      options: ['अ', 'आ', 'इ', 'उ'],
      correctIndex: 1,
      explanation:
          'आ (ā) एक लंबा स्वर है। लंबे स्वरों में ऊर्ध्वाधर रेखा (ा) होती है जो छोटे स्वरों में नहीं होती।',
    ),
    Exercise(
      id: 'ex_hi_vowels_3',
      lessonId: 'hi_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'आम शब्द में कौन सा स्वर है?',
      options: ['अ', 'आ', 'इ', 'ई'],
      correctIndex: 1,
      explanation:
          'आम (ām) में आ स्वर है। आ की मात्रा ा है जो क के साथ का बनाती है।',
    ),
    Exercise(
      id: 'ex_hi_vowels_4',
      lessonId: 'hi_script_vowels',
      type: ExerciseType.matching,
      prompt: 'स्वर को उदाहरण से मिलाएँ (Match vowel to example word)',
      pairs: [
        (left: 'अ', right: 'अनार'),
        (left: 'आ', right: 'आम'),
        (left: 'इ', right: 'इमली'),
        (left: 'ई', right: 'ईख'),
      ],
      explanation:
          'हर स्वर का अपना उदाहरण शब्द है। अनार में अ, आम में आ, इमली में इ, और ईख में ई स्वर है।',
    ),
  ],

  'hi_script_consonants': const [
    Exercise(
      id: 'ex_hi_consonants_1',
      lessonId: 'hi_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'इनमें से कौन सा व्यंजन क-वर्ग (velar) से है?',
      options: ['च', 'क', 'त', 'प'],
      correctIndex: 1,
      explanation:
          'क क-वर्ग से है — यह गले के पीछे उत्पन्न होता है। क-वर्ग में क ख ग घ ङ आते हैं।',
    ),
    Exercise(
      id: 'ex_hi_consonants_2',
      lessonId: 'hi_script_consonants',
      type: ExerciseType.mcq,
      prompt:
          '\u092E\u0939\u093E\u092A\u094D\u0930\u093E\u0923 (aspirated) \u0935\u094D\u092F\u0902\u091C\u0928 \u0915\u094C\u0928 \u0938\u093E \u0939\u0948?',
      options: const ['\u0915', '\u0916', '\u0917', '\u0918'],
      correctIndex: 1,
      explanation:
          "\u0916 (kha) \u092E\u0939\u093E\u092A\u094D\u0930\u093E\u0923 \u0939\u0948 — \u0907\u0938\u092E\u0947\u0902 '\u0915' \u0915\u0940 \u0927\u094D\u0935\u0928\u093F \u0915\u0947 \u0938\u093E\u0925 \u0939\u0935\u093E \u0915\u093E \u091D\u094B\u0902\u0915\u093E \u0939\u094B\u0924\u093E \u0939\u0948\u0964 \u0915\u092A\u0921\u093C\u0947 \u0915\u093E \u091F\u0947\u0938\u094D\u091F: \u0915 \u0938\u0947 \u0915\u092A\u0921\u093C\u093E \u0928\u0939\u0940\u0902 \u0939\u093F\u0932\u0924\u093E, \u0916 \u0938\u0947 \u0939\u093F\u0932\u0924\u093E \u0939\u0948\u0964",
    ),
    Exercise(
      id: 'ex_hi_consonants_3',
      lessonId: 'hi_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'घोड़ा शब्द में कौन सा व्यंजन नहीं है?',
      options: ['घ', 'र', 'ड', 'क'],
      correctIndex: 3,
      explanation:
          'घोड़ा में घ, र, ड, और आ (मात्रा) हैं। क इस शब्द में नहीं है।',
    ),
  ],

  'hi_script_matras': const [
    Exercise(
      id: 'ex_hi_matras_1',
      lessonId: 'hi_script_matras',
      type: ExerciseType.mcq,
      prompt: 'कि में कौन सी मात्रा है?',
      options: ['ी (ई)', 'ि (इ)', 'ु (उ)', 'े (ए)'],
      correctIndex: 1,
      explanation:
          'कि में इ की मात्रा (ि) है। यह एकमात्र मात्रा है जो व्यंजन के बाईं ओर जाती है, पर व्यंजन के बाद पढ़ी जाती है।',
    ),
    Exercise(
      id: 'ex_hi_matras_2',
      lessonId: 'hi_script_matras',
      type: ExerciseType.mcq,
      prompt: 'कू कौन सी मात्रा बनाती है?',
      options: ['ु (उ)', 'ू (ऊ)', 'े (ए)', 'ी (ई)'],
      correctIndex: 1,
      explanation:
          'कू में ऊ की मात्रा (ू) है — लंबी ऊर्ध्वाधर रेखा। छोटी रेखा (ु) उ की मात्रा है, बड़ी रेखा (ू) ऊ की।',
    ),
    Exercise(
      id: 'ex_hi_matras_3',
      lessonId: 'hi_script_matras',
      type: ExerciseType.matching,
      prompt: 'मात्रा को संयोजन से मिलाएँ (Match matra to result)',
      pairs: [
        (left: 'क + ा', right: 'का'),
        (left: 'क + ी', right: 'की'),
        (left: 'क + ो', right: 'को'),
        (left: 'क + े', right: 'के'),
      ],
      explanation:
          'हर मात्रा व्यंजन के साथ मिलकर एक नया संयोजन बनाती है। ा से का, ी से की, ो से को, े से के।',
    ),
  ],

  'hi_script_barakhadi': const [
    Exercise(
      id: 'ex_hi_barakhadi_1',
      lessonId: 'hi_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'बारहखड़ी किसे कहते हैं?',
      options: [
        'एक व्यंजन के साथ सभी स्वरों का संयोजन',
        'बारह व्यंजनों की सूची',
        'बारह शब्दों का समूह',
        'बारह वाक्यों का अभ्यास',
      ],
      correctIndex: 0,
      explanation:
          'बारहखड़ी एक व्यंजन के साथ सभी स्वरों (ग्यारह स्वर + मूल अ) के संयोजन को कहते हैं। यह पढ़ना सीखने का आधार है।',
    ),
    Exercise(
      id: 'ex_hi_barakhadi_2',
      lessonId: 'hi_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'म + ा = ?',
      options: ['मि', 'मा', 'मे', 'मो'],
      correctIndex: 1,
      explanation:
          'म + ा (आ की मात्रा) = मा। आ की मात्रा व्यंजन के बाद आती है।',
    ),
    Exercise(
      id: 'ex_hi_barakhadi_3',
      lessonId: 'hi_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: मकान',
      acceptedAnswers: ['makān', 'makan', 'makaan'],
      explanation:
          'मकान = म + क + ा + न = ma-kā-na = makān (house). आ की मात्रा के साथ क → का।',
    ),
    Exercise(
      id: 'ex_hi_barakhadi_4',
      lessonId: 'hi_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: दीवार',
      acceptedAnswers: ['dīvār', 'divar', 'deewar', 'divaar'],
      explanation:
          'दीवार = द + ी + व + ा + र = dī-vā-ra = dīvār (wall). ी से दी, ा से वा।',
    ),
  ],

  'hi_script_conjuncts': const [
    Exercise(
      id: 'ex_hi_conjuncts_1',
      lessonId: 'hi_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'हिन्दी शब्द में कौन सा संयुक्त व्यंजन है?',
      options: ['क्ष', 'त्र', 'न्द', 'ज्ञ'],
      correctIndex: 2,
      explanation:
          'हिन्दी में न्द (न + ् + द) संयुक्त व्यंजन है। ह + ि + न + ् + द + ी = हिन्दी।',
    ),
    Exercise(
      id: 'ex_hi_conjuncts_2',
      lessonId: 'hi_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'त्र किन दो व्यंजनों से बनता है?',
      options: ['त + र', 'ट + र', 'त + ड', 'त + य'],
      correctIndex: 0,
      explanation:
          'त्र = त + ् + र। हलंत (्) पहले व्यंजन का अ स्वर हटा देता है।',
    ),
    Exercise(
      id: 'ex_hi_conjuncts_3',
      lessonId: 'hi_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'ं (बिंदु / anusvara) का क्या काम है?',
      options: [
        'स्वर को लंबा करता है',
        'अगले व्यंजन को नाक से उच्चारित कराता है',
        'वाक्य को समाप्त करता है',
        'शब्द को बहुवचन बनाता है',
      ],
      correctIndex: 1,
      explanation:
          'ं (अनुस्वार) अगले व्यंजन को नासिक्य (nasal) बनाता है। जैसे संस्कृत में ं से पहले वाला स्वर नाक से बोला जाता है।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_hi_greet)
  // ════════════════════════════════════════════════════════════════════

  'hi_greet_namaste': const [
    Exercise(
      id: 'ex_hi_namaste_1',
      lessonId: 'hi_greet_namaste',
      type: ExerciseType.mcq,
      prompt: 'सबसे आम हिन्दी अभिवादन क्या है?',
      options: ['सुप्रभात', 'नमस्ते', 'अलविदा', 'धन्यवाद'],
      correctIndex: 1,
      explanation:
          'नमस्ते सबसे आम अभिवादन है। इसका अर्थ है "मैं आपको नमन करता हूँ"। इसे किसी भी समय, किसी के साथ भी इस्तेमाल किया जा सकता है।',
    ),
    Exercise(
      id: 'ex_hi_namaste_2',
      lessonId: 'hi_greet_namaste',
      type: ExerciseType.mcq,
      prompt: 'बुज़ुर्गों को सम्मान देने के लिए नमस्ते के साथ क्या जोड़ें?',
      options: ['जी', 'जीना', 'नहीं', 'हाँ'],
      correctIndex: 0,
      explanation:
          'जी (jī) सम्मान का चिह्न है। नमस्ते जी कहना बुज़ुर्गों या शिक्षकों के लिए उपयुक्त है।',
    ),
    Exercise(
      id: 'ex_hi_namaste_3',
      lessonId: 'hi_greet_namaste',
      type: ExerciseType.mcq,
      prompt: '"आप कैसे हैं?" का अर्थ क्या है?',
      options: [
        'What is your name?',
        'How are you?',
        'Where are you?',
        'Who are you?'
      ],
      correctIndex: 1,
      explanation:
          'आप कैसे हैं? = How are you? (respectful)। आप = you (respectful), कैसे = how, हैं = are।',
    ),
    Exercise(
      id: 'ex_hi_namaste_4',
      lessonId: 'hi_greet_namaste',
      type: ExerciseType.matching,
      prompt: 'अभिवादन को अर्थ से मिलाएँ (Match greeting to meaning)',
      pairs: [
        (left: 'नमस्ते', right: 'Hello / Greetings'),
        (left: 'सुप्रभात', right: 'Good morning'),
        (left: 'शुभ रात्रि', right: 'Good night'),
        (left: 'फिर मिलेंगे', right: 'See you again'),
      ],
      explanation:
          'हर अभिवादन का अपना अर्थ और समय है। नमस्ते सार्वभौमिक है, सुप्रभात सुबह, शुभ रात्रि रात, फिर मिलेंगे विदाई के समय।',
    ),
  ],

  'hi_greet_intro': const [
    Exercise(
      id: 'ex_hi_intro_1',
      lessonId: 'hi_greet_intro',
      type: ExerciseType.translation,
      prompt: 'Translate: मेरा नाम राहुल है।',
      acceptedAnswers: [
        'My name is Rahul',
        'My name is Rahul.',
      ],
      explanation:
          'मेरा नाम राहुल है = My name is Rahul। मेरा = my, नाम = name, है = is। SOV क्रम।',
    ),
    Exercise(
      id: 'ex_hi_intro_2',
      lessonId: 'hi_greet_intro',
      type: ExerciseType.mcq,
      prompt: '"आप कहाँ से हैं?" का अर्थ क्या है?',
      options: [
        'What is your name?',
        'Where are you from?',
        'How are you?',
        'When are you coming?'
      ],
      correctIndex: 1,
      explanation:
          'आप कहाँ से हैं? = Where are you from?। कहाँ = where, से = from। से postposition स्थान के बाद आता है।',
    ),
    Exercise(
      id: 'ex_hi_intro_3',
      lessonId: 'hi_greet_intro',
      type: ExerciseType.mcq,
      prompt: 'एक पुरुष छात्र खुद को कैसे परिचित करेगा?',
      options: [
        'मैं छात्रा हूँ।',
        'मैं छात्र हूँ।',
        'मैं शिक्षिका हूँ।',
        'मैं शिक्षक हूँ।'
      ],
      correctIndex: 1,
      explanation:
          'पुरुष छात्र = छात्र (chātr)। स्त्री = छात्रा (chātrā)। शिक्षक = teacher (पुरुष), शिक्षिका = teacher (स्त्री)।',
    ),
  ],

  'hi_greet_family': const [
    Exercise(
      id: 'ex_hi_family_1',
      lessonId: 'hi_greet_family',
      type: ExerciseType.mcq,
      prompt: 'माता के पिता को हिन्दी में क्या कहते हैं?',
      options: ['दादा', 'नाना', 'चाचा', 'मामा'],
      correctIndex: 1,
      explanation:
          'माता के पिता = नाना (nānā)। पिता के पिता = दादा (dādā)। हिन्दी में माता और पिता के पक्ष के रिश्तेदारों के अलग-अलग नाम हैं।',
    ),
    Exercise(
      id: 'ex_hi_family_2',
      lessonId: 'hi_greet_family',
      type: ExerciseType.mcq,
      prompt: '"मेरे दो भाई हैं" का अर्थ क्या है?',
      options: [
        'I have two sisters',
        'I have two brothers',
        'I have two sons',
        'I have two fathers',
      ],
      correctIndex: 1,
      explanation:
          'मेरे दो भाई हैं = I have two brothers। भाई = brother, दो = two। "मेरे" बहुवचन पुरुष संज्ञा के पहले आता है।',
    ),
    Exercise(
      id: 'ex_hi_family_3',
      lessonId: 'hi_greet_family',
      type: ExerciseType.matching,
      prompt: 'रिश्ता को अर्थ से मिलाएँ (Match kinship to meaning)',
      pairs: [
        (left: 'दादी', right: "father's mother"),
        (left: 'नानी', right: "mother's mother"),
        (left: 'चाचा', right: "father's younger brother"),
        (left: 'मामा', right: "mother's brother"),
      ],
      explanation:
          'हिन्दी रिश्ते बहुत विशिष्ट होते हैं। दादी = पिता की माँ, नानी = माता की माँ, चाचा = पिता का छोटा भाई, मामा = माता का भाई।',
    ),
  ],

  'hi_greet_numbers': const [
    Exercise(
      id: 'ex_hi_numbers_1',
      lessonId: 'hi_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'हिन्दी में 5 क्या है?',
      options: ['चार', 'पाँच', 'छह', 'सात'],
      correctIndex: 1,
      explanation: '5 = पाँच (pā̃c)। 4 = चार, 6 = छह।',
    ),
    Exercise(
      id: 'ex_hi_numbers_2',
      lessonId: 'hi_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'बीस कितना होता है?',
      options: ['12', '15', '20', '25'],
      correctIndex: 2,
      explanation: 'बीस (bīs) = 20। 12 = बारह, 15 = पंद्रह, 25 = पच्चीस।',
    ),
    Exercise(
      id: 'ex_hi_numbers_3',
      lessonId: 'hi_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'अंक को हिन्दी नाम से मिलाएँ (Match number to Hindi name)',
      pairs: [
        (left: '1', right: 'एक'),
        (left: '3', right: 'तीन'),
        (left: '7', right: 'सात'),
        (left: '10', right: 'दस'),
      ],
      explanation:
          'एक=1, तीन=3, सात=7, दस=10। ये आधारभूत संख्याएँ हैं जिन्हें हर हिन्दी सीखने वाले को याद रखना चाहिए।',
    ),
    Exercise(
      id: 'ex_hi_numbers_4',
      lessonId: 'hi_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'लाख कितना होता है?',
      options: ['1,000', '10,000', '100,000', '1,000,000'],
      correctIndex: 2,
      explanation:
          'लाख (lākh) = 100,000 (एक लाख)। करोड़ (karoṛ) = 10,000,000 (एक करोड़)। ये दक्षिण एशियाई संख्या प्रणाली के विशिष्ट शब्द हैं।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_hi_daily)
  // ════════════════════════════════════════════════════════════════════

  'hi_daily_sentences': const [
    Exercise(
      id: 'ex_hi_sentences_1',
      lessonId: 'hi_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'हिन्दी वाक्यों में वाक्य रचना का क्रम क्या है?',
      options: ['SVO', 'SOV', 'VSO', 'OSV'],
      correctIndex: 1,
      explanation:
          'हिन्दी में Subject-Object-Verb (SOV) क्रम है। जैसे: मैं (S) किताब (O) पढ़ता हूँ (V)। अंग्रेज़ी SVO है।',
    ),
    Exercise(
      id: 'ex_hi_sentences_2',
      lessonId: 'hi_daily_sentences',
      type: ExerciseType.translation,
      prompt: 'Translate: मैं चावल खाता हूँ।',
      acceptedAnswers: [
        'I eat rice',
        'I eat rice.',
      ],
      explanation:
          'मैं चावल खाता हूँ = I eat rice। SOV क्रम: मैं (I) चावल (rice) खाता हूँ (eat)।',
    ),
    Exercise(
      id: 'ex_hi_sentences_3',
      lessonId: 'hi_daily_sentences',
      type: ExerciseType.mcq,
      prompt: '"वह डॉक्टर है" का अर्थ क्या है?',
      options: [
        'He is a doctor',
        'She is a doctor',
        'He/She is a doctor',
        'They are doctors'
      ],
      correctIndex: 2,
      explanation:
          'वह डॉक्टर है = He/She is a doctor। हिन्दी में वह पुरुष और स्त्री दोनों के लिए इस्तेमाल होता है — संदर्भ से पता चलता है।',
    ),
  ],

  'hi_daily_questions': const [
    Exercise(
      id: 'ex_hi_questions_1',
      lessonId: 'hi_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"कहाँ" का अर्थ क्या है?',
      options: ['What', 'Who', 'Where', 'When'],
      correctIndex: 2,
      explanation:
          'कहाँ (kahā̃) = where। जैसे: आप कहाँ जाते हैं? = Where do you go?',
    ),
    Exercise(
      id: 'ex_hi_questions_2',
      lessonId: 'hi_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"क्यों" का अर्थ क्या है?',
      options: ['How', 'Why', 'What', 'Who'],
      correctIndex: 1,
      explanation:
          'क्यों (kyõ) = why। जवाब आमतौर पर क्योंकि (because) से शुरू होता है।',
    ),
    Exercise(
      id: 'ex_hi_questions_3',
      lessonId: 'hi_daily_questions',
      type: ExerciseType.translation,
      prompt: 'Translate: आप कहाँ से हैं?',
      acceptedAnswers: [
        'Where are you from',
        'Where are you from?',
      ],
      explanation:
          'आप कहाँ से हैं? = Where are you from?। कहाँ = where, से = from। से postposition स्थान के बाद।',
    ),
  ],

  'hi_daily_negation': const [
    Exercise(
      id: 'ex_hi_negation_1',
      lessonId: 'hi_daily_negation',
      type: ExerciseType.mcq,
      prompt:
          'मानक निषेध (standard negation) के लिए कौन सा शब्द इस्तेमाल होता है?',
      options: ['नहीं', 'न', 'मत', 'नहीं तो'],
      correctIndex: 0,
      explanation:
          'नहीं (nahī̃) सबसे आम निषेध शब्द है। यह क्रिया से ठीक पहले आता है: मैं नहीं जाता।',
    ),
    Exercise(
      id: 'ex_hi_negation_2',
      lessonId: 'hi_daily_negation',
      type: ExerciseType.mcq,
      prompt: 'नकारात्मक आदेश (negative command) के लिए क्या इस्तेमाल होता है?',
      options: ['नहीं', 'न', 'मत', 'कभी नहीं'],
      correctIndex: 2,
      explanation:
          'मत (mat) नकारात्मक आदेश के लिए है। जैसे: रोना मत! (Don\'t cry!)। यह क्रिया के बाद या पहले आ सकता है।',
    ),
    Exercise(
      id: 'ex_hi_negation_3',
      lessonId: 'hi_daily_negation',
      type: ExerciseType.translation,
      prompt: 'Make negative: मैं जाता हूँ।',
      acceptedAnswers: [
        'मैं नहीं जाता',
        'मैं नहीं जाता।',
        'मैं नहीं जाता हूँ',
        'मैं नहीं जाता हूँ।',
      ],
      explanation:
          'मैं जाता हूँ → मैं नहीं जाता। नहीं क्रिया से पहले आता है। वाक्यांश में हूँ अक्सर छोड़ दिया जाता है।',
    ),
  ],

  'hi_daily_routine': const [
    Exercise(
      id: 'ex_hi_routine_1',
      lessonId: 'hi_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"मैं रोज़ सुबह छह बजे उठता हूँ" — इसमें कौन सा काल है?',
      options: ['भूत काल', 'वर्तमान काल', 'भविष्य काल', 'कोई नहीं'],
      correctIndex: 1,
      explanation:
          'यह वर्तमान काल (present habitual) है। "रोज़" (daily) बताता है कि यह नियमित क्रिया है। उठता हूँ = I wake up (regularly)।',
    ),
    Exercise(
      id: 'ex_hi_routine_2',
      lessonId: 'hi_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"नहाना" का अर्थ क्या है?',
      options: ['To eat', 'To bathe', 'To sleep', 'To study'],
      correctIndex: 1,
      explanation: 'नहाना (nahānā) = to bathe। नहाता हूँ = I bathe।',
    ),
    Exercise(
      id: 'ex_hi_routine_3',
      lessonId: 'hi_daily_routine',
      type: ExerciseType.matching,
      prompt: 'क्रिया को अर्थ से मिलाएँ (Match activity to meaning)',
      pairs: [
        (left: 'स्कूल जाना', right: 'to go to school'),
        (left: 'खाना खाना', right: 'to eat food'),
        (left: 'सोना', right: 'to sleep'),
        (left: 'पढ़ाई करना', right: 'to study'),
      ],
      explanation:
          'ये दैनिक जीवन की बुनियादी क्रियाएँ हैं। स्कूल जाना, खाना खाना, सोना, पढ़ाई करना — हर एक का अपना क्रियापद है।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_hi_grammar)
  // ════════════════════════════════════════════════════════════════════

  'hi_grammar_pronouns': const [
    Exercise(
      id: 'ex_hi_pronouns_1',
      lessonId: 'hi_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'सम्मानजनक "आप" के साथ कौन सी क्रिया आती है?',
      options: ['हूँ', 'हो', 'हैं', 'है'],
      correctIndex: 2,
      explanation:
          'आप के साथ हैं (hain) आता है — बहुवचन/सम्मानजनक रूप। आप शिक्षक हैं। = You (resp.) are a teacher.',
    ),
    Exercise(
      id: 'ex_hi_pronouns_2',
      lessonId: 'hi_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: '"मुझे" किनके बराबर है?',
      options: ['मैं + को', 'तुम + को', 'वह + को', 'हम + को'],
      correctIndex: 0,
      explanation:
          'मुझे = मैं + को (to me)। मैं का oblique रूप मुझ है, + को = मुझे। जैसे: मुझे चाय दो (Give me tea)।',
    ),
    Exercise(
      id: 'ex_hi_pronouns_3',
      lessonId: 'hi_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'नज़दीक वाली चीज़ के लिए कौन सा सर्वनाम है?',
      options: ['वह', 'यह', 'वे', 'ये'],
      correctIndex: 1,
      explanation:
          'यह (yah/ye) = this (near)। वह (vah/vo) = that (far)। यह किताब = this book (near me)।',
    ),
    Exercise(
      id: 'ex_hi_pronouns_4',
      lessonId: 'hi_grammar_pronouns',
      type: ExerciseType.translation,
      prompt: 'Translate: मेरा भाई डॉक्टर है।',
      acceptedAnswers: [
        'My brother is a doctor',
        'My brother is a doctor.',
      ],
      explanation:
          'मेरा भाई डॉक्टर है = My brother is a doctor। मेरा = my (masc.), भाई = brother, डॉक्टर = doctor, है = is।',
    ),
  ],

  'hi_grammar_gender': const [
    Exercise(
      id: 'ex_hi_gender_1',
      lessonId: 'hi_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'लड़की का लिंग क्या है?',
      options: ['पुरुष (masculine)', 'स्त्री (feminine)'],
      correctIndex: 1,
      explanation:
          'लड़की (laṛkī) स्त्रीलिंग है। -ी अंत वाले शब्द आमतौर पर स्त्रीलिंग होते हैं। लड़का = boy (पुरुष)।',
    ),
    Exercise(
      id: 'ex_hi_gender_2',
      lessonId: 'hi_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'लड़का का बहुवचन क्या है?',
      options: ['लड़का', 'लड़के', 'लड़कियाँ', 'लड़कों'],
      correctIndex: 1,
      explanation:
          'लड़का → लड़के (बहुवचन)। -आ अंत वाले पुरुष शब्द -े में बदलते हैं: लड़का → लड़के, कमरा → कमरे।',
    ),
    Exercise(
      id: 'ex_hi_gender_3',
      lessonId: 'hi_grammar_gender',
      type: ExerciseType.mcq,
      prompt: 'किताब का लिंग क्या है?',
      options: ['पुरुष', 'स्त्री'],
      correctIndex: 1,
      explanation:
          'किताब (kitāb) स्त्रीलिंग है — हालांकि -ी अंत नहीं है। यह अरबी/फ़ारसी मूल का शब्द है। लिंग याद रखना पड़ता है।',
    ),
    Exercise(
      id: 'ex_hi_gender_4',
      lessonId: 'hi_grammar_gender',
      type: ExerciseType.matching,
      prompt: 'संज्ञा को लिंग से मिलाएँ (Match noun to gender)',
      pairs: [
        (left: 'घर', right: 'पुरुष'),
        (left: 'सड़क', right: 'स्त्री'),
        (left: 'दरवाज़ा', right: 'पुरुष'),
        (left: 'किताब', right: 'स्त्री'),
      ],
      explanation:
          'घर (m), सड़क (f), दरवाज़ा (m, -आ अंत), किताब (f, अरबी मूल)। लिंग हमेशा अंत से नहीं बजता — याद रखें।',
    ),
  ],

  'hi_grammar_tenses': const [
    Exercise(
      id: 'ex_hi_tenses_1',
      lessonId: 'hi_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"मैं गया था" — यह कौन सा काल है?',
      options: ['वर्तमान', 'भूत', 'भविष्य', 'आज्ञार्थ'],
      correctIndex: 1,
      explanation:
          'मैं गया था = I went (past tense)। भूत काल में क्रिया था/थी/थे के साथ आती है।',
    ),
    Exercise(
      id: 'ex_hi_tenses_2',
      lessonId: 'hi_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"मैं जाऊँगा" — यह कौन सा काल है?',
      options: ['वर्तमान', 'भूत', 'भविष्य', 'हाल'],
      correctIndex: 2,
      explanation:
          'मैं जाऊँगा = I will go (future)। -ऊँगा/-एगा अंत भविष्य काल का संकेत है।',
    ),
    Exercise(
      id: 'ex_hi_tenses_3',
      lessonId: 'hi_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'सकर्मक क्रिया (transitive verb) के भूत काल में क्या जोड़ते हैं?',
      options: ['को', 'से', 'ने', 'में'],
      correctIndex: 2,
      explanation:
          'सकर्मक क्रिया के भूत काल में कर्ता के बाद ने लगता है: मैंने खाया (I ate), उसने पढ़ा (She read)।',
    ),
    Exercise(
      id: 'ex_hi_tenses_4',
      lessonId: 'hi_grammar_tenses',
      type: ExerciseType.translation,
      prompt: 'Future tense: मैं जाता हूँ।',
      acceptedAnswers: [
        'मैं जाऊँगा',
        'मैं जाऊँगा।',
      ],
      explanation:
          'वर्तमान: मैं जाता हूँ → भविष्य: मैं जाऊँगा (I will go)। -ता हूँ → -ऊँगा।',
    ),
  ],

  'hi_grammar_postpositions': const [
    Exercise(
      id: 'ex_hi_post_1',
      lessonId: 'hi_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"घर में" का अर्थ क्या है?',
      options: [
        'on the house',
        'in the house',
        'from the house',
        'to the house'
      ],
      correctIndex: 1,
      explanation:
          'में (mein) = in/inside। घर में = in the house। postposition संज्ञा के बाद आती है।',
    ),
    Exercise(
      id: 'ex_hi_post_2',
      lessonId: 'hi_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"दिल्ली से" का अर्थ क्या है?',
      options: ['to Delhi', 'in Delhi', 'from Delhi', 'near Delhi'],
      correctIndex: 2,
      explanation:
          'से (se) = from। दिल्ली से = from Delhi। से के कई अर्थ हैं: from, with, by।',
    ),
    Exercise(
      id: 'ex_hi_post_3',
      lessonId: 'hi_grammar_postpositions',
      type: ExerciseType.translation,
      prompt: 'Translate: मेज़ पर',
      acceptedAnswers: [
        'on the table',
        'On the table',
      ],
      explanation:
          'मेज़ पर = on the table। पर (par) = on/at। मेज़ (table) + पर = on the table।',
    ),
    Exercise(
      id: 'ex_hi_post_4',
      lessonId: 'hi_grammar_postpositions',
      type: ExerciseType.matching,
      prompt: 'Postposition को अर्थ से मिलाएँ (Match postposition to meaning)',
      pairs: [
        (left: 'में', right: 'in'),
        (left: 'पर', right: 'on'),
        (left: 'से', right: 'from'),
        (left: 'को', right: 'to'),
      ],
      explanation:
          'में = in, पर = on, से = from, को = to। ये चार बुनियादी postpositions हैं जो हिन्दी वाक्यों में सबसे ज़्यादा आती हैं।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_hi_reading)
  // ════════════════════════════════════════════════════════════════════

  'hi_reading_conversation': const [
    Exercise(
      id: 'ex_hi_conv_1',
      lessonId: 'hi_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"भैया, टमाटर कैसे दिए?" — यह किस स्थिति में बोला जाता है?',
      options: [
        'किसी दोस्त से मिलते समय',
        'सब्ज़ी खरीदते समय दुकानदार से',
        'घर पर खाना बनाते समय',
        'रेस्तराँ में ऑर्डर करते समय',
      ],
      correctIndex: 1,
      explanation:
          'भैया (brother) दुकानदार को संबोधित करने का तरीका है। टमाटर कैसे दिए? = How much are the tomatoes? बाज़ार में सौदा होता है।',
    ),
    Exercise(
      id: 'ex_hi_conv_2',
      lessonId: 'hi_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"चलें?" का अर्थ क्या है संवाद में?',
      options: ['Let\'s walk', 'Shall we go?', 'Are you walking?', 'Walk!'],
      correctIndex: 1,
      explanation:
          'चलें? (chalen?) = Shall we go? / Let\'s go — सुझाव देने का तरीका। आगरा चलें? = Shall we go to Agra?',
    ),
    Exercise(
      id: 'ex_hi_conv_3',
      lessonId: 'hi_reading_conversation',
      type: ExerciseType.translation,
      prompt: 'Translate: सुबह छह बजे मिलते हैं।',
      acceptedAnswers: [
        'See you at six in the morning',
        'We will meet at six in the morning',
        'See you at 6 AM',
      ],
      explanation:
          'सुबह छह बजे मिलते हैं = See you at six in the morning। मिलते हैं = we will meet (future habitual)।',
    ),
  ],

  'hi_reading_paragraph': const [
    Exercise(
      id: 'ex_hi_para_1',
      lessonId: 'hi_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'जयपुर को क्या कहा जाता है passage 1 में?',
      options: ['हरा नगर', 'गुलाबी नगर', 'सफ़ेद नगर', 'नीला नगर'],
      correctIndex: 1,
      explanation:
          'जयपुर को "गुलाबी नगरी" कहा जाता है क्योंकि वहाँ की इमारतों का रंग गुलाबी है। Pink City = गुलाबी नगर।',
    ),
    Exercise(
      id: 'ex_hi_para_2',
      lessonId: 'hi_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'भारत किस चीज़ का देश है passage 2 के अनुसार?',
      options: ['नदियों', 'त्योहारों', 'पहाड़ों', 'मंदिरों'],
      correctIndex: 1,
      explanation:
          'Passage 2 कहता है: "भारत त्योहारों का देश है।" हर महीने कोई त्योहार आता है — दिवाली, होली, ईद, क्रिसमस।',
    ),
    Exercise(
      id: 'ex_hi_para_3',
      lessonId: 'hi_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'दक्षिण भारत में क्या खाते हैं passage 3 के अनुसार?',
      options: ['रोटी-दाल', 'डोसा-सांभर', 'मछली-चावल', 'ढबकरा-धोकला'],
      correctIndex: 1,
      explanation:
          'Passage 3 कहता है: "दक्षिण में डोसा-सांभर।" उत्तर = रोटी-दाल, पूर्व = मछली-चावल, पश्चिम = ढबकरा-धोकला।',
    ),
  ],

  'hi_reading_review': const [
    Exercise(
      id: 'ex_hi_review_1',
      lessonId: 'hi_reading_review',
      type: ExerciseType.mcq,
      prompt: 'हिन्दी वाक्य रचना का क्रम क्या है?',
      options: ['SVO', 'SOV', 'VSO', 'OVS'],
      correctIndex: 1,
      explanation:
          'Subject-Object-Verb (SOV)। मैं (S) किताब (O) पढ़ता हूँ (V)। यह हिन्दी की सबसे महत्वपूर्ण वाक्य रचना है।',
    ),
    Exercise(
      id: 'ex_hi_review_2',
      lessonId: 'hi_reading_review',
      type: ExerciseType.mcq,
      prompt: 'मानक निषेध के लिए कौन सा शब्द?',
      options: ['नहीं', 'मत', 'न', 'कभी'],
      correctIndex: 0,
      explanation: 'नहीं (nahī̃) मानक निषेध है। क्रिया से पहले: मैं नहीं जाता।',
    ),
    Exercise(
      id: 'ex_hi_review_3',
      lessonId: 'hi_reading_review',
      type: ExerciseType.mcq,
      prompt: '"मैंने खाया" में ने क्यों है?',
      options: [
        'क्योंकि खाना transitive है',
        'क्योंकि यह वर्तमान काल है',
        'क्योंकि मैं सम्मानजनक है',
        'क्योंकि खाना intransitive है',
      ],
      correctIndex: 0,
      explanation:
          'खाना (to eat) सकर्मक (transitive) है, इसलिए भूत काल में ने लगता है: मैंने खाया = I ate।',
    ),
    Exercise(
      id: 'ex_hi_review_4',
      lessonId: 'hi_reading_review',
      type: ExerciseType.translation,
      prompt: 'Translate: मेरा नाम _____ है।',
      acceptedAnswers: [
        'My name is _____',
      ],
      explanation:
          'मेरा नाम _____ है = My name is _____। यह बुनियादी परिचय वाक्य है जो हर हिन्दी सीखने वाला जानता है।',
    ),
  ],
};
