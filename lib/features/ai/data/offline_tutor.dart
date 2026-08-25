/// VaaniX AI - Offline Sanskrit Tutor (Learn V1)
///
/// A dependency-free, intent-aware tutoring layer used by the offline
/// adapter so the AI seam stays genuinely useful when no remote model is
/// configured. Every piece of content below is GROUNDED in the seeded
/// curriculum (vowels, consonants, barakhadi, greetings, family, numbers,
/// intro and questions lessons): no vocabulary or grammar claim is
/// invented here.
///
/// Devanagari is spelled with `\uXXXX` escapes so the source file stays
/// robust across editors, diff tools and encodings.
///
/// When a request falls outside the grounded knowledge the tutor says so
/// honestly and points the learner at the right lesson - it never pretends
/// to know something it does not.

/// The intent categories the offline tutor can safely serve.
enum OfflineIntent {
  greeting,
  thanks,
  identity,
  practice,
  translate,
  grammar,
  numbers,
  greetingsTopic,
  familyTopic,
  correction,
  encouragement,
  orientation,
}

/// A single vocabulary entry grounded in the seeded lessons.
class OfflinePhrase {
  const OfflinePhrase(this.devanagari, this.roman, this.english);

  final String devanagari;
  final String roman;
  final String english;
}

/// A practice question the offline tutor can ask, grade and explain.
class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.question,
    required this.answerTokens,
    required this.hint,
    required this.explanation,
  });

  final String id;

  /// Display text (the question already carries a "Practice:" prefix so the
  /// adapter can detect an outstanding question from the transcript alone).
  final String question;

  /// Lowercased substrings that count as a correct answer (Devanagari,
  /// romanised and English forms).
  final List<String> answerTokens;

  final String hint;

  /// Short explanation shown after a correct answer.
  final String explanation;
}

/// The outcome of one offline tutoring turn.
class OfflineTutorReply {
  const OfflineTutorReply({required this.text, this.nextQuestion});

  final String text;

  /// When non-null, the tutor asked (or re-asked) this question and is now
  /// waiting for an answer.
  final PracticeQuestion? nextQuestion;
}

/// The offline tutoring engine. Pure logic - no Flutter, no I/O - so it is
/// fully unit-testable and shared by [OfflineModelAdapter].
class OfflineTutor {
  const OfflineTutor();

  // ---------------------------------------------------------------------
  // Grounded vocabulary (Devanagari as \uXXXX escapes)
  // ---------------------------------------------------------------------

  static const String _namaste = '\u0928\u092E\u0938\u094D\u0924\u0947';
  static const String _suprabhatam =
      '\u0938\u0941\u092A\u094D\u0930\u092D\u093E\u0924\u092E\u094D';
  static const String _shubhaSayam =
      '\u0936\u0941\u092D \u0938\u093E\u092F\u092E\u094D';
  static const String _shubharatrih =
      '\u0936\u0941\u092D\u0930\u093E\u0924\u094D\u0930\u093F\u0903';
  static const String _dhanyavadah =
      '\u0927\u0928\u094D\u092F\u0935\u093E\u0926\u0903';
  static const String _kripaya = '\u0915\u0943\u092A\u092F\u093E';
  static const String _maapha =
      '\u092E\u093E\u092B \u0915\u0941\u0930\u0941\u0924\u0947';

  static const List<OfflinePhrase> _greetings = [
    OfflinePhrase(_namaste, 'namaste', 'Hello / I bow to you'),
    OfflinePhrase(_suprabhatam, 'suprabhatam', 'Good morning'),
    OfflinePhrase(_shubhaSayam, 'shubha sayam', 'Good evening'),
    OfflinePhrase(_shubharatrih, 'shubharatrih', 'Good night'),
    OfflinePhrase(_dhanyavadah, 'dhanyavadah', 'Thank you'),
    OfflinePhrase(_kripaya, 'kripaya', 'Please'),
    OfflinePhrase(_maapha, 'maapha kurute', 'Excuse me / Sorry'),
  ];

