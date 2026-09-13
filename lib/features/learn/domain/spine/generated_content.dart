/// Learn Mode 2.0 — AI-Generated Personalized Content (M5, Master Brief
/// §15/§16/§45/§46/§47/§48)
///
/// Where trusted content is the seed, this is the personalized layer the
/// brief allows ON TOP of it:
///
///   "or, where safe and supported: generate a personalized
///    explanation/example/exercise. AI-generated material must pass
///    validation." (§15)
///
///   "Do NOT let Gemini freely invent language facts. … generate from
///    trusted knowledge rather than hallucinating arbitrary grammar.
///    If confidence is insufficient: fallback to trusted content. Never
///    teach uncertain facts as certain." (§16)
///
/// The validator enforces §45's minimum list — language, difficulty,
/// structure, required fields, supported exercise type, expected answer,
/// explanation — plus the two honesty extras the brief demands:
///
/// - §45 "where possible compare against trusted vocabulary/grammar
///   data": generated text must share vocabulary with the concept's
///   [TrustedKnowledgeExcerpt] (skipped honestly when the excerpt is
///   empty — no trusted words means no grounding, so nothing is accepted
///   as "grounded" by default);
/// - §47/§48 language correctness + script direction: target-language
///   text for a non-Latin script that arrives in the wrong script is
///   discarded (Hindi grammar inside Bengali, wrong script, bad
///   transliteration — all become rejections, not lessons).
///
/// §46 is the failure contract: malformed AI material is DISCARDED
/// (never "fixed", never thrown) and the caller falls back to trusted
/// content — a broken exercise can never reach the UI.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';

/// The personalized material kinds the brief allows (§15 "explanation /
/// example / exercise"; §45 "examples, explanations, practice questions,
/// mini dialogues" — a mini dialogue is an [GeneratedContentKind.example]
/// with multiple lines).
enum GeneratedContentKind { explanation, example, practice }

/// Exercise types the M5 inline practice runner can render for GENERATED
/// content (the trusted banks keep supporting all five; generation is
/// deliberately narrower — "where safe and supported", §15).
const Set<ExerciseType> kGeneratableExerciseTypes = <ExerciseType>{
  ExerciseType.mcq,
  ExerciseType.fillBlank,
  ExerciseType.translation,
};

/// One line of a personalized example / mini dialogue.
class GeneratedExampleLine extends Equatable {
  const GeneratedExampleLine({required this.text, this.translation});

  final String text;

  /// Optional English gloss (the model may omit it).
  final String? translation;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (translation != null) 'translation': translation,
      };

  /// Defensive parse — never throws on malformed input.
  static GeneratedExampleLine? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final translation = raw['translation'];
    return GeneratedExampleLine(
      text: text.trim(),
      translation: translation is String && translation.trim().isNotEmpty
          ? translation.trim()
          : null,
    );
  }

  @override
  List<Object?> get props => [text, translation];
}

/// A validated piece of AI-personalized learning material.
///
/// Everything except [Exercise] fields is provenance-safe: the concept /
/// lesson anchors are FORCED to the trusted concept the material was
/// requested for (the model cannot point the material anywhere else),
/// and the difficulty knob is the REQUESTED one (the model's own number
/// is display-only, never trusted).
class GeneratedContent extends Equatable {
  const GeneratedContent({
    required this.id,
    required this.kind,
    required this.languageCode,
    required this.conceptId,
    required this.lessonId,
    required this.difficultyKnob,
    required this.title,
    required this.createdAt,
    this.body,
    this.lines = const <GeneratedExampleLine>[],
    this.exercise,
  });

  final String id;
  final GeneratedContentKind kind;
  final String languageCode;

  /// Trusted anchors (forced by the validator — never model-supplied).
  final String conceptId;
  final String lessonId;

  /// The requested difficulty knob (1..5).
  final int difficultyKnob;

  final String title;

  /// [GeneratedContentKind.explanation] body text.
  final String? body;

  /// [GeneratedContentKind.example] lines (mini dialogue / examples).
  final List<GeneratedExampleLine> lines;

