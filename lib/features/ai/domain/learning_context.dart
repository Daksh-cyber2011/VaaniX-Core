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
    this.examCourseId,
    this.examScopeTitles = const <String>[],
    this.examWeakTopicTitles = const <String>[],
    this.examReadinessLabel,
    this.examDailyStudyMinutes,
    this.examDiagnosticCompleted = false,
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

  /// The exact persisted Exam Mode course id. This is deliberately an id,
  /// rather than a guessed display name, so Hindi A/B and the two Sanskrit
  /// courses can never be collapsed in an AI turn.
  final String? examCourseId;

  /// A small, trusted digest of the student's selected Exam Mode scope.
  final List<String> examScopeTitles;

  /// Evidence-backed weak exam topics, not model-generated labels.
  final List<String> examWeakTopicTitles;

  /// The student's readiness anchor in a compact human-readable form.
  final String? examReadinessLabel;

  /// Realistic daily budget collected in Exam Mode, when configured.
  final int? examDailyStudyMinutes;

  /// Whether the selected Exam Mode course has been diagnostically sampled.
  final bool examDiagnosticCompleted;

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
          weakLessonTitles.isEmpty &&
          examCourseId == null &&
          examScopeTitles.isEmpty &&
          examWeakTopicTitles.isEmpty &&
          examReadinessLabel == null &&
          examDailyStudyMinutes == null &&
          !examDiagnosticCompleted);

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
    String? examCourseId,
    List<String> examScopeTitles = const <String>[],
    List<String> examWeakTopicTitles = const <String>[],
    String? examReadinessLabel,
    int? examDailyStudyMinutes,
    bool examDiagnosticCompleted = false,
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
      examCourseId: _clamp(examCourseId),
      examScopeTitles: examScopeTitles
          .map(_clamp)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .take(maxWeakTitlesInContext)
          .toList(growable: false),
      examWeakTopicTitles: examWeakTopicTitles
          .map(_clamp)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .take(maxWeakTitlesInContext)
          .toList(growable: false),
      examReadinessLabel: _clamp(examReadinessLabel),
      examDailyStudyMinutes:
          examDailyStudyMinutes == null || examDailyStudyMinutes < 1
              ? null
              : examDailyStudyMinutes,
      examDiagnosticCompleted: examDiagnosticCompleted,
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
    if (examCourseId != null) {
      lines.add(
          'EXAM MODE CONTEXT (trusted on-device scope; do not expand it):');
      lines.add('- Exact course: $examCourseId.');
      if (examScopeTitles.isNotEmpty) {
        lines.add('- Selected exam scope: ${examScopeTitles.join(', ')}.');
      }
      if (examReadinessLabel != null) {
        lines.add('- Readiness target: $examReadinessLabel.');
      }
      if (examDailyStudyMinutes != null) {
        lines.add(
            '- Realistic daily study time: $examDailyStudyMinutes minutes.');
      }
      lines.add(
          '- Diagnostic: ${examDiagnosticCompleted ? 'completed' : 'not completed yet'}.');
      if (examWeakTopicTitles.isNotEmpty) {
        lines.add(
            '- Exam topics needing support: ${examWeakTopicTitles.join(', ')}.');
      }
      lines.add(
          '- Respect the student\'s chosen plan and pace; never guilt them for missed study.');
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
        examCourseId,
        examScopeTitles,
        examWeakTopicTitles,
        examReadinessLabel,
        examDailyStudyMinutes,
        examDiagnosticCompleted,
      ];
}
