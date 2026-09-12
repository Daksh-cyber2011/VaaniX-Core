/// Bengali Exercises — VaaniX Learn Mode Part B
///
/// Practice exercises for the Bengali curriculum
/// (assets/curriculum/learn/bn.json). Keyed by lesson id; the engine
/// ([exercise_models.dart]) renders them deterministically. Each lesson
/// has 3-4 exercises covering MCQ, fillBlank, matching, and translation.
///
/// Content note: every exercise is grounded in the actual lesson content.
/// Bengali examples are natural (not machine-translated from Hindi).
/// Explanations teach WHY an answer is correct, in Bengali where
/// appropriate.
library;

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Bengali exercises keyed by lesson id.
///
/// Lesson IDs are prefixed with `bn_` to stay globally unique across
/// all Learn Mode languages and the legacy Sanskrit Exam Mode curriculum.
final Map<String, List<Exercise>> bengaliExercisesByLesson = {
  // ════════════════════════════════════════════════════════════════════
  // Chapter 1: Bengali Script (ch_bn_script)
  // ════════════════════════════════════════════════════════════════════

  'bn_script_vowels': const [
    Exercise(
      id: 'ex_bn_vowels_1',
      lessonId: 'bn_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় কয়টি স্বরবর্ণ আছে?',
      options: ['১০', '১১', '১৩', '২০'],
      correctIndex: 1,
      explanation:
          'বাংলায় ১১টি স্বরবর্ণ আছে: অ আ ই ঈ উ ঊ এ ঐ ও ঔ ঋ। তবে আধুনিক উচ্চারণে কিছু স্বর একসাথে মিশে গেছে (যেমন ই ও ঈ একইভাবে শোনায়)।',
    ),
    Exercise(
      id: 'ex_bn_vowels_2',
      lessonId: 'bn_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'ই এবং ঈ এর মধ্যে উচ্চারণে কী পার্থক্য আছে?',
      options: [
        'ই ছোট, ঈ বড়',
        'কোনো পার্থক্য নেই — দুটোই /i/ শোনায়',
        'ই সংস্কৃত, ঈ বাংলা',
        'ই ব্যবহৃত হয় না',
      ],
      correctIndex: 1,
      explanation:
          'আধুনিক বাংলায় ই এবং ঈ একইভাবে উচ্চারিত হয় — দুটোই /i/ (যেমন "see" তে)। ঐতিহাসিক ছোট/বড় পার্থক্য হারিয়ে গেছে। এটি হিন্দি থেকে একটি বড় পার্থক্য।',
    ),
    Exercise(
      id: 'ex_bn_vowels_3',
      lessonId: 'bn_script_vowels',
      type: ExerciseType.mcq,
      prompt: 'আম শব্দে কোন স্বর আছে?',
      options: ['অ', 'আ', 'ই', 'এ'],
      correctIndex: 1,
      explanation: 'আম (ām) শব্দে আ স্বর আছে। আ এর মাত্রা া যা ম এর সাথে যুক্ত হয়ে মা বানায়।',
    ),
    Exercise(
      id: 'ex_bn_vowels_4',
      lessonId: 'bn_script_vowels',
      type: ExerciseType.matching,
      prompt: 'স্বরকে উদাহরণ শব্দের সাথে মিলান (Match vowel to example word)',
      pairs: [
        (left: 'অ', right: 'অন্য'),
        (left: 'আ', right: 'আম'),
        (left: 'এ', right: 'এক'),
        (left: 'ও', right: 'ওজু'),
      ],
      explanation:
          'প্রতিটি স্বরের নিজস্ব উদাহরণ শব্দ আছে। অন্য মে অ, আম মে আ, এক মে এ, ওজু মে ও স্বর আছে।',
    ),
  ],

  'bn_script_consonants': const [
    Exercise(
      id: 'ex_bn_consonants_1',
      lessonId: 'bn_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় শ, ষ, স — এই তিনটি ব্যঞ্জন কীভাবে উচ্চারিত হয়?',
      options: [
        'আলাদা: শ=/ɕ/, ষ=/ʂ/, স=/s/',
        'সব একইভাবে: /ʃ/ (sh)',
        'শ এবং ষ একই, স আলাদা',
        'সব একইভাবে: /s/',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় শ, ষ, স — তিনটিই /ʃ/ (sh) হিসেবে উচ্চারিত হয়। সংস্কৃত পার্থক্য বানানে সংরক্ষিত কিন্তু উচ্চারণে হারিয়ে গেছে। সংসার = "shongshar"।',
    ),
    Exercise(
      id: 'ex_bn_consonants_2',
      lessonId: 'bn_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'ব বর্ণের দুটি উচ্চারণ কী কী?',
      options: [
        '/b/ এবং /p/',
        '/b/ (শব্দের শুরুতে) এবং /w/ বা নীরব (মাঝে)',
        '/b/ এবং /v/',
        'শুধু /b/',
      ],
      correctIndex: 1,
      explanation:
          'ব শব্দের শুরুতে /b/ (বই = boi) কিন্তু মাঝে /w/ বা নরম (কবি = kobi, ব নরম)। এটি বাংলার একটি বিশেষ বৈশিষ্ট্য।',
    ),
    Exercise(
      id: 'ex_bn_consonants_3',
      lessonId: 'bn_script_consonants',
      type: ExerciseType.mcq,
      prompt: 'য এবং জ বর্ণের মধ্যে আধুনিক বাংলায় কী সম্পর্ক?',
      options: [
        'আলাদা: য=/y/, জ=/dʒ/',
        'দুটোই /dʒ/ (j) হিসেবে উচ্চারিত',
        'য ব্যবহৃত হয় না',
        'জ ব্যবহৃত হয় না',
      ],
      correctIndex: 1,
      explanation:
          'আধুনিক বাংলায় য এবং জ দুটোই /dʒ/ (j) হিসেবে উচ্চারিত হয়। যম = "jom", জল = "jol"। সংস্কৃত পার্থক্য হারিয়ে গেছে।',
    ),
  ],

  'bn_script_matras': const [
    Exercise(
      id: 'ex_bn_matras_1',
      lessonId: 'bn_script_matras',
      type: ExerciseType.mcq,
      prompt: 'কি তে কোন মাত্রা আছে?',
      options: ['ী (ঈ)', 'ি (ই)', 'ু (উ)', 'ে (এ)'],
      correctIndex: 1,
      explanation:
          'কি তে ই এর মাত্রা (ি) আছে। এটি একমাত্র মাত্রা যা ব্যঞ্জনের বাম দিকে যায়, কিন্তু ব্যঞ্জনের পরে পড়া হয়।',
    ),
    Exercise(
      id: 'ex_bn_matras_2',
      lessonId: 'bn_script_matras',
      type: ExerciseType.mcq,
      prompt: 'ক এর inherent vowel (অন্তর্নিহিত স্বর) কী?',
      options: ['/a/ (হিন্দির মতো)', '/o/ বা /ɔ/', '/i/', '/u/'],
      correctIndex: 1,
      explanation:
          'বাংলায় ক এর inherent vowel হলো /o/ বা /ɔ/ (হিন্দিতে /a/)। কল = "kol" (কাল নয়)। এটি হিন্দি থেকে একটি বড় পার্থক্য।',
    ),
    Exercise(
      id: 'ex_bn_matras_3',
      lessonId: 'bn_script_matras',
      type: ExerciseType.matching,
      prompt: 'মাত্রাকে সংযোগের সাথে মিলান (Match matra to result)',
      pairs: [
        (left: 'ক + া', right: 'কা'),
        (left: 'ক + ী', right: 'কী'),
        (left: 'ক + ো', right: 'কো'),
        (left: 'ক + ে', right: 'কে'),
      ],
      explanation:
          'প্রতিটি মাত্রা ব্যঞ্জনের সাথে যুক্ত হয়ে নতুন সংযোগ বানায়। া থেকে কা, ী থেকে কী, ো থেকে কো, ে থেকে কে।',
    ),
  ],

  'bn_script_barakhadi': const [
    Exercise(
      id: 'ex_bn_barakhadi_1',
      lessonId: 'bn_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'ম + া = ?',
      options: ['মি', 'মা', 'মে', 'মো'],
      correctIndex: 1,
      explanation: 'ম + া (আ মাত্রা) = মা। আ মাত্রা ব্যঞ্জনের পরে আসে।',
    ),
    Exercise(
      id: 'ex_bn_barakhadi_2',
      lessonId: 'bn_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: কবিতা',
      acceptedAnswers: ['kobitā', 'kobita', 'kobitaa'],
      explanation:
          'কবিতা = ক + বি + ত + া = ko-bi-tā = kobitā (poem)। ক এর inherent vowel /o/, ব এর সাথে ি মাত্রা থেকে বি, ত এর সাথে া থেকে তা।',
    ),
    Exercise(
      id: 'ex_bn_barakhadi_3',
      lessonId: 'bn_script_barakhadi',
      type: ExerciseType.translation,
      prompt: 'Romanize: ভাত',
      acceptedAnswers: ['bhāt', 'bhat', 'bhaat'],
      explanation:
          'ভাত = ভ + া + ত = bhā-to = bhāt (cooked rice)। ভ + া মাত্রা থেকে ভা, ত এর inherent /o/। ভাত বাঙালিদের প্রধান খাবার।',
    ),
    Exercise(
      id: 'ex_bn_barakhadi_4',
      lessonId: 'bn_script_barakhadi',
      type: ExerciseType.mcq,
      prompt: 'বই শব্দে কোন স্বর আছে?',
      options: ['অ', 'ঐ', 'ও', 'আ'],
      correctIndex: 1,
      explanation: 'বই তে ঐ স্বর আছে (কোনো মাত্রা ছাড়া, পূর্ণ রূপে)। ব + ঐ = বই (boi = book)।',
    ),
  ],

  'bn_script_conjuncts': const [
    Exercise(
      id: 'ex_bn_conjuncts_1',
      lessonId: 'bn_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'বাংলা শব্দে কোন চিহ্ন আছে যা /ng/ শব্দ তৈরি করে?',
      options: ['ঁ (চন্দ্রবিন্দু)', 'ং (অনুস্বার)', '্ (হসন্ত)', 'ঃ (বিসর্গ)'],
      correctIndex: 1,
      explanation:
          'ং (অনুস্বার) পরবর্তী ব্যঞ্জনকে নাসিক্য করে। বাংলা = ব + া + ং + ল + া — ং এখানে /ng/ শব্দ তৈরি করে (bang-la)।',
    ),
    Exercise(
      id: 'ex_bn_conjuncts_2',
      lessonId: 'bn_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'জ্ঞ কীভাবে উচ্চারিত হয় বাংলায়?',
      options: ['/jñ/ (সংস্কৃত)', '/gy/ (হিন্দি)', '/ggyo/ (বাংলা)', '/ña/'],
      correctIndex: 2,
      explanation:
          'বাংলায় জ্ঞ = /ggyo/। জ্ঞান (জ্ঞান) = "ggyan"। এটি সংস্কৃত /jñ/ এবং হিন্দি /gy/ থেকে আলাদা — বাংলার নিজস্ব উচ্চারণ।',
    ),
    Exercise(
      id: 'ex_bn_conjuncts_3',
      lessonId: 'bn_script_conjuncts',
      type: ExerciseType.mcq,
      prompt: 'হ্যালো শব্দে কোন বিশেষ চিহ্ন আছে?',
      options: [
        'য-ফলা (য এর ছোট রূপ)',
        'র-ফলা',
        'চন্দ্রবিন্দু',
        'বিসর্গ',
      ],
      correctIndex: 0,
      explanation:
          'হ্যালো তে য-ফলা আছে — হ এর নিচে ছোট য। এটি /y/ শব্দ তৈরি করে: hyālo (hello)। য-ফলা বাংলা ও অসমিয়ার বিশেষত্ব।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 2: Greetings & Introductions (ch_bn_greet)
  // ════════════════════════════════════════════════════════════════════

  'bn_greet_nomoskar': const [
    Exercise(
      id: 'ex_bn_nomoskar_1',
      lessonId: 'bn_greet_nomoskar',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় সবচেয়ে সাধারণ অভিবাদন কী?',
      options: ['সুপ্রভাত', 'নমস্কার', 'বিদায়', 'ধন্যবাদ'],
      correctIndex: 1,
      explanation:
          'নমস্কার সবচেয়ে সাধারণ বাংলা অভিবাদন। এটি যেকোনো সময়, যেকারও সাথে ব্যবহার করা যায়। উচ্চারণ "nomoshkar" — মনে রাখবেন স = /ʃ/ (sh)।',
    ),
    Exercise(
      id: 'ex_bn_nomoskar_2',
      lessonId: 'bn_greet_nomoskar',
      type: ExerciseType.mcq,
      prompt: '"কেমন আছেন?" এর অর্থ কী?',
      options: ['What is your name?', 'How are you? (formal)', 'Where are you?', 'Who are you?'],
      correctIndex: 1,
      explanation:
          'কেমন আছেন? = How are you? (formal/respectful)। আপনি (you, formal) এর সাথে আছেন (are) ব্যবহৃত হয়। অনানুষ্ঠানিক রূপ: কেমন আছো? (তুমি এর সাথে)।',
    ),
    Exercise(
      id: 'ex_bn_nomoskar_3',
      lessonId: 'bn_greet_nomoskar',
      type: ExerciseType.matching,
      prompt: 'অভিবাদনকে অর্থের সাথে মিলান (Match greeting to meaning)',
      pairs: [
        (left: 'নমস্কার', right: 'Hello / Greetings'),
        (left: 'শুভ সকাল', right: 'Good morning'),
        (left: 'শুভ রাত্রি', right: 'Good night'),
        (left: 'আবার দেখা হবে', right: 'See you again'),
      ],
      explanation:
          'প্রতিটি অভিবাদনের নিজস্ব অর্থ ও সময় আছে। নমস্কার সার্বজনীন, শুভ সকাল সকালে, শুভ রাত্রি রাতে, আবার দেখা হবে বিদায়ের সময়।',
    ),
  ],

  'bn_greet_intro': const [
    Exercise(
      id: 'ex_bn_intro_1',
      lessonId: 'bn_greet_intro',
      type: ExerciseType.translation,
      prompt: 'Translate: আমার নাম রাহুল।',
      acceptedAnswers: [
        'My name is Rahul',
        'My name is Rahul.',
      ],
      explanation:
          'আমার নাম রাহুল = My name is Rahul। আমার = my, নাম = name। বাংলায় ক্রিয়া (হয়/আছে) প্রায়ই বাদ দেওয়া হয় সমীকরণমূলক বাক্যে।',
    ),
    Exercise(
      id: 'ex_bn_intro_2',
      lessonId: 'bn_greet_intro',
      type: ExerciseType.mcq,
      prompt: '"আপনি কোথায় থাকেন?" এর অর্থ কী?',
      options: ['What is your name?', 'Where do you live?', 'How are you?', 'When are you coming?'],
      correctIndex: 1,
      explanation:
          'আপনি কোথায় থাকেন? = Where do you live? (formal)। কোথায় = where, থাকেন = live (respectful)। অনানুষ্ঠানিক: তুমি কোথায় থাকো?',
    ),
    Exercise(
      id: 'ex_bn_intro_3',
      lessonId: 'bn_greet_intro',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় "I am a student" (male) কীভাবে বলবেন?',
      options: ['আমি ছাত্র।', 'আমি ছাত্রী।', 'আমি শিক্ষক।', 'আমি শিক্ষিকা।'],
      correctIndex: 0,
      explanation:
          'পুরুষ ছাত্র = ছাত্র (chhatro)। নারী = ছাত্রী (chhatri)। তবে মনে রাখবেন — বাংলায় ক্রিয়া লিঙ্গ অনুসারে পরিবর্তিত হয় না (হিন্দির মতো নয়)।',
    ),
  ],

  'bn_greet_family': const [
    Exercise(
      id: 'ex_bn_family_1',
      lessonId: 'bn_greet_family',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় দাদা কাকে বলা হয়?',
      options: [
        'পিতার বাবা (paternal grandfather)',
        'বড় ভাই (older brother)',
        'মায়ের বাবা (maternal grandfather)',
        'ছোট ভাই',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় দাদা = বড় ভাই (older brother)। কিন্তু হিন্দিতে दादা = paternal grandfather! এটি একটি গুরুত্বপূর্ণ পার্থক্য — বাংলা ও হিন্দির কুটুম্ব শব্দ আলাদা।',
    ),
    Exercise(
      id: 'ex_bn_family_2',
      lessonId: 'bn_greet_family',
      type: ExerciseType.mcq,
      prompt: '"আমার একটা দিদি আছে" এর অর্থ কী?',
      options: [
        'I have one older sister',
        'I have one younger sister',
        'I have one brother',
        'I have one mother',
      ],
      correctIndex: 0,
      explanation:
          'আমার একটা দিদি আছে = I have one older sister। দিদি = older sister। বাংলায় বড় বোনকে নাম ধরে ডাকা অশিষ্ট — দিদি বলাই শিষ্ট।',
    ),
    Exercise(
      id: 'ex_bn_family_3',
      lessonId: 'bn_greet_family',
      type: ExerciseType.matching,
      prompt: 'কুটুম্ব শব্দকে অর্থের সাথে মিলান (Match kinship to meaning)',
      pairs: [
        (left: 'ঠাকুরমা', right: 'paternal grandmother'),
        (left: 'দিদামা', right: 'maternal grandmother'),
        (left: 'কাকা', right: "father's younger brother"),
        (left: 'মেসো', right: "mother's brother"),
      ],
      explanation:
          'বাংলা কুটুম্ব শব্দ হিন্দির চেয়ে আলাদা। ঠাকুরমা = পিতার মা, দিদামা = মায়ের মা, কাকা = পিতার ছোট ভাই, মেসো = মায়ের ভাই।',
    ),
  ],

  'bn_greet_numbers': const [
    Exercise(
      id: 'ex_bn_numbers_1',
      lessonId: 'bn_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় ৫ কী?',
      options: ['চার', 'পাঁচ', 'ছয়', 'সাত'],
      correctIndex: 1,
      explanation: '৫ = পাঁচ (pānch)। ৪ = চার, ৬ = ছয়। বাংলা সংখ্যা দেবনাগরি থেকে আলাদা দেখতে।',
    ),
    Exercise(
      id: 'ex_bn_numbers_2',
      lessonId: 'bn_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'বিশ কত?',
      options: ['১২', '১৫', '২০', '২৫'],
      correctIndex: 2,
      explanation: 'বিশ (bish) = ২০। ১২ = বারো, ১৫ = পনেরো, ২৫ = পঁচিশ।',
    ),
    Exercise(
      id: 'ex_bn_numbers_3',
      lessonId: 'bn_greet_numbers',
      type: ExerciseType.matching,
      prompt: 'সংখ্যাকে বাংলা নামের সাথে মিলান (Match number to Bengali name)',
      pairs: [
        (left: '1', right: 'এক'),
        (left: '3', right: 'তিন'),
        (left: '7', right: 'সাত'),
        (left: '10', right: 'দশ'),
      ],
      explanation:
          'এক=1, তিন=3, সাত=7, দশ=10। এই বেসিক সংখ্যাগুলি প্রতিটি বাংলা শিখনার্থীর জানা উচিত।',
    ),
    Exercise(
      id: 'ex_bn_numbers_4',
      lessonId: 'bn_greet_numbers',
      type: ExerciseType.mcq,
      prompt: 'লক্ষ কত?',
      options: ['1,000', '10,000', '100,000', '1,000,000'],
      correctIndex: 2,
      explanation:
          'লক্ষ (lokho) = 100,000। কোটি (koti) = 10,000,000। বাংলায় লক্ষ উচ্চারণ /lok-kho/, হিন্দিতে लाख /lākh/।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 3: Daily Life (ch_bn_daily)
  // ════════════════════════════════════════════════════════════════════

  'bn_daily_sentences': const [
    Exercise(
      id: 'ex_bn_sentences_1',
      lessonId: 'bn_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় বাক্য রচনার ক্রম কী?',
      options: ['SVO', 'SOV', 'VSO', 'OSV'],
      correctIndex: 1,
      explanation:
          'বাংলায় Subject-Object-Verb (SOV) ক্রম। যেমন: আমি (S) ভাত (O) খাই (V)। হিন্দির মতোই, কিন্তু ইংরেজির বিপরীত।',
    ),
    Exercise(
      id: 'ex_bn_sentences_2',
      lessonId: 'bn_daily_sentences',
      type: ExerciseType.translation,
      prompt: 'Translate: আমি ভাত খাই।',
      acceptedAnswers: [
        'I eat rice',
        'I eat rice.',
      ],
      explanation:
          'আমি ভাত খাই = I eat rice। SOV: আমি (I) ভাত (rice) খাই (eat)। বাংলায় ভাত = cooked rice (হিন্দি: चावल)।',
    ),
    Exercise(
      id: 'ex_bn_sentences_3',
      lessonId: 'bn_daily_sentences',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় ক্রিয়া কি লিঙ্গ অনুসারে পরিবর্তিত হয়?',
      options: [
        'হ্যাঁ, হিন্দির মতো',
        'না, ক্রিয়া লিঙ্গ-নিরপেক্ষ',
        'শুধু অতীত কালে',
        'শুধু বর্তমান কালে',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় ক্রিয়া লিঙ্গ-নিরপেক্ষ! আমি যাই = I go — পুরুষ বা নারী যেকোনো বক্তার জন্য একই। এটি হিন্দির চেয়ে বড় সরলীকরণ।',
    ),
  ],

  'bn_daily_questions': const [
    Exercise(
      id: 'ex_bn_questions_1',
      lessonId: 'bn_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"কোথায়" এর অর্থ কী?',
      options: ['What', 'Who', 'Where', 'When'],
      correctIndex: 2,
      explanation: 'কোথায় (kothay) = where। যেমন: আপনি কোথায় যান? = Where do you go?',
    ),
    Exercise(
      id: 'ex_bn_questions_2',
      lessonId: 'bn_daily_questions',
      type: ExerciseType.mcq,
      prompt: '"কেন" এর অর্থ কী?',
      options: ['How', 'Why', 'What', 'Who'],
      correctIndex: 1,
      explanation: 'কেন (keno) = why। উত্তর সাধারণত কারণ (because) দিয়ে শুরু হয়।',
    ),
    Exercise(
      id: 'ex_bn_questions_3',
      lessonId: 'bn_daily_questions',
      type: ExerciseType.translation,
      prompt: 'Translate: আপনি কোথা থেকে এসেছেন?',
      acceptedAnswers: [
        'Where have you come from',
        'Where have you come from?',
        'Where are you from',
      ],
      explanation:
          'আপনি কোথা থেকে এসেছেন? = Where have you come from? (formal)। কোথা = where, থেকে = from।',
    ),
  ],

  'bn_daily_negation': const [
    Exercise(
      id: 'ex_bn_negation_1',
      lessonId: 'bn_daily_negation',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় ক্রিয়া নিষেধ করতে না কোথায় বসে?',
      options: [
        'ক্রিয়ার আগে (হিন্দির মতো)',
        'ক্রিয়ার পরে',
        'বাক্যের শুরুতে',
        'বাক্যের শেষে আলাদা',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় না ক্রিয়ার পরে বসে: আমি যাই না (I don\'t go)। হিন্দিতে নहीং ক্রিয়ার আগে বসে: मैं नहीं जाता। এটি একটি গুরুত্বপূর্ণ গাঠনিক পার্থক্য।',
    ),
    Exercise(
      id: 'ex_bn_negation_2',
      lessonId: 'bn_daily_negation',
      type: ExerciseType.mcq,
      prompt: '"সে ডাক্তার" বাক্যটি নিষেধাত্মক করুন।',
      options: [
        'সে ডাক্তার না।',
        'সে ডাক্তার নয়।',
        'সে না ডাক্তার।',
        'সে ডাক্তার নাই।',
      ],
      correctIndex: 1,
      explanation:
          'সে ডাক্তার নয় = He/She is not a doctor। নয় (noy) = "is not" — সমীকরণমূলক বাক্যে ব্যবহৃত। ক্রিয়া নিষেধে না ব্যবহৃত হয়, কিন্তু "is not" এ নয়।',
    ),
    Exercise(
      id: 'ex_bn_negation_3',
      lessonId: 'bn_daily_negation',
      type: ExerciseType.translation,
      prompt: 'Make negative: আমি যাই।',
      acceptedAnswers: [
        'আমি যাই না',
        'আমি যাই না।',
      ],
      explanation:
          'আমি যাই → আমি যাই না। না ক্রিয়ার পরে বসে (হিন্দির বিপরীতে)।',
    ),
  ],

  'bn_daily_routine': const [
    Exercise(
      id: 'ex_bn_routine_1',
      lessonId: 'bn_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"আমি রোজ সকালে ছয়টায় উঠি" — এটি কোন কাল?',
      options: ['অতীত কাল', 'বর্তমান কাল', 'ভবিষ্যৎ কাল', 'কোনোটি না'],
      correctIndex: 1,
      explanation:
          'এটি বর্তমান কাল (present habitual)। "রোজ" (daily) নির্দেশ করে যে এটি নিয়মিত ক্রিয়া। উঠি = I wake up (regularly)।',
    ),
    Exercise(
      id: 'ex_bn_routine_2',
      lessonId: 'bn_daily_routine',
      type: ExerciseType.mcq,
      prompt: '"গোসল করা" এর অর্থ কী?',
      options: ['To eat', 'To bathe', 'To sleep', 'To study'],
      correctIndex: 1,
      explanation: 'গোসল করা (goshol kora) = to bathe। গোসল করি = I bathe।',
    ),
    Exercise(
      id: 'ex_bn_routine_3',
      lessonId: 'bn_daily_routine',
      type: ExerciseType.matching,
      prompt: 'ক্রিয়াকে অর্থের সাথে মিলান (Match activity to meaning)',
      pairs: [
        (left: 'স্কুলে যাওয়া', right: 'to go to school'),
        (left: 'ভাত খাওয়া', right: 'to eat rice'),
        (left: 'ঘুমানো', right: 'to sleep'),
        (left: 'পড়াশোনা করা', right: 'to study'),
      ],
      explanation:
          'এই ক্রিয়াগুলি দৈনন্দিন জীবনের বেসিক। স্কুলে যাওয়া, ভাত খাওয়া, ঘুমানো, পড়াশোনা করা।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 4: Grammar (ch_bn_grammar)
  // ════════════════════════════════════════════════════════════════════

  'bn_grammar_pronouns': const [
    Exercise(
      id: 'ex_bn_pronouns_1',
      lessonId: 'bn_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'সম্মানজনক "আপনি" এর সাথে কোন ক্রিয়া রূপ ব্যবহৃত হয়?',
      options: ['-ি (-i)', '-ো (-o)', '-েন (-en)', '-ে (-e)'],
      correctIndex: 2,
      explanation:
          'আপনি এর সাথে -েন (-en) এর ক্রিয়া রূপ ব্যবহৃত হয়: আপনি করেন (you do, respectful)। তুমি এর সাথে -ো: তুমি করো।',
    ),
    Exercise(
      id: 'ex_bn_pronouns_2',
      lessonId: 'bn_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: '"আমাকে" কিসের সমতুল্য?',
      options: ['আমি + কে (to me)', 'তুমি + কে', 'সে + কে', 'আমরা + কে'],
      correctIndex: 0,
      explanation:
          'আমাকে = আমি + কে (to me)। যেমন: আমাকে চা দাও (Give me tea)। এটি oblique রূপ — postposition কে এর সাথে ব্যবহৃত।',
    ),
    Exercise(
      id: 'ex_bn_pronouns_3',
      lessonId: 'bn_grammar_pronouns',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় "সে" কাকে বোঝায়?',
      options: [
        'শুধু পুরুষ (he)',
        'শুধু নারী (she)',
        'পুরুষ, নারী, বা বস্তু (he/she/it)',
        'শুধু বস্তু (it)',
      ],
      correctIndex: 2,
      explanation:
          'বাংলায় সে = he/she/it — লিঙ্গ-নিরপেক্ষ! এটি হিন্দির চেয়ে বড় সরলীকরণ। হিন্দিতে ঵ह পুরুষ/নারী উভয়ের জন্য, কিন্তু ক্রিয়া লিঙ্গ দেখায়। বাংলায় ক্রিয়াও নিরপেক্ষ।',
    ),
  ],

  'bn_grammar_tenses': const [
    Exercise(
      id: 'ex_bn_tenses_1',
      lessonId: 'bn_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"আমি গেলাম" — এটি কোন কাল?',
      options: ['বর্তমান', 'অতীত', 'ভবিষ্যৎ', 'আজ্ঞার্থ'],
      correctIndex: 1,
      explanation:
          'আমি গেলাম = I went (past tense)। অতীত কালে -লাম (-lam) প্রথম পুরুষের শেষ। বর্তমান: আমি যাই। ভবিষ্যৎ: আমি যাব।',
    ),
    Exercise(
      id: 'ex_bn_tenses_2',
      lessonId: 'bn_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: '"আমি যাব" — এটি কোন কাল?',
      options: ['বর্তমান', 'অতীত', 'ভবিষ্যৎ', 'হাল'],
      correctIndex: 2,
      explanation:
          'আমি যাব = I will go (future)। -ব (-bo) প্রথম পুরুষের ভবিষ্যৎ কালের শেষ।',
    ),
    Exercise(
      id: 'ex_bn_tenses_3',
      lessonId: 'bn_grammar_tenses',
      type: ExerciseType.mcq,
      prompt: 'হিন্দির नে (past tense subject marker) এর বাংলায় সমতুল্য কী?',
      options: [
        'না',
        'কে',
        'কোনোটিই নেই — বাংলায় নে মার্কার নেই',
        'এ',
      ],
      correctIndex: 2,
      explanation:
          'বাংলায় নে মার্কার নেই! হিন্দিতে मैंने खायা (I ate, transitive past) — বাংলায় শুধু আমি খেলাম। এটি বাংলার একটি বড় সরলীকরণ।',
    ),
    Exercise(
      id: 'ex_bn_tenses_4',
      lessonId: 'bn_grammar_tenses',
      type: ExerciseType.translation,
      prompt: 'Future tense: আমি যাই।',
      acceptedAnswers: [
        'আমি যাব',
        'আমি যাব।',
      ],
      explanation:
          'বর্তমান: আমি যাই → ভবিষ্যৎ: আমি যাব (I will go)। -ি → -ব।',
    ),
  ],

  'bn_grammar_postpositions': const [
    Exercise(
      id: 'ex_bn_post_1',
      lessonId: 'bn_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"বাড়িতে" এর অর্থ কী?',
      options: ['on the house', 'in the house', 'from the house', 'to the house'],
      correctIndex: 1,
      explanation:
          'বাড়িতে (barite) = in the house। -এ (-e) locative case marker — ব্যঞ্জনের পরে। এটি বাংলার বিশেষত্ব (হিন্দিতে নেই)।',
    ),
    Exercise(
      id: 'ex_bn_post_2',
      lessonId: 'bn_grammar_postpositions',
      type: ExerciseType.mcq,
      prompt: '"কলকাতা থেকে" এর অর্থ কী?',
      options: ['to Kolkata', 'in Kolkata', 'from Kolkata', 'near Kolkata'],
      correctIndex: 2,
      explanation:
          'থেকে (theke) = from। কলকাতা থেকে = from Kolkata। থেকে হিন্দির से (se) এর সমতুল্য কিন্তু আলাদা শব্দ।',
    ),
    Exercise(
      id: 'ex_bn_post_3',
      lessonId: 'bn_grammar_postpositions',
      type: ExerciseType.translation,
      prompt: 'Translate: টেবিলে',
      acceptedAnswers: [
        'on the table',
        'On the table',
        'on the table',
      ],
      explanation: 'টেবিলে (ṭebile) = on the table। -এ (locative) টেবিল এর সাথে।',
    ),
    Exercise(
      id: 'ex_bn_post_4',
      lessonId: 'bn_grammar_postpositions',
      type: ExerciseType.matching,
      prompt: 'Postposition কে অর্থের সাথে মিলান (Match postposition to meaning)',
      pairs: [
        (left: '-এ / -য়', right: 'in / at'),
        (left: '-কে', right: 'to'),
        (left: '-থেকে', right: 'from'),
        (left: '-দিয়ে', right: 'by / with'),
      ],
      explanation:
          '-এ/-য় = in/at (locative), -কে = to, -থেকে = from, -দিয়ে = by/with। এই চারটি বেসিক postposition বাংলায় সবচেয়ে বেশি ব্যবহৃত।',
    ),
  ],

  'bn_grammar_no_gender': const [
    Exercise(
      id: 'ex_bn_nogender_1',
      lessonId: 'bn_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় ক্রিয়া কি লিঙ্গ অনুসারে পরিবর্তিত হয়?',
      options: [
        'হ্যাঁ, হিন্দির মতো (जाता हूँ vs जाती हूँ)',
        'না, বাংলায় ক্রিয়া লিঙ্গ-নিরপেক্ষ',
        'শুধু বর্তমান কালে',
        'শুধু অতীত কালে',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় ক্রিয়া লিঙ্গ-নিরপেক্ষ! আমি যাই = I go — পুরুষ বা নারী যেকোনো বক্তার জন্য একই। হিন্দিতে मैं जाता हूँ (পুরুষ) vs मैं जाती हूँ (নারী)।',
    ),
    Exercise(
      id: 'ex_bn_nogender_2',
      lessonId: 'bn_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: '"ভালো ছেলে" এবং "ভালো মেয়ে" — এখানে ভালো শব্দটি কীভাবে পরিবর্তিত হয়?',
      options: [
        'ভালো → ভালী (নারীর সাথে)',
        'ভালো অপরিবর্তিত থাকে — লিঙ্গ-নিরপেক্ষ',
        'ভালো → ভালে (নারীর সাথে)',
        'ভালো → ভালা (নারীর সাথে)',
      ],
      correctIndex: 1,
      explanation:
          'বাংলায় বিশেষণ লিঙ্গ-নিরপেক্ষ! ভালো ছেলে (good boy) এবং ভালো মেয়ে (good girl) — ভালো অপরিবর্তিত। হিন্দিতে अच्छा/अच्छী পরিবর্তিত হয়।',
    ),
    Exercise(
      id: 'ex_bn_nogender_3',
      lessonId: 'bn_grammar_no_gender',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় নির্দিষ্টতা বোঝাতে কোন প্রত্যয় ব্যবহৃত হয় (যেমন "the")?',
      options: ['-রা (-ra)', '-টা (-ṭa)', '-গুলো (-gulo)', 'কোনোটিই নয়'],
      correctIndex: 1,
      explanation:
          '-টা (-ṭa) definite article হিসেবে কাজ করে: ছেলেটা (the boy), বইটা (the book)। বাংলায় definite article আছে — হিন্দিতে নেই! এটি ইংরেজির সাথে মিল রাখে।',
    ),
  ],

  // ════════════════════════════════════════════════════════════════════
  // Chapter 5: Reading (ch_bn_reading)
  // ════════════════════════════════════════════════════════════════════

  'bn_reading_conversation': const [
    Exercise(
      id: 'ex_bn_conv_1',
      lessonId: 'bn_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"ভাইয়া, আলু কত দাম?" — এটি কোন পরিস্থিতিতে বলা হয়?',
      options: [
        'বন্ধুর সাথে দেখা হলে',
        'সবজি কেনার সময় দোকানদারের সাথে',
        'ঘরে রান্না করার সময়',
        'রেস্তোরাঁয় অর্ডার করার সময়',
      ],
      correctIndex: 1,
      explanation:
          'ভাইয়া (brother) দোকানদারকে সম্বোধন করার একটি উষ্ণ উপায়। আলু কত দাম? = How much are the potatoes? বাজারে দরদাম প্রত্যাশিত।',
    ),
    Exercise(
      id: 'ex_bn_conv_2',
      lessonId: 'bn_reading_conversation',
      type: ExerciseType.mcq,
      prompt: '"যাব?" এর অর্থ কী সংলাপে?',
      options: [
        'Let\'s walk',
        'Shall we go?',
        'Are you walking?',
        'Walk!',
      ],
      correctIndex: 1,
      explanation:
          'যাব? (yabo?) = Shall we go? / Let\'s go — পরামর্শ দেওয়ার উপায়। শান্তিনিকেতন যাব? = Shall we go to Shantiniketan?',
    ),
    Exercise(
      id: 'ex_bn_conv_3',
      lessonId: 'bn_reading_conversation',
      type: ExerciseType.translation,
      prompt: 'Translate: সকাল ছয়টায় দেখা হচ্ছে।',
      acceptedAnswers: [
        'See you at six in the morning',
        'See you at 6 AM',
        'We will meet at six in the morning',
      ],
      explanation:
          'সকাল ছয়টায় দেখা হচ্ছে = See you at six in the morning। দেখা হচ্ছে = we will meet / see you (literally: meeting is happening)।',
    ),
  ],

  'bn_reading_paragraph': const [
    Exercise(
      id: 'ex_bn_para_1',
      lessonId: 'bn_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'কলকাতাকে কী বলা হয় passage 1 এ?',
      options: [
        'হারিত নগরী',
        'সাংস্কৃতিক রাজধানী',
        'সাদা নগরী',
        'নীল নগরী',
      ],
      correctIndex: 1,
      explanation:
          'Passage 1 বলে: "কলকাতাকে সাংস্কৃতিক রাজধানী বলা হয়।" কারণ এখানে সাহিত্য, শিল্প, চলচ্চিত্র, থিয়েটারের চর্চা বহু শতক ধরে চলে আসছে।',
    ),
    Exercise(
      id: 'ex_bn_para_2',
      lessonId: 'bn_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'পয়লা বৈশাখ কখন পড়ে passage 2 অনুসারে?',
      options: [
        'মার্চ মাসে',
        'এপ্রিল মাসের মাঝামাঝি',
        'মে মাসে',
        'জানুয়ারিতে',
      ],
      correctIndex: 1,
      explanation:
          'Passage 2 বলে: "এটি সাধারণত এপ্রিল মাসের মাঝামাঝি পড়ে।" পয়লা বৈশাখ = Bengali New Year, এপ্রিল মাসের মাঝামাঝি।',
    ),
    Exercise(
      id: 'ex_bn_para_3',
      lessonId: 'bn_reading_paragraph',
      type: ExerciseType.mcq,
      prompt: 'বাঙালিদের প্রধান খাবার কী passage 3 অনুসারে?',
      options: ['রুটি', 'ভাত', 'মাছ', 'মাংস'],
      correctIndex: 1,
      explanation:
          'Passage 3 বলে: "ভাত হলো বাঙালিদের প্রধান খাবার।" দুপুরে আর রাতে ভাত খাওয়া হয়। মাছের ঝোল, শুক্তো, ডাল — সবই ভাতের সাথে।',
    ),
  ],

  'bn_reading_review': const [
    Exercise(
      id: 'ex_bn_review_1',
      lessonId: 'bn_reading_review',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় বাক্য রচনার ক্রম কী?',
      options: ['SVO', 'SOV', 'VSO', 'OVS'],
      correctIndex: 1,
      explanation:
          'Subject-Object-Verb (SOV)। আমি (S) ভাত (O) খাই (V)। এটি বাংলার সবচেয়ে গুরুত্বপূর্ণ গাঠনিক নিয়ম।',
    ),
    Exercise(
      id: 'ex_bn_review_2',
      lessonId: 'bn_reading_review',
      type: ExerciseType.mcq,
      prompt: 'বাংলায় ক্রিয়া নিষেধ করতে না কোথায় বসে?',
      options: [
        'ক্রিয়ার আগে',
        'ক্রিয়ার পরে',
        'বাক্যের শুরুতে',
        'কোথাও না',
      ],
      correctIndex: 1,
      explanation: 'না ক্রিয়ার পরে বসে: আমি যাই না (I don\'t go)। হিন্দির বিপরীতে।',
    ),
    Exercise(
      id: 'ex_bn_review_3',
      lessonId: 'bn_reading_review',
      type: ExerciseType.mcq,
      prompt: 'বাংলার সবচেয়ে বড় সরলীকরণ কী হিন্দির তুলনায়?',
      options: [
        'কোনো লিঙ্গ নেই',
        'কোনো কাল নেই',
        'কোনো postposition নেই',
        'কোনো সর্বনাম নেই',
      ],
      correctIndex: 0,
      explanation:
          'বাংলায় কোনো গ্রামাটিক্যাল লিঙ্গ নেই! ক্রিয়া, বিশেষণ, সর্বনাম — কিছুই লিঙ্গ অনুসারে পরিবর্তিত হয় না। এটি হিন্দি শিখনার্থীদের জন্য বড় সাহায্য।',
    ),
    Exercise(
      id: 'ex_bn_review_4',
      lessonId: 'bn_reading_review',
      type: ExerciseType.translation,
      prompt: 'Translate: আমার নাম _____।',
      acceptedAnswers: [
        'My name is _____',
      ],
      explanation:
          'আমার নাম _____ = My name is _____। এটি বেসিক পরিচয় বাক্য যা প্রতিটি বাংলা শিখনার্থী জানে।',
    ),
  ],
};