  /// [GeneratedContentKind.practice] exercise — a REAL [Exercise] in the
  /// trusted shape, so M6's exercise engine can adopt it unchanged.
  final Exercise? exercise;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'languageCode': languageCode,
        'conceptId': conceptId,
        'lessonId': lessonId,
        'difficultyKnob': difficultyKnob,
        'title': title,
        if (body != null) 'body': body,
        if (lines.isNotEmpty)
          'lines': [for (final line in lines) line.toJson()],
        if (exercise != null) 'exercise': _exerciseToJson(exercise!),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Defensive restore from persisted JSON. Returns `null` for anything
  /// unreadable — corrupt storage degrades to "no cache", never a crash
  /// (the generator re-validates restored items anyway).
  static GeneratedContent? fromJson(Map<String, dynamic> json) {
    final kind = GeneratedContentKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    String? requiredString(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final id = requiredString('id');
    final languageCode = requiredString('languageCode');
    final conceptId = requiredString('conceptId');
    final lessonId = requiredString('lessonId');
    final title = requiredString('title');
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id == null ||
        languageCode == null ||
        conceptId == null ||
        lessonId == null ||
        title == null ||
        createdAt == null) {
      return null;
    }
    final exerciseJson = json['exercise'];
    return GeneratedContent(
      id: id,
      kind: kind,
      languageCode: languageCode,
      conceptId: conceptId,
      lessonId: lessonId,
      difficultyKnob:
          ((json['difficultyKnob'] as num?)?.toInt() ?? 0).clamp(1, 5).toInt(),
      title: title,
      body: json['body'] is String ? json['body'] as String : null,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map(GeneratedExampleLine.fromJson)
          .whereType<GeneratedExampleLine>()
          .toList(),
      exercise: exerciseJson is Map<String, dynamic>
          ? _exerciseFromJson(exerciseJson)
          : null,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        languageCode,
        conceptId,
        lessonId,
        difficultyKnob,
        title,
        body,
        lines,
        exercise,
        createdAt,
      ];
}

// ─── Untrusted exercise JSON ⇄ trusted Exercise ─────────────────────────────

Map<String, dynamic> _exerciseToJson(Exercise exercise) => {
      'id': exercise.id,
      'lessonId': exercise.lessonId,
      'type': exercise.type.name,
      'prompt': exercise.prompt,
      'options': exercise.options,
      'correctIndex': exercise.correctIndex,
      'items': exercise.items,
      'acceptedAnswers': exercise.acceptedAnswers,
      'pairs': [
        for (final p in exercise.pairs) {'left': p.left, 'right': p.right},
      ],
      'explanation': exercise.explanation,
      'hint': exercise.hint,
    };

/// Builds a generated [Exercise] from untrusted JSON with FORCED trusted
/// anchors: [forcedLessonId] becomes the lessonId and [forcedId] the id —
/// the model can never re-anchor generated content to another lesson or
/// collide with a trusted exercise id.
Exercise? _exerciseFromJson(
  Map<String, dynamic> json, {
  String? forcedId,
  String? forcedLessonId,
}) {
  String asString(Object? v) => v is String ? v.trim() : '';
  final type = ExerciseType.values
      .where((t) => t.name == asString(json['type']))
      .firstOrNull;
  if (type == null) return null;
  final prompt = asString(json['prompt']);
  if (prompt.isEmpty) return null;
  List<String> asStrings(Object? v) => (v as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  return Exercise(
    id: forcedId ?? asString(json['id']),
    lessonId: forcedLessonId ?? asString(json['lessonId']),
    type: type,
    prompt: prompt,
    options: asStrings(json['options']),
    correctIndex: (json['correctIndex'] as num?)?.toInt(),
    items: asStrings(json['items']),
    acceptedAnswers: asStrings(json['acceptedAnswers']),
    pairs: [
      for (final raw in (json['pairs'] as List<dynamic>? ?? const []))
        if (raw is Map<String, dynamic> &&
            asString(raw['left']).isNotEmpty &&
            asString(raw['right']).isNotEmpty)
          (left: asString(raw['left']), right: asString(raw['right'])),
    ],
    explanation: asString(json['explanation']).isEmpty
        ? null
        : asString(json['explanation']),
    hint: asString(json['hint']).isEmpty ? null : asString(json['hint']),
  );
}

// ─── Validation ──────────────────────────────────────────────────────────────

/// Why a piece of generated material was rejected (Master Brief §45/§46).
enum GeneratedRejection {
  /// Output missing required fields / wrong types.
  malformedOutput,

  /// The material claims another language than the requested one.
  languageMismatch,

  /// Material kind not supported by this build/flow.
  unsupportedKind,

  /// Difficulty outside the valid range.
  invalidDifficulty,

  /// Exercise type outside the generatable set (§15 "where safe and
  /// supported").
  unsupportedExerciseType,

  /// A required field for the kind is missing/empty.
  missingFields,

  /// Target-language text arrived in the wrong script (§47/§48).
  wrongScript,

  /// The material shares no vocabulary with the trusted excerpt (§45
  /// "compare against trusted vocabulary/grammar data").
  ungroundedContent,

  /// Text exceeds the size caps (prompt-bloat guard).
  oversized,

  /// Text carries control or bidi-manipulation characters (M10, §90
  /// "unexpected Unicode": renders invisibly or spoofs direction).
  unsafeCharacters,

  /// The generated exercise is not well-formed for the engine.
  invalidExercise;

  String get explanation => switch (this) {
        GeneratedRejection.malformedOutput =>
          'generated output was missing required fields',
        GeneratedRejection.languageMismatch =>
          'material belongs to a different language',
        GeneratedRejection.unsupportedKind =>
          'material kind is not supported here',
        GeneratedRejection.invalidDifficulty => 'difficulty is out of range',
        GeneratedRejection.unsupportedExerciseType =>
          'exercise type cannot be generated safely',
        GeneratedRejection.missingFields => 'required fields are missing',
        GeneratedRejection.wrongScript => 'text is in the wrong script',
        GeneratedRejection.ungroundedContent =>
          'material is not grounded in the trusted vocabulary',
        GeneratedRejection.oversized => 'material exceeds size limits',
        GeneratedRejection.unsafeCharacters =>
          'text contains control or bidi-manipulation characters',
        GeneratedRejection.invalidExercise =>
          'the generated exercise is not well-formed',
      };
}

/// The outcome of validating one piece of generated material.
class GeneratedValidation {
  const GeneratedValidation._(this.content, this.rejections);

  final GeneratedContent? content;
  final List<GeneratedRejection> rejections;

  bool get isValid => content != null && rejections.isEmpty;
}

/// Validates decoded (untrusted) model output into a [GeneratedContent].
///
/// Everything the model supplies is treated as hostile: anchors and
/// difficulty are forced from the request, ids are forced fresh, and any
/// §45/§46/§47/§48 violation is a rejection — the caller discards and
/// falls back to trusted content (§46).
abstract final class GeneratedContentValidator {
  /// Size caps (Master Brief §46 "never let malformed AI-generated
  /// content crash the app" — and §63 bounded outputs).
  static const int kMaxTitleChars = 80;
  static const int kMinBodyChars = 20;
  static const int kMaxBodyChars = 1200;
  static const int kMaxLines = 8;
  static const int kMaxLineChars = 200;
  static const int kMaxPromptChars = 240;
  static const int kMaxOptions = 6;
  static const int kMaxAcceptedAnswers = 6;
  static const int kMinExplanationChars = 3;
  static const int kMaxExplanationChars = 600;

  /// Validates [raw] (a decoded JSON map) as ONE item of [requestedKind]
  /// for [concept], grounded in [excerpt].
  static GeneratedValidation validate({
    required Object? raw,
    required GeneratedContentKind requestedKind,
    required String languageCode,
    required bool isRTL,
    required String scriptCode,
    required String conceptId,
    required String lessonId,
    required int difficultyKnob,
    required TrustedKnowledgeExcerpt excerpt,
    required String Function() freshId,
  }) {
    if (raw is! Map<String, dynamic>) {
      return const GeneratedValidation._(
        null,
        [GeneratedRejection.malformedOutput],
      );
    }
    final rejections = <GeneratedRejection>[];

    // ── Kind ──
    final kindName = raw['kind'];
    final kind = GeneratedContentKind.values
        .where((k) => k.name == kindName)
        .firstOrNull;
    if (kind == null || kind != requestedKind) {
      rejections.add(GeneratedRejection.unsupportedKind);
      return GeneratedValidation._(null, rejections);
    }

    // ── Language gate (§14/§47) ──
    final claimedLanguage = raw['language'];
    if (claimedLanguage is String &&
        claimedLanguage.trim().isNotEmpty &&
        claimedLanguage.trim() != languageCode) {
      rejections.add(GeneratedRejection.languageMismatch);
      return GeneratedValidation._(null, rejections);
    }

    // ── Difficulty knob (the REQUESTED one is authoritative) ──
    if (difficultyKnob < 1 || difficultyKnob > 5) {
      rejections.add(GeneratedRejection.invalidDifficulty);
      return GeneratedValidation._(null, rejections);
    }

    // ── Title ──
    final title = _stringOf(raw['title']);
    if (title.isEmpty) {
      rejections.add(GeneratedRejection.missingFields);
      return GeneratedValidation._(null, rejections);
    }
    if (title.length > kMaxTitleChars) {
      rejections.add(GeneratedRejection.oversized);
      return GeneratedValidation._(null, rejections);
    }
    // M10 (§90 "unexpected Unicode"): invisible control characters and
    // bidi overrides can spoof direction or smuggle junk past every
    // other check. Rejected on sight, everywhere text is read.
    if (_containsUnsafeCharacters(title)) {
      rejections.add(GeneratedRejection.unsafeCharacters);
      return GeneratedValidation._(null, rejections);
    }

    // ── Kind-specific structure (§45: language, structure, required
    //    fields, supported exercise type, expected answer, explanation) ──
    String? body;
    var lines = const <GeneratedExampleLine>[];
    Exercise? exercise;

    switch (kind) {
      case GeneratedContentKind.explanation:
        body = _stringOf(raw['body']);
        if (body.isEmpty) {
          rejections.add(GeneratedRejection.missingFields);
        } else if (body.length < kMinBodyChars || body.length > kMaxBodyChars) {
          rejections.add(GeneratedRejection.oversized);
        } else if (_containsUnsafeCharacters(body)) {
          rejections.add(GeneratedRejection.unsafeCharacters);
        } else if (!_groundedIn(body, excerpt)) {
          rejections.add(GeneratedRejection.ungroundedContent);
        }

      case GeneratedContentKind.example:
        final rawLines = raw['lines'];
        lines = rawLines is List<dynamic>
            ? rawLines
                .map(GeneratedExampleLine.fromJson)
                .whereType<GeneratedExampleLine>()
                .toList()
            : const <GeneratedExampleLine>[];
        if (lines.isEmpty) {
          rejections.add(GeneratedRejection.missingFields);
        } else if (lines.length > kMaxLines) {
          rejections.add(GeneratedRejection.oversized);
        } else if (lines.any((l) => l.text.length > kMaxLineChars) ||
            lines.any(
              (l) => (l.translation?.length ?? 0) > kMaxLineChars,
            )) {
          rejections.add(GeneratedRejection.oversized);
        } else if (lines.any((l) =>
            _containsUnsafeCharacters(l.text) ||
            _containsUnsafeCharacters(l.translation ?? ''))) {
          rejections.add(GeneratedRejection.unsafeCharacters);
        } else if (!_usesExpectedScript(
          lines.map((l) => l.text).join(' '),
          scriptCode: scriptCode,
          isRTL: isRTL,
        )) {
          rejections.add(GeneratedRejection.wrongScript);
        } else if (!_anyLineGrounded(lines, excerpt)) {
          rejections.add(GeneratedRejection.ungroundedContent);
        }

      case GeneratedContentKind.practice:
        final result = _validatePracticeExercise(
          raw['exercise'],
          conceptId: conceptId,
          lessonId: lessonId,
          excerpt: excerpt,
          scriptCode: scriptCode,
          isRTL: isRTL,
          freshId: freshId,
        );
        exercise = result.$1;
        rejections.addAll(result.$2);
    }

    if (rejections.isNotEmpty) {
      return GeneratedValidation._(null, rejections);
    }

    return GeneratedValidation._(
      GeneratedContent(
        id: freshId(),
        kind: kind,
        languageCode: languageCode,
        conceptId: conceptId,
        lessonId: lessonId,
        difficultyKnob: difficultyKnob,
        title: title,
        body: body,
        lines: lines,
        exercise: exercise,
        createdAt: DateTime.now(),
      ),
      const [],
    );
  }

  /// Validates the practice-kind exercise object. Returns the built
  /// [Exercise] (with FORCED anchors) plus any rejections.
  static (Exercise?, List<GeneratedRejection>) _validatePracticeExercise(
    Object? rawExercise, {
    required String conceptId,
    required String lessonId,
    required TrustedKnowledgeExcerpt excerpt,
    required String scriptCode,
    required bool isRTL,
    required String Function() freshId,
  }) {
    if (rawExercise is! Map<String, dynamic>) {
      return (null, [GeneratedRejection.malformedOutput]);
    }
    final rejections = <GeneratedRejection>[];

    final typeName = _stringOf(rawExercise['type']);
    final type =
        ExerciseType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null || !kGeneratableExerciseTypes.contains(type)) {
      return (null, [GeneratedRejection.unsupportedExerciseType]);
    }

    // Force the trusted anchors BEFORE validity — the model never picks
    // the id or the lesson (defence in depth, §14/§32).
    final exercise = _exerciseFromJson(
      rawExercise,
      forcedId: freshId(),
      forcedLessonId: lessonId,
    );
    if (exercise == null) {
      return (null, [GeneratedRejection.malformedOutput]);
    }

    if (!exercise.isValid) {
      rejections.add(GeneratedRejection.invalidExercise);
    }

    // §45: expected answer must exist and be checkable.
    if (type == ExerciseType.translation && exercise.acceptedAnswers.isEmpty) {
      rejections.add(GeneratedRejection.missingFields);
    }
    if ((type == ExerciseType.mcq || type == ExerciseType.fillBlank) &&
        (exercise.correctIndex == null ||
            exercise.options.length < 2 ||
            exercise.options.length > kMaxOptions)) {
      rejections.add(GeneratedRejection.invalidExercise);
    }

    // §45: explanation is required for practice material.
    final explanation = exercise.explanation?.trim() ?? '';
    if (explanation.length < kMinExplanationChars) {
      rejections.add(GeneratedRejection.missingFields);
    } else if (explanation.length > kMaxExplanationChars ||
        exercise.prompt.length > kMaxPromptChars ||
        exercise.acceptedAnswers.length > kMaxAcceptedAnswers) {
      rejections.add(GeneratedRejection.oversized);
    }

    // M10 (§90 "unexpected Unicode"): same invisibles guard on every
    // exercise text field.
    if (_containsUnsafeCharacters(explanation) ||
        _containsUnsafeCharacters(exercise.prompt) ||
        exercise.options.any(_containsUnsafeCharacters) ||
        exercise.acceptedAnswers.any(_containsUnsafeCharacters) ||
        exercise.items.any(_containsUnsafeCharacters) ||
        exercise.pairs.any((p) =>
            _containsUnsafeCharacters(p.left) ||
            _containsUnsafeCharacters(p.right))) {
      rejections.add(GeneratedRejection.unsafeCharacters);
    }

    // §47/§48: the target-language fields must be in the expected script.
    if (rejections.isEmpty &&
        !_usesExpectedScript(
          [
            exercise.prompt,
            ...exercise.options,
            ...exercise.acceptedAnswers,
          ].join(' '),
          scriptCode: scriptCode,
          isRTL: isRTL,
        )) {
      rejections.add(GeneratedRejection.wrongScript);
    }

    // §45: compare against trusted vocabulary where possible.
    if (rejections.isEmpty &&
        !_groundedIn(
          [
            exercise.prompt,
            ...exercise.options,
            ...exercise.acceptedAnswers,
          ].join(' '),
          excerpt,
        )) {
      rejections.add(GeneratedRejection.ungroundedContent);
    }

    return (
      rejections.isEmpty ? exercise : null,
      rejections,
    );
  }

  /// True when [text] shares at least one trusted token with the excerpt.
  /// An empty excerpt honestly short-circuits to FALSE — with nothing
  /// trusted to compare against, nothing can be called grounded (§16
  /// "never teach uncertain facts as certain").
  static bool _groundedIn(String text, TrustedKnowledgeExcerpt excerpt) {
    if (excerpt.vocabulary.isEmpty) return false;
    final tokens = TrustedContentRegistry.tokenizeTrustedText(text)
        .map((t) => t.toLowerCase())
        .toSet();
    return tokens.any(excerpt.vocabulary.map((v) => v.toLowerCase()).contains);
  }

  static bool _anyLineGrounded(
    List<GeneratedExampleLine> lines,
    TrustedKnowledgeExcerpt excerpt,
  ) =>
      lines.any((line) => _groundedIn(line.text, excerpt));

  /// ISO 15924 script block the target-language text must touch
  /// (Master Brief §47 "wrong script" / §48 "preserve correct direction").
  static bool _usesExpectedScript(
    String text, {
    required String scriptCode,
    required bool isRTL,
  }) {
    if (text.isEmpty) return false;
    var hasNonAscii = false;
    for (final rune in text.runes) {
      if (rune > 0x7F) hasNonAscii = true;
      if (_inScriptBlock(rune, scriptCode)) return true;
    }
    // The six shipped A–G scripts all have dedicated blocks; a text with
    // no block character is a wrong-script rejection. For scripts without
    // a mapped block, non-ASCII is the best honest proxy.
    if (_hasMappedBlock(scriptCode)) return false;
    return hasNonAscii;
  }

  static bool _hasMappedBlock(String scriptCode) => switch (scriptCode) {
        'Deva' || 'Beng' || 'Telu' || 'Taml' || 'Gujr' || 'Arab' => true,
        'Knda' || 'Mlym' || 'Orya' => true,
        _ => false,
      };

  static bool _inScriptBlock(int rune, String scriptCode) {
    final (start, end) = switch (scriptCode) {
      'Deva' => (0x0900, 0x097F),
      'Beng' => (0x0980, 0x09FF),
      'Gujr' => (0x0A80, 0x0AFF),
      'Orya' => (0x0B00, 0x0B7F),
      'Taml' => (0x0B80, 0x0BFF),
      'Telu' => (0x0C00, 0x0C7F),
      'Knda' => (0x0C80, 0x0CFF),
      'Mlym' => (0x0D00, 0x0D7F),
      'Arab' => (0x0600, 0x06FF),
      _ => (0, -1), // unmapped: no block matches
    };
    if (end <= start) return false;
    // Arabic script also uses the supplement + presentation blocks.
    if (scriptCode == 'Arab') {
      final inSupplement = (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF);
      return (rune >= start && rune <= end) || inSupplement;
    }
    return rune >= start && rune <= end;
  }

  static String _stringOf(Object? value) => value is String ? value.trim() : '';

  /// M10 (§90 "unexpected Unicode"): true when [text] contains
  /// characters that render invisibly or manipulate display order —
  /// C0/C1 control characters (except the harmless newline/tab), the
  /// bidi overrides/embeddings (U+202A–U+202E) and the bidi isolates
  /// (U+2066–U+2069), the zero-width no-break BOM and the zero-width
  /// space.
  ///
  /// NOTE: U+200C (ZWNJ) and U+200D (ZWJ) are deliberately ALLOWED —
  /// they are standard, required orthography in Indic scripts (Tamil
  /// and Telugu trusted lessons use ZWNJ to prevent unwanted conjunct
  /// formation; Devanagari and Malayalam use both for rendering
  /// control). They carry no display-order or spoofing risk.
  static bool _containsUnsafeCharacters(String text) {
    for (final r in text.runes) {
      if (r == 0x0A || r == 0x09) continue; // newline, tab
      if (r < 0x20 || (r >= 0x7F && r < 0xA0)) return true; // C0 / C1
      if (r >= 0x202A && r <= 0x202E) return true; // bidi overrides
      if (r >= 0x2066 && r <= 0x2069) return true; // bidi isolates
      if (r == 0xFEFF) return true; // zero-width no-break BOM
      if (r == 0x200B) return true; // zero-width space
    }
    return false;
  }
}
