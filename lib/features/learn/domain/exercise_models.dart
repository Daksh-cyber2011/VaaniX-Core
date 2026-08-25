/// Exercise domain models for the Learn practice engine (Learn V1).
///
/// The engine supports three exercise types grounded in the existing
/// curriculum: multiple-choice (choose one), fill-in-the-blank
/// (choose the word that belongs in the blank), and ordering
/// (arrange items into the correct sequence). Additional types can be
/// added by extending [ExerciseType] and the notifier without changing
/// the rest of the app.

/// The supported practice exercise types.
enum ExerciseType { mcq, fillBlank, ordering }

/// A single practice exercise attached to a lesson.
///
/// - `mcq` / `fillBlank` use [options] + [correctIndex].
/// - `ordering` uses [items] (the correct sequence, in order).
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

  /// Feedback shown after answering.
  final String? explanation;

  /// Optional nudge shown before answering (only when authored).
  final String? hint;

  /// True when the exercise data is well-formed.
  bool get isValid => type == ExerciseType.ordering
      ? items.length >= 2
      : options.length >= 2 &&
          (correctIndex != null &&
              correctIndex! >= 0 &&
              correctIndex! < options.length);
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

/// Display-time preparation for a choice-based exercise: shuffles [options]
/// deterministically and reports the display index of the correct answer.
///
/// `ordering` exercises are handled by the UI directly (items get arranged),
/// so they simply pass [Exercise.items] through.
({List<String> options, int correctIndex}) prepareExerciseOptions(
  Exercise exercise,
  int sessionIndex,
) {
  if (exercise.type == ExerciseType.ordering) {
    return (options: List<String>.from(exercise.items), correctIndex: 0);
  }
  final seed = seedFromText('${exercise.id}#$sessionIndex');
  final shuffled = deterministicShuffle(exercise.options, seed);
  return (
    options: shuffled,
    correctIndex: shuffled.indexOf(exercise.options[exercise.correctIndex!]),
  );
}
