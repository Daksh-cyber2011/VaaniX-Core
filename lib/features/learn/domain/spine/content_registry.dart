/// Learn Mode 2.0 — Trusted Content Registry (M5, Master Brief §15/§32/§34)
///
/// M5 redesigns how learning content is selected and generated. The brief
/// is explicit about the foundation:
///
///   "Do NOT throw away existing static curricula. Instead classify them
///    as TRUSTED SEEDED CONTENT. They become available to the AI planner.
///    The AI can select: existing lesson / existing concept / existing
///    exercise — or, where safe and supported, generate a personalized
///    explanation/example/exercise. The system should PREFER trusted
///    content when available." (§15)
///
/// This file is that classification. It maps the EXISTING A–G curricula
/// (chapters → lessons → exercise banks) into addressable trusted content
/// entries — no content is rewritten, moved, or re-authored (§32 "use
/// existing content as trusted seeds").
///
/// It also derives, per concept, a [TrustedKnowledgeExcerpt]: the trusted
/// vocabulary, example sentences and reference text extracted ONLY from
/// the shipped curriculum and exercise banks. The AI generation path
/// (M5's personalized material) must ground every output in this excerpt
/// (§16 "generate from trusted knowledge rather than hallucinating
/// arbitrary grammar") and the validator compares its output against it
/// (§45 "where possible compare against trusted vocabulary/grammar data").
///
/// Priority ladder this enables (§34):
///   1. validated trusted content   ← this registry
///   2. validated language knowledge← the excerpts
///   3. AI personalization          ← generated_content.dart
///   4. AI generation when safe     ← generated_content.dart
///   5. fallback content            ← trusted entries again / safe empty
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// What kind of trusted content one entry points at (Master Brief §15:
/// "existing lesson / existing concept / existing exercise" — concepts
/// are addressed by [TrustedContent.conceptId] on every entry).
enum TrustedContentKind { lesson, exercise }

/// One addressable piece of trusted seeded content.
///
/// A lesson entry anchors the concept's trusted lesson (the same lesson
/// id the concept graph uses, so resolution is drift-free); an exercise
/// entry anchors one exercise from the shipped language bank.
class TrustedContent extends Equatable {
  const TrustedContent({
    required this.id,
    required this.kind,
    required this.languageCode,
    required this.conceptId,
    required this.lessonId,
    required this.skillId,
    required this.title,
    required this.detail,
    required this.difficulty,
    required this.order,
    this.exerciseType,
    this.exerciseCount = 0,
  });

  /// Stable registry id: `tc:<lang>:lesson:<lessonId>` for lessons,
  /// `tc:<lang>:ex:<exerciseId>` for exercises.
  final String id;

  final TrustedContentKind kind;

  /// ISO 639-1 code of the owning language.
  final String languageCode;

  /// The concept this content develops (graph-stable id).
  final String conceptId;

  /// The trusted lesson anchor (== the concept's lessonId).
  final String lessonId;

  /// Owning chapter id (the M1 skill id).
  final String skillId;

  final String title;

  /// Short human-readable summary (lesson content opening or the
  /// exercise prompt). Never AI-authored — curriculum data only.
  final String detail;

  final Difficulty difficulty;

  /// Curriculum order (chapter order × 1000 + lesson position); exercise
  /// entries inherit their lesson's order plus the exercise index.
  final int order;

  /// Set for [TrustedContentKind.exercise] entries only.
  final ExerciseType? exerciseType;

  /// For lesson entries: how many trusted exercises the bank ships.
  final int exerciseCount;

  @override
  List<Object?> get props => [
        id, kind, languageCode, conceptId, lessonId, skillId, title, detail,
        difficulty, order, exerciseType, exerciseCount,
      ];
}

/// The trusted knowledge layer for ONE concept (Master Brief §16/§31).
///
/// Everything here is extracted verbatim from the shipped curriculum
/// asset and exercise bank — the AI may PERSONALIZE from this material
/// but never invent beyond it. An empty excerpt (stub language, or a
/// lesson with no content) honestly signals "nothing trusted to ground
/// on" and the generation path refuses instead of guessing.
class TrustedKnowledgeExcerpt extends Equatable {
  const TrustedKnowledgeExcerpt({
    required this.languageCode,
    required this.conceptId,
    required this.lessonId,
    required this.vocabulary,
    required this.exampleSentences,
    required this.referenceText,
    required this.isRTL,
    required this.scriptCode,
  });

