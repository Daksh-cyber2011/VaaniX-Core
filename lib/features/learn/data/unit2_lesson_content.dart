/// Unit 2 (PRD §15) + V1 syllabus-expansion lesson content.
///
/// Devanagari is authored as `\uXXXX` escapes so the source file stays
/// encoding-safe. Merged into the curriculum by [CurriculumLoader].

const String kConjunctsContent = '''# \u0938\u0902\u092F\u0941\u0915\u094D\u0924\u0906\u0915\u094D\u0937\u0930 – Conjunct Consonants

When two consonants come together without a vowel between them, they join into a single **conjunct consonant** (\u0938\u0902\u092F\u0941\u0915\u094D\u0924\u0906\u0915\u094D\u0937\u0930). The mark \u094D removes the vowel from the first consonant so the two sounds blend into one unit.

## The \u0939\u0932\u094D\u0905\u0928\u094D\u0924 (Virama)

Every consonant letter carries an invisible vowel "a" after it: \u0915 = ka, not just k. The virama \u094D tells you to drop that vowel: \u0915\u094D = k only. When you see \u0915\u094D + \u0937, you read them as one blended sound \u0915\u094D\u0937.

## Common Conjuncts

| Conjunct | Made from | Example word | Meaning |
|---|---|---|---|
| \u0915\u094D\u0937 | \u0915\u094D + \u0937 | \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D | field |
| \u0924\u094D\u0930 | \u0924\u094D + \u0930 | \u0924\u094D\u0930\u092F\u0903 | three |
| \u091C\u094D\u091E | \u091C\u094D + \u091E | \u091C\u094D\u091E\u0906\u0928\u092E\u094D | knowledge |
| \u0936\u094D\u0930 | \u0936\u094D + \u0930 | \u0936\u094D\u0930\u0940 | respect/title |
| \u092A\u094D\u0930 | \u092A\u094D + \u0930 | \u092A\u094D\u0930\u093F\u092F\u0903 | dear |
| \u0938\u094D\u0935 | \u0938\u094D + \u0935 | \u0938\u094D\u0935\u0906\u092E\u0940 | master |
| \u0938\u094D\u0924 | \u0938\u094D + \u0924 | \u0938\u094D\u0924\u094D\u0930\u0940 | woman |
| \u0928\u094D\u0924 | \u0928\u094D + \u0924 | \u0905\u0928\u094D\u0924\u0903 | inside/end |

## How to Read a Conjunct

1. Split it at the \u094D (virama): \u0915\u094D\u0937 = \u0915\u094D + \u0937.
2. Say the first consonant with NO vowel, then the second with its vowel: k + Sha = kSa.
3. Practise slowly first; the sounds melt together with speed.

## Practice Tip

> Write each conjunct 5 times. Then cover the table and try to rebuild \u0915\u094D\u0937\u0947\u0924\u094D\u0930\u092E\u094D, \u0924\u094D\u0930\u092F\u0903 and \u091C\u094D\u091E\u0906\u0928\u092E\u094D from memory. Remember: the virama \u094D is the "silencer" – it removes the vowel.''';

