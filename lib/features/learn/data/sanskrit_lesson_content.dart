/// Sanskrit Lesson Content — V1
///
/// Real lesson content for the 8 V1 lessons. Each lesson's content is a
/// markdown-like string (see [Lesson.content] docstring for format spec).
///
/// Content covers: introduction, examples (Devanagari + IAST + English),
/// and a practice tip. Each lesson is 200-400 words.
///
/// This file is imported by [sanskrit_curriculum.dart] to attach content
/// to each Lesson. In Segment 8 this will be replaced by a JSON-driven
/// curriculum loader, but the content strings will be reused.

/// Lesson 1: Vowels (स्वराः)
const String kVowelsContent = '''# स्वराः · Vowels

Sanskrit has 13 vowels (स्वराः), divided into short (ह्रस्व) and long (दीर्घ). Vowels are the foundation of every Sanskrit word — mastering their pronunciation is essential before moving to consonants.

## The 13 Vowels

| Devanagari | IAST | English |
|---|---|---|
| अ | a | a (short, like "u" in "but") |
| आ | ā | a (long, like "a" in "father") |
| इ | i | i (short, like "i" in "sit") |
| ई | ī | i (long, like "ee" in "feet") |
| उ | u | u (short, like "u" in "put") |
| ऊ | ū | u (long, like "oo" in "boot") |
| ऋ | ṛ | ri (like "r" + "i" blended) |
| ॠ | ṝ | rī (long version of ऋ) |
| ऌ | ḷ | li (rare, like "l" + "i") |
| ॡ | ḹ | lī (long version of ऌ, very rare) |
| ए | e | e (like "e" in "they", always long) |
| ऐ | ai | ai (like "ai" in "aisle") |
| ओ | o | o (like "o" in "go", always long) |
| औ | au | au (like "ou" in "out") |

## Short vs Long

- Short vowels (ह्रस्व): अ, इ, उ, ऋ
- Long vowels (दीर्घ): आ, ई, ऊ, ॠ, ए, ऐ, ओ, औ
- The length matters! अ vs आ can change the meaning of a word entirely.

## Practice Tip

> Practice writing each vowel three times. Say it aloud as you write — Sanskrit is an oral tradition first. Notice how अ and आ look similar but आ has the vertical stroke on the right (ा). The same stroke turns any consonant into its long-vowel form.

## Common Words Using Vowels

- अग्नि (agni) — fire (starts with short अ)
- आनन्द (ānanda) — bliss (starts with long आ)
- इन्द्र (indra) — the deity Indra (starts with short इ)
- ईश (īśa) — lord (starts with long ई)
- उदय (udaya) — sunrise (starts with short उ)
- ऊर्ध्व (ūrdhva) — upward (starts with long ऊ)''';

/// Lesson 2: Consonants (व्यञ्जनानि)
const String kConsonantsContent = '''# व्यञ्जनानि · Consonants

Sanskrit has 33 consonants (व्यञ्जनानि), organized into 5 groups (वर्ग) based on where the sound is produced in the mouth. Each group has 5 consonants following a pattern: unaspirated, aspirated, unaspirated voiced, aspirated voiced, nasal.

## The 5 Groups (वर्ग)

### 1. कवर्ग (Velars — produced at the back of the throat)
| Devanagari | IAST | English |
|---|---|---|
| क | ka | k (like "k" in "kite") |
| ख | kha | kh (aspirated k, with a puff of air) |
| ग | ga | g (like "g" in "go") |
| घ | gha | gh (aspirated g) |
| ङ | ṅa | ng (like "ng" in "sing") |

### 2. चवर्ग (Palatals — produced at the hard palate)
| Devanagari | IAST | English |
|---|---|---|
| च | ca | ch (like "ch" in "church") |
| छ | cha | aspirated ch |
| ज | ja | j (like "j" in "jump") |
| झ | jha | aspirated j |
| ञ | ña | ny (like "ny" in "canyon") |

### 3. टवर्ग (Retroflex — tongue curled back)
| Devanagari | IAST | English |
|---|---|---|
| ट | ṭa | t (retroflex, harder than त) |
| ठ | ṭha | aspirated retroflex t |
| ड | ḍa | d (retroflex) |
| ढ | ḍha | aspirated retroflex d |
| ण | ṇa | n (retroflex) |

### 4. तवर्ग (Dentals — tongue touches the back of upper teeth)
| Devanagari | IAST | English |
|---|---|---|
| त | ta | t (like "t" in "ten", dental) |
| थ | tha | aspirated t (like "t" in "top") |
| द | da | d (like "d" in "dog", dental) |
| ध | dha | aspirated d |
| न | na | n (like "n" in "no") |

### 5. पवर्ग (Labials — produced at the lips)
| Devanagari | IAST | English |
|---|---|---|
| प | pa | p (like "p" in "pen") |
| फ | pha | aspirated p (like "p" in "pen" with air) |
| ब | ba | b (like "b" in "boy") |
| भ | bha | aspirated b |
| म | ma | m (like "m" in "man") |

## The Semi-Vowels and Sibilants

Beyond the 5 groups, there are 8 additional consonants:
- य (ya), र (ra), ल (la), व (va) — semi-vowels
- श (śa), ष (ṣa), स (sa) — sibilants (the three "sh" sounds)
- ह (ha) — the aspirate

## Practice Tip

> Start with the तवर्ग (dentals) — they are the closest to English sounds and easiest for beginners. Then move to पवर्ग (labials). The retroflex टवर्ग is the hardest for non-Indian speakers — practice curling your tongue back. Listen to native pronunciation recordings to hear the difference between aspirated (ख, घ, थ, ध, फ, भ) and unaspirated (क, ग, त, द, प, ब) — the puff of air is the key.''';

