/// VaaniX Learn Mode — Language Catalogue (Part 0 Foundation)
///
/// The 10 VaaniX Learn Mode languages and their linguistic metadata.
///
/// This catalogue is the single source of truth for:
/// - which languages Learn Mode offers
/// - how each language's curriculum asset is located
/// - script / direction / locale metadata used by the UI and AI context
///
/// LOCKED LIST (per the VaaniX Learn Mode Master Execution brief):
///   Hindi, Bengali, Marathi, Telugu, Tamil, Gujarati, Urdu, Kannada,
///   Malayalam, Odia.
///
/// Do NOT add languages here without an explicit Part directive — the
/// master brief locks this list at 10. Future expansions will arrive as
/// a separate, explicitly-versioned catalogue change.
///
/// This file contains NO curriculum content. Curriculum data lives in
/// per-language JSON assets under `assets/curriculum/learn/<code>.json`
/// and is loaded by [CurriculumLoader.loadLearnCurriculum]. Parts A–J
/// fill those assets; Part 0 ships only the schema and empty stubs.
library;

/// The 10 VaaniX Learn Mode languages.
///
/// The order is the canonical catalogue order (matches the master brief's
/// locked list). It is used by the language selection screen and by
/// analytics; it has no pedagogical meaning.
enum LearnLanguage {
  hindi,
  bengali,
  marathi,
  telugu,
  tamil,
  gujarati,
  urdu,
  kannada,
  malayalam,
  odia,
}

/// Reading direction of a language's script.
///
/// Urdu is the only RTL script in the catalogue; the other nine are LTR.
enum ScriptDirection { ltr, rtl }

/// Linguistic + asset metadata for one Learn Mode language.
///
/// Field commitments:
/// - [code] is the ISO 639-1 lower-case code (also the JSON asset filename).
/// - [iso639_2] is the ISO 639-2 / 639-3 three-letter code, used by the
///   AI context provider so the model can disambiguate languages.
/// - [scriptCode] is the ISO 15924 script tag (e.g. `Deva`, `Beng`).
/// - [curriculumAssetPath] is the rootBundle path the loader reads.
class LearnLanguageSpec {
  const LearnLanguageSpec({
    required this.language,
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.scriptName,
    required this.scriptCode,
    required this.scriptDirection,
    required this.iso639_1,
    required this.iso639_2,
    required this.curriculumAssetPath,
  });

  /// Enum value (used as the persistence key + Riverpod family key).
  final LearnLanguage language;

  /// ISO 639-1 lower-case code (`'hi'`, `'ur'`, …). Also the JSON filename.
  final String code;

  /// English name shown as a secondary label in the picker.
  final String englishName;

  /// Endonym in the language's own script (`'हिन्दी'`, `'اردو'`, …).
  /// Rendered with the script-appropriate font; the picker relies on
  /// Flutter's default font fallback chain.
  final String nativeName;

  /// Human-readable script name (`'Devanagari'`, `'Nastaliq'`, …).
  final String scriptName;

  /// ISO 15924 script code (`'Deva'`, `'Beng'`, `'Telu'`, …).
  final String scriptCode;

  /// Reading direction of the script.
  final ScriptDirection scriptDirection;

  /// ISO 639-1 code (same as [code], duplicated for clarity in AI context).
  final String iso639_1;

  /// ISO 639-2/3 three-letter code.
  final String iso639_2;

  /// rootBundle path to this language's curriculum JSON.
  final String curriculumAssetPath;

  /// True when the script reads right-to-left (only Urdu in the catalogue).
  bool get isRTL => scriptDirection == ScriptDirection.rtl;
}