const String kNounCasesContent = '''# \u0935\u093F\u092D\u0915\u094D\u0924\u093F – Nouns & Cases

A noun in Sanskrit changes its ending to show its job in the sentence. These ending sets are called **cases** (\u0935\u093F\u092D\u0915\u094D\u0924\u093F). Sanskrit has 8 cases.

## The 8 Cases

| # | Case (Sanskrit) | Job | Example |
|---|---|---|---|
| 1 | \u092A\u094D\u0930\u0925\u092E\u0906 (nominative) | subject (\u0915\u0930\u094D\u0924\u0906) | \u092C\u0906\u0932\u0915\u0903 – the boy (does the action) |
| 2 | \u0926\u094D\u0935\u093F\u0924\u0940\u092F\u0906 (accusative) | object (\u0915\u0930\u094D\u092E) | \u092C\u0906\u0932\u0915\u092E\u094D – the boy (receives the action) |
| 3 | \u0924\u0943\u0924\u0940\u092F\u0906 (instrumental) | with / by | \u092C\u0906\u0932\u0915\u0947\u0928 – by/with the boy |
| 4 | \u091A\u0924\u0941\u0930\u094D\u0925\u0940 (dative) | to / for | \u092C\u0906\u0932\u0915\u0906\u092F – to the boy |
| 5 | \u092A\u091E\u094D\u091A\u092E\u0940 (ablative) | from | \u092C\u0906\u0932\u0915\u0906\u0924\u094D – from the boy |
| 6 | \u0937\u0937\u094D\u0920\u0940 (genitive) | of | \u092C\u0906\u0932\u0915\u0938\u094D\u092F – of the boy |
| 7 | \u0938\u092A\u094D\u0924\u092E\u0940 (locative) | in / on / at | \u092C\u0906\u0932\u0915\u0947 – in the boy |
| 8 | \u0938\u092E\u094D\u092C\u094B\u0927\u0928 (vocative) | calling out | \u0939\u0947 \u092C\u0906\u0932\u0915 – O boy! |

## The Word \u092C\u0906\u0932\u0915 (boy) – Singular

| Case | Form |
|---|---|
| \u092A\u094D\u0930\u0925\u092E\u0906 | \u092C\u0906\u0932\u0915\u0903 |
| \u0926\u094D\u0935\u093F\u0924\u0940\u092F\u0906 | \u092C\u0906\u0932\u0915\u092E\u094D |
| \u0924\u0943\u0924\u0940\u092F\u0906 | \u092C\u0906\u0932\u0915\u0947\u0928 |
| \u091A\u0924\u0941\u0930\u094D\u0925\u0940 | \u092C\u0906\u0932\u0915\u0906\u092F |
| \u092A\u091E\u094D\u091A\u092E\u0940 | \u092C\u0906\u0932\u0915\u0906\u0924\u094D |
| \u0937\u0937\u094D\u0920\u0940 | \u092C\u0906\u0932\u0915\u0938\u094D\u092F |
| \u0938\u092A\u094D\u0924\u092E\u0940 | \u092C\u0906\u0932\u0915\u0947 |
| \u0938\u092E\u094D\u092C\u094B\u0927\u0928 | \u0939\u0947 \u092C\u0906\u0932\u0915 |

## Spot the Case

- \u0930\u0906\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u0906\u0926\u0924\u093F – \u0930\u0906\u092E\u0903 is case 1 (the eater), \u092B\u0932\u092E\u094D is case 2 (the fruit being eaten).
- \u092C\u0906\u0932\u0915\u0938\u094D\u092F \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D – "the boy's book": \u092C\u0906\u0932\u0915\u0938\u094D\u092F is case 6.

## Practice Tip

> Learn pairs, not lists: \u092A\u094D\u0930\u0925\u092E\u0906 + \u0926\u094D\u0935\u093F\u0924\u0940\u092F\u0906 (subject + object) first, then \u0937\u0937\u094D\u0920\u0940 ("of"), then \u0938\u092A\u094D\u0924\u092E\u0940 ("in"). These four cover most simple sentences.''';

const String kPronounsContent = '''# \u0938\u0930\u094D\u0935\u0928\u0906\u092E – Pronouns

Pronouns (\u0938\u0930\u094D\u0935\u0928\u0906\u092E) are words that stand in for nouns: I, you, he, she, it. Sanskrit pronouns must match the right verb form.

## The Basic Pronouns

| Person | Sanskrit | Meaning |
|---|---|---|
| 1st singular | \u0905\u0939\u0902 | I |
| 2nd singular | \u0924\u094D\u0935\u092E\u094D | you |
| 3rd singular masculine | \u0938\u0903 | he |
| 3rd singular feminine | \u0938\u0906 | she |
| 3rd singular neuter | \u0924\u0924\u094D | it |

## Pronouns in Action

| Sanskrit | Meaning |
|---|---|
| \u0905\u0939\u0902 \u092A\u0920\u0906\u092E\u093F | I read |
| \u0924\u094D\u0935\u092E\u094D \u092A\u0920\u0938\u093F | you read |
| \u0938\u0903 \u092A\u0920\u0924\u093F | he reads |
| \u0938\u0906 \u092A\u0920\u0924\u093F | she reads |
| \u0924\u0924\u094D \u0905\u0938\u094D\u0924\u093F | it is |

## Possessive Pronouns

| Sanskrit | Meaning |
|---|---|
| \u092E\u092E | my / mine |
| \u0924\u0935 | your / yours |
| \u092E\u092E \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D | my book |
| \u0924\u0935 \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D | your book |

## Remember

- \u0905\u0939\u0902 takes the -\u092E\u093F verb ending: \u092A\u0920\u0906\u092E\u093F.
- \u0924\u094D\u0935\u092E\u094D takes the -\u0938\u093F ending: \u092A\u0920\u0938\u093F.
- \u0938\u0903, \u0938\u0906 and \u0924\u0924\u094D all take -\u0924\u093F: \u092A\u0920\u0924\u093F.

## Practice Tip

> Point at people around you and say the pronoun: \u0905\u0939\u0902, \u0924\u094D\u0935\u092E\u094D, \u0938\u0903, \u0938\u0906. Then add one verb you know: \u092A\u0920\u0906\u092E\u093F, \u092A\u0920\u0938\u093F, \u092A\u0920\u0924\u093F. You have just built your first pronoun sentences!''';