  static const List<OfflinePhrase> _family = [
    OfflinePhrase('\u092E\u093E\u0924\u093E', 'maataa', 'Mother'),
    OfflinePhrase('\u092A\u093F\u0924\u093E', 'pitaa', 'Father'),
    OfflinePhrase('\u092A\u0941\u0924\u094D\u0930\u0903', 'putrah', 'Son'),
    OfflinePhrase('\u092A\u0941\u0924\u094D\u0930\u0940', 'putri', 'Daughter'),
    OfflinePhrase(
        '\u092D\u094D\u0930\u093E\u0924\u093E', 'bhraataa', 'Brother'),
    OfflinePhrase('\u092D\u0917\u093F\u0928\u0940', 'bhagini', 'Sister'),
    OfflinePhrase('\u092A\u0924\u094D\u0928\u0940', 'patni', 'Wife'),
    OfflinePhrase('\u092A\u0924\u093F\u0903', 'patih', 'Husband'),
    OfflinePhrase('\u092A\u093F\u0924\u093E\u092E\u0939\u0903', 'pitaamahah',
        'Grandfather (father\'s side)'),
    OfflinePhrase('\u092A\u093F\u0924\u093E\u092E\u0939\u0940', 'pitaamahi',
        'Grandmother (father\'s side)'),
    OfflinePhrase('\u092E\u093E\u0924\u0941\u0932\u0903', 'maatulah',
        'Uncle (mother\'s brother)'),
    OfflinePhrase('\u092A\u093F\u0924\u0943\u0935\u094D\u092F\u0903',
        'pitrivyah', 'Uncle (father\'s brother)'),
    OfflinePhrase('\u092E\u093E\u0924\u0941\u0932\u0940', 'maatuli',
        'Aunt (mother\'s sister)'),
    OfflinePhrase('\u092A\u093F\u0924\u0943\u0935\u094D\u092F\u0940',
        'pitrivyi', 'Aunt (father\'s sister)'),
  ];

  static const List<OfflinePhrase> _numbers = [
    OfflinePhrase('\u090F\u0915\u092E\u094D', 'ekam', 'One'),
    OfflinePhrase('\u0926\u094D\u0935\u0947', 'dve', 'Two'),
    OfflinePhrase('\u0924\u094D\u0930\u0940\u0923\u093F', 'trini', 'Three'),
    OfflinePhrase(
        '\u091A\u0924\u094D\u0935\u093E\u0930\u093F', 'catvari', 'Four'),
    OfflinePhrase('\u092A\u091E\u094D\u091A', 'pancha', 'Five'),
    OfflinePhrase('\u0937\u091F\u094D', 'shat', 'Six'),
    OfflinePhrase('\u0938\u092A\u094D\u0924', 'sapta', 'Seven'),
    OfflinePhrase('\u0905\u0937\u094D\u091F', 'ashta', 'Eight'),
    OfflinePhrase('\u0928\u0935', 'nava', 'Nine'),
    OfflinePhrase('\u0926\u0936', 'dasha', 'Ten'),
    OfflinePhrase('\u090F\u0915\u093E\u0926\u0936', 'ekadasha', 'Eleven'),
    OfflinePhrase('\u0926\u094D\u0935\u093E\u0926\u0936', 'dvadasha', 'Twelve'),
    OfflinePhrase(
        '\u0924\u094D\u0930\u092F\u094B\u0926\u0936', 'trayodasha', 'Thirteen'),
    OfflinePhrase(
        '\u091A\u0924\u0941\u0930\u094D\u0926\u0936', 'caturdasha', 'Fourteen'),
    OfflinePhrase(
        '\u092A\u091E\u094D\u091A\u0926\u0936', 'panchadasha', 'Fifteen'),
    OfflinePhrase('\u0937\u094B\u0921\u0936', 'shodasha', 'Sixteen'),
    OfflinePhrase(
        '\u0938\u092A\u094D\u0924\u0926\u0936', 'saptadasha', 'Seventeen'),
    OfflinePhrase(
        '\u0905\u0937\u094D\u091F\u093E\u0926\u0936', 'ashtadasha', 'Eighteen'),
    OfflinePhrase('\u0928\u0935\u0926\u0936', 'navadasha', 'Nineteen'),
    OfflinePhrase(
        '\u0935\u093F\u0902\u0936\u0924\u093F\u0903', 'vimshatih', 'Twenty'),
  ];