  /// A concept with no trusted material to ground on.
  const TrustedKnowledgeExcerpt.empty({
    required String languageCode,
    required String conceptId,
    required String lessonId,
  }) : this(
          languageCode: languageCode,
          conceptId: conceptId,
          lessonId: lessonId,
          vocabulary: const <String>[],
          exampleSentences: const <String>[],
          referenceText: '',
          isRTL: false,
          scriptCode: '',
        );

  final String languageCode;
  final String conceptId;
  final String lessonId;

  /// Trusted vocabulary tokens (capped — see [kMaxExcerptVocabulary]).
  final List<String> vocabulary;

  /// Short trusted example sentences from the lesson content.
  final List<String> exampleSentences;

  /// The lesson's own content, truncated — the grounding reference the
  /// prompt shows the model and the validator compares against.
  final String referenceText;

  /// Script direction (Urdu is the only RTL language in the catalogue).
  final bool isRTL;

  /// ISO 15924 script tag (`Deva`, `Arab`, …) — drives the wrong-script
  /// guard of the generated-content validator (Master Brief §47/§48).
  final String scriptCode;

  /// True when this excerpt has nothing trusted to ground on.
  bool get isEmpty =>
      vocabulary.isEmpty && exampleSentences.isEmpty && referenceText.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [
        languageCode, conceptId, lessonId, vocabulary, exampleSentences,
        referenceText, isRTL, scriptCode,
      ];
}

/// Caps that keep the excerpts (and therefore the AI prompts) small.
abstract final class TrustedContentLimits {
  /// Maximum vocabulary tokens kept per concept excerpt.
  static const int kMaxVocabulary = 90;

  /// Maximum trusted example sentences per concept excerpt.
  static const int kMaxExamples = 6;

  /// Maximum characters of raw lesson reference text.
  static const int kMaxReferenceChars = 700;

  /// Sentence bounds for the trusted example list.
  static const int kMinSentenceChars = 8;
  static const int kMaxSentenceChars = 90;
}

/// The trusted seeded content for ONE language, derived from the existing
/// curriculum + exercise banks (Master Brief §15/§32).
///
/// Not const-constructible by design: it memoizes lookup indexes.
class TrustedContentRegistry extends Equatable {
  TrustedContentRegistry({
    required this.languageCode,
    required this.isRTL,
    required this.scriptCode,
    required this.entries,
    required this.excerpts,
  })  : _conceptIndex = _indexBy(entries, (e) => e.conceptId),
        _lessonIndex = _indexBy(
          entries.where((e) => e.kind == TrustedContentKind.lesson),
          (e) => e.lessonId,
        ),
        _exerciseIdIndex = {
          for (final e in entries)
            if (e.kind == TrustedContentKind.exercise)
              e.id.substring('tc:${e.languageCode}:ex:'.length): e,
        };

  /// A registry for a language with no trusted content (stub curricula,
  /// or the smart-practice path opened before a language is picked).
  factory TrustedContentRegistry.empty({
    String languageCode = '',
    bool isRTL = false,
    String scriptCode = '',
  }) {
    return TrustedContentRegistry(
      languageCode: languageCode,
      isRTL: isRTL,
      scriptCode: scriptCode,
      entries: const <TrustedContent>[],
      excerpts: const <String, TrustedKnowledgeExcerpt>{},
    );
  }