/// The locked, ordered catalogue of all 10 VaaniX Learn Mode languages.
///
/// Indexes are stable; do not reorder without an explicit Part directive.
const List<LearnLanguageSpec> kLearnLanguageCatalogue = <LearnLanguageSpec>[
  LearnLanguageSpec(
    language: LearnLanguage.hindi,
    code: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    scriptName: 'Devanagari',
    scriptCode: 'Deva',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'hi',
    iso639_2: 'hin',
    curriculumAssetPath: 'assets/curriculum/learn/hi.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.bengali,
    code: 'bn',
    englishName: 'Bengali',
    nativeName: 'বাংলা',
    scriptName: 'Bengali',
    scriptCode: 'Beng',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'bn',
    iso639_2: 'ben',
    curriculumAssetPath: 'assets/curriculum/learn/bn.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.marathi,
    code: 'mr',
    englishName: 'Marathi',
    nativeName: 'मराठी',
    scriptName: 'Devanagari',
    scriptCode: 'Deva',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'mr',
    iso639_2: 'mar',
    curriculumAssetPath: 'assets/curriculum/learn/mr.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.telugu,
    code: 'te',
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
    scriptName: 'Telugu',
    scriptCode: 'Telu',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'te',
    iso639_2: 'tel',
    curriculumAssetPath: 'assets/curriculum/learn/te.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.tamil,
    code: 'ta',
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
    scriptName: 'Tamil',
    scriptCode: 'Taml',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'ta',
    iso639_2: 'tam',
    curriculumAssetPath: 'assets/curriculum/learn/ta.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.gujarati,
    code: 'gu',
    englishName: 'Gujarati',
    nativeName: 'ગુજરાતી',
    scriptName: 'Gujarati',
    scriptCode: 'Gujr',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'gu',
    iso639_2: 'guj',
    curriculumAssetPath: 'assets/curriculum/learn/gu.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.urdu,
    code: 'ur',
    englishName: 'Urdu',
    nativeName: 'اُردُو',
    scriptName: 'Nastaliq (Arabic)',
    scriptCode: 'Arab',
    scriptDirection: ScriptDirection.rtl,
    iso639_1: 'ur',
    iso639_2: 'urd',
    curriculumAssetPath: 'assets/curriculum/learn/ur.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.kannada,
    code: 'kn',
    englishName: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    scriptName: 'Kannada',
    scriptCode: 'Knda',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'kn',
    iso639_2: 'kan',
    curriculumAssetPath: 'assets/curriculum/learn/kn.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.malayalam,
    code: 'ml',
    englishName: 'Malayalam',
    nativeName: 'മലയാളം',
    scriptName: 'Malayalam',
    scriptCode: 'Mlym',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'ml',
    iso639_2: 'mal',
    curriculumAssetPath: 'assets/curriculum/learn/ml.json',
  ),
  LearnLanguageSpec(
    language: LearnLanguage.odia,
    code: 'or',
    englishName: 'Odia',
    nativeName: 'ଓଡ଼ିଆ',
    scriptName: 'Odia',
    scriptCode: 'Orya',
    scriptDirection: ScriptDirection.ltr,
    iso639_1: 'or',
    iso639_2: 'ori',
    curriculumAssetPath: 'assets/curriculum/learn/or.json',
  ),
];

/// Returns the spec for [language] from the catalogue.
///
/// Lookup is by enum value (not by string code) so the call site is
/// type-safe. Throws [ArgumentError] if [language] is not in the
/// catalogue — this should be impossible for any valid enum value, but
/// the explicit check keeps the failure mode debuggable.
LearnLanguageSpec learnLanguageSpec(LearnLanguage language) {
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.language == language) return spec;
  }
  throw ArgumentError.value(language, 'language',
      'not present in kLearnLanguageCatalogue');
}

/// Looks up a spec by ISO 639-1 [code] (case-insensitive).
///
/// Returns `null` when no language in the catalogue matches. Used by
/// the persistence layer to convert the stored string back to a spec
/// without crashing on legacy / corrupt values.
LearnLanguageSpec? learnLanguageSpecByCode(String code) {
  final lower = code.toLowerCase();
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.code == lower) return spec;
  }
  return null;
}

/// Looks up a spec by its enum [name] (the persisted form).
///
/// Used by [LearnLanguageRepository] to deserialize the stored value.
/// Returns `null` for unknown / legacy names so a corrupt store never
/// crashes the app — the Learn screen falls back to the unselected state.
LearnLanguageSpec? learnLanguageSpecByName(String name) {
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.language.name == name) return spec;
  }
  return null;
}