  static const List<OfflinePhrase> _basics = [
    OfflinePhrase('\u0905\u0939\u092E\u094D', 'aham', 'I'),
    OfflinePhrase('\u0928\u093E\u092E', 'nama', 'Name'),
    OfflinePhrase('\u091B\u093E\u0924\u094D\u0930\u0903', 'chatrah', 'Student'),
    OfflinePhrase('\u0938\u0902\u0938\u094D\u0915\u0943\u0924\u092E\u094D',
        'samskritam', 'Sanskrit'),
    OfflinePhrase(
        '\u092D\u093E\u0930\u0924\u0940\u092F\u0903', 'bharatiyah', 'Indian'),
    OfflinePhrase('\u0915\u092E\u0932\u092E\u094D', 'kamalam', 'Lotus'),
    OfflinePhrase('\u0905\u0917\u094D\u0928\u093F', 'agni', 'Fire'),
    OfflinePhrase('\u0906\u0928\u0928\u094D\u0926', 'ananda', 'Bliss'),
    OfflinePhrase('\u0917\u0940\u0924\u093E', 'gita', 'Song'),
    OfflinePhrase(
        '\u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D', 'pustakam', 'Book'),
    OfflinePhrase('\u0936\u0924\u092E\u094D', 'satam', 'Hundred'),
    OfflinePhrase(
        '\u0938\u0939\u0938\u094D\u0930\u092E\u094D', 'sahasram', 'Thousand'),
    OfflinePhrase('\u0915\u093F\u092E\u094D', 'kim', 'What'),
    OfflinePhrase('\u0915\u0941\u0924\u094D\u0930', 'kutra', 'Where'),
    OfflinePhrase('\u0915\u0926\u093E', 'kada', 'When'),
    OfflinePhrase('\u0915\u0925\u092E\u094D', 'katham', 'How'),
    OfflinePhrase('\u0915\u0924\u093F', 'kati', 'How many'),
    OfflinePhrase(
        '\u0915\u093F\u092E\u0930\u094D\u0925\u092E\u094D', 'kimartham', 'Why'),
    OfflinePhrase('\u0915\u0903', 'kah', 'Who (masculine)'),
    OfflinePhrase('\u0915\u093E', 'ka', 'Who (feminine)'),
  ];

  /// English question scaffolds that are not lookup targets.
  static const Set<String> _scaffoldWords = {
    'what',
    'how',
    'who',
    'where',
    'when',
    'why',
    'which',
    'how many',
    'how much',
    'about',
    'with',
    'from',
  };

  /// Every grounded phrase in one flat list (dictionary scan target).
  static List<OfflinePhrase> get _allPhrases =>
      [..._greetings, ..._family, ..._numbers, ..._basics];

  // ---------------------------------------------------------------------
  // Practice content (grounded in lesson exercises)
  // ---------------------------------------------------------------------

  static const List<PracticeQuestion> practiceQuestions = [
    PracticeQuestion(
      id: 'p_num_five',
      question:
          'Practice: What is "five" in Sanskrit? (tip: it starts with "pa-")',
      answerTokens: [
        '\u092A\u091E\u094D\u091A',
        'pancha',
        'panch',
        'panca',
        '5',
        'five'
      ],
      hint: 'The word is "pa-ñca" - it starts like "pan-".',
      explanation: '\u092A\u091E\u094D\u091A (pancha) means five.',
    ),
    PracticeQuestion(
      id: 'p_barakhadi_matra',
      question: 'Practice: In barakhadi, which vowel matra attaches on the '
          'LEFT of a consonant?',
      answerTokens: [
        'short i',
        'i matra',
        'i-matra',
        '\u091B\u094B\u091F\u0940 \u0907'
      ],
      hint:
          'It is the SHORT i (\u093F) - the only matra that attaches on the left.',
      explanation: 'The short-i matra (\u093F) is the only one written on the '
          'LEFT of a consonant; every other matra goes right, above or below.',
    ),
    PracticeQuestion(
      id: 'p_intro_mama_nama',
      question:
          'Practice: What does "\u092E\u092E \u0928\u093E\u092E" (mama nama) mean?',
      answerTokens: [
        'my name',
        'name is',
        'mera nam',
        '\u092E\u0947\u0930\u093E \u0928\u093E\u092E'
      ],
      hint: '"mama" = my, "nama" = name. So "mama nama ..." = ...',
      explanation: '"mama nama" means "My name is...".',
    ),
    PracticeQuestion(
      id: 'p_greetings_thankyou',
      question: 'Practice: How do you say "thank you" in Sanskrit?',
      answerTokens: [
        '\u0927\u0928\u094D\u092F\u0935\u093E\u0926',
        'dhanyavad',
        'dhanyavada',
        'dhanyawad',
      ],
      hint: 'It starts with "dh-": dhanya + vada = speech of gratitude.',
      explanation:
          '"dhanyavadah" (\u0927\u0928\u094D\u092F\u0935\u093E\u0926\u0903) '
          'means "Thank you".',
    ),
  ];