  /// Builds the registry from the EXISTING curriculum data.
  ///
  /// Defensive by design: duplicate lesson/exercise ids keep the first
  /// occurrence, lessons with no exercises still produce a lesson entry
  /// (with exerciseCount 0), and a fully empty curriculum produces an
  /// empty registry — never an exception.
  factory TrustedContentRegistry.build({
    required ConceptGraph graph,
    required List<Chapter> chapters,
    required Map<String, List<Exercise>> exercisesByLesson,
    required bool isRTL,
    required String scriptCode,
  }) {
    final contentByLesson = <String, Lesson>{};
    for (final chapter in chapters) {
      for (final lesson in chapter.lessons) {
        contentByLesson.putIfAbsent(lesson.id, () => lesson);
      }
    }

    final entries = <TrustedContent>[];
    final excerpts = <String, TrustedKnowledgeExcerpt>{};
    final seenIds = <String>{};

    for (final concept in graph.concepts) {
      final lesson = contentByLesson[concept.lessonId];
      final exercises = exercisesByLesson[concept.lessonId] ?? const [];

      // ── Lesson entry (the trusted anchor) ──
      final lessonId = 'tc:${graph.languageCode}:lesson:${concept.lessonId}';
      if (seenIds.add(lessonId)) {
        entries.add(TrustedContent(
          id: lessonId,
          kind: TrustedContentKind.lesson,
          languageCode: graph.languageCode,
          conceptId: concept.id,
          lessonId: concept.lessonId,
          skillId: concept.skillId,
          title: lesson?.title ?? concept.title,
          detail: _summarize(lesson),
          difficulty: concept.difficulty,
          order: concept.order,
          exerciseCount: exercises.length,
        ));
      }

      // ── Exercise entries (the trusted practice pool) ──
      for (var i = 0; i < exercises.length; i++) {
        final exercise = exercises[i];
        final exId = 'tc:${graph.languageCode}:ex:${exercise.id}';
        if (!seenIds.add(exId)) continue;
        entries.add(TrustedContent(
          id: exId,
          kind: TrustedContentKind.exercise,
          languageCode: graph.languageCode,
          conceptId: concept.id,
          lessonId: concept.lessonId,
          skillId: concept.skillId,
          title: exercise.prompt,
          detail: exercise.explanation ?? '',
          difficulty: concept.difficulty,
          order: concept.order * 10 + i,
          exerciseType: exercise.type,
        ));
      }

      excerpts[concept.id] = _buildExcerpt(
        languageCode: graph.languageCode,
        concept: concept,
        lesson: lesson,
        exercises: exercises,
        isRTL: isRTL,
        scriptCode: scriptCode,
      );
    }

    return TrustedContentRegistry(
      languageCode: graph.languageCode,
      isRTL: isRTL,
      scriptCode: scriptCode,
      entries: List.unmodifiable(entries),
      excerpts: Map.unmodifiable(excerpts),
    );
  }

  final String languageCode;
  final bool isRTL;
  final String scriptCode;

  /// All trusted entries in curriculum order.
  final List<TrustedContent> entries;

  /// Per-concept trusted knowledge excerpts.
  final Map<String, TrustedKnowledgeExcerpt> excerpts;

  final Map<String, List<TrustedContent>> _conceptIndex;
  final Map<String, TrustedContent> _lessonIndex;
  final Map<String, TrustedContent> _exerciseIdIndex;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  int get lessonCount => _lessonIndex.length;
  int get exerciseCount =>
      entries.where((e) => e.kind == TrustedContentKind.exercise).length;

  /// All trusted content for one concept (lesson entry first, then its
  /// exercises in bank order). Empty when the concept is unknown.
  List<TrustedContent> entriesForConcept(String conceptId) =>
      _conceptIndex[conceptId] ?? const <TrustedContent>[];

  /// The trusted lesson entry for a concept, or `null` when unknown.
  TrustedContent? lessonEntryFor(String conceptId) {
    for (final entry in entriesForConcept(conceptId)) {
      if (entry.kind == TrustedContentKind.lesson) return entry;
    }
    return null;
  }

  /// The trusted exercise entries for a concept, in bank order.
  List<TrustedContent> exerciseEntriesFor(String conceptId) =>
      entriesForConcept(conceptId)
          .where((e) => e.kind == TrustedContentKind.exercise)
          .toList();

  /// Resolves an exercise entry by its RAW exercise id (without the
  /// `tc:<lang>:ex:` prefix), or `null`.
  TrustedContent? entryForExercise(String exerciseId) =>
      _exerciseIdIndex[exerciseId];

  /// The trusted knowledge excerpt for a concept. Unknown concepts get an
  /// EMPTY excerpt (fail-closed: nothing trusted → nothing generated).
  TrustedKnowledgeExcerpt excerptFor(String conceptId) =>
      excerpts[conceptId] ??
      const TrustedKnowledgeExcerpt.empty(
        languageCode: '',
        conceptId: '',
        lessonId: '',
      );

  static Map<String, List<TrustedContent>> _indexBy(
    Iterable<TrustedContent> source,
    String Function(TrustedContent) keyOf,
  ) {
    final map = <String, List<TrustedContent>>{};
    for (final entry in source) {
      map.putIfAbsent(keyOf(entry), () => <TrustedContent>[]).add(entry);
    }
    return map;
  }

