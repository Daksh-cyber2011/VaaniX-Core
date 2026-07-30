/// Quiz Providers — Riverpod wiring
///
/// Builds a flat list of quiz questions from the curriculum chapters and
/// exposes the reactive [QuizNotifier] that drives the exam flow.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// All quiz questions across the curriculum, flattened into one quiz.
final quizQuestionsProvider = Provider<List<QuizQuestion>>((ref) {
  final bank = ref.watch(chapterQuizzesProvider);
  return bank.values.expand((q) => q).toList();
});

/// State of an in-progress quiz attempt.
class QuizState {
  const QuizState({
    this.currentIndex = 0,
    this.score = 0,
    this.selectedOption,
    this.answered = false,
    this.finished = false,
  });

  final int currentIndex;
  final int score;
  final int? selectedOption;
  final bool answered;
  final bool finished;

  QuizState copyWith({
    int? currentIndex,
    int? score,
    int? selectedOption,
    bool? answered,
    bool? finished,
    bool clearSelection = false,
  }) {
    return QuizState(
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      selectedOption:
          clearSelection ? null : selectedOption ?? this.selectedOption,
      answered: answered ?? this.answered,
      finished: finished ?? this.finished,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState> {
  QuizNotifier(this._questions) : super(const QuizState());

  final List<QuizQuestion> _questions;

  int get total => _questions.length;

  QuizQuestion get current => _questions[state.currentIndex.clamp(0, total - 1)];

  void select(int optionIndex) {
    if (state.answered) return;
    state = state.copyWith(selectedOption: optionIndex);
  }

  void submit() {
    if (state.selectedOption == null || state.answered) return;
    final correct = state.selectedOption == current.correctIndex;
    state = state.copyWith(
      answered: true,
      score: correct ? state.score + 1 : state.score,
    );
  }

  void next() {
    if (state.currentIndex + 1 >= total) {
      state = state.copyWith(finished: true);
    } else {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        answered: false,
        clearSelection: true,
      );
    }
  }

  void restart() {
    state = const QuizState();
  }
}

final quizProvider =
    StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  final questions = ref.watch(quizQuestionsProvider);
  return QuizNotifier(questions);
});
