/// Quiz Providers — Riverpod wiring
///
/// Builds a flat bank of quiz questions from the curriculum chapters and
/// exposes the reactive [QuizNotifier] that drives the exam flow.
///
/// Exam V1: questions now carry chapter + difficulty metadata.
/// [selectExamQuestions] deterministically filters the bank by
/// chapter/difficulty, and [examQuizProvider] exposes a fresh [QuizNotifier]
/// per [ExamConfig] (chapter + difficulty) so attempt state resets cleanly
/// when the user picks a different exam set.
library;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// All quiz questions across the curriculum, flattened into one bank.
final quizQuestionsProvider = Provider<List<QuizQuestion>>((ref) {
  final bank = chapterQuizzes;
  return bank.values.expand((q) => q).toList();
});

/// An exam configuration: an optional chapter and a difficulty band.
///
/// Doubles as the family key for [examQuizProvider] and the unit of
/// attempt tracking (see [ExamConfig.quizId]).
class ExamConfig extends Equatable {
  const ExamConfig({this.chapterId, this.difficulty = Difficulty.beginner});

  /// Owning chapter id. `null` means "all chapters" (selection not narrowed).
  final String? chapterId;

  final Difficulty difficulty;

  /// Stable, deterministic id used for progress/attempt-history tracking.
  String get quizId => 'quiz_${chapterId ?? 'all'}_${difficulty.name}';

  @override
  List<Object?> get props => [chapterId, difficulty];
}

/// Deterministically selects the questions matching [chapterId] and
/// [difficulty], sorted by id for a stable, reproducible order.
List<QuizQuestion> selectExamQuestions(
  List<QuizQuestion> all, {
  String? chapterId,
  Difficulty difficulty = Difficulty.beginner,
}) {
  final selected = all
      .where((q) =>
          (chapterId == null || q.chapterId == chapterId) &&
          q.difficulty == difficulty)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return selected;
}

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

  QuizQuestion get current =>
      _questions[state.currentIndex.clamp(0, total - 1)];

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

/// A quiz session keyed by [ExamConfig]. Changing the config yields a fresh
/// [QuizNotifier] with the matching, deterministically-ordered question set.
final examQuizProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, ExamConfig>(
  (ref, config) {
    final all = ref.watch(quizQuestionsProvider);
    return QuizNotifier(selectExamQuestions(all,
        chapterId: config.chapterId, difficulty: config.difficulty));
  },
);