/// Lesson 3: Barakhadi (बाराखड़ी)
const String kBarakhadiContent = '''# बाराखड़ी · Consonant + Vowel Combinations

Barakhadi (बाराखड़ी) is the system of combining each consonant with each vowel. The consonant takes its base form, and the vowel is attached as a "matra" (मात्रा) — a modifier stroke that changes the vowel sound of the consonant.

## The Pattern

Take the consonant क (ka). Adding each vowel's matra produces:

| Form | Devanagari | IAST | Meaning |
|---|---|---|---|
| क + अ | क | ka | k + a (default, no matra) |
| क + आ | का | kā | k + long a |
| क + इ | कि | ki | k + short i |
| क + ई | की | kī | k + long i |
| क + उ | कु | ku | k + short u |
| क + ऊ | कू | kū | k + long u |
| क + ऋ | कृ | kṛ | k + vocalic r |
| क + ए | के | ke | k + e |
| क + ऐ | कै | kai | k + ai |
| क + ओ | को | ko | k + o |
| क + औ | कौ | kau | k + au |

## Matra Shapes

Each vowel has a distinct matra (modifier):
- आ (ā) → ा (vertical stroke on the right)
- इ (i) → ि (stroke on the LEFT — this is the only left-attaching matra!)
- ई (ī) → ी (horizontal line on top)
- उ (u) → ु (curve below the consonant)
- ऊ (ū) → ू (hook below)
- ऋ (ṛ) → ृ (curve below, different from ु)
- ए (e) → े (stroke above)
- ऐ (ai) → ै (double stroke above)
- ओ (o) → ो (stroke above + vertical right)
- औ (au) → ौ (double stroke above + vertical right)

## Practice Tip

> The tricky part is remembering which matra goes above, below, left, or right. The ि (short i) matra is the only one that attaches on the LEFT — this catches many beginners. Practice writing क with each matra until the shapes become muscle memory. Once you master क, the same matras work with every consonant.

## Example Words

- कमल (kamala) — lotus (क + म + ल, all default अ)
- नाम (nāma) — name (न + ा + म)
- गीत (gīta) — song (ग + ी + त)
- पुस्तक (pustaka) — book (प + ु + स् + त + क)''';

