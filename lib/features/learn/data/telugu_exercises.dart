/// Telugu Exercises — VaaniX Learn Mode Part D
///
/// Practice exercises for the Telugu curriculum
/// (assets/curriculum/learn/te.json). Keyed by lesson id. Each lesson
/// has 3-4 exercises covering MCQ, fillBlank, matching, and translation.
///
/// Content note: every exercise is grounded in the actual lesson content.
/// Telugu examples are natural (not machine-translated). Telugu-specific
/// features (Dravidian grammar, no grammatical gender, older/younger
/// sibling distinction, -కి/-నుండి/-లో postpositions) are tested.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Telugu exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `te_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode curriculum.
final Map<String, List<Exercise>> teluguExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Telugu Script (ch_te_script)
  // ════════════════════════════════════════════════════════════════════

  'te_script_vowels': const [
    Exercise(
      id: 'ex_te_vowels_1',
      lessonId: 'te_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'తెలుగు ఏ లిపిని ఉపయోగిస్తుంది?',
      options: ['దేవనాగరి', 'తెలుగు లిపి', 'బెంగాలి', 'గుర్ముఖి'],
      correctIndex: 1,
      explanation:
          'తెలుగు తెలుగు లిపిని ఉపయోగిస్తుంది — ఇది దేవనాగరి (హిందీ) మరియు బెంగాలి నుండి భిన్నం. తెలుగు లిపి గుండ్రని ఆకారాలతో ఉంటుంది.',
    ),
    Exercise(
      id: 'ex_te_vowels_2',
      lessonId: 'te_script_vowels',
      type: ExerciseType.mcq,
      prompt: '"అన్నం" అంటే ఏమిటి?',
      options: ['water', 'rice', 'bread', 'fruit'],
      correctIndex: 1,
      explanation:
          'అన్నం (annaṃ) = rice (cooked). ఇది తెలుగు వారి ప్రధాన ఆహారం. హిందీ చావల్/భात మరియు బెంగాలి ভাত నుండి భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_vowels_3',
      lessonId: 'te_script_vowels',
      type: ExerciseType.matching,
      prompt: 'స్వరాలను ఉదాహరణ పదాలతో జతచేయండి (Match vowels to example words)',
      pairs: [
        (left: 'అ', right: 'అన్నం'),
        (left: 'ఆ', right: 'ఆమ'),
        (left: 'ఇ', right: 'ఇల్లు'),
        (left: 'ఉ', right: 'ఉప్పు'),
      ],
      explanation:
          'ప్రతి స్వరానికి దాని స్వంత ఉదాహరణ పదం ఉంది. అన్నం లో అ, ఆమ లో ఆ, ఇల్లు లో ఇ, ఉప్పు లో ఉ.',
    ),
  ],

  'te_script_consonants': const [
    Exercise(
      id: 'ex_te_consonants_1',
      lessonId: 'te_script_consonants',
      type: ExerciseType.mcq,
      prompt: '"డబ్బు" అంటే ఏమిటి?',
      options: ['house', 'money', 'book', 'water'],
      correctIndex: 1,
      explanation:
          'డబ్బు (dabbu) = money. ఇది తెలుగులో అనౌపచారిక పదం కానీ చాలా సాధారణం. అధికారిక పదం ధనం.',
    ),
    Exercise(
      id: 'ex_te_consonants_2',
      lessonId: 'te_script_consonants',
      type: ExerciseType.mcq,
      prompt: '"చేప" అంటే ఏమిటి?',
      options: ['meat', 'fish', 'egg', 'milk'],
      correctIndex: 1,
      explanation:
          'చేప (chēpa) = fish. తెలుగు వంటలో చేప ముఖ్యమైన భాగం, ముఖ్యంగా కోస్తా ప్రాంతంలో.',
    ),
    Exercise(
      id: 'ex_te_consonants_3',
      lessonId: 'te_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో ళ (ḷa) ధ్వని ఉందా?',
      options: [
        'లేదు, తెలుగులో ళ లేదు',
        'ఉంది — ళ ఉంది (మారాఠీ, తమిళం లాగా)',
        'కేవలం సంస్కృత పదాలలో',
        'కేవలం ఆంగ్ల పదాలలో',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో ళ (ḷa) ఉంది — retroflex lateral. ఇది మారాఠీ, తమిళం, మలయాళం లలో కూడా ఉంది, కానీ హిందీ/బెంగాలి లో లేదు.',
    ),
  ],

  'te_script_matras': const [
    Exercise(
      id: 'ex_te_matras_1',
      lessonId: 'te_script_matras',
      type: ExerciseType.mcq,
      prompt: '"అమ్మ" పదంలో ఏ మాత్ర ఉంది?',
      options: ['ా (ఆ)', 'ి (ఇ)', 'ు (ఉ)', 'ే (ఏ)'],
      correctIndex: 0,
      explanation:
          'అమ్మ లో ఆ మాత్ర (ా) ఉంది — అ + మ + ్మ = am-ma. ఆ మాత్ర మ తరువాత వస్తుంది.',
    ),
    Exercise(
      id: 'ex_te_matras_2',
      lessonId: 'te_script_matras',
      type: ExerciseType.mcq,
      prompt: '"అమ్మ" అంటే ఏమిటి?',
      options: ['father', 'mother', 'sister', 'grandmother'],
      correctIndex: 1,
      explanation:
          'అమ్మ (amma) = mother. ఇది తెలుగులో "mother" కోసం సాధారణ పదం — హిందీ మाँ నుండి భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_matras_3',
      lessonId: 'te_script_matras',
      type: ExerciseType.translation,
      prompt: 'Romanize: నమస్తే',
      acceptedAnswers: ['namastē', 'namaste', 'namasthe'],
      explanation:
          'నమస్తే = namastē. ఇది తెలుగులో సాధారణ అభివాదన. అధికారిక రూపం నమస్కారం.',
    ),
  ],

  'te_script_barakhadi': const [
    Exercise(
      id: 'ex_te_barakhadi_1',
      lessonId: 'te_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'క + ా = ?',
      options: ['కి', 'కా', 'కే', 'కొ'],
      correctIndex: 1,
      explanation: 'క + ా (ఆ మాత్ర) = కా. ఆ మాత్ర వ్యంజనం తరువాత వస్తుంది.',
    ),
    Exercise(
      id: 'ex_te_barakhadi_2',
      lessonId: 'te_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: అన్నం',
      acceptedAnswers: ['annaṃ', 'annam', 'annam'],
      explanation:
          'అన్నం = annaṃ (rice). అ + న + ్న + ం = an-naṃ. న + ్న ద్విగుణ న.',
    ),
    Exercise(
      id: 'ex_te_barakhadi_3',
      lessonId: 'te_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: నీళ్లు',
      acceptedAnswers: ['nīllu', 'nillu', 'neellu'],
      explanation:
          'నీళ్లు = nīllu (water). న + ీ + ళ + ్ల + ు = nīl-lu. తెలుగులో water కోసం పదం.',
    ),
  ],

  'te_script_conjuncts': const [
    Exercise(
      id: 'ex_te_conjuncts_1',
      lessonId: 'te_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'అన్నం పదంలో ఏ సంయుక్త వ్యంజనం ఉంది?',
      options: ['క్ష', 'న్న', 'త్ర', 'జ్ఞ'],
      correctIndex: 1,
      explanation:
          'అన్నం లో న్న (న + ్ + న) సంయుక్త వ్యంజనం ఉంది. అ + న + ్న + ం = అన్నం.',
    ),
    Exercise(
      id: 'ex_te_conjuncts_2',
      lessonId: 'te_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో జ్ఞ ఎలా ఉచ్చరిస్తారు?',
      options: [
        '/gy/ (హిందీ లాగా)',
        '/dʒɲ/ (jñ)',
        '/ggyo/ (బెంగాలి లాగా)',
        '/ña/'
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో జ్ఞ = /dʒɲ/ (jñ) — సంస్కృత ఉచ్చారణ దగ్గరగా. జ్ఞానం = jñānaṃ. హిందీలో /gy/ (gyān).',
    ),
    Exercise(
      id: 'ex_te_conjuncts_3',
      lessonId: 'te_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'పుస్తకం పదంలో ఏ సంయుక్త వ్యంజనం ఉంది?',
      options: ['క్ష', 'స్త', 'త్ర', 'జ్ఞ'],
      correctIndex: 1,
      explanation:
          'పుస్తకం లో స్త (స + ్ + త) సంయుక్త వ్యంజనం ఉంది. ప + ు + స + ్త + క + ం = పుస్తకం (pustakaṃ).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_te_greet)
  // ════════════════════════════════════════════════════════════════════

  'te_greet_namaste': const [
    Exercise(
      id: 'ex_te_namaste_1',
      lessonId: 'te_greet_namaste',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో అత్యంత సాధారణ అభివాదన ఏది?',
      options: ['నమస్కారం', 'నమస్తే', 'హాయ్', 'బై'],
      correctIndex: 1,
      explanation:
          'నమస్తే (namastē) అత్యంత సాధారణ తెలుగు అభివాదన. అధికారిక సందర్భాలలో నమస్కారం వాడతారు.',
    ),
    Exercise(
      id: 'ex_te_namaste_2',
      lessonId: 'te_greet_namaste',
      type: ExerciseType.mcq,
      prompt: '"మీరు ఎలా ఉన్నారు?" అంటే ఏమిటి?',
      options: [
        'What is your name?',
        'How are you? (respectful)',
        'Where are you?',
        'Who are you?'
      ],
      correctIndex: 1,
      explanation:
          'మీరు ఎలా ఉన్నారు? = How are you? (respectful). మీరు = you (respectful), ఎలా = how, ఉన్నారు = are.',
    ),
    Exercise(
      id: 'ex_te_namaste_3',
      lessonId: 'te_greet_namaste',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో "you" కి ఎన్ని స్థాయిలు ఉన్నాయి?',
      options: ['2', '3 (నువ్వు, మీరు, మీ)', '1', '4'],
      correctIndex: 0,
      explanation:
          'తెలుగులో 2 స్థాయిలు: నువ్వు (informal), మీరు (respectful/plural). హిందీలో 3 (तू/तुम/आप), మారాఠీలో 3 (तू/तुम्ही/आपण).',
    ),
    Exercise(
      id: 'ex_te_namaste_4',
      lessonId: 'te_greet_namaste',
      type: ExerciseType.matching,
      prompt: 'అభివాదనలను అర్థాలతో జతచేయండి (Match greetings to meanings)',
      pairs: [
        (left: 'నమస్తే', right: 'Hello (informal)'),
        (left: 'నమస్కారం', right: 'Greetings (formal)'),
        (left: 'శుభోదయం', right: 'Good morning'),
        (left: 'శుభరాత్రి', right: 'Good night'),
      ],
      explanation:
          'ప్రతి అభివాదనకు దాని స్వంత అర్థం మరియు సమయం ఉంది. నమస్తే సాధారణ, నమస్కారం అధికారిక.',
    ),
  ],

  'te_greet_intro': const [
    Exercise(
      id: 'ex_te_intro_1',
      lessonId: 'te_greet_intro',
      type: ExerciseType.translation,
      prompt: 'Translate: నా పేరు రాహుల్।',
      acceptedAnswers: [
        'My name is Rahul',
        'My name is Rahul.',
      ],
      explanation:
          'నా పేరు రాహుల్ = My name is Rahul. నా = my, పేరు = name. హిందీ मेरा नाम కి బదులుగా తెలుగులో నా పేరు.',
    ),
    Exercise(
      id: 'ex_te_intro_2',
      lessonId: 'te_greet_intro',
      type: ExerciseType.mcq,
      prompt: '"మీరు ఎక్కడ నుండి వచ్చారు?" అంటే ఏమిటి?',
      options: [
        'What is your name?',
        'Where are you from?',
        'How are you?',
        'When are you coming?'
      ],
      correctIndex: 1,
      explanation:
          'మీరు ఎక్కడ నుండి వచ్చారు? = Where are you from? ఎక్కడ = where, నుండి = from. -నుండి తెలుగు "from" postposition.',
    ),
    Exercise(
      id: 'ex_te_intro_3',
      lessonId: 'te_greet_intro',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో "I am a student" ఎలా చెప్పాలి?',
      options: [
        'నేను విద్యార్థిని।',
        'నేను విద్యార్థినిని।',
        'నేను ఉపాధ్యాయుడిని।',
        'నేను డాక్టర్.'
      ],
      correctIndex: 0,
      explanation:
          'నేను విద్యార్థిని = I am a student. గమనిక: తెలుగులో క్రియ లింగం ప్రకారం మారదు — నేను విద్యార్థిని అన్ని వక్తలకు ఒకే.',
    ),
  ],

  'te_greet_family': const [
    Exercise(
      id: 'ex_te_family_1',
      lessonId: 'te_greet_family',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో "అన్న" అంటే ఏమిటి?',
      options: ['younger brother', 'older brother', 'father', 'uncle'],
      correctIndex: 1,
      explanation:
          'అన్న (anna) = older brother. తెలుగులో పెద్ద/చిన్న తేడా ఉంది: అన్న (older), తమ్ముడు (younger). హిందీలో భాఈ అందరికీ.',
    ),
    Exercise(
      id: 'ex_te_family_2',
      lessonId: 'te_greet_family',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో "అక్క" అంటే ఏమిటి?',
      options: ['younger sister', 'older sister', 'mother', 'aunt'],
      correctIndex: 1,
      explanation:
          'అక్క (akka) = older sister. తెలుగులో: అక్క (older), చెల్లెలు (younger). పెద్ద/చిన్న తేడా దక్షిణ భారతీయ విశిష్టత.',
    ),
    Exercise(
      id: 'ex_te_family_3',
      lessonId: 'te_greet_family',
      type: ExerciseType.matching,
      prompt: 'కుటుంబ పదాలను అర్థాలతో జతచేయండి (Match kinship to meaning)',
      pairs: [
        (left: 'అమ్మ', right: 'mother'),
        (left: 'నాన్న', right: 'father'),
        (left: 'అన్న', right: 'older brother'),
        (left: 'అక్క', right: 'older sister'),
      ],
      explanation:
          'తెలుగు కుటుంబ పదాలు హిందీ నుండి భిన్నం: అమ్మ (mother, హిందీ माँ), నాన్న (father, హిందీ पापा), అన్న (older brother, హిందీ भाई).',
    ),
  ],

  'te_greet_numbers': const [
    Exercise(
      id: 'ex_te_numbers_1',
      lessonId: 'te_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో 5 ని ఏమని అంటారు?',
      options: ['ఐదు', 'పంచ', 'పాంచ్', 'ఐద్'],
      correctIndex: 0,
      explanation:
          'తెలుగులో 5 = ఐదు (aidu). హిందీ పाँच, మారాఠీ पंच, బెంగాలి পাঁচ — అన్నీ భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_numbers_2',
      lessonId: 'te_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో 10 ని ఏమని అంటారు?',
      options: ['దశ', 'పది', 'దహా', 'దస్'],
      correctIndex: 1,
      explanation:
          'తెలుగులో 10 = పది (padi). హిందీ दस, మారాఠీ दहा, బెంగాలి दश — అన్నీ భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_numbers_3',
      lessonId: 'te_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో 100 ని ఏమని అంటారు?',
      options: ['సౌ', 'శంభర్', 'వంద', 'శత'],
      correctIndex: 2,
      explanation:
          'తెలుగులో 100 = వంద (vaṃda). హిందీ सौ, మారాఠీ शंभर్ — అన్నీ భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_numbers_4',
      lessonId: 'te_greet_numbers',
      type: ExerciseType.matching,
      prompt:
          'సంఖ్యలను తెలుగు పేర్లతో జతచేయండి (Match numbers to Telugu names)',
      pairs: [
        (left: '1', right: 'ఒకటి'),
        (left: '5', right: 'ఐదు'),
        (left: '10', right: 'పది'),
        (left: '100', right: 'వంద'),
      ],
      explanation:
          'తెలుగు సంఖ్యలు హిందీ నుండి పూర్తిగా భిన్నం: 1=ఒకటి, 5=ఐదు, 10=పది, 100=వంద.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_te_daily)
  // ════════════════════════════════════════════════════════════════════

  'te_daily_sentences': const [
    Exercise(
      id: 'ex_te_sentences_1',
      lessonId: 'te_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో వాక్య క్రమం ఏమిటి?',
      options: ['SVO', 'SOV', 'VSO', 'OSV'],
      correctIndex: 1,
      explanation:
          'తెలుగులో Subject-Object-Verb (SOV) క్రమం — హిందీ, బెంగాలి, మారాఠీ లాగా. నేను (S) అన్నం (O) తింటాను (V).',
    ),
    Exercise(
      id: 'ex_te_sentences_2',
      lessonId: 'te_daily_sentences',
      type: ExerciseType.translation,
      prompt: 'Translate: నేను అన్నం తింటాను।',
      acceptedAnswers: [
        'I eat rice',
        'I eat rice.',
      ],
      explanation:
          'నేను అన్నం తింటాను = I eat rice. SOV: నేను (I) అన్నం (rice) తింటాను (eat). అన్నం = cooked rice (హిందీ चावल).',
    ),
    Exercise(
      id: 'ex_te_sentences_3',
      lessonId: 'te_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో క్రియ లింగం ప్రకారం మారుతుందా?',
      options: [
        'అవును, హిందీ లాగా',
        'లేదు — క్రియ లింగ-నిరపేక్ష',
        'కేవలం వర్తమాన కాలంలో',
        'కేవలం భూత కాలంలో',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో క్రియ లింగ-నిరపేక్ష! నేను వెళ్తాను = I go — ఏ వక్త అయినా ఒకే. ఇది ద్రావిడ భాషా విశిష్టత (బెంగాలి లాగా, హిందీ/మారాఠీ కాదు).',
    ),
  ],

  'te_daily_questions': const [
    Exercise(
      id: 'ex_te_questions_1',
      lessonId: 'te_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"ఎక్కడ" అంటే ఏమిటి?',
      options: ['What', 'Who', 'Where', 'When'],
      correctIndex: 2,
      explanation:
          'ఎక్కడ (ekkaḍa) = where. ఉదా: మీరు ఎక్కడ వెళ్తారు? = Where do you go?',
    ),
    Exercise(
      id: 'ex_te_questions_2',
      lessonId: 'te_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"ఎందుకు" అంటే ఏమిటి?',
      options: ['How', 'Why', 'What', 'Who'],
      correctIndex: 1,
      explanation:
          'ఎందుకు (eṃduku) = why. సమాధానం సాధారణంగా ఎందుకంటే (because) తో మొదలవుతుంది.',
    ),
    Exercise(
      id: 'ex_te_questions_3',
      lessonId: 'te_daily_questions',
      type: ExerciseType.translation,
      prompt: 'Translate: మీరు ఎక్కడ నుండి వచ్చారు?',
      acceptedAnswers: [
        'Where have you come from',
        'Where have you come from?',
        'Where are you from',
      ],
      explanation:
          'మీరు ఎక్కడ నుండి వచ్చారు? = Where have you come from? ఎక్కడ = where, నుండి = from.',
    ),
  ],

  'te_daily_negation': const [
    Exercise(
      id: 'ex_te_negation_1',
      lessonId: 'te_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"నేను డాక్టర్ కాదు" అంటే ఏమిటి?',
      options: [
        'I am a doctor',
        'I am not a doctor',
        'I want to be a doctor',
        'Where is the doctor',
      ],
      correctIndex: 1,
      explanation:
          'కాదు (kādu) = "is not". నేను డాక్టర్ కాదు = I am not a doctor. కాదు సమీకరణ వాక్యాలలో "to be" ని నిషేధిస్తుంది.',
    ),
    Exercise(
      id: 'ex_te_negation_2',
      lessonId: 'te_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"వెళ్ళ వద్దు!" అంటే ఏమిటి?',
      options: [
        'I am not going',
        'Don\'t go! (command)',
        'He is not going',
        'No going',
      ],
      correctIndex: 1,
      explanation:
          'వద్దు (vaddu) = don\'t! (negative command). వెళ్ళ వద్దు! = Don\'t go! హిందీ మत (mat) కి సమానం కానీ పదం భిన్నం.',
    ),
    Exercise(
      id: 'ex_te_negation_3',
      lessonId: 'te_daily_negation',
      type: ExerciseType.translation,
      prompt: 'Make negative: నేను వెళ్తాను।',
      acceptedAnswers: [
        'నేను వెళ్ళ లేదు',
        'నేను వెళ్ళ లేదు।',
      ],
      explanation:
          'నేను వెళ్తాను → నేను వెళ్ళ లేదు. లేదు (lēdu) క్రియ నిషేధానికి వాడతారు.',
    ),
  ],

  'te_daily_routine': const [
    Exercise(
      id: 'ex_te_routine_1',
      lessonId: 'te_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"నేను రోజు ఉదయం ఆరు గంటలకు లేస్తాను" — ఇది ఏ కాలం?',
      options: ['భూత కాలం', 'వర్తమాన కాలం', 'భవిష్యత్ కాలం', 'ఆజ్ఞార్థ'],
      correctIndex: 1,
      explanation:
          'ఇది వర్తమాన కాలం (present habitual). "రోజు" (daily) చూపిస్తుంది ఇది క్రమం తప్పక క్రియ. లేస్తాను = I wake up.',
    ),
    Exercise(
      id: 'ex_te_routine_2',
      lessonId: 'te_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"స్నానం చేయడం" అంటే ఏమిటి?',
      options: ['To eat', 'To bathe', 'To sleep', 'To study'],
      correctIndex: 1,
      explanation:
          'స్నానం చేయడం (snānaṃ cēyaḍaṃ) = to bathe. స్నానం చేస్తాను = I bathe.',
    ),
    Exercise(
      id: 'ex_te_routine_3',
      lessonId: 'te_daily_routine',
      type: ExerciseType.matching,
      prompt: 'క్రియలను అర్థాలతో జతచేయండి (Match activities to meanings)',
      pairs: [
        (left: 'పాఠశాలకు వెళ్ళడం', right: 'to go to school'),
        (left: 'అన్నం తినడం', right: 'to eat rice'),
        (left: 'నిద్రపోవడం', right: 'to sleep'),
        (left: 'చదువుకోవడం', right: 'to study'),
      ],
      explanation:
          'ఇవి దైనందిన జీవితంలో ప్రాథమిక క్రియలు. పాఠశాలకు వెళ్ళడం, అన్నం తినడం, నిద్రపోవడం, చదువుకోవడం.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_te_grammar)
  // ════════════════════════════════════════════════════════════════════

  'te_grammar_pronouns': const [
    Exercise(
      id: 'ex_te_pronouns_1',
      lessonId: 'te_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో "we" కి ఎన్ని రూపాలు?',
      options: [
        '1 (మేము)',
        '2 — మేము (exclusive) మరియు మనము (inclusive)',
        '3',
        '4',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో 2 "we" రూపాలు: మేము (exclusive — శ్రోతను మినహాయించి), మనము (inclusive — శ్రోతను కలిపి). మారాఠీ లాగా, హిందీ కాదు.',
    ),
    Exercise(
      id: 'ex_te_pronouns_2',
      lessonId: 'te_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: '"నాకు" అంటే ఏమిటి?',
      options: ['to me', 'from me', 'with me', 'by me'],
      correctIndex: 0,
      explanation:
          'నాకు (nāku) = to me. నేను + కి = నాకు. ఉదా: నాకు టీ ఇవ్వండి (Give me tea). -కి తెలుగు "to" postposition.',
    ),
    Exercise(
      id: 'ex_te_pronouns_3',
      lessonId: 'te_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో ఎన్ని third-person pronoun లింగాలు?',
      options: ['2 (అతను, ఆమె)', '3 (అతను, ఆమె, అది)', '1 (వారు)', '4'],
      correctIndex: 1,
      explanation:
          'తెలుగులో 3 third-person pronoun లింగాలు: అతను (he), ఆమె (she), అది (it). కానీ ఇవి grammatical gender కాదు — pronoun class మాత్రమే. క్రియ లింగం ప్రకారం మారదు.',
    ),
  ],

  'te_grammar_tenses': const [
    Exercise(
      id: 'ex_te_tenses_1',
      lessonId: 'te_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"నేను వెళ్ళాను" — ఇది ఏ కాలం?',
      options: ['వర్తమానం', 'భూతం', 'భవిష్యత్తు', 'ఆజ్ఞార్థ'],
      correctIndex: 1,
      explanation:
          'నేను వెళ్ళాను = I went (past). భూత కాలంలో మొదటి పురుష అంత్యం -ాను. వర్తమానం: నేను వెళ్తాను.',
    ),
    Exercise(
      id: 'ex_te_tenses_2',
      lessonId: 'te_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"నేను వెళ్తాను" — ఇది ఏ కాలం?',
      options: [
        'కేవలం వర్తమానం',
        'కేవలం భవిష్యత్తు',
        'వర్తమానం మరియు భవిష్యత్తు',
        'భూతం'
      ],
      correctIndex: 2,
      explanation:
          'నేను వెళ్తాను = I go / I will go. ఆధునిక తెలుగులో వర్తమానం మరియు భవిష్యత్తు రూపాలు ఒకే — సందర్భం నిర్ణయిస్తుంది.',
    ),
    Exercise(
      id: 'ex_te_tenses_3',
      lessonId: 'te_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో హిందీ ने marker కి సమానం ఉందా?',
      options: [
        'లేదు — తెలుగులో నे marker లేదు',
        'ఉంది — చేత',
        'కేవలం భూత కాలంలో',
        'కేవలం భవిష్యత్తులో',
      ],
      correctIndex: 0,
      explanation:
          'తెలుగులో నे marker లేదు! హిందీ: मैंने खाया. తెలుగు: నేను తిన్నాను. -చేత ఉంది కానీ అది passive agent కోసం, past-tense subject కోసం కాదు.',
    ),
  ],

  'te_grammar_postpositions': const [
    Exercise(
      id: 'ex_te_post_1',
      lessonId: 'te_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"ఇంట్లో" అంటే ఏమిటి?',
      options: [
        'on the house',
        'in the house',
        'from the house',
        'to the house'
      ],
      correctIndex: 1,
      explanation:
          '-లో (-lō) = in/inside. ఇంట్లో = in the house. postposition నామవాచకం తరువాత వస్తుంది.',
    ),
    Exercise(
      id: 'ex_te_post_2',
      lessonId: 'te_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"హైదరాబాద్ నుండి" అంటే ఏమిటి?',
      options: [
        'to Hyderabad',
        'in Hyderabad',
        'from Hyderabad',
        'near Hyderabad'
      ],
      correctIndex: 2,
      explanation:
          '-నుండి (-nuṇḍi) = from. హైదరాబాద్ నుండి = from Hyderabad. హిందీ से, మారాఠీ -हून, బెంగాలి থেকে కి బదులుగా తెలుగులో -నుండి.',
    ),
    Exercise(
      id: 'ex_te_post_3',
      lessonId: 'te_grammar_postpositions',
      type: ExerciseType.translation,
      prompt: 'Translate: నాకు',
      acceptedAnswers: [
        'to me',
        'To me',
      ],
      explanation:
          'నాకు (nāku) = to me. నేను + కి = నాకు. -కి తెలుగు "to" postposition.',
    ),
    Exercise(
      id: 'ex_te_post_4',
      lessonId: 'te_grammar_postpositions',
      type: ExerciseType.matching,
      prompt:
          'Postpositions ను అర్థాలతో జతచేయండి (Match postpositions to meanings)',
      pairs: [
        (left: '-లో', right: 'in'),
        (left: '-కి', right: 'to'),
        (left: '-నుండి', right: 'from'),
        (left: '-తో', right: 'with'),
      ],
      explanation:
          '-లో=in, -కి=to, -నుండి=from, -తో=with. ఇవి తెలుగులో అత్యంత సాధారణ postpositions.',
    ),
  ],

  'te_grammar_no_gender': const [
    Exercise(
      id: 'ex_te_nogender_1',
      lessonId: 'te_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో క్రియ లింగం ప్రకారం మారుతుందా?',
      options: [
        'అవును, హిందీ లాగా (जाता हूँ vs जाती हूँ)',
        'లేదు — తెలుగులో క్రియ లింగ-నిరపేక్ష',
        'కేవలం వర్తమాన కాలంలో',
        'కేవలం భూత కాలంలో',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో క్రియ లింగ-నిరపేక్ష! నేను వెళ్తాను = I go — ఏ వక్త అయినా ఒకే. హిందీ: मैं जाता हूँ (male) vs मैं जाती हूँ (female). ఇది ద్రావిడ విశిష్టత.',
    ),
    Exercise(
      id: 'ex_te_nogender_2',
      lessonId: 'te_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: '"మంచి అబ్బాయి" మరియు "మంచి అమ్మాయి" — ఇక్కడ మంచి ఎలా మారుతుంది?',
      options: [
        'మంచి → మంచి (నారీతో)',
        'మంచి మారదు — లింగ-నిరపేక్ష',
        'మంచి → మంచు (నారీతో)',
        'మంచి → మంచా (నారీతో)',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో విశేషణ లింగ-నిరపేక్ష! మంచి అబ్బాయి (good boy), మంచి అమ్మాయి (good girl) — మంచి మారదు. హిందీ: अच्छा/अच्छी మారుతుంది.',
    ),
    Exercise(
      id: 'ex_te_nogender_3',
      lessonId: 'te_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో possessive లింగం ప్రకారం మారుతుందా?',
      options: [
        'అవును — నా/నీ లాగా',
        'లేదు — నా (my) అన్ని నామవాచకాల ముందు ఒకే',
        'కేవలం పురుష నామవాచకాల ముందు',
        'కేవలం స్త్రీ నామవాచకాల ముందు',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో possessive లింగ-నిరపేక్ష! నా అన్న (my brother), నా అక్క (my sister) — నా ఒకే. హిందీ: मेरा/मेरी మారుతుంది, మారాఠీ: माझा/माझी/माझं.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_te_reading)
  // ════════════════════════════════════════════════════════════════════

  'te_reading_conversation': const [
    Exercise(
      id: 'ex_te_conv_1',
      lessonId: 'te_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"అన్నా, బంగాళదుంపలు ఎంత?" — ఇది ఏ సందర్భంలో అంటారు?',
      options: [
        'స్నేహితుడితో కలిసేటప్పుడు',
        'కూరగాయలు కొనేటప్పుడు దుకాణదారుతో',
        'ఇంట్లో వంట చేసేటప్పుడు',
        'రెస్టారెంట్‌లో ఆర్డర్ చేసేటప్పుడు',
      ],
      correctIndex: 1,
      explanation:
          'అన్నా (brother) దుకాణదారుని సంబోధించడానికి. బంగాళదుంపలు ఎంత? = How much are the potatoes? మార్కెట్‌లో దరదా సాధారణం.',
    ),
    Exercise(
      id: 'ex_te_conv_2',
      lessonId: 'te_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"వెళ్దాం?" అంటే ఏమిటి?',
      options: [
        'Let\'s walk',
        'Shall we go?',
        'Are you walking?',
        'Walk!',
      ],
      correctIndex: 1,
      explanation:
          'వెళ్దాం? (veḷdāṃ?) = Shall we go? / Let\'s go. తిరుపతి వెళ్దాం? = Shall we go to Tirupati?',
    ),
    Exercise(
      id: 'ex_te_conv_3',
      lessonId: 'te_reading_conversation',
      type: ExerciseType.translation,
      prompt: 'Translate: ఉదయం ఆరు గంటలకు కలుద్దాం।',
      acceptedAnswers: [
        'See you at six in the morning',
        'See you at 6 AM',
        'Let\'s meet at six in the morning',
      ],
      explanation:
          'ఉదయం ఆరు గంటలకు కలుద్దాం = See you / Let\'s meet at six in the morning. కలుద్దాం = let\'s meet.',
    ),
  ],

  'te_reading_paragraph': const [
    Exercise(
      id: 'ex_te_para_1',
      lessonId: 'te_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 1 ప్రకారం హైదరాబాద్‌ను ఏమని పిలుస్తారు?',
      options: [
        'హరిత నగరం',
        'సిటీ ఆఫ్ పర్ల్స్',
        'సఫెద్ నగరం',
        'నీల నగరం',
      ],
      correctIndex: 1,
      explanation:
          'Passage 1 చెబుతోంది: "హైదరాబాద్‌ను సిటీ ఆఫ్ పర్ల్స్ అని పిలుస్తారు ఎందుకంటే ఇక్కడ ముత్యాల వ్యాపారం చాలా చేస్తారు."',
    ),
    Exercise(
      id: 'ex_te_para_2',
      lessonId: 'te_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 2 ప్రకారం తెలుగు సినిమాను ఏమని అంటారు?',
      options: ['బాలీవుడ్', 'టాలీవుడ్', 'కాలీవుడ్', 'మాలీవుడ్'],
      correctIndex: 1,
      explanation:
          'Passage 2 చెబుతోంది: "తెలుగు సినిమా, దీనిని టాలీవుడ్ అని కూడా అంటారు." టాలీవుడ్ = Telugu + Hollywood.',
    ),
    Exercise(
      id: 'ex_te_para_3',
      lessonId: 'te_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 3 ప్రకారం తెలుగు వారి ప్రధాన ఆహారం ఏమిటి?',
      options: ['రొట్టె', 'అన్నం', 'బ్రెడ్', 'మాంసం'],
      correctIndex: 1,
      explanation:
          'Passage 3 చెబుతోంది: "అన్నం తెలుగు వారి ప్రధాన ఆహారం." అన్నం = cooked rice — తెలుగు ఆహారంలో కేంద్రం.',
    ),
  ],

  'te_reading_review': const [
    Exercise(
      id: 'ex_te_review_1',
      lessonId: 'te_reading_review',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో వాక్య క్రమం ఏమిటి?',
      options: ['SVO', 'SOV', 'VSO', 'OVS'],
      correctIndex: 1,
      explanation:
          'Subject-Object-Verb (SOV). నేను (S) అన్నం (O) తింటాను (V). ఇది తెలుగులో అత్యంత ముఖ్యమైన వ్యాకరణ నియమం.',
    ),
    Exercise(
      id: 'ex_te_review_2',
      lessonId: 'te_reading_review',
      type: ExerciseType.mcq,
      prompt: 'తెలుగులో అతిపెద్ద సరళీకరణ ఏమిటి హిందీతో పోలిస్తే?',
      options: [
        'క్రియలో లింగం లేదు',
        'కాలాలు లేవు',
        'postpositions లేవు',
        'pronouns లేవు',
      ],
      correctIndex: 0,
      explanation:
          'తెలుగులో క్రియలో గ్రామాటికల్ లింగం లేదు! నేను వెళ్తాను = I go — ఏ వక్త అయినా ఒకే. ఇది ద్రావిడ విశిష్టత.',
    ),
    Exercise(
      id: 'ex_te_review_3',
      lessonId: 'te_reading_review',
      type: ExerciseType.mcq,
      prompt: 'తెలుగు కుటుంబ పదాలలో పెద్ద/చిన్న తేడా ఉందా?',
      options: [
        'లేదు — అందరికీ ఒకే పదం',
        'ఉంది — అన్న/తమ్ముడు, అక్క/చెల్లెలు',
        'కేవలం స్త్రీలలో',
        'కేవలం పురుషులలో',
      ],
      correctIndex: 1,
      explanation:
          'తెలుగులో పెద్ద/చిన్న తేడా ఉంది: అన్న (older brother), తమ్ముడు (younger brother), అక్క (older sister), చెల్లెలు (younger sister). ఇది దక్షిణ భారతీయ విశిష్టత.',
    ),
    Exercise(
      id: 'ex_te_review_4',
      lessonId: 'te_reading_review',
      type: ExerciseType.translation,
      prompt: 'Translate: నా పేరు _____।',
      acceptedAnswers: [
        'My name is _____',
      ],
      explanation:
          'నా పేరు _____ = My name is _____. ఇది ప్రాథమిక పరిచయ వాక్యం — ప్రతి తెలుగు నేర్చుకునేవాడు తెలుసుకోవాలి.',
    ),
  ],
};
