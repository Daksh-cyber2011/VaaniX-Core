/// VaaniX AI — Learning Context
///
/// A bounded, privacy-friendly snapshot of the learner's REAL curriculum
/// state, assembled once per chat turn and injected into Van's persona
/// prompt so the model can personalize around actual progress.
///
/// Pipeline (V1 spec §4):
///   LearningContext
///     → learningContextProvider (derived from progress + adaptive engines)
///     → ChatController (stamped onto ConversationContext)
///     → ConversationContext.learningContextFragment
///     → PromptPipeline (persona assembly — the ONLY prompt wording site)
///     → Gemini / offline ModelAdapter.
///
/// Design rules:
///   - BOUNDED: weak-area titles are capped at [maxWeakTitles], each title
///     is truncated to [maxTitleLength], and [fragment] caps its own length
///     at [maxFragmentLength]. The prompt can never balloon.
///   - PRIVACY-FRIENDLY: contains learning state only (lesson/chapter
///     titles, counts, streak). No contact details, no identifiers, no
///     raw transcripts. All data already lives locally on-device.
///   - GROUNDED: every value comes from the progress repository or the
///     adaptive engine — the model is told what is real, never fabricated.
library;

import 'package:equatable/equatable.dart';

/// Maximum weak-area titles included in the fragment (mirrors the Progress
/// screen's top-5 weak areas; chat uses a tighter cap to stay bounded).
const int maxWeakTitlesInContext = 3;

/// Maximum characters of any single title before truncation.
const int maxTitleLength = 60;

/// Hard ceiling for the assembled fragment injected into the prompt.
const int maxFragmentLength = 900;

/// Bounded snapshot of the learner's curriculum state for prompt injection.
class LearningContext extends Equatable {
  const LearningContext({
    this.currentChapterTitle,
    this.currentLessonTitle,
    this.nextActionLabel,
    this.nextActionHint,
    this.lessonsCompleted = 0,
    this.lessonsTotal = 0,
    this.currentStreak = 0,
    this.weakLessonTitles = const <String>[],
  });

  /// Title of the chapter the learner is currently working in.
  final String? currentChapterTitle;

  /// Title of the lesson the adaptive engine points at, when it points at
  /// a lesson (start journey / continue / practice).
  final String? currentLessonTitle;

  /// Short label of the adaptive next action (e.g. "Practice: Vowels").
  final String? nextActionLabel;

  /// One-line guidance the adaptive engine attaches to that action.
  final String? nextActionHint;

  /// Number of lessons completed so far (real persisted count).
  final int lessonsCompleted;

  /// Total lessons in the loaded curriculum (0 when still loading).
  final int lessonsTotal;

  /// Current day streak (real persisted count).
  final int currentStreak;

  /// Titles of completed-but-unmastered lessons, weak areas first,
  /// ALREADY capped at [maxWeakTitlesInContext] by the factory.
  final List<String> weakLessonTitles;

  /// An empty context — renders an empty fragment (nothing injected).
  static const LearningContext empty = LearningContext();

  bool get isEmpty =>
      this == empty ||
      (currentChapterTitle == null &&
          currentLessonTitle == null &&
          nextActionLabel == null &&
          nextActionHint == null &&
          lessonsCompleted == 0 &&
          lessonsTotal == 0 &&
          currentStreak == 0 &&
          weakLessonTitles.isEmpty);

  /// Builds a bounded LearningContext from raw curriculum data.
  ///
  /// Central clamp point: weak titles are capped, every title truncated.
  /// Callers cannot accidentally produce an unbounded context.
  factory LearningContext.bounded({
    String? currentChapterTitle,
    String? currentLessonTitle,
    String? nextActionLabel,
    String? nextActionHint,
    int lessonsCompleted = 0,
    int lessonsTotal = 0,
    int currentStreak = 0,
    List<String> weakLessonTitles = const <String>[],
  }) {
    return LearningContext(
      currentChapterTitle: _clamp(currentChapterTitle),
      currentLessonTitle: _clamp(currentLessonTitle),
      nextActionLabel: _clamp(nextActionLabel),
      nextActionHint: _clamp(nextActionHint),
      lessonsCompleted: lessonsCompleted < 0 ? 0 : lessonsCompleted,
      lessonsTotal: lessonsTotal < 0 ? 0 : lessonsTotal,
      currentStreak: currentStreak < 0 ? 0 : currentStreak,
      weakLessonTitles: weakLessonTitles
          .map(_clamp)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .take(maxWeakTitlesInContext)
          .toList(growable: false),
    );
  }

  static String? _clamp(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.length <= maxTitleLength) return t;
    return '${t.substring(0, maxTitleLength)}…';
  }

  /// The prompt-ready fragment. Empty string when nothing is known —
  /// the prompt pipeline only injects non-empty fragments.
  ///
  /// Instruction wording lives here (not in the persona builder) so the
  /// boundary stays testable: [DefaultPromptPipeline] appends this text
  /// verbatim, and tests assert the fragment reaches the final persona.
  String get fragment {
    if (isEmpty) return '';
    final lines = <String>[];
    lines.add('LEARNING CONTEXT (real on-device progress; use it to '
        'personalize, never invent progress):');
    if (lessonsTotal > 0) {
      lines.add('- Progress: $lessonsCompleted of $lessonsTotal lessons '
          'completed.');
    } else if (lessonsCompleted > 0) {
      lines.add('- Progress: $lessonsCompleted lessons completed.');
    }
    if (currentStreak > 0) {
      lines.add('- Day streak: $currentStreak.');
    }
    if (currentChapterTitle != null) {
      lines.add('- Current chapter: $currentChapterTitle.');
    }
    if (nextActionLabel != null) {
      final hint = nextActionHint == null ? '' : ' — $nextActionHint';
      lines.add('- Suggested next step: $nextActionLabel$hint.');
    }
    if (weakLessonTitles.isNotEmpty) {
      lines.add('- Topics to revisit: ${weakLessonTitles.join(', ')}.');
    }
    var text = lines.join('\n');
    if (text.length > maxFragmentLength) {
      text = '${text.substring(0, maxFragmentLength)}…';
    }
    return text;
  }

  @override
  List<Object?> get props => [
        currentChapterTitle,
        currentLessonTitle,
        nextActionLabel,
        nextActionHint,
        lessonsCompleted,
        lessonsTotal,
        currentStreak,
        weakLessonTitles,
      ];
}
