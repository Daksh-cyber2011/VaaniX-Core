/// Learn Mode 2.0 — Adaptive Diagnostic Engine (M3)
///
/// The genuinely-adaptive placement flow from the Master Brief §11/§12,
/// implemented as a pure-Dart state machine over TRUSTED content:
///
///   START (seeded from the learner's self-report — never shown as a level)
///     ↓
///   baseline probe (first dimension, seeded difficulty band)
///     ↓
///   two correct in a row → harder band
///     ↓
///   a miss → the next probe is a PREREQUISITE of the missed item
///            (same dimension, earlier concept in curriculum order)
///     ↓
///   rotate dimensions (script → vocabulary → grammar → …)
///     ↓
///   stop when every measurable dimension has enough evidence,
///   or the probe budget is reached, or the trusted pools run dry
///     ↓
///   structured [DiagnosticResult] (+ friendly summary, no raw scores)
///
/// Honesty guarantees (Master Brief §11):
/// - probes come ONLY from the trusted exercise banks mapped onto the
///   concept graph — the diagnostic can never ask anything the app does
///   not authoritatively know;
/// - only dimensions that actually have probes are measured. With the
///   current A–G banks that is script / practical / vocabulary / grammar /
///   reading / sentence-formation. LISTENING is never scored (no audio
///   exists) and comprehension is left unmeasured rather than faked.
///
/// Timing (Master Brief §11 "3–7 minutes"): the stop rules bound a run to
/// [kMinProbes]–[kMaxProbes] probes (8–16). At the natural pace of the
/// exercise engine (~20–30 s per probe) that is the 3–7 minute window,
/// varying with pool richness and performance.
///
/// Determinism: for a fixed bank, seed and answer sequence the whole run
/// is reproducible (unit-tested). Seeds vary between retakes so a retake
/// does not serve the identical probe list.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/exercise_models.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart'
    show LearnLanguage;
import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart'
    show Difficulty;

// ─── Resolved probe ─────────────────────────────────────────────────────────

/// One concrete diagnostic probe: a trusted [Exercise] resolved from the
/// banks, plus the graph anchors the adaptive strategy needs.
class DiagnosticItem extends Equatable {
  const DiagnosticItem({
    required this.exercise,
    required this.probe,
    required this.conceptOrder,
  });

  final Exercise exercise;
  final DiagnosticProbe probe;

  /// Curriculum order of the owning concept (smaller = more foundational).
  final int conceptOrder;

  DiagnosticDimension get dimension => probe.dimension;

  @override
  List<Object?> get props => [exercise.id, probe, conceptOrder];
}

// ─── Answer input (parity with the practice engine's semantics) ─────────────

/// The learner's answer to a probe, in display space.
///
/// Correctness semantics deliberately mirror [ExerciseNotifier] (first-try
/// engine): options compare against the deterministic display permutation,
/// translation normalizes (trim, collapse whitespace, lower-case), ordering
/// compares sequences, matching verifies the display-slot permutation.
/// Pinned by unit tests so the two engines can never silently drift.
sealed class DiagnosticAnswer {
  const DiagnosticAnswer();

  bool isCorrectFor(DiagnosticItem item) {
    final exercise = item.exercise;
    final display = prepareExerciseOptions(exercise, 0);
    return switch (this) {
      DiagnosticChoiceAnswer(:final displayIndex) =>
        displayIndex == display.correctIndex,
      DiagnosticTextAnswer(:final text) => _textIsCorrect(exercise, text),
      DiagnosticOrderAnswer(:final items) => _listEquals(items, exercise.items),
      DiagnosticMatchAnswer(:final leftToRightDisplay) =>
        _matchIsCorrect(exercise, leftToRightDisplay),
    };
  }