  /// One honest sentence of lesson detail (never AI-authored).
  static String _summarize(Lesson? lesson) {
    if (lesson == null) return '';
    final subtitle = lesson.subtitle?.trim();
    if (subtitle != null && subtitle.isNotEmpty) return subtitle;
    final content = lesson.content?.trim() ?? '';
    if (content.isEmpty) return '';
    final firstLine =
        content.split(RegExp(r'\n')).firstWhere((l) => l.trim().isNotEmpty,
            orElse: () => content);
    final trimmed = firstLine.trim();
    return trimmed.length <= 140
        ? trimmed
        : '${trimmed.substring(0, 137)}…';
  }

  /// Extracts the trusted knowledge excerpt for one concept from the
  /// lesson content + the exercise bank (ALL verbatim trusted data).
  static TrustedKnowledgeExcerpt _buildExcerpt({
    required String languageCode,
    required LearnConcept concept,
    required Lesson? lesson,
    required List<Exercise> exercises,
    required bool isRTL,
    required String scriptCode,
  }) {
    final content = lesson?.content?.trim() ?? '';

    // ── Vocabulary: trusted tokens, exercise-answer words first ──
    final vocab = <String>[];
    void addTokens(String text) {
      for (final token in tokenizeTrustedText(text)) {
        if (vocab.length >= TrustedContentLimits.kMaxVocabulary) return;
        if (!vocab.contains(token)) vocab.add(token);
      }
    }

    // Answers and options carry the tested vocabulary — they lead.
    for (final exercise in exercises) {
      addTokens(exercise.acceptedAnswers.join(' '));
      if (exercise.correctIndex != null &&
          exercise.correctIndex! >= 0 &&
          exercise.correctIndex! < exercise.options.length) {
        addTokens(exercise.options[exercise.correctIndex!]);
      }
      addTokens(exercise.items.join(' '));
      addTokens(exercise.pairs.map((p) => '${p.left} ${p.right}').join(' '));
    }
    for (final exercise in exercises) {
      addTokens(exercise.prompt);
    }
    addTokens(content);
    addTokens(lesson?.subtitle ?? '');

    // ── Example sentences: short trusted lines from the lesson ──
    final examples = <String>[];
    for (final sentence in _splitSentences(content)) {
      if (examples.length >= TrustedContentLimits.kMaxExamples) break;
      if (sentence.length < TrustedContentLimits.kMinSentenceChars) continue;
      if (sentence.length > TrustedContentLimits.kMaxSentenceChars) continue;
      if (!examples.contains(sentence)) examples.add(sentence);
    }

    final reference = content.length <= TrustedContentLimits.kMaxReferenceChars
        ? content
        : content.substring(0, TrustedContentLimits.kMaxReferenceChars);

    return TrustedKnowledgeExcerpt(
      languageCode: languageCode,
      conceptId: concept.id,
      lessonId: concept.lessonId,
      vocabulary: List.unmodifiable(vocab),
      exampleSentences: List.unmodifiable(examples),
      referenceText: reference,
      isRTL: isRTL,
      scriptCode: scriptCode,
    );
  }

  /// Splits trusted content into sentence-ish lines (Devanagari danda,
  /// Latin punctuation and newlines all count as boundaries).
  static List<String> _splitSentences(String text) => text
      .split(RegExp(r'[।!?\n\r]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Unicode-aware letter-run tokenizer used by both the excerpt builder
  /// and the generated-content grounding check (same rules both sides).
  static final RegExp _tokenPattern = RegExp(r'\p{L}+', unicode: true);

  static List<String> tokenizeTrustedText(String text) {
    final tokens = <String>[];
    for (final match in _tokenPattern.allMatches(text)) {
      final token = match.group(0)!;
      // Single-letter runs carry no testable vocabulary.
      if (token.length < 2) continue;
      tokens.add(token);
    }
    return tokens;
  }

  @override
  List<Object?> get props =>
      [languageCode, isRTL, scriptCode, entries, excerpts];
}

/// Maps the planner's 1..5 difficulty knob onto the app's [Difficulty]
/// bands and back (inverse of `AiPlanParser.difficultyFromKnob`).
int difficultyKnobForBand(Difficulty difficulty) => switch (difficulty) {
      Difficulty.beginner => 2,
      Difficulty.intermediate => 3,
      Difficulty.advanced => 4,
    };