const String kVerbsContent = '''# \u0932\u0915\u0906\u0930 – Basic Verbs (Present Tense \u0932\u0924\u094D)

Verbs change their endings to match who is doing the action. This is called **conjugation**. The present tense is called \u0932\u0924\u094D \u0932\u0915\u0906\u0930.

## The Verb \u092A\u0920\u094D (to read)

| Person | Ending | Form | Meaning |
|---|---|---|---|
| I | -\u092E\u093F | \u092A\u0920\u0906\u092E\u093F | I read |
| you (singular) | -\u0938\u093F | \u092A\u0920\u0938\u093F | you read |
| he / she / it | -\u0924\u093F | \u092A\u0920\u0924\u093F | he/she reads |
| we | -\u092E\u0903 | \u092A\u0920\u0906\u092E\u0903 | we read |
| you (plural) | -\u0925 | \u092A\u0920\u0925 | you all read |
| they | -\u0928\u094D\u0924\u093F | \u092A\u0920\u0928\u094D\u0924\u093F | they read |

## The Verb \u0905\u0938\u094D\u0924\u093F (to be)

\u0905\u0938\u094D\u0924\u093F is the most common Sanskrit verb – "is". For "I am", beginner sentences usually just leave the verb out:

- \u0905\u0939\u0902 \u091B\u0906\u0924\u094D\u0930\u0903 – I am a student (no verb needed)
- \u0938\u0903 \u091B\u0906\u0924\u094D\u0930\u0903 \u0905\u0938\u094D\u0924\u093F – he is a student

## Easy Sentence Building

| Sanskrit | Meaning |
|---|---|
| \u0905\u0939\u0902 \u092A\u0920\u0906\u092E\u093F | I read |
| \u0924\u094D\u0935\u092E\u094D \u092A\u0920\u0938\u093F | you read |
| \u0938\u0903 \u092A\u0920\u0924\u093F | he reads |
| \u0935\u092F\u092E\u094D \u092A\u0920\u0906\u092E\u0903 | we read |
| \u0924\u0947 \u092A\u0920\u0928\u094D\u0924\u093F | they read |

## Practice Tip

> Learn the six forms of \u092A\u0920\u094D as a chant: \u092A\u0920\u0906\u092E\u093F, \u092A\u0920\u0938\u093F, \u092A\u0920\u0924\u093F, \u092A\u0920\u0906\u092E\u0903, \u092A\u0920\u0925, \u092A\u0920\u0928\u094D\u0924\u093F. The ending tells you WHO – that is the whole trick of the \u0932\u0924\u094D \u0932\u0915\u0906\u0930.''';

const String kTranslationContent = '''# \u0905\u0928\u0941\u0935\u0906\u0926 – Translation Practice

Sanskrit word order is different from English: it is **Subject – Object – Verb** (SOV). English says "Ram eats a fruit"; Sanskrit says "Ram a fruit eats".

## The Golden Order

| English order | Sanskrit order |
|---|---|
| Subject → Verb → Object | Subject → Object → Verb |
| Ram eats a fruit | \u0930\u0906\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u0906\u0926\u0924\u093F |

## Read These Aloud

| Sanskrit | Word by word | Meaning |
|---|---|---|
| \u0930\u0906\u092E\u0903 \u092B\u0932\u092E\u094D \u0916\u0906\u0926\u0924\u093F | Ram / fruit / eats | Ram eats a fruit |
| \u0938\u0940\u0924\u0906 \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D \u092A\u0920\u0924\u093F | Sita / book / reads | Sita reads a book |
| \u092C\u0906\u0932\u093F\u0915\u0906 \u091C\u0932\u092E\u094D \u092A\u093F\u092C\u0924\u093F | girl / water / drinks | The girl drinks water |
| \u092E\u0906\u0924\u0906 \u0905\u0928\u094D\u0928\u092E\u094D \u092A\u091A\u0924\u093F | mother / food / cooks | Mother cooks food |
| \u092C\u0906\u0932\u0915\u0903 \u0935\u093F\u0926\u094D\u092F\u0906\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u0924\u093F | boy / school / goes | The boy goes to school |

## Translate with Pronouns

| Sanskrit | Meaning |
|---|---|
| \u0905\u0939\u0902 \u092A\u0941\u0938\u094D\u0924\u0915\u092E\u094D \u092A\u0920\u0906\u092E\u093F | I read a book |
| \u0924\u094D\u0935\u092E\u094D \u0915\u093F\u092E\u094D \u0916\u0906\u0926\u0938\u093F? | What are you eating? |
| \u0905\u0939\u0902 \u0935\u093F\u0926\u094D\u092F\u0906\u0932\u092F\u092E\u094D \u0917\u091A\u094D\u091B\u0906\u092E\u093F | I go to school |

## Find the Verb Last

In every sentence above the verb is LAST. When you translate into Sanskrit:

1. Find the subject → case 1.
2. Find the object → case 2 (masculine words like \u092B\u0932\u092E\u094D take the -\u092E\u094D ending).
3. Put the verb at the END.

## Practice Tip

> Take any English sentence from this lesson and rebuild it in SOV order. \u092B\u0932\u092E\u094D first, then the eater, then \u0916\u0906\u0926\u0924\u093F. The habit of "verb last" is the single most useful skill for reading real Sanskrit.''';

/// Content for the expanded lessons, merged by [CurriculumLoader].
final Map<String, String> unit2LessonContent = {
  'ls_alphabet_conjuncts': kConjunctsContent,
  'ls_grammar_nouns_cases': kNounCasesContent,
  'ls_grammar_pronouns': kPronounsContent,
  'ls_grammar_verbs': kVerbsContent,
  'ls_sentences_translation': kTranslationContent,
};