  static bool _textIsCorrect(Exercise exercise, String input) {
    final normalized = normalizeDiagnosticAnswer(input);
    if (normalized.isEmpty) return false;
    return exercise.acceptedAnswers
        .any((a) => normalizeDiagnosticAnswer(a) == normalized);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _matchIsCorrect(
    Exercise exercise,
    Map<int, int> leftToRightDisplay,
  ) {
    if (leftToRightDisplay.length != exercise.pairs.length) return false;
    final slotToPair = prepareExerciseOptions(exercise, 0).pairIndexByDisplay;
    final seenSlots = <int>{};
    for (final entry in leftToRightDisplay.entries) {
      final slot = entry.value;
      if (slot < 0 || slot >= slotToPair.length) return false;
      if (!seenSlots.add(slot)) return false; // same right slot used twice
      if (slotToPair[slot] != entry.key) return false;
    }
    return true;
  }
}

/// Selected display option (mcq / fillBlank probes).
class DiagnosticChoiceAnswer extends DiagnosticAnswer {
  const DiagnosticChoiceAnswer(this.displayIndex);
  final int displayIndex;
}

/// Typed answer (translation probes).
class DiagnosticTextAnswer extends DiagnosticAnswer {
  const DiagnosticTextAnswer(this.text);
  final String text;
}

/// Arranged sequence (ordering probes, forward-compatible).
class DiagnosticOrderAnswer extends DiagnosticAnswer {
  const DiagnosticOrderAnswer(this.items);
  final List<String> items;
}

/// Pairs formed so far (matching probes): left pair index → right DISPLAY
/// slot index.
class DiagnosticMatchAnswer extends DiagnosticAnswer {
  const DiagnosticMatchAnswer(this.leftToRightDisplay);
  final Map<int, int> leftToRightDisplay;
}

/// Normalized free-text comparison — identical rules to the practice
/// engine (`ExerciseNotifier.normalizeAnswer`): trimmed, whitespace-
/// collapsed, lower-cased. Kept local so the pure engine never imports
/// the presentation layer.
String normalizeDiagnosticAnswer(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

// ─── Item bank (trusted pools) ──────────────────────────────────────────────

/// Dimension rotation priority. Script first (the gateway), then the
/// bread-and-butter dimensions, production near the end. Dimensions
/// without pools are skipped, never faked.
const List<DiagnosticDimension> kDiagnosticDimensionPriority = [
  DiagnosticDimension.script,
  DiagnosticDimension.vocabulary,
  DiagnosticDimension.grammar,
  DiagnosticDimension.sentenceFormation,
  DiagnosticDimension.reading,
  DiagnosticDimension.practical,
  DiagnosticDimension.comprehension,
  DiagnosticDimension.listening,
];

/// Classifies a trusted exercise into the diagnostic dimension it can
/// honestly measure.
///
/// Type rules first (forward-compatible with banks that add ordering /
/// fillBlank exercises later), then the A–G chapter themes — verified
/// identical across all seven shipped curricula (script → greetings →
/// daily life → grammar → reading & writing). Chapter order beyond the
/// shipped five falls through to the reading/production split so H–J
/// content classifies sensibly before M9 refines the knowledge layer.
DiagnosticDimension? classifyDiagnosticDimension({
  required int chapterOrder,
  required ExerciseType type,
}) {
  switch (type) {
    case ExerciseType.ordering:
      return DiagnosticDimension.sentenceFormation;
    case ExerciseType.fillBlank:
      return DiagnosticDimension.grammar;
    case ExerciseType.mcq:
    case ExerciseType.matching:
    case ExerciseType.translation:
      break;
  }
  switch (chapterOrder) {
    case 0:
      return DiagnosticDimension.script;
    case 1:
      return DiagnosticDimension.practical;
    case 2:
      return type == ExerciseType.translation
          ? DiagnosticDimension.sentenceFormation
          : DiagnosticDimension.vocabulary;
    case 3:
      return DiagnosticDimension.grammar;
    default:
      return type == ExerciseType.translation
          ? DiagnosticDimension.sentenceFormation
          : DiagnosticDimension.reading;
  }
}

/// Trusted probe pools for one language: dimension → difficulty band →
/// items. The raw pools stay in curriculum order; each bank instance
/// carries one deterministic session shuffle ([reshuffled]) so retakes
/// vary while staying reproducible for a fixed seed.
class DiagnosticItemBank {
  DiagnosticItemBank._(this._raw, this._pools);

  /// Raw pools (curriculum order): dimension → (difficulty → items).
  final Map<DiagnosticDimension, Map<Difficulty, List<DiagnosticItem>>> _raw;

  /// Session-shuffled view the accessors walk.
  final Map<DiagnosticDimension, Map<Difficulty, List<DiagnosticItem>>> _pools;

  static DiagnosticItemBank empty() => DiagnosticItemBank._(const {}, const {});

  /// Builds the pools from the trusted concept graph + exercise banks.
  ///
  /// - only graph concepts are considered (the graph is the trust anchor);
  /// - only well-formed exercises enter a pool (`Exercise.isValid`);
  /// - duplicate exercise ids keep the first occurrence;
  /// - an empty graph (stub languages kn/ml/or) yields an empty bank.
  factory DiagnosticItemBank.build({
    required ConceptGraph graph,
    required Map<String, List<Exercise>> exercisesByLesson,
    int seed = 0,
  }) {
    final raw = <DiagnosticDimension, Map<Difficulty, List<DiagnosticItem>>>{};
    final seen = <String>{};

    for (final concept in graph.concepts) {
      final exercises = exercisesByLesson[concept.lessonId] ??
          exercisesByLesson[concept.id] ??
          const <Exercise>[];
      final chapterOrder = concept.order ~/ 1000;
      // §12 prerequisite contract requires a STRICT total order inside
      // every (dimension × difficulty) bucket so a "prereq" probe can be
      // identified by `conceptOrder < missed.conceptOrder`. Lessons share
      // the same chapter.order × 1000 + i value, so we walk each lesson's
      // exercises in their authored order and give each item a strictly
      // unique conceptOrder (1000-wide room per lesson keeps room for
      // later authoring without collision).
      var exerciseSlot = 0;
      for (final exercise in exercises) {
        if (!exercise.isValid) continue;
        if (!seen.add(exercise.id)) continue;
        final dimension = classifyDiagnosticDimension(
          chapterOrder: chapterOrder,
          type: exercise.type,
        );
        if (dimension == null) continue;

        final item = DiagnosticItem(
          exercise: exercise,
          probe: DiagnosticProbe(
            id: exercise.id,
            dimension: dimension,
            difficulty: concept.difficulty,
            conceptId: concept.id,
          ),
          conceptOrder: concept.order * 10 + exerciseSlot,
        );
        exerciseSlot++;
        raw
            .putIfAbsent(dimension, () => {})
            .putIfAbsent(
              concept.difficulty,
              () => [],
            )
            .add(item);
      }
    }

    return DiagnosticItemBank._(raw, _shufflePools(raw, seed));
  }

  static Map<DiagnosticDimension, Map<Difficulty, List<DiagnosticItem>>>
      _shufflePools(
    Map<DiagnosticDimension, Map<Difficulty, List<DiagnosticItem>>> raw,
    int seed,
  ) {
    var poolIndex = 0;
    return {
      for (final dimension in kDiagnosticDimensionPriority)
        if (raw[dimension] != null)
          dimension: {
            for (final entry in raw[dimension]!.entries)
              entry.key: deterministicShuffle(
                entry.value,
                seed + poolIndex++ * 7919,
              ),
          },
    };
  }

  /// Same trusted pools, re-shuffled for a new session seed — a retake
  /// varies its probe list without re-reading any content.
  DiagnosticItemBank reshuffled(int seed) =>
      DiagnosticItemBank._(_raw, _shufflePools(_raw, seed));

  bool get isEmpty => _pools.isEmpty;
  bool get isNotEmpty => _pools.isNotEmpty;

  /// Dimensions that actually have probes, in rotation-priority order.
  List<DiagnosticDimension> get activeDimensions => [
        for (final d in kDiagnosticDimensionPriority)
          if (_pools.containsKey(d)) d,
      ];

  /// Unasked items of [dimension] at [band] (session-shuffled order).
  List<DiagnosticItem> itemsAt(DiagnosticDimension dimension, Difficulty band,
          {Set<String>? excludeIds}) =>
      [
        for (final item in _pools[dimension]?[band] ?? const <DiagnosticItem>[])
          if (excludeIds == null || !excludeIds.contains(item.exercise.id))
            item,
      ];

  /// Unasked items of [dimension] across ALL bands (curriculum order).
  List<DiagnosticItem> itemsAnyBand(DiagnosticDimension dimension,
          {Set<String>? excludeIds}) =>
      [
        for (final band in Difficulty.values)
          ...itemsAt(dimension, band, excludeIds: excludeIds),
      ]..sort((a, b) => a.conceptOrder.compareTo(b.conceptOrder));

  /// Total unasked probe count for the stop rule "pools ran dry".
  int remainingCount({Set<String>? excludeIds}) => [
        for (final d in _pools.keys) ...itemsAnyBand(d, excludeIds: excludeIds),
      ].length;
}

// ─── Adaptive engine ────────────────────────────────────────────────────────

/// One answered probe, in order (the raw material for state extras:
/// recent performance events + weak-concept review entries).
class DiagnosticAnswerRecord extends Equatable {
  const DiagnosticAnswerRecord({
    required this.probeId,
    required this.dimension,
    required this.correct,
    this.conceptId,
  });

  final String probeId;
  final DiagnosticDimension dimension;
  final bool correct;
  final String? conceptId;

  @override
  List<Object?> get props => [probeId, dimension, correct, conceptId];
}

/// The adaptive placement session (Master Brief §12 strategy).
///
/// One answer per probe — no retries inside the diagnostic, so the score
/// stays a truthful first-try estimate. The engine owns adaptivity and
/// stopping; the Riverpod notifier (M3 providers) owns UI pacing
/// (feedback → next) and persistence.
class DiagnosticEngine {
  DiagnosticEngine({
    required DiagnosticItemBank bank,
    int seedLevel = 0,
  })  : _bank = bank,
        _levelTrack = seedLevel.clamp(0, 4).toInt(),
        _activeDimensions = bank.activeDimensions {
    for (final d in _activeDimensions) {
      _accumulators[d] = const _Accumulator();
    }
    _current = _selectNext();
  }

  /// Probe budget (Master Brief §11: 3–7 minutes ≈ 8–16 probes).
  static const int kMinProbes = 8;
  static const int kMaxProbes = 16;

  /// Evidence target per dimension before the run may stop as complete.
  static const int kTargetProbesPerDimension = 2;

  final DiagnosticItemBank _bank;
  final List<DiagnosticDimension> _activeDimensions;
  final Map<DiagnosticDimension, _Accumulator> _accumulators = {};
  final List<DiagnosticAnswerRecord> _records = [];
  final Set<String> _askedIds = {};

  /// 0..4 internal level estimate, moved by the §12 strategy.
  int _levelTrack;
  int _consecutiveCorrect = 0;

  DiagnosticItem? _current;
  DiagnosticItem? _pending;
  bool _answeredCurrent = false;
  bool _finished = false;

  DiagnosticItem? get currentItem => _current;
  bool get isFinished => _finished;
  int get askedCount => _records.length;
  int get levelTrack => _levelTrack;

  /// Upper bound for the friendly progress meter (never shown as a
  /// countdown — the run may finish earlier).
  int get estimatedMax {
    final coverage = _activeDimensions.length * kTargetProbesPerDimension;
    final bounded = coverage.clamp(kMinProbes, kMaxProbes);
    return bounded;
  }

  List<DiagnosticAnswerRecord> get answerRecords => List.unmodifiable(_records);

  /// Records the answer to the current probe (first-try, no retries) and
  /// applies the §12 difficulty strategy:
  /// - two consecutive correct → the level estimate moves UP one step;
  /// - a miss → the estimate moves DOWN one step and the NEXT probe
  ///   becomes a prerequisite of the missed item (same dimension, the
  ///   nearest unasked item earlier in curriculum order).
  void recordAnswer(bool correct) {
    if (_finished || _current == null || _answeredCurrent) return;
    final item = _current!;
    final dimension = item.dimension;
    _answeredCurrent = true;
    _askedIds.add(item.exercise.id);
    _accumulators[dimension] = _accumulators[dimension]!.add(correct);
    _records.add(DiagnosticAnswerRecord(
      probeId: item.exercise.id,
      dimension: dimension,
      correct: correct,
      conceptId: item.probe.conceptId,
    ));

    if (correct) {
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 2 && _levelTrack < 4) {
        _levelTrack++;
        _consecutiveCorrect = 0;
      }
      _pending = _selectNext();
    } else {
      _consecutiveCorrect = 0;
      if (_levelTrack > 0) _levelTrack--;
      _pending = _prerequisiteProbe(item) ?? _selectNext();
    }
  }

  /// Advances to the probe chosen by [recordAnswer], or finishes the run
  /// when the strategy says the evidence is sufficient (or pools ran dry).
  void advance() {
    if (!_answeredCurrent || _finished) return;
    if (_pending == null) {
      _finished = true;
      _current = null;
      _answeredCurrent = false;
      return;
    }
    // Hard probe budget.
    if (askedCount >= kMaxProbes) {
      _finished = true;
      _current = null;
      _answeredCurrent = false;
      _pending = null;
      return;
    }
    _current = _pending;
    _pending = null;
    _answeredCurrent = false;
  }

  // ── selection internals ───────────────────────────────────────────────

  /// Round-robin over dimensions still below the per-dimension evidence
  /// target, in priority order. `null` = stop (targets met, or nothing
  /// unasked left).
  DiagnosticItem? _selectNext() {
    if (_records.length >= kMaxProbes) return null;
    if (_records.length >= kMinProbes && _coverageComplete()) return null;

    final startAt = _records.isEmpty
        ? 0
        : _activeDimensions.indexOf(_records.last.dimension) + 1;
    for (var i = 0; i < _activeDimensions.length; i++) {
      final dimension =
          _activeDimensions[(startAt + i) % _activeDimensions.length];
      if ((_accumulators[dimension]?.asked ?? 0) >= kTargetProbesPerDimension) {
        continue;
      }
      final item = _pickAtBand(dimension);
      if (item != null) return item;
    }
    // Targets not yet met but every candidate dimension is exhausted —
    // keep going with any unasked item so short-pool languages still get
    // a meaningful estimate, until the budget or dry-pool stop applies.
    if (_bank.remainingCount(excludeIds: _askedIds) > 0) {
      for (final dimension in _activeDimensions) {
        final item = _pickAnyBand(dimension);
        if (item != null) return item;
      }
    }
    return null;
  }

  /// The §12 "diagnostic prerequisite" probe: same dimension as the missed
  /// item, with STRICTLY EARLIER conceptOrder when possible. When no such
  /// item exists in the same dimension, fall back to an easier-band probe
  /// within the same dimension so the learner gets a recovery chance in
  /// the same skill rather than being whiplashed to a different skill.
  DiagnosticItem? _prerequisiteProbe(DiagnosticItem missed) {
    final pool = _bank.itemsAnyBand(missed.dimension, excludeIds: _askedIds);
    if (pool.isEmpty) return null;
    final earlier = pool.where((c) => c.conceptOrder < missed.conceptOrder);
    if (earlier.isNotEmpty) {
      return earlier.last; // nearest earlier item, itemsAnyBand is ordered
    }
    // No strictly-earlier concept in the same dimension. Stay in the same
    // dimension (the §12 contract) but drop to the easiest unasked band so
    // the learner has a real chance of recovery.
    for (final band in const [
      Difficulty.beginner,
      Difficulty.intermediate,
      Difficulty.advanced,
    ]) {
      final fallback =
          _bank.itemsAt(missed.dimension, band, excludeIds: _askedIds);
      if (fallback.isNotEmpty) return fallback.first;
    }
    return null;
  }

  /// Picks an unasked item at the current band, falling back to the
  /// nearest band with items (preferring the easier side — a probe the
  /// learner can actually attempt teaches more than a blank stare).
  DiagnosticItem? _pickAtBand(DiagnosticDimension dimension) {
    final band = _bandForLevel(_levelTrack);
    final direct = _bank.itemsAt(dimension, band, excludeIds: _askedIds);
    if (direct.isNotEmpty) return direct.first;

    for (final candidate in Difficulty.values) {
      if (candidate == band) continue;
      final fallback =
          _bank.itemsAt(dimension, candidate, excludeIds: _askedIds);
      if (fallback.isNotEmpty) return fallback.first;
    }
    return null;
  }

  DiagnosticItem? _pickAnyBand(DiagnosticDimension dimension) {
    final items = _bank.itemsAnyBand(dimension, excludeIds: _askedIds);
    return items.isEmpty ? null : items.first;
  }

  bool _coverageComplete() {
    for (final dimension in _activeDimensions) {
      if ((_accumulators[dimension]?.asked ?? 0) < kTargetProbesPerDimension) {
        // A dimension below target is acceptable ONLY if it has nothing
        // left to ask.
        if (_bank.itemsAnyBand(dimension, excludeIds: _askedIds).isNotEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  // ── result assembly ───────────────────────────────────────────────────

  /// Builds the structured result (Master Brief §11). Only dimensions
  /// with real answers appear — nothing is fabricated from seeds.
  DiagnosticResult buildResult({
    required LearnLanguage language,
    DateTime? completedAt,
    Duration duration = const Duration(),
  }) {
    final scores = <DiagnosticDimension, DimensionScore>{};
    var confidenceSum = 0.0;
    var weightedLevelSum = 0.0;

    for (final dimension in _activeDimensions) {
      final acc = _accumulators[dimension]!;
      if (acc.asked == 0) continue; // never fabricate a dimension score
      final confidence = _confidenceForAsked(acc.asked);
      scores[dimension] = DimensionScore(
        dimension: dimension,
        score: acc.correct / acc.asked,
        confidence: confidence,
        asked: acc.asked,
        correct: acc.correct,
      );
      confidenceSum += confidence;
      weightedLevelSum += (acc.correct / acc.asked) * 4 * confidence;
    }

    final measuredLevel =
        confidenceSum == 0 ? 0.0 : weightedLevelSum / confidenceSum;
    final overallLevel =
        (((measuredLevel + _levelTrack) / 2).round()).clamp(0, 4).toInt();
    final overallConfidence =
        scores.isEmpty ? 0.0 : (confidenceSum / scores.length);

    return DiagnosticResult(
      language: language,
      overallLevel: overallLevel,
      dimensionScores: scores,
      confidence: DimensionScore.clamp01(overallConfidence),
      duration: duration,
      completedAt: completedAt ?? DateTime.now(),
    );
  }

  /// Confidence grows with evidence, deliberately saturating below 1.0 —
  /// a 16-probe game is still a game, not a full examination.
  static double _confidenceForAsked(int asked) {
    if (asked <= 0) return 0;
    if (asked == 1) return 0.25;
    if (asked == 2) return 0.45;
    if (asked == 3) return 0.60;
    if (asked == 4) return 0.70;
    return 0.80;
  }

  static Difficulty _bandForLevel(int level) {
    final l = level.clamp(0, 4).toInt();
    if (l <= 1) return Difficulty.beginner;
    if (l <= 3) return Difficulty.intermediate;
    return Difficulty.advanced;
  }
}

/// Immutable per-dimension evidence accumulator.
class _Accumulator {
  const _Accumulator({this.asked = 0, this.correct = 0});

  final int asked;
  final int correct;

  _Accumulator add(bool wasCorrect) => _Accumulator(
        asked: asked + 1,
        correct: correct + (wasCorrect ? 1 : 0),
      );
}
