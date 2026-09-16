/// Gujarati Exercises — VaaniX Learn Mode Part F
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

final Map<String, List<Exercise>> gujaratiExercisesByLesson = {
  'gu_script_vowels': const [
    Exercise(
        id: 'ex_gu_vowels_1',
        lessonId: 'gu_script_vowels',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતી કઈ લિપિ વાપરે છે?',
        options: ['દેવનાગરી', 'ગુજરાતી લિપિ', 'બંગાળી', 'તમિળ'],
        correctIndex: 1,
        explanation:
            'ગુજરાતી ગુજરાતી લિપિ વાપરે છે — દેવનાગરી જેવી પણ ટોચની રેખા વગર.'),
    Exercise(
        id: 'ex_gu_vowels_2',
        lessonId: 'gu_script_vowels',
        type: ExerciseType.mcq,
        prompt: '"પાણી" એટલે શું?',
        options: ['food', 'water', 'bread', 'tea'],
        correctIndex: 1,
        explanation:
            'પાણી (pāṇī) = water. હિન્દી पानी જેવું પણ ગુજરાતી લિપિમાં.'),
    Exercise(
        id: 'ex_gu_vowels_3',
        lessonId: 'gu_script_vowels',
        type: ExerciseType.matching,
        prompt: 'સ્વરને ઉદાહરણ સાથે જોડો',
        pairs: [
          (left: 'અ', right: 'અન્ન'),
          (left: 'આ', right: 'આંખ'),
          (left: 'એ', right: 'એક'),
          (left: 'ઓ', right: 'ઓરડો')
        ],
        explanation: 'દરેક સ્વરનું પોતાનું ઉદાહરણ છે.'),
  ],
  'gu_script_consonants': const [
    Exercise(
        id: 'ex_gu_consonants_1',
        lessonId: 'gu_script_consonants',
        type: ExerciseType.mcq,
        prompt: '"ભાઈ" એટલે શું?',
        options: ['sister', 'brother', 'father', 'friend'],
        correctIndex: 1,
        explanation: 'ભાઈ (bhāī) = brother.'),
    Exercise(
        id: 'ex_gu_consonants_2',
        lessonId: 'gu_script_consonants',
        type: ExerciseType.mcq,
        prompt: '"મમ્મી" એટલે શું?',
        options: ['father', 'mother', 'sister', 'aunt'],
        correctIndex: 1,
        explanation: 'મમ્મી (mammī) = mother. ગુજરાતીમાં સૌથી સામાન્ય શબ્દ.'),
    Exercise(
        id: 'ex_gu_consonants_3',
        lessonId: 'gu_script_consonants',
        type: ExerciseType.matching,
        prompt: 'વ્યંજનને અર્થ સાથે જોડો',
        pairs: [
          (left: 'ક', right: 'કલમ'),
          (left: 'ચ', right: 'ચા'),
          (left: 'પ', right: 'પાણી'),
          (left: 'મ', right: 'મમ્મી')
        ],
        explanation: 'દરેક વ્યંજનનું ઉદાહરણ.'),
  ],
  'gu_script_matras': const [
    Exercise(
        id: 'ex_gu_matras_1',
        lessonId: 'gu_script_matras',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં શિરોરેખા (top line) હોય છે?',
        options: ['હા', 'ના', 'કેટલીક વખત', 'ફક્ત સ્વરમાં'],
        correctIndex: 1,
        explanation: 'ગુજરાતીમાં શિરોરેખા નથી — દેવનાગરીથી મુખ્ય તફાવત.'),
    Exercise(
        id: 'ex_gu_matras_2',
        lessonId: 'gu_script_matras',
        type: ExerciseType.translation,
        prompt: 'Romanize: નમસ્તે',
        acceptedAnswers: ['namastē', 'namaste'],
        explanation: 'નમસ્તે = namastē. ગુજરાતી અભિવાદન.'),
    Exercise(
        id: 'ex_gu_matras_3',
        lessonId: 'gu_script_matras',
        type: ExerciseType.translation,
        prompt: 'Romanize: પાણી',
        acceptedAnswers: ['pāṇī', 'pani'],
        explanation: 'પાણી = pāṇī (water).'),
  ],
  'gu_script_barakhadi': const [
    Exercise(
        id: 'ex_gu_barakhadi_1',
        lessonId: 'gu_script_barakhadi',
        type: ExerciseType.translation,
        prompt: 'Romanize: રોટલી',
        acceptedAnswers: ['roṭlī', 'rotli'],
        explanation: 'રોટલી = roṭlī (flatbread). ગુજરાતી શબ્દ.'),
    Exercise(
        id: 'ex_gu_barakhadi_2',
        lessonId: 'gu_script_barakhadi',
        type: ExerciseType.translation,
        prompt: 'Romanize: ભાઈ',
        acceptedAnswers: ['bhāī', 'bhai'],
        explanation: 'ભાઈ = bhāī (brother).'),
    Exercise(
        id: 'ex_gu_barakhadi_3',
        lessonId: 'gu_script_barakhadi',
        type: ExerciseType.mcq,
        prompt: 'ક + ા = ?',
        options: ['કિ', 'કા', 'કે', 'કો'],
        correctIndex: 1,
        explanation: 'ક + ા (આ માત્રા) = કા.'),
  ],
  'gu_script_conjuncts': const [
    Exercise(
        id: 'ex_gu_conjuncts_1',
        lessonId: 'gu_script_conjuncts',
        type: ExerciseType.mcq,
        prompt: 'નમસ્તે શબ્દમાં કયું સંયુક્ત વ્યંજન છે?',
        options: ['ક્ષ', 'ન્મ', 'ત્ર', 'જ્ઞ'],
        correctIndex: 1,
        explanation: 'નમસ્તે માં ન્મ (ન + ્ + મ) છે.'),
    Exercise(
        id: 'ex_gu_conjuncts_2',
        lessonId: 'gu_script_conjuncts',
        type: ExerciseType.mcq,
        prompt: 'મમ્મી શબ્દમાં કયું સંયુક્ત છે?',
        options: ['મ્મ', 'પ્પ', 'ન્ન', 'લ્લ'],
        correctIndex: 0,
        explanation: 'મમ્મી માં મ્મ (મ + ્ + મ) છે.'),
  ],
  'gu_greet_namaste': const [
    Exercise(
        id: 'ex_gu_namaste_1',
        lessonId: 'gu_greet_namaste',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં સૌથી સામાન્ય અભિવાદન શું?',
        options: ['નમસ્તે', 'હાય', 'બાય', 'આવજો'],
        correctIndex: 0,
        explanation: 'નમસ્તે સૌથી સામાન્ય અભિવાદન છે.'),
    Exercise(
        id: 'ex_gu_namaste_2',
        lessonId: 'gu_greet_namaste',
        type: ExerciseType.mcq,
        prompt: '"કેમ છો?" એટલે શું?',
        options: [
          'What is your name?',
          'How are you?',
          'Where are you?',
          'Who are you?'
        ],
        correctIndex: 1,
        explanation: 'કેમ છો? = How are you?'),
    Exercise(
        id: 'ex_gu_namaste_3',
        lessonId: 'gu_greet_namaste',
        type: ExerciseType.mcq,
        prompt: '"હું મજામાં છું" એટલે શું?',
        options: ['I am sad', 'I am fine', 'I am tired', 'I am angry'],
        correctIndex: 1,
        explanation: 'હું મજામાં છું = I am fine (lit: I am in fun).'),
    Exercise(
        id: 'ex_gu_namaste_4',
        lessonId: 'gu_greet_namaste',
        type: ExerciseType.matching,
        prompt: 'અભિવાદનને અર્થ સાથે જોડો',
        pairs: [
          (left: 'નમસ્તે', right: 'Hello'),
          (left: 'જય શ્રી કૃષ્ણ', right: 'Hail Krishna'),
          (left: 'શુભ સવાર', right: 'Good morning'),
          (left: 'આવજો', right: 'Come again / Bye')
        ],
        explanation: 'દરેક અભિવાદનનો પોતાનો અર્થ છે.'),
  ],
  'gu_greet_intro': const [
    Exercise(
        id: 'ex_gu_intro_1',
        lessonId: 'gu_greet_intro',
        type: ExerciseType.translation,
        prompt: 'Translate: મારું નામ રાહુલ છે.',
        acceptedAnswers: ['My name is Rahul', 'My name is Rahul.'],
        explanation: 'મારું નામ રાહુલ છે = My name is Rahul.'),
    Exercise(
        id: 'ex_gu_intro_2',
        lessonId: 'gu_greet_intro',
        type: ExerciseType.mcq,
        prompt: '"તમે ક્યાંથી છો?" એટલે શું?',
        options: [
          'What is your name?',
          'Where are you from?',
          'How are you?',
          'When?'
        ],
        correctIndex: 1,
        explanation: 'ક્યાંથી = from where. -થી = from.'),
    Exercise(
        id: 'ex_gu_intro_3',
        lessonId: 'gu_greet_intro',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં "I am a student" કેવી રીતે કહેવાય?',
        options: [
          'હું વિદ્યાર્થી છું.',
          'હું શિક્ષક છું.',
          'હું ડૉક્ટર છું.',
          'હું એન્જિનિયર છું.'
        ],
        correctIndex: 0,
        explanation:
            'હું વિદ્યાર્થી છું = I am a student. ક્રિયા લિંગ-નિરપેક્ષ છે.'),
  ],
  'gu_greet_family': const [
    Exercise(
        id: 'ex_gu_family_1',
        lessonId: 'gu_greet_family',
        type: ExerciseType.mcq,
        prompt: '"મમ્મી" એટલે શું?',
        options: ['father', 'mother', 'sister', 'grandmother'],
        correctIndex: 1,
        explanation: 'મમ્મી = mother. ગુજરાતીમાં સૌથી સામાન્ય શબ્દ.'),
    Exercise(
        id: 'ex_gu_family_2',
        lessonId: 'gu_greet_family',
        type: ExerciseType.matching,
        prompt: 'કુટુંબ શબ્દને અર્થ સાથે જોડો',
        pairs: [
          (left: 'મમ્મી', right: 'mother'),
          (left: 'પપ્પા', right: 'father'),
          (left: 'ભાઈ', right: 'brother'),
          (left: 'બહેન', right: 'sister')
        ],
        explanation: 'ગુજરાતી કુટુંબ શબ્દો.'),
    Exercise(
        id: 'ex_gu_family_3',
        lessonId: 'gu_greet_family',
        type: ExerciseType.mcq,
        prompt: '"મારે બે ભાઈ છે" એટલે શું?',
        options: [
          'I have two sisters',
          'I have two brothers',
          'I have two sons',
          'I have two fathers'
        ],
        correctIndex: 1,
        explanation: 'મારે બે ભાઈ છે = I have two brothers. મારે = to me.'),
  ],
  'gu_greet_numbers': const [
    Exercise(
        id: 'ex_gu_numbers_1',
        lessonId: 'gu_greet_numbers',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં 2 ને શું કહેવાય?',
        options: ['દો', 'બે', 'દુઈ', 'બી'],
        correctIndex: 1,
        explanation: 'બે (be) = 2. હિન્દી दો થી અલગ.'),
    Exercise(
        id: 'ex_gu_numbers_2',
        lessonId: 'gu_greet_numbers',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં 6 ને શું કહેવાય?',
        options: ['છ', 'છહ', 'ષ', 'સ'],
        correctIndex: 0,
        explanation: 'છ (chha) = 6. હિન્દी छह થી અલગ.'),
    Exercise(
        id: 'ex_gu_numbers_3',
        lessonId: 'gu_greet_numbers',
        type: ExerciseType.matching,
        prompt: 'આંકડાને ગુજરાતી નામ સાથે જોડો',
        pairs: [
          (left: '1', right: 'એક'),
          (left: '5', right: 'પાંચ'),
          (left: '10', right: 'દસ'),
          (left: '100', right: 'સો')
        ],
        explanation: 'ગુજરાતી આંકડા હિન્દી થી અલગ છે.'),
  ],
  'gu_daily_sentences': const [
    Exercise(
        id: 'ex_gu_sentences_1',
        lessonId: 'gu_daily_sentences',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં વાક્ય ક્રમ શું?',
        options: ['SVO', 'SOV', 'VSO', 'OSV'],
        correctIndex: 1,
        explanation: 'Subject-Object-Verb (SOV).'),
    Exercise(
        id: 'ex_gu_sentences_2',
        lessonId: 'gu_daily_sentences',
        type: ExerciseType.translation,
        prompt: 'Translate: હું રોટલી ખાઉં છું.',
        acceptedAnswers: ['I eat bread', 'I eat flatbread', 'I eat rotli'],
        explanation: 'હું રોટલી ખાઉં છું = I eat flatbread. SOV ક્રમ.'),
    Exercise(
        id: 'ex_gu_sentences_3',
        lessonId: 'gu_daily_sentences',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં present tense ક્રિયા લિંગ પ્રમાણે બદલાય છે?',
        options: [
          'હા, હિન્દી જેવું',
          'ના — ક્રિયા લિંગ-નિરપેક્ષ',
          'ફક્ત વર્તમાનમાં',
          'ફક્ત ભૂતમાં'
        ],
        correctIndex: 1,
        explanation:
            'ગુજરાતીમાં present tense ક્રિયા લિંગ-નિરપેક્ષ છે! છું એ જ બધા માટે.'),
  ],
  'gu_daily_questions': const [
    Exercise(
        id: 'ex_gu_questions_1',
        lessonId: 'gu_daily_questions',
        type: ExerciseType.mcq,
        prompt: '"ક્યાં" એટલે શું?',
        options: ['What', 'Who', 'Where', 'When'],
        correctIndex: 2,
        explanation: 'ક્યાં (kyā̃) = where.'),
    Exercise(
        id: 'ex_gu_questions_2',
        lessonId: 'gu_daily_questions',
        type: ExerciseType.mcq,
        prompt: '"કેમ" એટલે શું?',
        options: ['How', 'Why', 'What', 'Who'],
        correctIndex: 0,
        explanation: 'કેમ (kem) = how.'),
    Exercise(
        id: 'ex_gu_questions_3',
        lessonId: 'gu_daily_questions',
        type: ExerciseType.translation,
        prompt: 'Translate: તમે ક્યાંથી છો?',
        acceptedAnswers: ['Where are you from', 'Where are you from?'],
        explanation: 'ક્યાંથી = from where. -થી = from.'),
  ],
  'gu_daily_negation': const [
    Exercise(
        id: 'ex_gu_negation_1',
        lessonId: 'gu_daily_negation',
        type: ExerciseType.mcq,
        prompt: '"હું ડૉક્ટર નથી" એટલે શું?',
        options: [
          'I am a doctor',
          'I am not a doctor',
          'I want to be a doctor',
          'Where is the doctor'
        ],
        correctIndex: 1,
        explanation: 'નથી (nathī) = not. present tense negation.'),
    Exercise(
        id: 'ex_gu_negation_2',
        lessonId: 'gu_daily_negation',
        type: ExerciseType.mcq,
        prompt: '"જવા મા!" એટલે શું?',
        options: ['I am going', 'Don\'t go!', 'He is going', 'No going'],
        correctIndex: 1,
        explanation: 'મા (mā) = don\'t! (negative command).'),
    Exercise(
        id: 'ex_gu_negation_3',
        lessonId: 'gu_daily_negation',
        type: ExerciseType.translation,
        prompt: 'Make negative: હું જાઉં છું.',
        acceptedAnswers: ['હું જાઉં નથી', 'હું જાઉં નથી।'],
        explanation: 'હું જાઉં છું → હું જાઉં નથી.'),
  ],
  'gu_daily_routine': const [
    Exercise(
        id: 'ex_gu_routine_1',
        lessonId: 'gu_daily_routine',
        type: ExerciseType.mcq,
        prompt: '"હું રોજ સવારે છ વાગ્યે ઊઠું છું" — કયો કાળ?',
        options: ['ભૂત', 'વર્તમાન', 'ભવિષ્ય', 'આજ્ઞા'],
        correctIndex: 1,
        explanation: 'વર્તમાન કાળ. "રોજ" = daily.'),
    Exercise(
        id: 'ex_gu_routine_2',
        lessonId: 'gu_daily_routine',
        type: ExerciseType.matching,
        prompt: 'ક્રિયાને અર્થ સાથે જોડો',
        pairs: [
          (left: 'સવારે ઊઠવું', right: 'to wake up'),
          (left: 'ચા પીવી', right: 'to drink tea'),
          (left: 'સ્નાન કરવું', right: 'to bathe'),
          (left: 'ભણવું', right: 'to study')
        ],
        explanation: 'દૈનિક ક્રિયાઓ.'),
  ],
  'gu_grammar_pronouns': const [
    Exercise(
        id: 'ex_gu_pronouns_1',
        lessonId: 'gu_grammar_pronouns',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં "I" ને શું કહેવાય?',
        options: ['મૈં', 'હું', 'મું', 'હમ'],
        correctIndex: 1,
        explanation: 'હું (huṃ) = I. હિન્દी मैં થી અલગ.'),
    Exercise(
        id: 'ex_gu_pronouns_2',
        lessonId: 'gu_grammar_pronouns',
        type: ExerciseType.mcq,
        prompt: '"મને" એટલે શું?',
        options: ['to me', 'from me', 'with me', 'by me'],
        correctIndex: 0,
        explanation: 'મને (mane) = to me. -ને = to.'),
    Exercise(
        id: 'ex_gu_pronouns_3',
        lessonId: 'gu_grammar_pronouns',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં "you" (respectful) ને શું કહેવાય?',
        options: ['તું', 'તમે', 'આપ', 'તુમ'],
        correctIndex: 1,
        explanation: 'તમે (tame) = you (respectful). તું = informal.'),
  ],
  'gu_grammar_gender': const [
    Exercise(
        id: 'ex_gu_gender_1',
        lessonId: 'gu_grammar_gender',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં કેટલા લિંગ છે?',
        options: ['2', '3 (પુલ્લિંગ, સ્ત્રીલિંગ, નપુંસક)', '1', '4'],
        correctIndex: 1,
        explanation:
            'ગુજરાતીમાં 3 લિંગ છે — મરાઠી જેવું. નપુંસકલિંગ વિશિષ્ટ છે.'),
    Exercise(
        id: 'ex_gu_gender_2',
        lessonId: 'gu_grammar_gender',
        type: ExerciseType.mcq,
        prompt: '"પુસ્તક" કયા લિંગમાં છે?',
        options: ['પુલ્લિંગ', 'સ્ત્રીલિંગ', 'નપુંસકલિંગ'],
        correctIndex: 2,
        explanation:
            'પુસ્તક = નપુંસક! હિન્દીમાં feminine છે પણ ગુજરાતીમાં neuter.'),
    Exercise(
        id: 'ex_gu_gender_3',
        lessonId: 'gu_grammar_gender',
        type: ExerciseType.matching,
        prompt: 'મારું/મારી/મારા ને સંજ્ઞા સાથે જોડો',
        pairs: [
          (left: 'મારું', right: 'પુસ્તક (neuter)'),
          (left: 'મારી', right: 'બહેન (feminine)'),
          (left: 'મારા', right: 'ભાઈ (masculine)')
        ],
        explanation: 'Possessive લિંગ પ્રમાણે બદલાય છે.'),
  ],
  'gu_grammar_tenses': const [
    Exercise(
        id: 'ex_gu_tenses_1',
        lessonId: 'gu_grammar_tenses',
        type: ExerciseType.mcq,
        prompt: '"હું ગયો" — કયો કાળ?',
        options: ['વર્તમાન', 'ભૂત', 'ભવિષ્ય', 'આજ્ઞા'],
        correctIndex: 1,
        explanation: 'હું ગયો = I went (past, male).'),
    Exercise(
        id: 'ex_gu_tenses_2',
        lessonId: 'gu_grammar_tenses',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતી present tense માં ક્રિયા લિંગ પ્રમાણે બદલાય છે?',
        options: [
          'હા',
          'ના — છું એ જ બધા માટે',
          'ફક્ત પુરુષ માટે',
          'ફક્ત સ્ત્રી માટે'
        ],
        correctIndex: 1,
        explanation:
            'Present tense માં ક્રિયા લિંગ-નિરપેક્ષ! છું એ જ બધા માટે.'),
    Exercise(
        id: 'ex_gu_tenses_3',
        lessonId: 'gu_grammar_tenses',
        type: ExerciseType.translation,
        prompt: 'Future: હું જાઉં છું.',
        acceptedAnswers: ['હું જઈશ', 'હું જઈશ।'],
        explanation: 'વર્તમાન: જાઉં છું → ભવિષ્ય: જઈશ.'),
  ],
  'gu_grammar_postpositions': const [
    Exercise(
        id: 'ex_gu_post_1',
        lessonId: 'gu_grammar_postpositions',
        type: ExerciseType.mcq,
        prompt: '"ઘરમાં" એટલે શું?',
        options: [
          'on the house',
          'in the house',
          'from the house',
          'to the house'
        ],
        correctIndex: 1,
        explanation: '-માં (-mā̃) = in. ઘરમાં = in the house.'),
    Exercise(
        id: 'ex_gu_post_2',
        lessonId: 'gu_grammar_postpositions',
        type: ExerciseType.mcq,
        prompt: '"અમદાવાદથી" એટલે શું?',
        options: [
          'to Ahmedabad',
          'in Ahmedabad',
          'from Ahmedabad',
          'near Ahmedabad'
        ],
        correctIndex: 2,
        explanation: '-થી (-thī) = from.'),
    Exercise(
        id: 'ex_gu_post_3',
        lessonId: 'gu_grammar_postpositions',
        type: ExerciseType.translation,
        prompt: 'Translate: મને',
        acceptedAnswers: ['to me', 'To me'],
        explanation: 'મને (mane) = to me. -ને = to.'),
    Exercise(
        id: 'ex_gu_post_4',
        lessonId: 'gu_grammar_postpositions',
        type: ExerciseType.matching,
        prompt: 'Postposition ને અર્થ સાથે જોડો',
        pairs: [
          (left: '-માં', right: 'in'),
          (left: '-ને', right: 'to'),
          (left: '-થી', right: 'from'),
          (left: '-સાથે', right: 'with')
        ],
        explanation: '-માં=in, -ને=to, -થી=from, -સાથે=with.'),
  ],
  'gu_reading_conversation': const [
    Exercise(
        id: 'ex_gu_conv_1',
        lessonId: 'gu_reading_conversation',
        type: ExerciseType.mcq,
        prompt: '"ભાઈ, બટાકા કેટલાના?" — આ કયા સંજોગમાં કહેવાય?',
        options: [
          'મિત્ર સાથે',
          'શાકભાજી ખરીદતી વખતે',
          'ઘરે રસોઈ કરતી વખતે',
          'રેસ્ટોરન્ટમાં'
        ],
        correctIndex: 1,
        explanation: 'ભાઈ = shopkeeper ને સંબોધવા.'),
    Exercise(
        id: 'ex_gu_conv_2',
        lessonId: 'gu_reading_conversation',
        type: ExerciseType.translation,
        prompt: 'Translate: સવારે છ વાગ્યે મળીશું.',
        acceptedAnswers: ['See you at six in the morning', 'See you at 6 AM'],
        explanation: 'મળીશું = we will meet.'),
  ],
  'gu_reading_paragraph': const [
    Exercise(
        id: 'ex_gu_para_1',
        lessonId: 'gu_reading_paragraph',
        type: ExerciseType.mcq,
        prompt: 'Passage 1 પ્રમાણે અમદાવાદને શું કહેવાય?',
        options: [
          'હરિયાળું શહેર',
          'માનચેસ્ટર ઓફ ધ ઈસ્ટ',
          'સફેદ શહેર',
          'વાદળી શહેર'
        ],
        correctIndex: 1,
        explanation: 'અમદાવાદને "માનચેસ્ટર ઓફ ધ ઈસ્ટ" કહેવાય.'),
    Exercise(
        id: 'ex_gu_para_2',
        lessonId: 'gu_reading_paragraph',
        type: ExerciseType.mcq,
        prompt: 'Passage 2 પ્રમાણે નવરાત્રિમાં લોકો શું રમે છે?',
        options: ['ક્રિકેટ', 'ગરબા', 'હોકી', 'કબડ્ડી'],
        correctIndex: 1,
        explanation: 'નવરાત્રિમાં ગરબા રમે છે.'),
    Exercise(
        id: 'ex_gu_para_3',
        lessonId: 'gu_reading_paragraph',
        type: ExerciseType.mcq,
        prompt: 'Passage 3 પ્રમાણે ગુજરાતી ભોજનમાં કયા સ્વાદ હોય છે?',
        options: [
          'મીઠું જ',
          'ખાટું જ',
          'તીખું જ',
          'મીઠું, ખાટું, તીખું — ત્રણેય'
        ],
        correctIndex: 3,
        explanation: 'ગુજરાતી ભોજનમાં ત્રણેય સ્વાદ હોય છે.'),
  ],
  'gu_reading_review': const [
    Exercise(
        id: 'ex_gu_review_1',
        lessonId: 'gu_reading_review',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીમાં વાક્ય ક્રમ શું?',
        options: ['SVO', 'SOV', 'VSO', 'OVS'],
        correctIndex: 1,
        explanation: 'Subject-Object-Verb (SOV).'),
    Exercise(
        id: 'ex_gu_review_2',
        lessonId: 'gu_reading_review',
        type: ExerciseType.mcq,
        prompt: 'ગુજરાતીનું સૌથી મોટું સરળીકરણ શું છે?',
        options: [
          'ક્રિયામાં લિંગ નથી (present)',
          'કાળ નથી',
          'postposition નથી',
          'pronoun નથી'
        ],
        correctIndex: 0,
        explanation:
            'Present tense માં ક્રિયા લિંગ-નિરપેક્ષ! છું એ જ બધા માટે.'),
    Exercise(
        id: 'ex_gu_review_3',
        lessonId: 'gu_reading_review',
        type: ExerciseType.translation,
        prompt: 'Translate: મારું નામ _____ છે.',
        acceptedAnswers: ['My name is _____'],
        explanation: 'મારું નામ _____ છે = My name is _____.'),
  ],
};
