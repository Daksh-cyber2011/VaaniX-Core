/// Kannada Exercises — VaaniX Learn Mode Part H (M9)
///
/// Practice exercises for the Kannada curriculum
/// (assets/curriculum/learn/kn.json). Keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically. Each lesson
/// has 3 exercises covering mcq, fillBlank, ordering, translation and
/// matching types.
///
/// Content note: every exercise is grounded in the actual lesson
/// content. Kannada examples are natural (not machine-translated).
/// Explanations teach WHY an answer is correct, per the VaaniX
/// feedback quality standard.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Kannada exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `kn_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode
/// curriculum.
final Map<String, List<Exercise>> kannadaExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Kannada Script (ch_kn_script)
  // ════════════════════════════════════════════════════════════════════

  'kn_script_vowels': const [
    Exercise(
      id: 'ex_kn_vowels_1',
      lessonId: 'kn_script_vowels',
      type: ExerciseType.mcq,
      prompt:
          'ಕನ್ನಡದಲ್ಲಿ ಎಷ್ಟು ಸ್ವರಗಳಿವೆ? (How many vowels does Kannada have?)',
      options: ['10', '11', '13', '14'],
      correctIndex: 3,
      explanation:
          'Kannada has 14 vowels (ಸ್ವರಗಳು) including ಅಂ and ಅಃ. The short/long pairs (ಅ/ಆ, ಇ/ಈ…) are the core of the system.',
    ),
    Exercise(
      id: 'ex_kn_vowels_2',
      lessonId: 'kn_script_vowels',
      type: ExerciseType.matching,
      prompt:
          'ಸ್ವರಗಳನ್ನು ಅರ್ಥದೊಂದಿಗೆ ಹೊಂದಿಸಿ (Match vowels to their example words)',
      pairs: [
        (left: 'ಅಮ್ಮ', right: 'a — mother'),
        (left: 'ಆಕಾಶ', right: 'ā — sky'),
        (left: 'ಈಗ', right: 'ī — now'),
        (left: 'ಐದು', right: 'ai — five'),
      ],
      explanation:
          'Each example word showcases one vowel: ಅಮ್ಮ begins with ಅ, ಆಕಾಶ with the long ಆ, ಈಗ with ಈ, ಐದು with the diphthong ಐ.',
    ),
    Exercise(
      id: 'ex_kn_vowels_3',
      lessonId: 'kn_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'ಇವುಗಳಲ್ಲಿ ದೀರ್ಘ ಸ್ವರ ಯಾವುದು? (Which one is the LONG vowel?)',
      options: ['ಇ', 'ಈ', 'ಎ', 'ಒ'],
      correctIndex: 1,
      explanation:
          'ಈ is the long form of ಇ. Length changes meaning: ಕವಿ (poet) vs ಕಾವಿ (ochre) — the held vowel is the long one.',
    ),
  ],

  'kn_script_consonants': const [
    Exercise(
      id: 'ex_kn_cons_1',
      lessonId: 'kn_script_consonants',
      type: ExerciseType.matching,
      prompt: 'ವ್ಯಂಜನಗಳನ್ನು ಹೊಂದಿಸಿ (Match consonants to their sounds)',
      pairs: [
        (left: 'ಕ', right: 'ka'),
        (left: 'ಗ', right: 'ga'),
        (left: 'ಮ', right: 'ma'),
        (left: 'ಳ', right: 'retroflex ḷa'),
      ],
      explanation:
          'A bare consonant carries built-in ಅ: ಕ = ka. ಳ is the curled retroflex l — the sound Kannada is famous for.',
    ),
    Exercise(
      id: 'ex_kn_cons_2',
      lessonId: 'kn_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'ಯಾವ ಅಕ್ಷರ ನಾಲಗೆ ಹಿಂದಕ್ಕೆ ಸುರುಳಾಗಿ ಉಚ್ಚರಿಸಲ್ಪಡುತ್ತದೆ? '
          '(Which letter is made with the tongue CURLED BACK?)',
      options: ['ತ (ta)', 'ಟ (ṭa)', 'ನ (na)', 'ಪ (pa)'],
      correctIndex: 1,
      explanation:
          'ಟ is retroflex — tongue curled back. ತ is dental, tongue at the teeth. Compare ಕಣ್ಣು (eye) vs ಕನ್ನಡ (the language).',
    ),
    Exercise(
      id: 'ex_kn_cons_3',
      lessonId: 'kn_script_consonants',
      type: ExerciseType.ordering,
      prompt: 'ಸರಿಯಾದ ಕ್ರಮದಲ್ಲಿ ಜೋಡಿಸಿ (Arrange the velar row in order)',
      items: ['ಕ ka', 'ಖ kha', 'ಗ ga', 'ಘ gha'],
      explanation:
          'The velar row runs voiceless → aspirated → voiced → voiced-aspirated: ಕ ಖ ಗ ಘ. Every row of the grid follows this pattern.',
    ),
  ],

  'kn_script_matras': const [
    Exercise(
      id: 'ex_kn_matras_1',
      lessonId: 'kn_script_matras',
      type: ExerciseType.mcq,
      prompt: 'ಕ + ಿ ಎಂದರೆ ಏನು? (What does ಕ + the sign ಿ read as?)',
      options: ['ka', 'kā', 'ki', 'ku'],
      correctIndex: 2,
      explanation:
          'The sign ಿ changes ಕ (ka) to ಕಿ (ki). Note: the sign is written on the LEFT of the consonant but pronounced AFTER it.',
    ),
    Exercise(
      id: 'ex_kn_matras_2',
      lessonId: 'kn_script_matras',
      type: ExerciseType.matching,
      prompt:
          'ಗುಣಿತಾಕ್ಷರಗಳನ್ನು ಹೊಂದಿಸಿ (Match the developed letters to sounds)',
      pairs: [
        (left: 'ಕಾ', right: 'kā'),
        (left: 'ಕಿ', right: 'ki'),
        (left: 'ಕು', right: 'ku'),
        (left: 'ಕೋ', right: 'kō'),
      ],
      explanation:
          'Each sign carries one vowel: ಾ = ā, ಿ = i, ು = u (written below), ೋ = ō. The consonant ಕ stays constant.',
    ),
    Exercise(
      id: 'ex_kn_matras_3',
      lessonId: 'kn_script_matras',
      type: ExerciseType.mcq,
      prompt: "'ನದಿ' (river) ಎಂಬ ಪದದಲ್ಲಿ ಎಷ್ಟು ಮಾತ್ರೆಗಳಿವೆ? "
          '(How many vowel signs appear in ನದಿ — river?)',
      options: ['0', '1', '2', '3'],
      correctIndex: 1,
      explanation:
          'ನದಿ = ನ + ದ + ಿ. Only one sign (ಿ on ದ). The word reads na-di: the ಿ sign sits left of ದ but sounds after it.',
    ),
  ],

  'kn_script_vattakshara': const [
    Exercise(
      id: 'ex_kn_vatt_1',
      lessonId: 'kn_script_vattakshara',
      type: ExerciseType.mcq,
      prompt: "'ಕನ್ನಡ' ಎಂಬ ಪದದಲ್ಲಿ ಯಾವ ಒಕ್ಕೂರಿದೆ? "
          '(Which cluster appears in ಕನ್ನಡ — the language name?)',
      options: ['ಮ್ಮ', 'ನ್ನ', 'ಲ್ಲ', 'ಟ್ಟ'],
      correctIndex: 1,
      explanation:
          'ಕನ್ನಡ contains ನ್ನ — two ನ letters with the second subjoined below (ವಟ್ಟಕ್ಷರ). Same pattern as ಅಮ್ಮ with ಮ್ಮ.',
    ),
    Exercise(
      id: 'ex_kn_vatt_2',
      lessonId: 'kn_script_vattakshara',
      type: ExerciseType.matching,
      prompt: 'ಒಕ್ಕೂರುಗಳನ್ನು ಪದಗಳೊಂದಿಗೆ ಹೊಂದಿಸಿ (Match clusters to words)',
      pairs: [
        (left: 'ಅಮ್ಮ', right: 'mother'),
        (left: 'ಬೆಳ್ಳಿ', right: 'silver'),
        (left: 'ಧೈರ್ಯ', right: 'courage'),
        (left: 'ಕಟ್ಟು', right: 'to build/tie'),
      ],
      explanation:
          'Each word shows a common subjoined cluster: ಮ್ಮ, ಳ್ಳ, ರ್ಯ, ಟ್ಟ. These five are among the highest-frequency shapes in print.',
    ),
    Exercise(
      id: 'ex_kn_vatt_3',
      lessonId: 'kn_script_vattakshara',
      type: ExerciseType.mcq,
      prompt: 'ಪುಳ್ಳಿ/ವಿರಾಮ (್) ಯಾವ ಕೆಲಸ ಮಾಡುತ್ತದೆ? '
          '(What does the virama ್ do to a consonant?)',
      options: [
        'Doubles it (doubles the letter)',
        "Removes the built-in 'a' sound (removes the built-in a)",
        'Makes it long (makes it long)',
        'Nothing (nothing)',
      ],
      correctIndex: 1,
      explanation:
          '್ kills the vowel: ಕ್ is bare "k". So ಉತ್ತರ (uttara, north) = ಉ + ತ್ + ತ + ರ.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_kn_greet)
  // ════════════════════════════════════════════════════════════════════

  'kn_greet_namaskara': const [
    Exercise(
      id: 'ex_kn_greet_1',
      lessonId: 'kn_greet_namaskara',
      type: ExerciseType.mcq,
      prompt: 'ಯಾವುದೇ ಸಮಯದಲ್ಲಿ, ಯಾರಿಗಾದರೂ ಸಲ್ಲುವ ಶುಭಾಶಯ ಯಾವುದು? '
          '(Which greeting works with anyone, at any time of day?)',
      options: ['ಶುಭೋದಯ', 'ನಮಸ್ಕಾರ', 'ಶುಭ ರಾತ್ರಿ', 'ಯಾಕೋ'],
      correctIndex: 1,
      explanation:
          'ನಮಸ್ಕಾರ is the all-purpose polite greeting. ಶುಭೋದಯ is morning-only, ಶುಭ ರಾತ್ರಿ night-only, and ಯಾಕೋ is for close friends.',
    ),
    Exercise(
      id: 'ex_kn_greet_2',
      lessonId: 'kn_greet_namaskara',
      type: ExerciseType.matching,
      prompt: 'ಅರ್ಥ ಹೊಂದಿಸಿ (Match the phrases to meanings)',
      pairs: [
        (left: 'ಧನ್ಯವಾದಗಳು', right: 'thank you'),
        (left: 'ಕ್ಷಮಿಸಿ', right: 'sorry / excuse me'),
        (left: 'ಹೋಗಿ ಬರುತ್ತೇನೆ', right: "I'll go and come back"),
        (left: 'ಚೆನ್ನಾಗಿದ್ದೇನೆ', right: "I'm well"),
      ],
      explanation:
          'ಹೋಗಿ ಬರುತ್ತೇನೆ is the classic Kannada goodbye — leaving is framed as returning. ಚೆನ್ನಾಗಿದ್ದೇನೆ answers ಹೇಗಿದ್ದೀರಾ?',
    ),
    Exercise(
      id: 'ex_kn_greet_3',
      lessonId: 'kn_greet_namaskara',
      type: ExerciseType.mcq,
      prompt: 'ಗೆಳೆಯನಿಗೆ "ಹೇಗಿದ್ದೀಯ?" ಎಂದು ಕೇಳಿದರೆ ಉತ್ತರ: '
          '(A friend asks ಹೇಗಿದ್ದೀಯ? — how are you? You answer…)',
      options: ['ಚೆನ್ನಾಗಿದ್ದೇನೆ', 'ನಮಸ್ಕಾರ', 'ಎಷ್ಟು?', 'ಬನ್ನಿ'],
      correctIndex: 0,
      explanation:
          'ಚೆನ್ನಾಗಿದ್ದೇನೆ = "I am well". ಬನ್ನಿ means "come/please come" and ಎಷ್ಟು means "how much" — neither answers the question.',
    ),
  ],

  'kn_greet_intro': const [
    Exercise(
      id: 'ex_kn_intro_1',
      lessonId: 'kn_greet_intro',
      type: ExerciseType.translation,
      prompt:
          "ಗೆಳೆಯನ ಹೆಸರನ್ನು ಕೇಳಿ — 'What is your name?' (to a FRIEND, intimate)",
      acceptedAnswers: ['ನಿನ್ನ ಹೆಸರು ಏನು', 'ninna hesaru enu'],
      explanation:
          'ನಿನ್ನ ಹೆಸರು ಏನು? is the intimate form. For respect: ನಿಮ್ಮ ಹೆಸರು ಏನು? — ನಿನ್ನ (your-intimate) vs ನಿಮ್ಮ (your-respectful).',
    ),
    Exercise(
      id: 'ex_kn_intro_2',
      lessonId: 'kn_greet_intro',
      type: ExerciseType.ordering,
      prompt: 'ವಾಕ್ಯ ಜೋಡಿಸಿ (Arrange: "My name is Ravi")',
      items: ['ನನ್ನ (my)', 'ಹೆಸರು (name)', 'ರವಿ (Ravi)'],
      explanation:
          'ನನ್ನ ಹೆಸರು ರವಿ — Kannada runs possessor → possessed → value. The structure never shuffles.',
    ),
    Exercise(
      id: 'ex_kn_intro_3',
      lessonId: 'kn_greet_intro',
      type: ExerciseType.mcq,
      prompt: "'ನಾನು ಕನ್ನಡ ಕಲಿಯುತ್ತಿದ್ದೇನೆ' ಎಂದರೆ: "
          "(What does ನಾನು ಕನ್ನಡ ಕಲಿಯುತ್ತಿದ್ದೇನೆ mean?)",
      options: [
        'I am teaching Kannada',
        'I am learning Kannada',
        'I know Kannada',
        'I forgot Kannada',
      ],
      correctIndex: 1,
      explanation:
          'ಕಲಿಯುತ್ತಿದ್ದೇನೆ = "am learning" (-ತ್ತಿದ್ದೇನೆ is the continuous). The magic follow-up: ನಿಧಾನವಾಗಿ ಮಾತನಾಡಿ — speak slowly!',
    ),
  ],

  'kn_greet_family': const [
    Exercise(
      id: 'ex_kn_family_1',
      lessonId: 'kn_greet_family',
      type: ExerciseType.matching,
      prompt: 'ಕುಟುಂಬದ ಪದಗಳನ್ನು ಹೊಂದಿಸಿ (Match the family words)',
      pairs: [
        (left: 'ಅಣ್ಣ', right: 'elder brother'),
        (left: 'ತಮ್ಮ', right: 'younger brother'),
        (left: 'ಅಕ್ಕ', right: 'elder sister'),
        (left: 'ತಂಗಿ', right: 'younger sister'),
      ],
      explanation:
          'Kannada kinship encodes RELATIVE AGE — there is no single neutral "brother". Your elder brother is ಅಣ್ಣ; younger, ತಮ್ಮ.',
    ),
    Exercise(
      id: 'ex_kn_family_2',
      lessonId: 'kn_greet_family',
      type: ExerciseType.mcq,
      prompt: 'ಅಜ್ಜಿ ಯಾರು? (Who is the ಅಜ್ಜಿ?)',
      options: ['grandfather', 'grandmother', 'aunt', 'elder sister'],
      correctIndex: 1,
      explanation:
          'ಅಜ್ಜಿ = grandmother; ಅಜ್ಜ = grandfather. Both double as affectionate addresses for elderly strangers too.',
    ),
    Exercise(
      id: 'ex_kn_family_3',
      lessonId: 'kn_greet_family',
      type: ExerciseType.translation,
      prompt: 'ಕನ್ನಡದಲ್ಲಿ ಹೇಳಿ: "This is my elder brother."',
      acceptedAnswers: ['ಇದು ನನ್ನ ಅಣ್ಣ', 'idu nanna anna'],
      explanation:
          'ಇದು ನನ್ನ ಅಣ್ಣ — this + my + elder brother. SOV order puts the noun last; nothing else moves.',
    ),
  ],

  'kn_greet_numbers': const [
    Exercise(
      id: 'ex_kn_num_1',
      lessonId: 'kn_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'ಸಂಖ್ಯೆಗಳನ್ನು ಹೊಂದಿಸಿ (Match numerals to names)',
      pairs: [
        (left: '೧', right: 'ಒಂದು (one)'),
        (left: '೫', right: 'ಐದು (five)'),
        (left: '೭', right: 'ಏಳು (seven)'),
        (left: '೯', right: 'ಒಂಬತ್ತು (nine)'),
      ],
      explanation:
          'Kannada digits ೦–೯ appear on bus boards and old bills. ೧ ಒಂದು, ೫ ಐದು, ೭ ಏಳು, ೯ ಒಂಬತ್ತು.',
    ),
    Exercise(
      id: 'ex_kn_num_2',
      lessonId: 'kn_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'ನೂರು ಎಂದರೆ ಎಷ್ಟು? (What number is ನೂರು?)',
      options: ['10', '50', '100', '1000'],
      correctIndex: 2,
      explanation:
          'ನೂರು = one hundred. The tens: ಇಪ್ಪತ್ತು 20, ಮೂವತ್ತು 30, ನಲವತ್ತು 40, ಐವತ್ತು 50 — irregular like English "eleven".',
    ),
    Exercise(
      id: 'ex_kn_num_3',
      lessonId: 'kn_greet_numbers',
      type: ExerciseType.translation,
      prompt: 'ಬೆಲೆ ಕೇಳಿ — "How much?" (the market word)',
      acceptedAnswers: ['ಎಷ್ಟು', 'eshtu', 'eṣṭu'],
      explanation:
          'ಎಷ್ಟು (eṣṭu) = how much / how many. Pair it: ಎಷ್ಟು ಬೆಲೆ? (how much price?), ಎಷ್ಟು ರೂಪಾಯಿ? (how many rupees?).',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_kn_daily)
  // ════════════════════════════════════════════════════════════════════

  'kn_daily_sentences': const [
    Exercise(
      id: 'ex_kn_daily1_1',
      lessonId: 'kn_daily_sentences',
      type: ExerciseType.ordering,
      prompt: 'ವಾಕ್ಯ ಜೋಡಿಸಿ (Arrange: "I eat rice")',
      items: ['ನಾನು (I)', 'ಅನ್ನ (rice)', 'ತಿನ್ನುತ್ತೇನೆ (eat)'],
      explanation:
          'Kannada is SOV: subject → object → verb. ನಾನು ಅನ್ನ ತಿನ್ನುತ್ತೇನೆ. The verb ALWAYS closes the sentence.',
    ),
    Exercise(
      id: 'ex_kn_daily1_2',
      lessonId: 'kn_daily_sentences',
      type: ExerciseType.mcq,
      prompt: "'ಪುಸ್ತಕ ಮೇಜಿನ ಮೇಲೆ ಇದೆ' ಎಂದರೆ: "
          '(What does ಪುಸ್ತಕ ಮೇಜಿನ ಮೇಲೆ ಇದೆ mean?)',
      options: [
        'The book is under the table',
        'The book is on the table',
        'The table is on the book',
        'The book is near the table',
      ],
      correctIndex: 1,
      explanation:
          'ಮೇಲೆ = on/above; ಕೆಳಗೆ = under; ಹತ್ತಿರ = near. And ಇದೆ = "is" (the ಇರು verb for things).',
    ),
    Exercise(
      id: 'ex_kn_daily1_3',
      lessonId: 'kn_daily_sentences',
      type: ExerciseType.fillBlank,
      prompt: 'ನಾನು ಮನೆ___ ಇದ್ದೇನೆ. (I am AT home — fill the ending)',
      options: ['ಗೆ', 'ಇಂದ', 'ಅಲ್ಲಿ (as ಯಲ್ಲಿ)', 'ಜೊತೆ'],
      correctIndex: 2,
      explanation:
          'ಮನೆ + ಅಲ್ಲಿ → ಮನೆಯಲ್ಲಿ (in the house). -ಗೆ is "to", -ಇಂದ "from", -ಜೊತೆ "with" — location-in takes -ಅಲ್ಲಿ.',
    ),
  ],

  'kn_daily_questions': const [
    Exercise(
      id: 'ex_kn_daily2_1',
      lessonId: 'kn_daily_questions',
      type: ExerciseType.matching,
      prompt: 'ಪ್ರಶ್ನಾವಾಚಕಗಳನ್ನು ಹೊಂದಿಸಿ (Match the question words)',
      pairs: [
        (left: 'ಏನು', right: 'what'),
        (left: 'ಯಾರು', right: 'who'),
        (left: 'ಎಲ್ಲಿ', right: 'where'),
        (left: 'ಯಾವಾಗ', right: 'when'),
      ],
      explanation:
          'Four question words that unlock daily talk. Also: ಎಷ್ಟು (how much), ಯಾವ (which). They stay IN PLACE — no word shuffling.',
    ),
    Exercise(
      id: 'ex_kn_daily2_2',
      lessonId: 'kn_daily_questions',
      type: ExerciseType.mcq,
      prompt: 'ಬಸ್ ಎಲ್ಲಿ? ಎಂದರೆ: (What does ಬಸ್ ಎಲ್ಲಿ? ask?)',
      options: [
        'When is the bus?',
        'Where is the bus?',
        'How much is the bus?',
        'Who is on the bus?',
      ],
      correctIndex: 1,
      explanation:
          'ಎಲ್ಲಿ = where. Question word sits where the answer would sit: "bus where?" — exactly the Odia/Kannada way.',
    ),
    Exercise(
      id: 'ex_kn_daily2_3',
      lessonId: 'kn_daily_questions',
      type: ExerciseType.mcq,
      prompt:
          '"ನಾನು ಗೊತ್ತಿಲ್ಲ" — ಇದರ ಅರ್ಥ: (The best everyday "I don\'t know" is…)',
      options: ['ಗೊತ್ತು', 'ಗೊತ್ತಿಲ್ಲ', 'ಇಷ್ಟ', 'ಸರಿ'],
      correctIndex: 1,
      explanation:
          'ಗೊತ್ತಿಲ್ಲ = don\'t know (ಗೊತ್ತು + negative ಇಲ್ಲ). ಸರಿ means "okay" — the most-used word in Karnataka.',
    ),
  ],

  'kn_daily_negation': const [
    Exercise(
      id: 'ex_kn_daily3_1',
      lessonId: 'kn_daily_negation',
      type: ExerciseType.matching,
      prompt: 'ನಿಷೇಧ ಪದಗಳನ್ನು ಕೆಲಸದೊಂದಿಗೆ ಹೊಂದಿಸಿ (Match each "no" to its job)',
      pairs: [
        (left: 'ಇಲ್ಲ', right: 'there isn\'t / don\'t have'),
        (left: 'ಅಲ್ಲ', right: 'it is not (identity)'),
        (left: 'ಬೇಡ', right: "don't want (refusal)"),
        (left: 'ಗೊತ್ತಿಲ್ಲ', right: "don't know"),
      ],
      explanation:
          'Kannada splits negation by job: existence (ಇಲ್ಲ), identity (ಅಲ್ಲ), refusal (ಬೇಡ), knowledge (ಗೊತ್ತಿಲ್ಲ).',
    ),
    Exercise(
      id: 'ex_kn_daily3_2',
      lessonId: 'kn_daily_negation',
      type: ExerciseType.mcq,
      prompt: "'ನಾನು ಡಾಕ್ಟರ್ ಅಲ್ಲ' — ಸರಿಯಾದ ಅರ್ಥ: "
          '(Why ಅಲ್ಲ (not ಇಲ್ಲ) in ನಾನು ಡಾಕ್ಟರ್ ಅಲ್ಲ?)',
      options: [
        'It negates identity: "I am NOT a doctor"',
        'It negates possession: "I have no doctor"',
        'It is a polite request',
        'It means maybe',
      ],
      correctIndex: 0,
      explanation:
          'ಅಲ್ಲ rejects what something IS (identity). ಇಲ್ಲ rejects what EXISTS/IS HAD. ನಾನು ಡಾಕ್ಟರ್ ಅಲ್ಲ = I am not a doctor.',
    ),
    Exercise(
      id: 'ex_kn_daily3_3',
      lessonId: 'kn_daily_negation',
      type: ExerciseType.fillBlank,
      prompt: 'ಹಣ ___ (There is no money — fill the negative)',
      options: ['ಇದೆ', 'ಇಲ್ಲ', 'ಅಲ್ಲ', 'ಬೇಡ'],
      correctIndex: 1,
      explanation:
          'ಹಣ ಇಲ್ಲ — money is-not(present). The positive would be ಹಣ ಇದೆ. Same swap for ಸಮಯ ಇಲ್ಲ (no time).',
    ),
  ],

  'kn_daily_routine': const [
    Exercise(
      id: 'ex_kn_daily4_1',
      lessonId: 'kn_daily_routine',
      type: ExerciseType.matching,
      prompt: 'ದಿನದ ಭಾಗಗಳನ್ನು ಹೊಂದಿಸಿ (Match the day-parts)',
      pairs: [
        (left: 'ಬೆಳಿಗ್ಗೆ', right: 'morning'),
        (left: 'ಮಧ್ಯಾಹ್ನ', right: 'afternoon'),
        (left: 'ಸಂಜೆ', right: 'evening'),
        (left: 'ರಾತ್ರಿ', right: 'night'),
      ],
      explanation:
          'Four day-parts prefix every clock time: ಬೆಳಿಗ್ಗೆ ಏಳು ಗಂಟೆ = seven in the morning.',
    ),
    Exercise(
      id: 'ex_kn_daily4_2',
      lessonId: 'kn_daily_routine',
      type: ExerciseType.mcq,
      prompt: "'ಊಟ ಆಯಿತಾ?' ಎಂದರೆ: (What does ಊಟ ಆಯಿತಾ? ask?)",
      options: [
        'Is the meal done/ready?',
        'Did you cook?',
        'Where is lunch?',
        'Do you want dinner?',
      ],
      correctIndex: 0,
      explanation:
          'ಊಟ = meal, ಆಯಿತಾ? = has it happened/done? The happy answer: ಆಯಿತು! (done!) — followed by ರುಚಿಯಾಗಿದೆ (it\'s tasty).',
    ),
    Exercise(
      id: 'ex_kn_daily4_3',
      lessonId: 'kn_daily_routine',
      type: ExerciseType.ordering,
      prompt: 'ದಿನಚರಿ ಕ್ರಮ ಜೋಡಿಸಿ (Arrange a morning in order)',
      items: [
        'ಏಳುತ್ತೇನೆ (I wake)',
        'ಕಾಫಿ ಕುಡಿಯುತ್ತೇನೆ (I drink coffee)',
        'ಕೆಲಸಕ್ಕೆ ಹೋಗುತ್ತೇನೆ (I go to work)',
      ],
      explanation:
          'A routine is a verb chain: wake → drink → go. Chain five verbs with times and you narrate a full day naturally.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_kn_grammar)
  // ════════════════════════════════════════════════════════════════════

  'kn_grammar_pronouns': const [
    Exercise(
      id: 'ex_kn_gram1_1',
      lessonId: 'kn_grammar_pronouns',
      type: ExerciseType.matching,
      prompt: 'ಸರ್ವನಾಮಗಳನ್ನು ಹೊಂದಿಸಿ (Match the pronouns)',
      pairs: [
        (left: 'ನಾನು', right: 'I'),
        (left: 'ನೀವು', right: 'you (respectful)'),
        (left: 'ಅವಳು', right: 'she'),
        (left: 'ನಾವು', right: 'we'),
      ],
      explanation:
          'ನೀವು for strangers/elders; ನೀನು only for intimates. ಅವರು doubles as respectful "he/she" — the plural-of-respect.',
    ),
    Exercise(
      id: 'ex_kn_gram1_2',
      lessonId: 'kn_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'ಗೌರವದಿಂದ "ಅವರು" ಯಾವಾಗ ಬಳಸಲ್ಪಡುತ್ತದೆ? '
          '(When is ಅವರು used for ONE respected person?)',
      options: [
        'Never — it is only plural',
        'As the honorific he/she',
        'Only for children',
        'Only for animals',
      ],
      correctIndex: 1,
      explanation:
          'ಅವರು ("they") is the standard respectful third person: ಅವರು ಬಂದರು — he/she (hon.) came. Kannada has no grammatical gender for objects either.',
    ),
    Exercise(
      id: 'ex_kn_gram1_3',
      lessonId: 'kn_grammar_pronouns',
      type: ExerciseType.fillBlank,
      prompt: 'ಅವಳು ಮಾಡು___. (She is doing — fill the ending)',
      options: ['ತ್ತೇನೆ', 'ತ್ತಾನೆ', 'ತ್ತಾಳೆ', 'ತ್ತಾರೆ'],
      correctIndex: 2,
      explanation:
          'Person endings: -ತ್ತೇನೆ (I), -ತ್ತಾನೆ (he), -ತ್ತಾಳೆ (she), -ತ್ತಾರೆ (they/resp). One verb, seven endings, fully regular.',
    ),
  ],

  'kn_grammar_tenses': const [
    Exercise(
      id: 'ex_kn_gram2_1',
      lessonId: 'kn_grammar_tenses',
      type: ExerciseType.matching,
      prompt: 'ಕಾಲಗಳನ್ನು ಹೊಂದಿಸಿ (Match the tense forms of ಮಾಡು)',
      pairs: [
        (left: 'ಮಾಡುತ್ತೇನೆ', right: 'I do / am doing'),
        (left: 'ಮಾಡಿದೆನು', right: 'I did'),
        (left: 'ಮಾಡುವೆನು', right: 'I will do'),
        (left: 'ಮಾಡಬೇಡ', right: "don't do"),
      ],
      explanation:
          'Present -ಉತ್ತ-, past -ಇದ್-, future -ಉವ- plus the person ending. Learn the three suffixes once — they fit every verb.',
    ),
    Exercise(
      id: 'ex_kn_gram2_2',
      lessonId: 'kn_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: "'ಬಾ' (come) ಯ ಭೂತಕಾಲ: (The past of ಬಾ — come — is…)",
      options: ['ಬರುತ್ತೇನೆ', 'ಬಂದೆನು', 'ಬಾರೆನು', 'ಬಾ'],
      correctIndex: 1,
      explanation:
          'ಬಾ → ಬಂದೆನು (came). Strong verbs twist in the past: ಹೋಗು → ಹೋದೆನು, ಕೊಡು → ಕೊಟ್ಟೆನು. Learn past forms as partner-words.',
    ),
    Exercise(
      id: 'ex_kn_gram2_3',
      lessonId: 'kn_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: "'ನಾಳೆ' ಎಂದರೆ: (What does ನಾಳೆ mean?)",
      options: ['today', 'yesterday', 'tomorrow', 'every day'],
      correctIndex: 2,
      explanation:
          'ನಾಳೆ = tomorrow; ನಿನ್ನೆ = yesterday; ಇಂದು = today; ಪ್ರತಿದಿನ = every day. The time word half-does the tense work.',
    ),
  ],

  'kn_grammar_cases': const [
    Exercise(
      id: 'ex_kn_gram3_1',
      lessonId: 'kn_grammar_cases',
      type: ExerciseType.matching,
      prompt: 'ವಿಭಕ್ತಿ ಪ್ರತ್ಯಯಗಳನ್ನು ಹೊಂದಿಸಿ (Match the case endings)',
      pairs: [
        (left: '-ಗೆ', right: 'to'),
        (left: '-ಇಂದ', right: 'from'),
        (left: '-ಜೊತೆ', right: 'with'),
        (left: '-ನ', right: "'s (possessive)"),
      ],
      explanation:
          'Kannada has no prepositions — nouns wear endings: ಮನೆಗೆ (home-to), ಊರಿಂದ (town-from), ರವಿಯ ಪುಸ್ತಕ (Ravi\'s book).',
    ),
    Exercise(
      id: 'ex_kn_gram3_2',
      lessonId: 'kn_grammar_cases',
      type: ExerciseType.mcq,
      prompt: "'ನಾನು ಬೆಂಗಳೂರಿಗೆ ಹೋಗುತ್ತೇನೆ' ಎಂದರೆ: "
          '(What does ನಾನು ಬೆಂಗಳೂರಿಗೆ ಹೋಗುತ್ತೇನೆ mean?)',
      options: [
        'I am going FROM Bengaluru',
        'I am going TO Bengaluru',
        'I am IN Bengaluru',
        'I am WITH Bengaluru',
      ],
      correctIndex: 1,
      explanation:
          '-ಗೆ marks direction: ಬೆಂಗಳೂರು + ಗೆ → ಬೆಂಗಳೂರಿಗೆ. From would be -ಇಂದ (ಬೆಂಗಳೂರಿನಿಂದ), in would be -ಅಲ್ಲಿ.',
    ),
    Exercise(
      id: 'ex_kn_gram3_3',
      lessonId: 'kn_grammar_cases',
      type: ExerciseType.fillBlank,
      prompt:
          'ಇದು ಅಜ್ಜಿ___ ಮನೆ. (This is grandmother\'s house — fill the possessive)',
      options: ['-ಗೆ', '-ಇಂದ', '-ಯ', '-ಜೊತೆ'],
      correctIndex: 2,
      explanation:
          'ಅಜ್ಜಿ + ಯ → ಅಜ್ಜಿಯ ಮನೆ. Vowel-final nouns take a glue -ಯ- before the possessive -ನ. Watch for the ಯ/ವ glue sounds.',
    ),
  ],

  'kn_grammar_politeness': const [
    Exercise(
      id: 'ex_kn_gram4_1',
      lessonId: 'kn_grammar_politeness',
      type: ExerciseType.matching,
      prompt: 'ಗೌರವ ರೂಪಗಳನ್ನು ಹೊಂದಿಸಿ (Match intimate to respectful)',
      pairs: [
        (left: 'ಬಾ', right: 'ಬನ್ನಿ (come)'),
        (left: 'ಕುಳಿತುಕೋ', right: 'ಕುಳಿತುಕೊಳ್ಳಿ (sit)'),
        (left: 'ಹೇಳು', right: 'ಹೇಳಿ (say)'),
        (left: 'ನೀನು', right: 'ನೀವು (you-resp)'),
      ],
      explanation:
          'Respect swaps the verb form, not just the pronoun: ಬಾ → ಬನ್ನಿ. A shop line: ಬನ್ನಿ, ಕುಳಿತುಕೊಳ್ಳಿ, ಏನು ಬೇಕು?',
    ),
    Exercise(
      id: 'ex_kn_gram4_2',
      lessonId: 'kn_grammar_politeness',
      type: ExerciseType.mcq,
      prompt: "'ನಿಧಾನವಾಗಿ ಮಾತನಾಡಿ' ಎಂದರೆ: "
          '(What does ನಿಧಾನವಾಗಿ ಮಾತನಾಡಿ mean?)',
      options: [
        'Please speak slowly',
        'Please speak loudly',
        'Please stop speaking',
        'Please speak English',
      ],
      correctIndex: 0,
      explanation:
          'ನಿಧಾನ = slowly/patiently. Together with ನನ್ನ ಕನ್ನಡ ಸ್ವಲ್ಪ ಸರಿ ಇಲ್ಲ (my Kannada isn\'t quite right), it is the learner\'s best pair of sentences.',
    ),
    Exercise(
      id: 'ex_kn_gram4_3',
      lessonId: 'kn_grammar_politeness',
      type: ExerciseType.mcq,
      prompt: 'ಗೌರವದ "ರವಿ" ಎಂದು ಹೇಗೆ ಕರೆಯುವುದು? '
          '(How is Ravi referred to RESPECTFULLY?)',
      options: ['ರವಿ', 'ರವಿ ಅವರು', 'ರವಿ ಅಣ್ಣ only', 'ಅದು'],
      correctIndex: 1,
      explanation:
          'ರವಿ ಅವರು (-ಅವರು attach) is the classic polite style — every announcement uses it. -ರು/-ಅವರು is the respect marker.',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_kn_reading)
  // ════════════════════════════════════════════════════════════════════

  'kn_reading_conversation': const [
    Exercise(
      id: 'ex_kn_read1_1',
      lessonId: 'kn_reading_conversation',
      type: ExerciseType.mcq,
      prompt: "ಮಾರುಕಟ್ಟೆ ಸಂಭಾಷಣೆ: 'ಸ್ವಲ್ಪ ಕಡಿಮೆ ಮಾಡಿ!' ಎಂದರೆ: "
          '(In the market dialogue, ಸ್ವಲ್ಪ ಕಡಿಮೆ ಮಾಡಿ! means…)',
      options: [
        'Make it a little less! (bargain)',
        'Give me more!',
        'I will pay full price',
        'Close the shop!',
      ],
      correctIndex: 0,
      explanation:
          'ಸ್ವಲ್ಪ = a little, ಕಡಿಮೆ = less. The universal bargain line, followed by the vendor\'s ಸರಿ (okay) and a new price.',
    ),
    Exercise(
      id: 'ex_kn_read1_2',
      lessonId: 'kn_reading_conversation',
      type: ExerciseType.mcq,
      prompt: "'ನಾನೂ ಬರುತ್ತೇನೆ' ಎಂದರೆ: (What does ನಾನೂ ಬರುತ್ತೇನೆ mean?)",
      options: [
        'I am not coming',
        'I too am coming',
        'You come too',
        'He comes'
      ],
      correctIndex: 1,
      explanation:
          'ನೂ = also/too, tagged on: ನಾನು + ನೂ → ನಾನೂ. From the friend dialogue: ನಾನೂ ಬರುತ್ತೇನೆ! — I\'ll come too!',
    ),
    Exercise(
      id: 'ex_kn_read1_3',
      lessonId: 'kn_reading_conversation',
      type: ExerciseType.mcq,
      prompt:
          "'-ತ್ತಿದ್ದೇನೆ' ಯಾವ ಕಾಲ? (The ending -ತ್ತಿದ್ದೇನೆ (ಹೋಗುತ್ತಿದ್ದೇನೆ) marks…)",
      options: [
        'the right-now continuous ("am going")',
        'the past ("went")',
        'a command ("go!")',
        'a question ("going?")',
      ],
      correctIndex: 0,
      explanation:
          'ಹೋಗುತ್ತಿದ್ದೇನೆ = "am going (right now)". The friend dialogue uses it: ನೀನು ಎಲ್ಲಿ ಹೋಗುತ್ತಿದ್ದೀಯ?',
    ),
  ],

  'kn_reading_paragraph': const [
    Exercise(
      id: 'ex_kn_read2_1',
      lessonId: 'kn_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'ಮೈಸೂರು ಪ್ರವಾಸ: ಬಸ್ ಪ್ರಯಾಣ ಎಷ್ಟು ಗಂಟೆ? '
          '(In the paragraph, how long is the bus ride?)',
      options: ['ಎರಡು ಗಂಟೆ', 'ಮೂರು ಗಂಟೆ', 'ಐದು ಗಂಟೆ', 'ಒಂದು ಗಂಟೆ'],
      correctIndex: 1,
      explanation:
          'ಬೆಂಗಳೂರಿನಿಂದ ಬಸ್ಸಿನಲ್ಲಿ ಮೂರು ಗಂಟೆ — three hours by bus from Bengaluru. ಮೂರು = three (you know it from numbers!).',
    ),
    Exercise(
      id: 'ex_kn_read2_2',
      lessonId: 'kn_reading_paragraph',
      type: ExerciseType.matching,
      prompt: 'ಪದಗಳನ್ನು ಹೊಂದಿಸಿ (Match words from the paragraph)',
      pairs: [
        (left: 'ಅರಮನೆ', right: 'palace'),
        (left: 'ಬೆಟ್ಟ', right: 'hill'),
        (left: 'ರುಚಿ', right: 'taste/delicious'),
        (left: 'ಕಳೆದ ವಾರ', right: 'last week'),
      ],
      explanation:
          'All four appear in the paragraph: ಅರಮನೆ ನೋಡಿದೆ, ಚಾಮುಂಡಿ ಬೆಟ್ಟ, ರುಚಿ!, ಕಳೆದ ವಾರ.',
    ),
    Exercise(
      id: 'ex_kn_read2_3',
      lessonId: 'kn_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'ಲೇಖಕ ಏನು ತಿಂದನು? (What did the writer eat?)',
      options: ['ದೋಸೆ', 'ಮೈಸೂರು ಪಾಕ್', 'ಪಾಸ್ಟಾ', 'ಪಲಾವ್'],
      correctIndex: 1,
      explanation:
          'ಮೈಸೂರು ಪಾಕ್ ತಿಂದೆ — ರುಚಿ! The famous Mysore pak sweet, eaten on the road down Chamundi Hill.',
    ),
  ],

  'kn_reading_proverbs': const [
    Exercise(
      id: 'ex_kn_read3_1',
      lessonId: 'kn_reading_proverbs',
      type: ExerciseType.matching,
      prompt: 'ಗಾದೆಗಳನ್ನು ಅರ್ಥದೊಂದಿಗೆ ಹೊಂದಿಸಿ (Match proverbs to meanings)',
      pairs: [
        (
          left: 'ಮಾತು ಬೆಳ್ಳಿ, ಮೌನ ಬಂಗಾರ',
          right: 'speech is silver, silence is gold'
        ),
        (left: 'ಬಿತ್ತಿದ ಬೀಜ', right: 'the sown seed (sprouts)'),
        (left: 'ಮೌನ', right: 'silence'),
        (left: 'ಬೀಜ', right: 'seed'),
      ],
      explanation:
          'Proverbs teach vocabulary plus worldview: ಬೆಳ್ಳಿ silver, ಬಂಗಾರ gold, ಬೀಜ seed, ಮೊಳಕೆ sprout.',
    ),
    Exercise(
      id: 'ex_kn_read3_2',
      lessonId: 'kn_reading_proverbs',
      type: ExerciseType.mcq,
      prompt: "'ಬಿತ್ತಿದ ಬೀಜ ಮೊಳಕೆಯೊಡೆಯುತ್ತದೆ' — ಈ ಗಾದೆ ಯಾವಾಗ? "
          '(When would you say "the sown seed sprouts"?)',
      options: [
        'When encouraging someone whose effort will show results',
        'When refusing food',
        'When it rains',
        'When greeting elders',
      ],
      correctIndex: 0,
      explanation:
          'It is the farmer\'s proverb for patient effort — perfect for a language learner. Practice is the seed; fluency is the sprout.',
    ),
    Exercise(
      id: 'ex_kn_read3_3',
      lessonId: 'kn_reading_proverbs',
      type: ExerciseType.mcq,
      prompt: 'ಗಾದೆಗಳಲ್ಲಿ ವಾಕ್ಯ ಕ್ರಮ: (Word order inside Kannada proverbs is…)',
      options: ['SVO', 'SOV (same as sentences)', 'random', 'VSO'],
      correctIndex: 1,
      explanation:
          'Proverbs keep SOV too — ಮಾತು (topic) first, the punch verb/noun last. Reading rhythm is half the memory.',
    ),
  ],

  'kn_reading_review': const [
    Exercise(
      id: 'ex_kn_read4_1',
      lessonId: 'kn_reading_review',
      type: ExerciseType.mcq,
      prompt: 'ಸಂಪೂರ್ಣ ಪಯಣ: ಕನ್ನಡದಲ್ಲಿ ವಾಕ್ಯ ಯಾವುದರಿಂದ ಮುಗಿಯುತ್ತದೆ? '
          '(Full journey recap: what closes EVERY Kannada sentence?)',
      options: ['the subject', 'the object', 'the verb', 'a question word'],
      correctIndex: 2,
      explanation:
          'SOV — the verb parks at the end in statements, routines, dialogues and even proverbs. That single rule holds the language together.',
    ),
    Exercise(
      id: 'ex_kn_read4_2',
      lessonId: 'kn_reading_review',
      type: ExerciseType.translation,
      prompt:
          'ಸ್ವಯಂ-ಪರೀಕ್ಷೆ: "ನನ್ನ ಹೆಸರು ___" — complete it with YOUR name (type any name)',
      acceptedAnswers: ['ನನ್ನ ಹೆಸರು', 'nanna hesaru'],
      explanation:
          'ನನ್ನ ಹೆಸರು + [your name]. The first sentence every learner says — and now you can build ten more around it.',
    ),
    Exercise(
      id: 'ex_kn_read4_3',
      lessonId: 'kn_reading_review',
      type: ExerciseType.mcq,
      prompt: 'ಓದಿ: ಸಂಸ್ಕೃತಿ, ಧೈರ್ಯ, ಸ್ವಾಗತ — ಯಾವುದು "ಧೈರ್ಯ"? '
          '(Of ಸಂಸ್ಕೃತಿ / ಧೈರ್ಯ / ಸ್ವಾಗತ — which one means courage?)',
      options: ['ಸಂಸ್ಕೃತಿ', 'ಧೈರ್ಯ', 'ಸ್ವಾಗತ', 'all three'],
      correctIndex: 1,
      explanation:
          'ಧೈರ್ಯ = courage (ರ್ಯ cluster inside). ಸಂಸ್ಕೃತಿ = culture, ಸ್ವಾಗತ = welcome. Three sight-words from the conjunct lesson.',
    ),
  ],
};
