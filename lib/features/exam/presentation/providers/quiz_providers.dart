/// Quiz Providers — Riverpod wiring
///
/// Phase 2 single source of truth: the question bank is loaded from the
/// JSON curriculum asset ([quizBankProvider] → `loadAllQuizQuestions`), with
/// the compiled-in Dart bank kept only as a malformed-asset fallback. The
/// exam session itself is an async family ([examQuizProvider]) so the bank
/// load settles before the first question is served.
///
/// [selectExamQuestions] deterministically filters the bank by
/// chapter/difficulty, and [examQuizProvider] exposes one [QuizNotifier]
/// engine per [ExamConfig] (chapter + difficulty) so attempt state resets
/// cleanly when the student picks a different exam set.
library;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// The full question bank, loaded once from the JSON curriculum.
///
/// The loader never fails (Dart fallback inside), so consumers can treat
/// an empty list as "config with no questions" rather than an error state.
final quizBankProvider = FutureProvider<List<QuizQuestion>>((ref) async {
  return loadAllQuizQuestions();
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

/// Pure quiz engine: selection, first-try scoring and question flow for one
/// deterministic question set. Deliberately Riverpod-free so it stays unit
/// testable (see quiz_notifier_test.dart) and reusable — the Riverpod
/// surface ([ExamQuizController]) only mirrors this engine's state.
class QuizNotifier extends StateNotifier<QuizState> {
  QuizNotifier(this._questions) : super(const QuizState());

  final List<QuizQuestion> _questions;

  int get total => _questions.length;

  /// The question at the current index. The exam screen never renders the
  /// quiz body when [total] is 0, but this getter must fail with a clear
  /// error instead of the confusing ArgumentError a raw clamp() throws
  /// when the lower bound exceeds the upper one (empty bank).
  QuizQuestion get current {
    if (_questions.isEmpty) {
      throw StateError('QuizNotifier has no questions for this config.');
    }
    return _questions[state.currentIndex.clamp(0, _questions.length - 1)];
  }

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

/// Riverpod session for one [ExamConfig]. Loads the bank asynchronously,
/// builds the pure [QuizNotifier] engine for this config, and mirrors every
/// engine mutation into an [AsyncValue<QuizState>] so the exam screen can
/// render a loading state while the (single-source) JSON bank settles.
class ExamQuizController extends FamilyAsyncNotifier<QuizState, ExamConfig> {
  QuizNotifier? _engine;

  /// The deterministic question set for this config (empty while loading).
  int get total => _engine?.total ?? 0;

  /// The question at the engine's current index. Only valid once the
  /// session state is [AsyncData] — the exam screen guarantees that.
  QuizQuestion get current {
    final engine = _engine;
    if (engine == null) {
      throw StateError('Exam session is still loading its question bank.');
    }
    return engine.current;
  }

  @override
  Future<QuizState> build(ExamConfig arg) async {
    final bank = await ref.watch(quizBankProvider.future);
    final engine = QuizNotifier(selectExamQuestions(
      bank,
      chapterId: arg.chapterId,
      difficulty: arg.difficulty,
    ));
    _engine = engine;

    // Mirror every engine mutation into this notifier's AsyncValue. The
    // disposed guard stops mirrors landing after the family entry dies.
    var disposed = false;
    void mirror(QuizState engineState) {
      if (!disposed) state = AsyncData(engineState);
    }

    final removeMirror = engine.addListener(mirror);
    ref.onDispose(() {
      disposed = true;
      removeMirror();
    });
    // A brand-new engine always starts from the identical fresh state.
    return const QuizState();
  }

  void select(int optionIndex) => _engine?.select(optionIndex);

  void submit() => _engine?.submit();

  void next() => _engine?.next();

  /// Fresh attempt for the SAME config. Used when retaking a topic + level
  /// whose family entry still holds a finished attempt.
  void restart() => _engine?.restart();
}

/// A quiz session keyed by [ExamConfig]. Changing the config yields a fresh
/// session with the matching, deterministically-ordered question set.
final examQuizProvider =
    AsyncNotifierProvider.family<ExamQuizController, QuizState, ExamConfig>(
  ExamQuizController.new,
);