/// Lesson 4: Greetings (अभिवादनम्)
const String kGreetingsContent = '''# अभिवादनम् · Greetings

Sanskrit greetings are warm and meaningful. Unlike English "hello," each Sanskrit greeting carries a specific blessing or wish. Learning these is your first step to speaking Sanskrit with real people.

## Essential Greetings

| Devanagari | IAST | English |
|---|---|---|
| नमस्ते | namaste | Hello / I bow to you |
| नमो वः | namo vaḥ | Greetings to you (plural/formal) |
| सुप्रभातम् | suprabhātam | Good morning |
| शुभ सायम् | śubha sāyam | Good evening |
| शुभरात्रिः | śubharātriḥ | Good night |
| धन्यवादः | dhanyavādaḥ | Thank you |
| कृपया | kṛpayā | Please |
| माफ कुरुते | māpha kurute | Excuse me / Sorry |

## Breaking Down नमस्ते

नमस्ते (namaste) is the most famous Sanskrit word. It comes from:
- नमः (namaḥ) — bow, obeisance
- ते (te) — to you

So नमस्ते literally means "I bow to you" — a gesture of respect recognizing the divine in the other person.

## Time-Based Greetings

- सुप्रभातम् (suprabhātam) — "good morning" (literally: good dawn)
  - सु (su) = good
  - प्रभात (prabhāta) = dawn
- शुभ सायम् (śubha sāyam) — "good evening"
  - शुभ (śubha) = auspicious
  - सायम् (sāyam) = evening
- शुभरात्रिः (śubharātriḥ) — "good night"
  - रात्रि (rātri) = night

## Thank You and Please

- धन्यवादः (dhanyavādaḥ) — "thank you"
  - धन्य (dhanya) = grateful
  - वाद (vāda) = speech/saying
- कृपया (kṛpayā) — "please"
  - कृपा (kṛpā) = grace, kindness
  - कृपया = "with grace" (instrumental case)

## Practice Tip

> Start with नमस्ते — it works in any situation. Practice saying सुप्रभातम् each morning. When someone helps you, say धन्यवादः. The more you use these in daily life, the more Sanskrit becomes a living language for you, not just a subject to study.''';

/// Lesson 5: Family (परिवारः)
const String kFamilyContent = '''# परिवारः · Family

Family is at the heart of Indian culture, and Sanskrit has precise words for every family relationship. Unlike English, which uses "uncle" for both father's and mother's brothers, Sanskrit distinguishes them clearly.

## Immediate Family

| Devanagari | IAST | English |
|---|---|---|
| माता | mātā | Mother |
| पिता | pitā | Father |
| पुत्रः | putraḥ | Son |
| पुत्री | putrī | Daughter |
| भ्राता | bhrātā | Brother |
| भगिनी | bhaginī | Sister |
| पत्नी | patnī | Wife |
| पतिः | patiḥ | Husband |

## Extended Family (Paternal — Father's Side)

| Devanagari | IAST | English |
|---|---|---|
| पितामहः | pitāmahaḥ | Grandfather (paternal) |
| पितामही | pitāmahī | Grandmother (paternal) |
| पितृव्यः | pitṛvyaḥ | Uncle (father's brother) |
| मातुलः | mātulaḥ | Uncle (mother's brother) |
| पितृव्यी | pitṛvyī | Aunt (father's sister) |
| मातुली | mātulī | Aunt (mother's sister) |

## Why the Distinction Matters

In Indian families, relationships define social roles:
- Your मातुलः (mother's brother) has a special role — he is traditionally the one who carries the bride in a wedding.
- Your पितामहः (paternal grandfather) is the head of the joint family.
- Your भगिनी (sister) is called भगिनी regardless of whether she is older or younger — Sanskrit uses separate words for older (अग्रजा) and younger (अनुजा) but भगिनी is the general term.

## Common Word Formation

Many family words come from roots:
- मा (mā) — "to measure" → माता (she who measures out love)
- पा (pā) — "to protect" → पिता (protector)
- भृ (bhṛ) — "to bear/support" → भ्राता (one who supports)

## Practice Tip

> Draw your family tree and label each person in Sanskrit. This personal connection makes the vocabulary stick. If you have a मातुलः (maternal uncle), practice calling him that — he will be delighted! The precision of Sanskrit family terms reflects the deep family structure of Indian culture.''';

