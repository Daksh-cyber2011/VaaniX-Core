/// Exercise Providers — Learn V1 practice session wiring.
///
/// [exercisesForLessonProvider] exposes the content bank for a lesson;
/// [exerciseSessionProvider] runs a deterministic, testable practice
/// session (scoring + feedback) for one lesson.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart';

/// Exercises available for a lesson (empty when none authored yet).
final exercisesForLessonProvider =
    Provider.family<List<Exercise>, String>((ref, lessonId) {
  return exercisesByLesson[lessonId] ?? const [];
});

/// State of an in-progress practice session.
class ExerciseState {
  const ExerciseState({
    this.currentIndex = 0,
    this.score = 0,
    this.selectedIndex,
    this.answered = false,
    this.finished = false,
    this.chosenItems = const [],
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

  ExerciseState copyWith({
    int? currentIndex,
    int? score,
    int? selectedIndex,
    bool? answered,
    bool? finished,
    List<String>? chosenItems,
  }) {
    return ExerciseState(
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      answered: answered ?? this.answered,
      finished: finished ?? this.finished,
      chosenItems: chosenItems ?? this.chosenItems,
    );
  }
}

class ExerciseNotifier extends StateNotifier<ExerciseState> {
  ExerciseNotifier(this._exercises) : super(const ExerciseState()) {
    _display = [
      for (var i = 0; i < _exercises.length; i++)
        prepareExerciseOptions(_exercises[i], i),
    ];
  }

  final List<Exercise> _exercises;

  /// Indices already counted towards the score (no double counting).
  final Set<int> _scored = {};

  /// Precomputed display options + correct display index per exercise
  /// (deterministic per exercise id + session index).
  late final List<({List<String> options, int correctIndex})> _display;

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

  /// True when the current exercise was answered correctly (false when
  /// not yet answered or answered wrongly).
  bool get currentAnswerIsCorrect {
    if (!state.answered) return false;
    final exercise = current;
    if (exercise.type == ExerciseType.ordering) {
      return listEquals(state.chosenItems, exercise.items);
    }
    return state.selectedIndex == currentCorrectDisplayIndex;
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

  /// Checks the current exercise. Scoring counts FIRST-TRY correct answers
  /// only: retrying after a wrong answer never adds a point.
  void submit() {
    if (state.answered) return;
    final exercise = current;
    final bool correct;
    if (exercise.type == ExerciseType.ordering) {
      if (state.chosenItems.length != exercise.items.length) return;
      correct = listEquals(state.chosenItems, exercise.items);
    } else {
      if (state.selectedIndex == null) return;
      correct = state.selectedIndex == currentCorrectDisplayIndex;
    }
    if (correct) {
      if (_scored.add(state.currentIndex)) {
        state = state.copyWith(answered: true, score: state.score + 1);
      } else {
        state = state.copyWith(answered: true);
      }
    } else {
      state = state.copyWith(answered: true);
    }
  }

  /// Retry the current exercise (after a wrong answer) without advancing.
  void retry() {
    state = state.copyWith(
      answered: false,
      selectedIndex: null,
      chosenItems: const [],
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
      );
    }
  }

  void restart() {
    _scored.clear();
    state = const ExerciseState();
  }
}

/// A practice session for a lesson (empty notifier when no exercises yet).
final exerciseSessionProvider =
    StateNotifierProvider.family<ExerciseNotifier, ExerciseState, String>(
        (ref, lessonId) {
  return ExerciseNotifier(exercisesByLesson[lessonId] ?? const []);
});
