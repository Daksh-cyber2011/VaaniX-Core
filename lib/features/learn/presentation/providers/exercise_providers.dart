/// Exercise Providers - Learn V1 practice session wiring.
///
/// [exercisesForLessonProvider] exposes the content bank for a lesson;
/// [exerciseSessionProvider] runs a deterministic, testable practice
/// session (scoring + feedback) for one lesson.
///
/// All five engine types are handled here: mcq / fillBlank (option
/// select), ordering (item sequence), translation (normalized free text)
/// and matching (left/right pairing).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Exercises available for a lesson (empty when none authored yet).
final exercisesForLessonProvider =
    Provider.family<List<Exercise>, String>((ref, lessonId) {
  return exercisesByLesson[lessonId] ?? const [];
});

/// A matched pair in the user's answer for a `matching` exercise.
/// [right] is the DISPLAY index into the shuffled right column.
typedef UserMatch = ({int left, int right});

/// State of an in-progress practice session.
class ExerciseState {
  const ExerciseState({
    this.currentIndex = 0,
    this.score = 0,
    this.selectedIndex,
    this.answered = false,
    this.finished = false,
    this.chosenItems = const [],
    this.answerText = '',
    this.selectedPairs = const [],
  });

  final int currentIndex;

  /// First-try correct answers so far.
  final int score;

  /// Selected display option for the current mcq/fillBlank exercise.
  final int? selectedIndex;

  final bool answered;
  final bool finished;

  /// Items tapped so far for the current ordering exercise (in user order).
  final List<String> chosenItems;

  /// Typed answer for the current translation exercise.
  final String answerText;

  /// Pairs formed so far for the current matching exercise.
  final List<UserMatch> selectedPairs;

  ExerciseState copyWith({
    int? currentIndex,
    int? score,
    int? selectedIndex,
    bool? answered,
    bool? finished,
    List<String>? chosenItems,
    String? answerText,
    List<UserMatch>? selectedPairs,
  }) {
    return ExerciseState(
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      answered: answered ?? this.answered,
      finished: finished ?? this.finished,
      chosenItems: chosenItems ?? this.chosenItems,
      answerText: answerText ?? this.answerText,
      selectedPairs: selectedPairs ?? this.selectedPairs,
    );
  }
}

class ExerciseNotifier extends StateNotifier<ExerciseState> {
  /// [analytics] is optional so pure engine tests can construct the
  /// notifier without any client; production wires the real provider.
  ExerciseNotifier(this._exercises, [AnalyticsClient? analytics])
      : _analytics = analytics ?? const NoopAnalyticsClient(),
        super(const ExerciseState()) {
    _display = [
      for (var i = 0; i < _exercises.length; i++)
        prepareExerciseOptions(_exercises[i], i),
    ];
  }

  final List<Exercise> _exercises;
  final AnalyticsClient _analytics;

  /// Indices already counted towards the score (no double counting).
  final Set<int> _scored = {};

  /// Precomputed display options + correct display index per exercise
  /// (deterministic per exercise id + session index).
  late final List<
      ({
        List<String> options,
        int correctIndex,
        List<int> pairIndexByDisplay
      })> _display;

  int get total => _exercises.length;

  /// Ids of exercises answered correctly at least once this session
  /// (index order; used to persist per-lesson mastery without XP effects).
  List<String> get masteredExerciseIds {
    final indices = _scored.toList()..sort();
    return [for (final i in indices) _exercises[i].id];
  }

  /// Indices answered correctly at least once this session (unmodifiable).
  Set<int> get masteredIndices => Set.unmodifiable(_scored);

  Exercise get current => _exercises[state.currentIndex];

  List<String> get currentOptions => _display[state.currentIndex].options;

  int get currentCorrectDisplayIndex =>
      _display[state.currentIndex].correctIndex;

  /// Display-slot -> pair-index map for the current matching exercise.
  List<int> get currentPairIndexByDisplay =>
      _display[state.currentIndex].pairIndexByDisplay;

  /// True when the current exercise was answered correctly (false when
  /// not yet answered or answered wrongly).
  bool get currentAnswerIsCorrect {
    if (!state.answered) return false;
    final exercise = current;
    return switch (exercise.type) {
      ExerciseType.ordering => listEquals(state.chosenItems, exercise.items),
      ExerciseType.translation =>
        _matchesTranslation(exercise, state.answerText),
      ExerciseType.matching =>
        _matchingIsCorrect(exercise, state.selectedPairs),
      _ => state.selectedIndex == currentCorrectDisplayIndex,
    };
  }

  void select(int optionIndex) {
    if (state.answered) return;
    state = state.copyWith(selectedIndex: optionIndex);
  }

  void addChosenItem(String item) {
    if (state.answered || state.chosenItems.contains(item)) return;
    state = state.copyWith(chosenItems: [...state.chosenItems, item]);
  }

  void removeChosenItem(int index) {
    if (state.answered) return;
    final items = [...state.chosenItems]..removeAt(index);
    state = state.copyWith(chosenItems: items);
  }

  void setAnswerText(String text) {
    if (state.answered) return;
    state = state.copyWith(answerText: text);
  }

  /// Adds a (left item index, right DISPLAY slot index) pair for the
  /// current matching exercise. Duplicate left or right slots are ignored.
  void addMatch(int leftIndex, int rightDisplayIndex) {
    if (state.answered) return;
    final already = state.selectedPairs.any(
      (p) => p.left == leftIndex || p.right == rightDisplayIndex,
    );
    if (already) return;
    state = state.copyWith(
      selectedPairs: [
        ...state.selectedPairs,
        (left: leftIndex, right: rightDisplayIndex)
      ],
    );
  }