  // ---------------------------------------------------------------------
  // Intent detection
  // ---------------------------------------------------------------------

  /// Detects which intent a raw message maps to. Pure string logic over
  /// English, romanised and Devanagari patterns.
  OfflineIntent detectIntent(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return OfflineIntent.greeting;

    if (_containsAny(t, [
      'thank',
      'dhanyavad',
      'dhanyawad',
      'shukriya',
      'thanks',
    ])) {
      return OfflineIntent.thanks;
    }
    if (_containsAny(t, [
      'hello',
      'hi ',
      ' hi',
      'hey',
      'namaste',
      'namaskar',
      'suprabhat',
      'good morning',
      'good evening',
      'good night',
      _namaste,
      _suprabhatam,
      _shubharatrih,
    ])) {
      return OfflineIntent.greeting;
    }
    if (_containsAny(t, ['who are you', 'what are you', 'kaun ho'])) {
      return OfflineIntent.identity;
    }
    if (_containsAny(t, [
      'practice',
      'quiz',
      'ask me',
      'test me',
      'exercise',
      'abhyas',
      'drill',
      'challenge',
      'question me',
    ])) {
      return OfflineIntent.practice;
    }
    // Translation / meaning requests (checked before topic intents so that
    // "what does maataa mean" becomes a lookup, not the family lesson).
    if (_containsAny(t, [
      'translate',
      'how do you say',
      'how to say',
      'in sanskrit',
      'sanskrit word',
      'meaning',
      ' mean',
      'what is',
      'kya matlab',
      'ka arth',
    ])) {
      return OfflineIntent.translate;
    }
    if (_containsAny(t, [
      'grammar',
      'verb',
      'tense',
      'conjugation',
      'conjugate',
      'declension',
      'case',
      'gender',
      'matra',
      'barakhadi',
      'vowel',
      'consonant',
    ])) {
      return OfflineIntent.grammar;
    }
    if (_containsAny(t, [
      'number',
      'count',
      'counting',
      'how many',
      'ekam',
      'dve',
      'trini',
      'one to ten',
      '1 to 10',
    ])) {
      return OfflineIntent.numbers;
    }
    if (_containsAny(t, [
      'greeting',
      'greet',
      'hello kaise',
    ])) {
      return OfflineIntent.greetingsTopic;
    }
    if (_containsAny(t, [
      'family',
      'mother',
      'father',
      'brother',
      'sister',
      'relation',
      'parivaar',
      'mata',
      'pita',
      'maataa',
      'pitaa',
    ])) {
      return OfflineIntent.familyTopic;
    }
    if (_containsAny(t, [
      'correct',
      'is this right',
      'check my',
      'galat',
      'sahi',
      'grammatically',
    ])) {
      return OfflineIntent.correction;
    }
    if (_containsAny(t, [
      'motivate',
      'encourage',
      'tired',
      'hard',
      'difficult',
      'stuck',
      'give up',
      'bored',
      'inspired',
      'thoda',
      ' aur',
    ])) {
      return OfflineIntent.encouragement;
    }
    return OfflineIntent.orientation;
  }

  // ---------------------------------------------------------------------
  // Reply composition
  // ---------------------------------------------------------------------

