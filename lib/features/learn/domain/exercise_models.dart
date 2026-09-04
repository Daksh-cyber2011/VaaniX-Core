/// Exercise domain models for the Learn practice engine (Learn V1).
///
/// The engine supports five exercise types grounded in the existing
/// curriculum: multiple-choice (choose one), fill-in-the-blank
/// (choose the word that belongs in the blank), ordering (arrange items
/// into the correct sequence), translation (type the accepted answer)
/// and matching (pair items from two columns). Additional types can be
/// added by extending [ExerciseType] and the notifier without changing
/// the rest of the app.
library;

/// A left/right item pair for a `matching` exercise. Correct pairing is by
/// INDEX: `pairs[i].left` matches `pairs[i].right`.
typedef MatchPair = ({String left, String right});

/// The supported practice exercise types.
enum ExerciseType { mcq, fillBlank, ordering, translation, matching }

/// A single practice exercise attached to a lesson.
///
/// - `mcq` / `fillBlank` use [options] + [correctIndex].
/// - `ordering` uses [items] (the correct sequence, in order).
/// - `translation` uses [prompt] + [acceptedAnswers] (normalized compare).
/// - `matching` uses [pairs] (correct pairing by index).
///
/// [id] must be globally unique (convention: `ex_<lessonId>_<n>`).
class Exercise {
  const Exercise({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.correctIndex,
    this.items = const [],
    this.acceptedAnswers = const [],
    this.pairs = const [],
    this.explanation,
    this.hint,
  });

  final String id;
  final String lessonId;
  final ExerciseType type;
  final String prompt;

  /// Answer choices for `mcq` / `fillBlank`.
  final List<String> options;

  /// Index of the correct choice in [options] (for `mcq` / `fillBlank`).
  final int? correctIndex;

  /// The correct sequence for `ordering` exercises, in order.
  final List<String> items;

  /// Acceptable answers for `translation` exercises (compared after
  /// normalization: trimmed, whitespace-collapsed, lower-cased).
  final List<String> acceptedAnswers;

  /// The item pairs for `matching` exercises (pairing by index).
  final List<MatchPair> pairs;

  /// Feedback shown after answering.
  final String? explanation;

  /// Optional nudge shown before answering (only when authored).
  final String? hint;

  /// True when the exercise data is well-formed.
  bool get isValid => switch (type) {
        ExerciseType.ordering => items.length >= 2,
        ExerciseType.translation => acceptedAnswers.isNotEmpty &&
            acceptedAnswers.every((a) => a.trim().isNotEmpty),
        ExerciseType.matching => pairs.length >= 2 &&
            pairs.every(
                (p) => p.left.trim().isNotEmpty && p.right.trim().isNotEmpty),
        _ => options.length >= 2 &&
            (correctIndex != null &&
                correctIndex! >= 0 &&
                correctIndex! < options.length),
      };
}

/// Stable, platform-independent seed derived from text.
/// (Dart's `String.hashCode` is not guaranteed stable across releases, so we
/// derive our own seed for reproducibility in tests.)
int seedFromText(String text) =>
    text.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Deterministic Fisher-Yates shuffle (testable, stable for a given seed).
List<T> deterministicShuffle<T>(List<T> input, int seed) {
  final list = List<T>.from(input);
  var rng = seed;
  for (var i = list.length - 1; i > 0; i--) {
    rng = (rng * 1103515245 + 12345) & 0x7fffffff;
    final j = rng % (i + 1);
    if (j != i) {
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
  return list;
}

/// Display-time preparation for an exercise.
///
/// - `mcq` / `fillBlank`: shuffles [options] deterministically and reports
///   the display index of the correct answer.
/// - `ordering`: passes [Exercise.items] through (the UI arranges them).
/// - `translation`: no options; an empty list is returned.
/// - `matching`: [options] is the RIGHT column in deterministic display
///   order; [pairIndexByDisplay] maps each display slot back to the pair
///   index it belongs to.
({List<String> options, int correctIndex, List<int> pairIndexByDisplay})
    prepareExerciseOptions(Exercise exercise, int sessionIndex) {
  if (exercise.type == ExerciseType.ordering) {
    return (
      options: List<String>.from(exercise.items),
      correctIndex: 0,
      pairIndexByDisplay: const [],
    );
  }
  if (exercise.type == ExerciseType.translation) {
    return (
      options: const [],
      correctIndex: 0,
      pairIndexByDisplay: const [],
    );
  }
  if (exercise.type == ExerciseType.matching) {
    final seed = seedFromText('${exercise.id}#$sessionIndex');
    final rightItems = [for (final p in exercise.pairs) p.right];
    final display = deterministicShuffle(rightItems, seed);
    return (
      options: display,
      correctIndex: 0,
      pairIndexByDisplay: [
        for (final text in display) rightItems.indexOf(text),
      ],
    );
  }
  final seed = seedFromText('${exercise.id}#$sessionIndex');
  final shuffled = deterministicShuffle(exercise.options, seed);
  return (
    options: shuffled,
    correctIndex: shuffled.indexOf(exercise.options[exercise.correctIndex!]),
    pairIndexByDisplay: const [],
  );
}