/// Lesson 6: Numbers (सङ्ख्याः)
const String kNumbersContent = '''# सङ्ख्याः · Numbers 1–20

Sanskrit numbers follow a logical pattern but have distinct forms for 1–19. From 20 onward, the system becomes decimal (twenty, thirty, forty...), similar to English. Mastering 1–20 is essential for telling time, counting, and understanding Sanskrit literature.

## Numbers 1–10

| Devanagari | IAST | English |
|---|---|---|
| एकम् | ekam | One |
| द्वे | dve | Two |
| त्रीणि | trīṇi | Three |
| चत्वारि | catvāri | Four |
| पञ्च | pañca | Five |
| षट् | ṣaṭ | Six |
| सप्त | sapta | Seven |
| अष्ट | aṣṭa | Eight |
| नव | nava | Nine |
| दश | daśa | Ten |

## Numbers 11–20

| Devanagari | IAST | English |
|---|---|---|
| एकादश | ekādaśa | Eleven |
| द्वादश | dvādaśa | Twelve |
| त्रयोदश | trayodaśa | Thirteen |
| चतुर्दश | caturdaśa | Fourteen |
| पञ्चदश | pañcadaśa | Fifteen |
| षोडश | ṣoḍaśa | Sixteen |
| सप्तदश | saptadaśa | Seventeen |
| अष्टादश | aṣṭādaśa | Eighteen |
| नवदश | navadaśa | Nineteen |
| विंशतिः | viṁśatiḥ | Twenty |

## The Pattern

Notice the pattern from 11–19:
- एकादश (ekādaśa) = एक (one) + दश (ten) = "one-ten" = 11
- द्वादश (dvādaśa) = द्वे (two) + दश (ten) = 12
- त्रयोदश (trayodaśa) = त्रीणि (three) + दश (ten) = 13

This is similar to English "seventeen" (seven + ten).

## Tens (20, 30, 40...)

| Devanagari | IAST | English |
|---|---|---|
| विंशतिः | viṁśatiḥ | Twenty |
| त्रिंशत् | triṁśat | Thirty |
| चत्वारिंशत् | catvāriṁśat | Forty |
| पञ्चाशत् | pañcāśat | Fifty |
| षष्टिः | ṣaṣṭiḥ | Sixty |
| सप्ततिः | saptatiḥ | Seventy |
| अशीतिः | aśītiḥ | Eighty |
| नवतिः | navatiḥ | Ninety |
| शतम् | śatam | One Hundred |

## Cultural Note

- शतम् (śatam) = 100 (cognate with English "hundred" via Proto-Indo-European)
- सहस्रम् (sahasram) = 1000
- The Bhagavad Gita has 700 verses (श्लोकाः) — called गीता-सप्तशती (Gītā-Saptaśatī)

## Practice Tip

> Count objects around you in Sanskrit: "एकम्, द्वे, त्रीणि..." Practice your phone number digit by digit. The numbers 1, 2, 3 (एकम्, द्वे, त्रीणि) are the most important — they appear in almost every Sanskrit text. Note that Sanskrit numbers change form based on gender and case (we will cover this in a later lesson on noun declension).''';

/// Lesson 7: Introducing Yourself (परिचयः)
const String kIntroContent = '''# परिचयः · Introducing Yourself

Introducing yourself in Sanskrit is a beautiful way to connect with the language. The structure is simple: "My name is..." followed by your name. Let's learn the building blocks.

## The Core Phrase

मम नाम ... (mama nāma ...) — "My name is ..."

Breaking it down:
- मम (mama) — "my" (possessive pronoun, first person singular)
- नाम (nāma) — "name"
- Then add your name

Examples:
- मम नाम रामः (mama nāma rāmaḥ) — My name is Ram
- मम नाम सीता (mama nāma sītā) — My name is Sita
- मम नाम अर्जुनः (mama nāma arjunaḥ) — My name is Arjun

## Asking Someone's Name

भवतः नाम किम्? (bhavataḥ nāma kim?) — "What is your name?" (to a male)
भवत्याः नाम किम्? (bhavatyāḥ nāma kim?) — "What is your name?" (to a female)

Breaking it down:
- भवतः (bhavataḥ) — "your" (respectful, masculine)
- भवत्याः (bhavatyāḥ) — "your" (respectful, feminine)
- नाम (nāma) — "name"
- किम् (kim) — "what" (the question word)

## Full Introduction

Here's a complete self-introduction:

> मम नाम [name]। अहम् [city] वसामि। अहं छात्रः।
> (mama nāma [name]. aham [city] vasāmi. ahaṁ chātraḥ.)

Translation:
- मम नाम [name] — My name is [name]
- अहम् [city] वसामि — I live in [city]
- अहं छात्रः — I am a student

## Word Breakdown

- अहम् (aham) — "I" (first person pronoun)
- वसामि (vasāmi) — "I dwell/live" (verb, first person singular)
- छात्रः (chātraḥ) — "student" (masculine)
- For a female student: छात्रा (chātrā)

## Simple Sentences

- अहं भारतीयः (ahaṁ bhāratīyaḥ) — I am Indian (male)
- अहं भारतीया (ahaṁ bhāratīyā) — I am Indian (female)
- मम आयुः [number] वर्षाणि (mama āyuḥ [number] varṣāṇi) — I am [number] years old
- अहं संस्कृतम् अभ्यस्मि (ahaṁ saṁskṛtam abhyasmi) — I study Sanskrit

## Practice Tip

> Write your own introduction in Sanskrit. Start simple: मम नाम [your name]। Then build up: add where you live, what you do. Practice saying it aloud. The verb forms change based on who is doing the action (I, you, he, she, we, they) — this is called conjugation, and we will study it systematically in the next chapter. For now, memorize "अहम्" (I) + verb-मि ending = "I do [action]".''';