  /// Builds the reply for one turn.
  ///
  /// [pendingQuestion] is non-null when the tutor previously asked a
  /// practice question and this message is the learner's answer attempt.
  /// [practiceIndex] selects the next fresh question (deterministic per
  /// conversation - the caller advances the cursor).
  OfflineTutorReply reply({
    required String message,
    required String displayName,
    required String companionName,
    required PracticeQuestion? pendingQuestion,
    required int practiceIndex,
  }) {
    final companion =
        companionName.trim().isEmpty ? 'Van' : companionName.trim();
    final name = displayName.trim();
    final text = message.trim().toLowerCase();

    // -- Answer an outstanding practice question first -------------------
    if (pendingQuestion != null) {
      final questions = practiceQuestions;
      if (_containsAny(text, ['skip', 'next ', 'agla'])) {
        final next = questions[(practiceIndex + 1) % questions.length];
        return OfflineTutorReply(
          text: '${_greet(name)}sure! Here is another one:\n\n'
              '${next.question}\n\nHint: ${next.hint}',
          nextQuestion: next,
        );
      }
      if (_containsAny(text, pendingQuestion.answerTokens)) {
        return OfflineTutorReply(
          text: '${_greet(name)}yes, that is right! '
              '${pendingQuestion.explanation} '
              'Want another? Just say "practice".',
          nextQuestion: null,
        );
      }
      return OfflineTutorReply(
        text: '${_greet(name)}not quite yet. Hint: ${pendingQuestion.hint} '
            'Try again, or say "skip" for a different one.',
        nextQuestion: pendingQuestion,
      );
    }

    final intent = detectIntent(text);

    switch (intent) {
      case OfflineIntent.greeting:
        return OfflineTutorReply(
          text: name.isEmpty
              ? 'Hello! I am $companion, your Sanskrit buddy. Ask me to '
                  'practice, translate, or explain something - or say "help".'
              : 'Hello $name! I am $companion. Ready to practice some '
                  'Sanskrit? Ask me to translate, count, or quiz you - or '
                  'say "help".',
        );
      case OfflineIntent.thanks:
        return OfflineTutorReply(
          text: '${_greet(name)}you are welcome! And remember: '
              '$_dhanyavadah (dhanyavadah) is how you say "thank you" in '
              'Sanskrit - a good word to use today.',
        );
      case OfflineIntent.identity:
        return OfflineTutorReply(
          text: 'I am $companion, an AI duck companion that helps you learn '
              'Sanskrit offline. I can teach greetings, family words, '
              'numbers and barakhadi - and quiz you with practice questions. '
              'Just ask!',
        );
      case OfflineIntent.practice:
        final question =
            practiceQuestions[practiceIndex % practiceQuestions.length];
        return OfflineTutorReply(
          text: '${_greet(name)}great idea! Here is your question:\n\n'
              '${question.question}\n\nHint: ${question.hint}',
          nextQuestion: question,
        );
      case OfflineIntent.translate:
        return _translate(text, name, companion);
      case OfflineIntent.grammar:
        return _grammarReply(name, companion);
      case OfflineIntent.numbers:
        return _numbersReply(text, name);
      case OfflineIntent.greetingsTopic:
        return _tableReply(_greetings, 'Greetings', name,
            'Start with $_namaste (namaste) - it works in every situation.');
      case OfflineIntent.familyTopic:
        return _tableReply(_family, 'Family words', name,
            'Sanskrit distinguishes paternal and maternal relatives.');
      case OfflineIntent.correction:
        return OfflineTutorReply(
          text: '${_greet(name)}I would love to check your sentence, but I '
              'cannot judge free-form Sanskrit while offline '
              '(no learning model is connected). '
              'Try the practice questions in Learn instead - I can grade '
              'those for you right now. Say "practice"!',
        );
      case OfflineIntent.encouragement:
        return OfflineTutorReply(
          text: '${_greet(name)}you are doing great! Every word you learn is '
              'a step closer to reading real Sanskrit. '
              'Try one little thing: say the numbers 1 to 5 out loud in '
              'Sanskrit right now. I will wait!',
        );
      case OfflineIntent.orientation:
        if (_containsAny(text, ['help', 'what can you', 'ka kar'])) {
          return OfflineTutorReply(
            text: 'I can help you with:\n'
                '• "how do you say X in sanskrit" - word lookups\n'
                '• "numbers", "greetings", "family" - mini lessons\n'
                '• "grammar" - barakhadi and sentence patterns\n'
                '• "practice" - graded quiz questions\n\n'
                'Try one!',
          );
        }
        return OfflineTutorReply(
          text: '${_greet(name)}I am not sure I understood that. '
              'Try: "how do you say mother in sanskrit", "numbers", '
              '"grammar", or "practice".',
        );
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  String _greet(String name) => name.isEmpty ? '' : '$name, ';

  OfflineTutorReply _translate(String text, String name, String companion) {
    // Grammar keywords asked inside a "what is ..." phrasing should flow to
    // the grammar card, not the vocabulary scan.
    if (_containsAny(text, [
      'matra',
      'barakhadi',
      'vowel',
      'consonant',
      'verb',
      'case',
      'gender',
      'tense',
      'declension',
    ])) {
      return _grammarReply(name, companion);
    }

    // 1) Whole-number lookups first (e.g. "what is 7 in sanskrit").
    final digit = RegExp(r'\b(\d{1,2})\b').firstMatch(text);
    if (digit != null) {
      final n = int.tryParse(digit.group(1)!);
      if (n != null && n >= 1 && n <= 20) {
        final phrase = _numbers[n - 1];
        return OfflineTutorReply(
          text: '${_greet(name)}$n in Sanskrit is ${phrase.devanagari} '
              '(${phrase.roman}). From the Numbers lesson.',
        );
      }
    }

    // 2) Scan the grounded dictionary (Devanagari, romanised, English).
    // Single-character English keys (e.g. "I") and very short roman keys
    // (e.g. "ka") would false-positive inside ordinary words, so they are
    // skipped; Devanagari keys are unambiguous and always match.
    for (final phrase in _allPhrases) {
      final english = phrase.english.toLowerCase();
      final englishMatch = english.length >= 2 &&
          !_scaffoldWords.contains(english) &&
          text.contains(english);
      final romanMatch =
          phrase.roman.length >= 3 && text.contains(phrase.roman);
      if (englishMatch || romanMatch || text.contains(phrase.devanagari)) {
        return OfflineTutorReply(
          text: '${_greet(name)}"${phrase.english}" is ${phrase.devanagari} '
              '(${phrase.roman}). From the seeded lessons.',
        );
      }
    }

    // 3) Honest boundary: unknown outside grounded content.
    return OfflineTutorReply(
      text: '${_greet(name)}I do not have that word in my offline lessons '
          'yet, so I cannot translate it reliably. '
          '(No learning model is connected - I can only answer from the '
          'lessons.) Try greetings, family or numbers - or say "practice".',
    );
  }

  OfflineTutorReply _grammarReply(String name, String companion) {
    return OfflineTutorReply(
      text: '${_greet(name)}here is a quick grammar card from the lessons:\n\n'
          '• Barakhadi: a vowel matra modifies a consonant - and the short-i '
          'matra is the ONLY one that attaches on the LEFT.\n'
          '• Sentences: "$_mamaNama ..." (mama nama ...) = "My name is ...". '
          'Verbs take -mi endings for "I do": \u0905\u0939\u092E\u094D (aham) '
          '+ \u0905\u092D\u094D\u092F\u0938\u094D\u092E\u093F (abhyasmi) = '
          '"I study Sanskrit".\n'
          '• Question words start with k-: \u0915\u093F\u092E\u094D (kim/what), '
          '\u0915\u0941\u0924\u094D\u0930 (kutra/where), '
          '\u0915\u0926\u093E (kada/when), \u0915\u0925\u092E\u094D (katham/how).\n\n'
          'For deeper grammar I need a learning model (offline limitation).',
    );
  }

  static const String _mamaNama = '\u092E\u092E \u0928\u093E\u092E';

  OfflineTutorReply _numbersReply(String text, String name) {
    final digit = RegExp(r'\b(\d{1,2})\b').firstMatch(text);
    if (digit != null) {
      final n = int.tryParse(digit.group(1)!);
      if (n != null && n >= 1 && n <= 20) {
        final phrase = _numbers[n - 1];
        return OfflineTutorReply(
          text: '${_greet(name)}$n is ${phrase.devanagari} (${phrase.roman}).',
        );
      }
    }
    final rows = _numbers
        .take(10)
        .map((p) => '${p.devanagari} (${p.roman}) = ${p.english}')
        .join('\n');
    return OfflineTutorReply(
      text: '${_greet(name)}numbers 1-10:\n$rows\n\n'
          'From 11-19 the pattern is "one-ten" (ekadasha), "two-ten" '
          '(dvadasha)... Learn them all in the Numbers lesson!',
    );
  }

  OfflineTutorReply _tableReply(
    List<OfflinePhrase> rows,
    String title,
    String name,
    String tip,
  ) {
    final body = rows
        .map((p) => '${p.devanagari} (${p.roman}) = ${p.english}')
        .join('\n');
    return OfflineTutorReply(
      text: '${_greet(name)}$title:\n$body\n\nTip: $tip',
    );
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }
}