  void removeMatch(int position) {
    if (state.answered) return;
    final pairs = [...state.selectedPairs]..removeAt(position);
    state = state.copyWith(selectedPairs: pairs);
  }

  /// Checks the current exercise. Scoring counts FIRST-TRY correct answers
  /// only: retrying after a wrong answer never adds a point. An incomplete
  /// answer (no selection / incomplete sequence / empty text / partial
  /// matching) is not accepted at all.
  void submit() {
    if (state.answered) return;
    final exercise = current;
    switch (exercise.type) {
      case ExerciseType.ordering:
        if (state.chosenItems.length != exercise.items.length) return;
      case ExerciseType.translation:
        if (normalizeAnswer(state.answerText).isEmpty) return;
      case ExerciseType.matching:
        if (state.selectedPairs.length != exercise.pairs.length) return;
      case ExerciseType.mcq || ExerciseType.fillBlank:
        if (state.selectedIndex == null) return;
    }
    final bool correct = switch (exercise.type) {
      ExerciseType.ordering => _submitOrdering(exercise),
      ExerciseType.translation => _submitTranslation(exercise),
      ExerciseType.matching => _submitMatching(exercise),
      _ => _submitChoice(exercise),
    };
    if (correct) {
      final firstTry = _scored.add(state.currentIndex);
      if (firstTry) {
        state = state.copyWith(answered: true, score: state.score + 1);
      } else {
        state = state.copyWith(answered: true);
      }
      _analytics.log(AnalyticsEvent(
        AnalyticsEventName.exerciseCompleted,
        {'exerciseId': exercise.id, 'correct': correct, 'firstTry': firstTry},
      ));
    } else {
      state = state.copyWith(answered: true);
      _analytics.log(AnalyticsEvent(
        AnalyticsEventName.exerciseCompleted,
        {'exerciseId': exercise.id, 'correct': correct, 'firstTry': false},
      ));
    }
  }

  bool _submitChoice(Exercise exercise) {
    if (state.selectedIndex == null) return false;
    return state.selectedIndex == currentCorrectDisplayIndex;
  }

  bool _submitOrdering(Exercise exercise) {
    if (state.chosenItems.length != exercise.items.length) return false;
    return listEquals(state.chosenItems, exercise.items);
  }

  bool _submitTranslation(Exercise exercise) {
    return _matchesTranslation(exercise, state.answerText);
  }

  bool _submitMatching(Exercise exercise) {
    if (state.selectedPairs.length != exercise.pairs.length) return false;
    return _matchingIsCorrect(exercise, state.selectedPairs);
  }

  /// Normalized free-text comparison: trimmed, whitespace-collapsed,
  /// lower-cased. Empty input never matches.
  static String normalizeAnswer(String input) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.toLowerCase();
  }

  bool _matchesTranslation(Exercise exercise, String input) {
    final normalized = normalizeAnswer(input);
    if (normalized.isEmpty) return false;
    return exercise.acceptedAnswers
        .any((a) => normalizeAnswer(a) == normalized);
  }

  bool _matchingIsCorrect(Exercise exercise, List<UserMatch> pairs) {
    if (pairs.length != exercise.pairs.length) return false;
    final slotToPair = currentPairIndexByDisplay;
    final seenLeft = <int>{};
    for (final p in pairs) {
      if (p.left < 0 || p.left >= exercise.pairs.length) return false;
      if (p.right < 0 || p.right >= slotToPair.length) return false;
      if (!seenLeft.add(p.left)) return false;
      if (slotToPair[p.right] != p.left) return false;
    }
    return true;
  }

  /// Retry the current exercise (after a wrong answer) without advancing.
  void retry() {
    state = state.copyWith(
      answered: false,
      selectedIndex: null,
      chosenItems: const [],
      answerText: '',
      selectedPairs: const [],
    );
  }

  void next() {
    if (state.currentIndex + 1 >= total) {
      state = state.copyWith(finished: true);
    } else {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        answered: false,
        selectedIndex: null,
        chosenItems: const [],
        answerText: '',
        selectedPairs: const [],
      );
    }
  }

  void restart() {
    _scored.clear();
    state = const ExerciseState();
  }

  /// Restores a previously persisted in-progress session (Phase 2 resume).
  ///
  /// Applies ONLY to a fresh notifier (a restart would silently drop real
  /// progress otherwise). Mastered exercise ids are mapped back to their
  /// indices — unknown ids (curriculum drift) are ignored — and the score
  /// is re-derived from the mastered set so it always stays truthful.
  /// [currentIndex] is clamped into range. Returns true when applied.
  bool restoreSession({
    required int currentIndex,
    required int score,
    List<String> masteredIds = const [],
  }) {
    if (total == 0) return false;
    final fresh = state.currentIndex == 0 &&
        state.score == 0 &&
        !state.finished &&
        _scored.isEmpty;
    if (!fresh) return false;
    if (currentIndex <= 0 && score <= 0 && masteredIds.isEmpty) {
      return false; // nothing meaningful to resume
    }

    for (final id in masteredIds) {
      final index = _exercises.indexWhere((e) => e.id == id);
      if (index >= 0) _scored.add(index);
    }
    final restoredScore = _scored.length.clamp(0, total);
    final restoredIndex = currentIndex.clamp(0, total - 1);
    state = ExerciseState(
      currentIndex: restoredIndex,
      score: restoredScore,
    );
    return true;
  }
}

/// A practice session for a lesson (empty notifier when no exercises yet).
final exerciseSessionProvider =
    StateNotifierProvider.family<ExerciseNotifier, ExerciseState, String>(
        (ref, lessonId) {
  return ExerciseNotifier(
    exercisesByLesson[lessonId] ?? const [],
    ref.watch(analyticsClientProvider),
  );
});