/// Lesson 8: Asking Questions (प्रश्नाः)
const String kQuestionsContent = '''# प्रश्नाः · Asking Questions

Question words in Sanskrit are powerful — once you know them, you can ask anything. Sanskrit questions often start with a क्- (k-) sound, just like English (who, what, where, when, why).

## The Question Words

| Devanagari | IAST | English |
|---|---|---|
| किम् | kim | What? |
| कः | kaḥ | Who? (masculine) |
| का | kā | Who? (feminine) |
| कति | kati | How many? |
| कुत्र | kutra | Where? |
| कदा | kadā | When? |
| कथम् | katham | How? |
| किमर्थम् | kimartham | Why? |
| कुतः | kutaḥ | From where? / Why? |

## Forming Questions

Sanskrit questions are simple: Question word + subject + verb.

- किम् एतत्? (kim etat?) — What is this?
- कः भवान्? (kaḥ bhavān?) — Who are you? (to a male, respectful)
- का भवती? (kā bhavatī?) — Who are you? (to a female, respectful)
- कुत्र वससि? (kutra vasasi?) — Where do you live?
- कदा आगच्छसि? (kadā āgacchasi?) — When will you come?
- कथम् गच्छसि? (katham gacchasi?) — How do you go?
- किमर्थम् रुदसि? (kimartham rudasi?) — Why are you crying?

## The Yes/No Question

For yes/no questions, add किम् (kim) at the start or end, or just use a rising intonation:

- किम् भवान् छात्रः? (kim bhavān chātraḥ?) — Are you a student?
- भवान् छात्रः किम्? (bhavān chātraḥ kim?) — Are you a student? (kim at end)
- आगच्छसि? (āgacchasi?) — Are you coming? (intonation only)

## Question Words in Sentences

- किम् (kim) — "what"
  - किम् एतत्? — What is this?
  - किम् करोषि? — What are you doing?

- कः (kaḥ) — "who" (masculine)
  - कः सः? — Who is he?
  - कः त्वम्? — Who are you? (informal)

- कुत्र (kutra) — "where"
  - कुत्र अस्ति विद्यालयः? — Where is the school?
  - कुत्र गच्छसि? — Where are you going?

- कदा (kadā) — "when"
  - कदा आगमिष्यसि? — When will you come?
  - कदा जन्म? — When is your birthday?

- कथम् (katham) — "how"
  - कथम् अस्ति? — How are you?
  - कथम् इदं करोमि? — How do I do this?

## Common Question Patterns

- किम् + noun + किम्? — double किम् for emphasis: "What on earth is this?"
- कः + भवान्? — "Who are you?" (respectful)
- किं न? — "Is it not?" (rhetorical, expecting yes)

## Cultural Note

In Sanskrit literature, questions are a sign of a sincere student. The Bhagavad Gita begins with Arjuna's questions to Krishna. The Upanishads are structured as questions and answers between teacher and student. Asking "कथम्?" (how?) and "किमर्थम्?" (why?) is the path to wisdom.

## Practice Tip

> Start using question words immediately. Point to objects and ask किम् एतत्? (What is this?). When someone arrives, ask कुत्र आगच्छसि? (Where are you coming from?). The key to learning any language is curiosity — Sanskrit rewards the curious student. Learn किम्, कः, कुत्र, कदा, कथम् first — these 5 words unlock thousands of questions.''';
