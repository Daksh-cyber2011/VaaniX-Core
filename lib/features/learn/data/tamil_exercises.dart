/// Tamil Exercises — VaaniX Learn Mode Part E
///
/// Practice exercises for the Tamil curriculum
/// (assets/curriculum/learn/ta.json). Keyed by lesson id.
/// Tamil-specific features (Dravidian, no grammatical gender,
/// ழ/ள/ற/ண/ன sounds, older/younger siblings) are tested.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Tamil exercises keyed by lesson id.
/// Lesson IDs are prefixed with `ta_` to stay globally unique.
final Map<String, List<Exercise>> tamilExercisesByLesson = {
  'ta_script_vowels': const [
    Exercise(
      id: 'ex_ta_vowels_1',
      lessonId: 'ta_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'தமிழ் எந்த லிபியைப் பயன்படுத்துகிறது?',
      options: ['தேவநாகரி', 'தமிழ் லிபி', 'பெங்காலி', 'குர்முகி'],
      correctIndex: 1,
      explanation:
          'தமிழ் தமிழ் லிபியைப் பயன்படுத்துகிறது — இது தேவநாகரி (ஹிந்தி) மற்றும் பெங்காலியிலிருந்து வேறுபட்டது.',
    ),
    Exercise(
      id: 'ex_ta_vowels_2',
      lessonId: 'ta_script_vowels',
      type: ExerciseType.mcq,
      prompt: '"அன்பு" என்றால் என்ன?',
      options: ['love', 'joy', 'peace', 'anger'],
      correctIndex: 0,
      explanation:
          'அன்பு (anbu) = love. இது தமிழ் கலாச்சாரத்தில் மிக முக்கியமான கருத்து.',
    ),
    Exercise(
      id: 'ex_ta_vowels_3',
      lessonId: 'ta_script_vowels',
      type: ExerciseType.matching,
      prompt: 'உயிர் எழுத்துக்களை உதாரண சொற்களுடன் இணைக்கவும்',
      pairs: [
        (left: 'அ', right: 'அன்பு'),
        (left: 'ஆ', right: 'ஆனந்தம்'),
        (left: 'இ', right: 'இலை'),
        (left: 'உ', right: 'உப்பு'),
      ],
      explanation: 'ஒவ்வொரு உயிர் எழுத்துக்கும் அதன் சொந்த உதாரண சொல் உண்டு.',
    ),
  ],

  'ta_script_consonants': const [
    Exercise(
      id: 'ex_ta_consonants_1',
      lessonId: 'ta_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் எத்தனை மெய்யெழுத்துக்கள் உள்ளன?',
      options: ['18', '25', '33', '40'],
      correctIndex: 0,
      explanation:
          'தமிழில் 18 மெய்யெழுத்துக்கள் உள்ளன — சமஸ்கிருதத்தை விட குறைவு, ஏனெனில் தமிழில் aspirated consonants இல்லை.',
    ),
    Exercise(
      id: 'ex_ta_consonants_2',
      lessonId: 'ta_script_consonants',
      type: ExerciseType.mcq,
      prompt: '"தமிழ்" சொல்லில் எந்த தனித்துவமான ஒலி உள்ளது?',
      options: ['ல (la)', 'ழ (ḻa)', 'ள (ḷa)', 'ர (ra)'],
      correctIndex: 1,
      explanation:
          'தமிழ் சொல்லில் ழ (ḻa) உள்ளது — retroflex approximant. இந்த ஒலி தமிழுக்கு மட்டுமே சொந்தமானது.',
    ),
    Exercise(
      id: 'ex_ta_consonants_3',
      lessonId: 'ta_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் எத்தனை "L" ஒலிகள் உள்ளன?',
      options: ['1', '2', '3 (ல, ள, ழ)', '4'],
      correctIndex: 2,
      explanation:
          'தமிழில் 3 "L" ஒலிகள்: ல (la), ள (ḷa), ழ (ḻa). ஒவ்வொன்றும் வெவ்வேறு ஒலி.',
    ),
  ],

  'ta_script_matras': const [
    Exercise(
      id: 'ex_ta_matras_1',
      lessonId: 'ta_script_matras',
      type: ExerciseType.mcq,
      prompt: '"அம்மா" சொல்லில் என்ன pulli உள்ளது?',
      options: ['க + ்', 'ம + ்', 'த + ்', 'ப + ்'],
      correctIndex: 1,
      explanation:
          'அம்மா சொல்லில் ம + ் (pulli) உள்ளது — இரட்டை ம. அ + ம + ்ம + ா = அம்மா.',
    ),
    Exercise(
      id: 'ex_ta_matras_2',
      lessonId: 'ta_script_matras',
      type: ExerciseType.translation,
      prompt: 'Romanize: வணக்கம்',
      acceptedAnswers: ['vaṇakkam', 'vanakkam'],
      explanation:
          'வணக்கம் = vaṇakkam. இது தமிழின் முக்கிய வாழ்த்து. ஹிந்தி नमस्ते இலிருந்து வேறுபட்டது.',
    ),
    Exercise(
      id: 'ex_ta_matras_3',
      lessonId: 'ta_script_matras',
      type: ExerciseType.mcq,
      prompt: '"அம்மா" என்றால் என்ன?',
      options: ['father', 'mother', 'sister', 'grandmother'],
      correctIndex: 1,
      explanation:
          'அம்மா (ammā) = mother. தமிழில் "mother" க்கான சொல் — ஹிந்தी मां இலிருந்து வேறுபட்டது.',
    ),
  ],

  'ta_script_barakhadi': const [
    Exercise(
      id: 'ex_ta_barakhadi_1',
      lessonId: 'ta_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: தமிழ்',
      acceptedAnswers: ['tamiḻ', 'tamizh', 'tamil'],
      explanation:
          'தமிழ் = tamiḻ. ழ (ḻa) என்பது தமிழின் தனித்துவமான ஒலி.',
    ),
    Exercise(
      id: 'ex_ta_barakhadi_2',
      lessonId: 'ta_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: சோறு',
      acceptedAnswers: ['cōṟu', 'choru', 'sooru'],
      explanation:
          'சோறு = cōṟu (rice). ற (ṟa) ஒலி — தமிழின் தனித்துவமான ஒலி.',
    ),
    Exercise(
      id: 'ex_ta_barakhadi_3',
      lessonId: 'ta_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: நீர்',
      acceptedAnswers: ['nīr', 'neer'],
      explanation:
          'நீர் = nīr (water). தமிழில் water க்கான சொல் — ஹிந்தी पानी இலிருந்து வேறுபட்டது.',
    ),
  ],

  'ta_script_conjuncts': const [
    Exercise(
      id: 'ex_ta_conjuncts_1',
      lessonId: 'ta_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'தமிழ் சொல்லில் எந்த pulli உள்ளது?',
      options: ['த + ்', 'ம + ்', 'ழ + ்', 'இ + ்'],
      correctIndex: 2,
      explanation:
          'தமிழ் சொல்லில் ழ + ் (pulli) உள்ளது — ழ இன் உள்ளார்ந்த உயிரை நீக்குகிறது.',
    ),
    Exercise(
      id: 'ex_ta_conjuncts_2',
      lessonId: 'ta_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் எழுத்து மற்றும் பேச்சு வேறுபாடு உண்டா?',
      options: [
        'இல்லை — ஒன்றே',
        'ஆம் — எழுத்து (formal) மற்றும் பேச்சு (colloquial) வேறுபடும்',
        'கேவலம் எழுத்தில்',
        'கேவலம் பேச்சில்',
      ],
      correctIndex: 1,
      explanation:
          'தமிழில் diglossia உள்ளது — எழுத்து (செந்தமிழ்) மற்றும் பேச்சு (கொடுந்தமிழ்) வேறுபடும். இது தமிழின் முக்கிய பண்பு.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions
  // ════════════════════════════════════════════════════════════════════

  'ta_greet_vanakkam': const [
    Exercise(
      id: 'ex_ta_vanakkam_1',
      lessonId: 'ta_greet_vanakkam',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் மிகப் பொதுவான வாழ்த்து எது?',
      options: ['நமஸ்தே', 'வணக்கம்', 'ஹாய்', 'பை'],
      correctIndex: 1,
      explanation:
          'வணக்கம் (vaṇakkam) தமிழின் மிகப் பொதுவான வாழ்த்து. ஹிந்தி நமஸ்தே இலிருந்து வேறுபட்டது.',
    ),
    Exercise(
      id: 'ex_ta_vanakkam_2',
      lessonId: 'ta_greet_vanakkam',
      type: ExerciseType.mcq,
      prompt: '"நீங்கள் எப்படி இருக்கிறீர்கள்?" என்றால் என்ன?',
      options: ['What is your name?', 'How are you? (respectful)', 'Where are you?', 'Who are you?'],
      correctIndex: 1,
      explanation:
          'நீங்கள் எப்படி இருக்கிறீர்கள்? = How are you? (respectful).',
    ),
    Exercise(
      id: 'ex_ta_vanakkam_3',
      lessonId: 'ta_greet_vanakkam',
      type: ExerciseType.matching,
      prompt: 'வாழ்த்துக்களை அர்த்தங்களுடன் இணைக்கவும்',
      pairs: [
        (left: 'வணக்கம்', right: 'Hello / Greetings'),
        (left: 'காலை வணக்கம்', right: 'Good morning'),
        (left: 'மாலை வணக்கம்', right: 'Good evening'),
        (left: 'மீண்டும் சந்திப்போம்', right: 'See you again'),
      ],
      explanation: 'ஒவ்வொரு வாழ்த்துக்கும் அதன் சொந்த அர்த்தம் மற்றும் நேரம் உண்டு.',
    ),
  ],

  'ta_greet_intro': const [
    Exercise(
      id: 'ex_ta_intro_1',
      lessonId: 'ta_greet_intro',
      type: ExerciseType.translation,
      prompt: 'Translate: என் பெயர் ராகுல்।',
      acceptedAnswers: ['My name is Rahul', 'My name is Rahul.'],
      explanation:
          'என் பெயர் ராகுல் = My name is Rahul. என் = my, பெயர் = name.',
    ),
    Exercise(
      id: 'ex_ta_intro_2',
      lessonId: 'ta_greet_intro',
      type: ExerciseType.mcq,
      prompt: '"நீங்கள் எங்கிருந்து வந்திருக்கிறீர்கள்?" என்றால் என்ன?',
      options: ['What is your name?', 'Where are you from?', 'How are you?', 'When are you coming?'],
      correctIndex: 1,
      explanation:
          'எங்கிருந்து = from where. -இருந்து என்பது தமிழ் "from" postposition.',
    ),
    Exercise(
      id: 'ex_ta_intro_3',
      lessonId: 'ta_greet_intro',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் "I am a student" எப்படி சொல்வது (male)?',
      options: ['நான் மாணவன்.', 'நான் மாணவி.', 'நான் ஆசிரியர்.', 'நான் மருத்துவர்.'],
      correctIndex: 0,
      explanation:
          'நான் மாணவன் = I am a student (male). பெண்: மாணவி. ஆனால் கிரியா லிங்கம் படி மாறாது.',
    ),
  ],

  'ta_greet_family': const [
    Exercise(
      id: 'ex_ta_family_1',
      lessonId: 'ta_greet_family',
      type: ExerciseType.mcq,
      prompt: '"அண்ணன்" என்றால் என்ன?',
      options: ['younger brother', 'older brother', 'father', 'uncle'],
      correctIndex: 1,
      explanation:
          'அண்ணன் (aṇṇaṉ) = older brother. தமிழில் பெரிய/சிறிய வித்தியாசம் உண்டு.',
    ),
    Exercise(
      id: 'ex_ta_family_2',
      lessonId: 'ta_greet_family',
      type: ExerciseType.mcq,
      prompt: '"அக்கா" என்றால் என்ன?',
      options: ['younger sister', 'older sister', 'mother', 'aunt'],
      correctIndex: 1,
      explanation:
          'அக்கா (akkā) = older sister. தங்கை = younger sister.',
    ),
    Exercise(
      id: 'ex_ta_family_3',
      lessonId: 'ta_greet_family',
      type: ExerciseType.matching,
      prompt: 'குடும்ப சொற்களை அர்த்தங்களுடன் இணைக்கவும்',
      pairs: [
        (left: 'அம்மா', right: 'mother'),
        (left: 'அப்பா', right: 'father'),
        (left: 'அண்ணன்', right: 'older brother'),
        (left: 'அக்கா', right: 'older sister'),
      ],
      explanation:
          'தமிழ் குடும்ப சொற்கள் ஹிந்தியிலிருந்து வேறுபட்டவை.',
    ),
  ],

  'ta_greet_numbers': const [
    Exercise(
      id: 'ex_ta_numbers_1',
      lessonId: 'ta_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் 5 ஐ எப்படி சொல்வது?',
      options: ['ஐந்து', 'பஞ்ச்', 'பாஂச்', 'ஐது'],
      correctIndex: 0,
      explanation: 'தமிழில் 5 = ஐந்து (aindu). ஹிந்தी पांच, தெலுங்கு ఐదు — அனைத்தும் வேறு.',
    ),
    Exercise(
      id: 'ex_ta_numbers_2',
      lessonId: 'ta_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் 100 ஐ எப்படி சொல்வது?',
      options: ['ஸௌ', 'ஶம்பர்', 'நூறு', 'வந்த'],
      correctIndex: 2,
      explanation: 'தமிழில் 100 = நூறு (nūṟu). ஹிந்தी सौ, மராத்தி शंभर் — அனைத்தும் வேறு.',
    ),
    Exercise(
      id: 'ex_ta_numbers_3',
      lessonId: 'ta_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'எண்களை தமிழ் பெயர்களுடன் இணைக்கவும்',
      pairs: [
        (left: '1', right: 'ஒன்று'),
        (left: '5', right: 'ஐந்து'),
        (left: '10', right: 'பத்து'),
        (left: '100', right: 'நூறு'),
      ],
      explanation: 'தமிழ் எண்கள் ஹிந்தியிலிருந்து முற்றிலும் வேறு.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life
  // ════════════════════════════════════════════════════════════════════

  'ta_daily_sentences': const [
    Exercise(
      id: 'ex_ta_sentences_1',
      lessonId: 'ta_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் வாக்கிய அமைப்பு என்ன?',
      options: ['SVO', 'SOV', 'VSO', 'OSV'],
      correctIndex: 1,
      explanation:
          'Subject-Object-Verb (SOV). நான் (S) சோறு (O) சாப்பிடுகிறேன் (V).',
    ),
    Exercise(
      id: 'ex_ta_sentences_2',
      lessonId: 'ta_daily_sentences',
      type: ExerciseType.translation,
      prompt: 'Translate: நான் சோறு சாப்பிடுகிறேன்।',
      acceptedAnswers: ['I eat rice', 'I eat rice.'],
      explanation: 'நான் சோறு சாப்பிடுகிறேன் = I eat rice. SOV அமைப்பு.',
    ),
    Exercise(
      id: 'ex_ta_sentences_3',
      lessonId: 'ta_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் கிரியா லிங்கம் படி மாறுகிறதா?',
      options: [
        'ஆம், ஹிந்தி போல',
        'இல்லை — கிரியா லிங்க-சார்பற்றது',
        'கேவலம் நிகழ்காலத்தில்',
        'கேவலம் இறந்தகாலத்தில்',
      ],
      correctIndex: 1,
      explanation:
          'தமிழில் கிரியா லிங்க-சார்பற்றது! நான் போகிறேன் = I go — எந்த பேச்சாளருக்கும் ஒன்றே. இது திராவிட மொழி பண்பு.',
    ),
  ],

  'ta_daily_questions': const [
    Exercise(
      id: 'ex_ta_questions_1',
      lessonId: 'ta_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"எங்கே" என்றால் என்ன?',
      options: ['What', 'Who', 'Where', 'When'],
      correctIndex: 2,
      explanation: 'எங்கே (eṅgē) = where.',
    ),
    Exercise(
      id: 'ex_ta_questions_2',
      lessonId: 'ta_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"ஏன்" என்றால் என்ன?',
      options: ['How', 'Why', 'What', 'Who'],
      correctIndex: 1,
      explanation: 'ஏன் (ēṉ) = why.',
    ),
    Exercise(
      id: 'ex_ta_questions_3',
      lessonId: 'ta_daily_questions',
      type: ExerciseType.translation,
      prompt: 'Translate: நீங்கள் எங்கிருந்து வந்திருக்கிறீர்கள்?',
      acceptedAnswers: ['Where have you come from', 'Where have you come from?', 'Where are you from'],
      explanation: 'எங்கிருந்து = from where. -இருந்து என்பது தமிழ் "from" postposition.',
    ),
  ],

  'ta_daily_negation': const [
    Exercise(
      id: 'ex_ta_negation_1',
      lessonId: 'ta_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"நான் மருத்துவர் இல்லை" என்றால் என்ன?',
      options: ['I am a doctor', 'I am not a doctor', 'I want to be a doctor', 'Where is the doctor'],
      correctIndex: 1,
      explanation:
          'இல்லை (illai) = "is not". நான் மருத்துவர் இல்லை = I am not a doctor.',
    ),
    Exercise(
      id: 'ex_ta_negation_2',
      lessonId: 'ta_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"போக வேண்டாம்!" என்றால் என்ன?',
      options: ['I am not going', 'Don\'t go! (command)', 'He is not going', 'No going'],
      correctIndex: 1,
      explanation:
          'வேண்டாம் (vēṇṭām) = don\'t! (negative command). போக வேண்டாம்! = Don\'t go!',
    ),
    Exercise(
      id: 'ex_ta_negation_3',
      lessonId: 'ta_daily_negation',
      type: ExerciseType.translation,
      prompt: 'Make negative (future): நான் போகிறேன்।',
      acceptedAnswers: ['நான் போமாட்டேன்', 'நான் போமாட்டேன்।'],
      explanation: 'நான் போகிறேன் → நான் போமாட்டேன் (I won\'t go). -மாட்டேன் = future negation.',
    ),
  ],

  'ta_daily_routine': const [
    Exercise(
      id: 'ex_ta_routine_1',
      lessonId: 'ta_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"நான் தினமும் காலை ஆறு மணிக்கு எழுகிறேன்" — இது எந்த காலம்?',
      options: ['இறந்தகாலம்', 'நிகழ்காலம்', 'எதிர்காலம்', 'ஆணை'],
      correctIndex: 1,
      explanation:
          'இது நிகழ்காலம் (present habitual). "தினமும்" (daily) காட்டுகிறது இது தொடர்ச்சியான செயல்.',
    ),
    Exercise(
      id: 'ex_ta_routine_2',
      lessonId: 'ta_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"குளித்தல்" என்றால் என்ன?',
      options: ['To eat', 'To bathe', 'To sleep', 'To study'],
      correctIndex: 1,
      explanation: 'குளித்தல் (kuḷittal) = to bathe.',
    ),
    Exercise(
      id: 'ex_ta_routine_3',
      lessonId: 'ta_daily_routine',
      type: ExerciseType.matching,
      prompt: 'செயல்களை அர்த்தங்களுடன் இணைக்கவும்',
      pairs: [
        (left: 'பள்ளிக்குச் செல்லுதல்', right: 'to go to school'),
        (left: 'சோறு சாப்பிடுதல்', right: 'to eat rice'),
        (left: 'தூங்குதல்', right: 'to sleep'),
        (left: 'படித்தல்', right: 'to study'),
      ],
      explanation: 'இவை அன்றாட வாழ்க்கையின் அடிப்படை செயல்கள்.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar
  // ════════════════════════════════════════════════════════════════════

  'ta_grammar_pronouns': const [
    Exercise(
      id: 'ex_ta_pronouns_1',
      lessonId: 'ta_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் "we" க்கு எத்தனை வடிவங்கள்?',
      options: ['1 (நாங்கள்)', '2 — நாம் (inclusive) மற்றும் நாங்கள் (exclusive)', '3', '4'],
      correctIndex: 1,
      explanation:
          'தமிழில் 2 "we" வடிவங்கள்: நாம் (inclusive — கேட்பவரையும் சேர்த்து), நாங்கள் (exclusive — கேட்பவரை தவிர்த்து).',
    ),
    Exercise(
      id: 'ex_ta_pronouns_2',
      lessonId: 'ta_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: '"எனக்கு" என்றால் என்ன?',
      options: ['to me', 'from me', 'with me', 'by me'],
      correctIndex: 0,
      explanation: 'எனக்கு (enakku) = to me. நான் + க்கு = எனக்கு.',
    ),
    Exercise(
      id: 'ex_ta_pronouns_3',
      lessonId: 'ta_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் எத்தனை third-person pronoun வகைகள்?',
      options: ['2', '3 (அவன், அவள், அது)', '1', '4'],
      correctIndex: 1,
      explanation:
          'தமிழில் 3 third-person pronoun வகைகள்: அவன் (he), அவள் (she), அது (it). ஆனால் இவை grammatical gender அல்ல — pronoun class மட்டுமே.',
    ),
  ],

  'ta_grammar_tenses': const [
    Exercise(
      id: 'ex_ta_tenses_1',
      lessonId: 'ta_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"நான் போனேன்" — இது எந்த காலம்?',
      options: ['நிகழ்காலம்', 'இறந்தகாலம்', 'எதிர்காலம்', 'ஆணை'],
      correctIndex: 1,
      explanation: 'நான் போனேன் = I went (past). இறந்தகாலத்தில் -னேன் முடிவு.',
    ),
    Exercise(
      id: 'ex_ta_tenses_2',
      lessonId: 'ta_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"நான் போவேன்" — இது எந்த காலம்?',
      options: ['நிகழ்காலம்', 'இறந்தகாலம்', 'எதிர்காலம்', 'ஹால்'],
      correctIndex: 2,
      explanation: 'நான் போவேன் = I will go (future). -வேன் முடிவு.',
    ),
    Exercise(
      id: 'ex_ta_tenses_3',
      lessonId: 'ta_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் ஹிந்தி ने marker க்கு சமமானது உண்டா?',
      options: [
        'இல்லை — தமிழில் நे marker இல்லை',
        'ஆம், -ஆல்',
        'கேவலம் இறந்தகாலத்தில்',
        'கேவலம் எதிர்காலத்தில்',
      ],
      correctIndex: 0,
      explanation:
          'தமிழில் நे marker இல்லை! ஹிந்தி: मैंने खाया. தமிழ்: நான் சாப்பிட்டேன்.',
    ),
  ],

  'ta_grammar_postpositions': const [
    Exercise(
      id: 'ex_ta_post_1',
      lessonId: 'ta_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"வீட்டில்" என்றால் என்ன?',
      options: ['on the house', 'in the house', 'from the house', 'to the house'],
      correctIndex: 1,
      explanation: '-இல் (-il) = in/at/on. வீட்டில் = in the house.',
    ),
    Exercise(
      id: 'ex_ta_post_2',
      lessonId: 'ta_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"சென்னையிலிருந்து" என்றால் என்ன?',
      options: ['to Chennai', 'in Chennai', 'from Chennai', 'near Chennai'],
      correctIndex: 2,
      explanation: '-இருந்து (-ilirundhu) = from. சென்னையிலிருந்து = from Chennai.',
    ),
    Exercise(
      id: 'ex_ta_post_3',
      lessonId: 'ta_grammar_postpositions',
      type: ExerciseType.translation,
      prompt: 'Translate: எனக்கு',
      acceptedAnswers: ['to me', 'To me'],
      explanation: 'எனக்கு (enakku) = to me. நான் + க்கு = எனக்கு.',
    ),
    Exercise(
      id: 'ex_ta_post_4',
      lessonId: 'ta_grammar_postpositions',
      type: ExerciseType.matching,
      prompt: 'Postpositions ஐ அர்த்தங்களுடன் இணைக்கவும்',
      pairs: [
        (left: '-இல்', right: 'in'),
        (left: '-க்கு', right: 'to'),
        (left: '-இருந்து', right: 'from'),
        (left: '-உடன்', right: 'with'),
      ],
      explanation: '-இல்=in, -க்கு=to, -இருந்து=from, -உடன்=with.',
    ),
  ],

  'ta_grammar_no_gender': const [
    Exercise(
      id: 'ex_ta_nogender_1',
      lessonId: 'ta_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் கிரியா லிங்கம் படி மாறுகிறதா?',
      options: [
        'ஆம், ஹிந்தி போல',
        'இல்லை — தமிழில் கிரியா லிங்க-சார்பற்றது',
        'கேவலம் நிகழ்காலத்தில்',
        'கேவலம் இறந்தகாலத்தில்',
      ],
      correctIndex: 1,
      explanation:
          'தமிழில் கிரியா லிங்க-சார்பற்றது! நான் போகிறேன் = I go — எந்த பேச்சாளருக்கும் ஒன்றே. இது திராவிட மொழி பண்பு.',
    ),
    Exercise(
      id: 'ex_ta_nogender_2',
      lessonId: 'ta_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: '"நல்ல பையன்" மற்றும் "நல்ல பெண்" — இங்கு நல்ல எப்படி மாறுகிறது?',
      options: [
        'நல்ல → நல்லி (பெண்ணுடன்)',
        'நல்ல மாறாது — லிங்க-சார்பற்றது',
        'நல்ல → நல்லா (பெண்ணுடன்)',
        'நல்ல → நல்லே (பெண்ணுடன்)',
      ],
      correctIndex: 1,
      explanation:
          'தமிழில் விசேஷணம் லிங்க-சார்பற்றது! நல்ல பையன் (good boy), நல்ல பெண் (good girl) — நல்ல மாறாது.',
    ),
    Exercise(
      id: 'ex_ta_nogender_3',
      lessonId: 'ta_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் possessive லிங்கம் படி மாறுகிறதா?',
      options: [
        'ஆம் — என்/என் போல',
        'இல்லை — என் (my) அனைத்து பெயர்களுக்கும் ஒன்றே',
        'கேவலம் ஆண் பெயர்களுக்கு',
        'கேவலம் பெண் பெயர்களுக்கு',
      ],
      correctIndex: 1,
      explanation:
          'தமிழில் possessive லிங்க-சார்பற்றது! என் அண்ணன் (my brother), என் தங்கை (my sister) — என் ஒன்றே.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading
  // ════════════════════════════════════════════════════════════════════

  'ta_reading_conversation': const [
    Exercise(
      id: 'ex_ta_conv_1',
      lessonId: 'ta_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"அண்ணா, உருளைக்கிழங்கு எவ்வளவு?" — இது எந்த சூழ்நிலையில் சொல்லப்படுகிறது?',
      options: [
        'நண்பரை சந்திக்கும்போது',
        'காய்கறி வாங்கும்போது கடைக்காரரிடம்',
        'வீட்டில் சமைக்கும்போது',
        'ரெஸ்டாரன்டில் ஆர்டர் செய்யும்போது',
      ],
      correctIndex: 1,
      explanation:
          'அண்ணா (brother) கடைக்காரரை அழைக்கும் வார்த்தை. உருளைக்கிழங்கு எவ்வளவு? = How much are the potatoes?',
    ),
    Exercise(
      id: 'ex_ta_conv_2',
      lessonId: 'ta_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"போகலாமா?" என்றால் என்ன?',
      options: ['Let\'s walk', 'Shall we go?', 'Are you walking?', 'Walk!'],
      correctIndex: 1,
      explanation: 'போகலாமா? = Shall we go? / Let\'s go. மகாபலிபுரம் போகலாமா? = Shall we go to Mahabalipuram?',
    ),
    Exercise(
      id: 'ex_ta_conv_3',
      lessonId: 'ta_reading_conversation',
      type: ExerciseType.translation,
      prompt: 'Translate: காலை ஆறு மணிக்கு சந்திப்போம்।',
      acceptedAnswers: [
        'See you at six in the morning',
        'See you at 6 AM',
        'Let\'s meet at six in the morning',
      ],
      explanation: 'காலை ஆறு மணிக்கு சந்திப்போம் = See you / Let\'s meet at six in the morning.',
    ),
  ],

  'ta_reading_paragraph': const [
    Exercise(
      id: 'ex_ta_para_1',
      lessonId: 'ta_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 1 படி சென்னையை என்ன என்று அழைக்கிறார்கள்?',
      options: ['பசுமை நகரம்', 'தென்னிந்தியாவின் நுழைவாயில்', 'வெள்ளை நகரம்', 'நீல நகரம்'],
      correctIndex: 1,
      explanation: 'Passage 1 கூறுகிறது: "சென்னை தென்னிந்தியாவின் நுழைவாயில் என்று அழைக்கப்படுகிறது."',
    ),
    Exercise(
      id: 'ex_ta_para_2',
      lessonId: 'ta_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 2 படி திருக்குறளை எழுதியவர் யார்?',
      options: ['பாரதியார்', 'திருவள்ளுவர்', 'கம்பர்', 'ஔவையார்'],
      correctIndex: 1,
      explanation: 'Passage 2 கூறுகிறது: "திருக்குறளை எழுதியவர் திருவள்ளுவர்."',
    ),
    Exercise(
      id: 'ex_ta_para_3',
      lessonId: 'ta_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'Passage 3 படி தமிழர்களின் முக்கிய உணவு என்ன?',
      options: ['ரொட்டி', 'சோறு', 'பிரட்', 'மாமிசம்'],
      correctIndex: 1,
      explanation: 'Passage 3 கூறுகிறது: "சோறு தமிழர்களின் முக்கிய உணவு."',
    ),
  ],

  'ta_reading_review': const [
    Exercise(
      id: 'ex_ta_review_1',
      lessonId: 'ta_reading_review',
      type: ExerciseType.mcq,
      prompt: 'தமிழில் வாக்கிய அமைப்பு என்ன?',
      options: ['SVO', 'SOV', 'VSO', 'OVS'],
      correctIndex: 1,
      explanation: 'Subject-Object-Verb (SOV). நான் (S) சோறு (O) சாப்பிடுகிறேன் (V).',
    ),
    Exercise(
      id: 'ex_ta_review_2',
      lessonId: 'ta_reading_review',
      type: ExerciseType.mcq,
      prompt: 'தமிழின் மிகப்பெரிய எளிமை என்ன ஹிந்தியுடன் ஒப்பிடுகையில்?',
      options: [
        'கிரியாவில் லிங்கம் இல்லை',
        'காலங்கள் இல்லை',
        'postpositions இல்லை',
        'pronouns இல்லை',
      ],
      correctIndex: 0,
      explanation:
          'தமிழில் கிரியாவில் லிங்கம் இல்லை! நான் போகிறேன் = I go — எந்த பேச்சாளருக்கும் ஒன்றே.',
    ),
    Exercise(
      id: 'ex_ta_review_3',
      lessonId: 'ta_reading_review',
      type: ExerciseType.mcq,
      prompt: 'தமிழின் தனித்துவமான ஒலி எது ஹிந்தியில் இல்லை?',
      options: ['ல', 'ழ (ḻa)', 'ர', 'க'],
      correctIndex: 1,
      explanation:
          'ழ (ḻa) — retroflex approximant — தமிழின் தனித்துவமான ஒலி. தமிழ் சொல்லிலேயே இந்த ஒலி உள்ளது.',
    ),
    Exercise(
      id: 'ex_ta_review_4',
      lessonId: 'ta_reading_review',
      type: ExerciseType.translation,
      prompt: 'Translate: என் பெயர் _____।',
      acceptedAnswers: ['My name is _____'],
      explanation: 'என் பெயர் _____ = My name is _____. இது அடிப்படை அறிமுக வாக்கியம்.',
    ),
  ],
};
