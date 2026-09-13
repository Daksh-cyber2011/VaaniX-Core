/// Learning Milestones — Domain Layer (Milestone 7)
///
/// Competency-based learning milestones: the gamification layer that
/// certifies WHAT the learner can actually do, not how many buttons they
/// pressed. Distinct from the count-based [Achievement] system:
///
/// - Achievements ("Dedicated Learner: complete 5 lessons") reward volume.
/// - Milestones ("Script Explorer") reward demonstrated competency: a
///   chapter's lessons completed, its practice exercises mastered, and —
///   where the chapter ships exam questions — its exam passed.
///
/// Every milestone is defined by a configurable [MilestoneCriterion] that
/// is evaluated against a [MilestoneEvidence] snapshot built exclusively
/// from REAL persisted state (completed lessons, exercise mastery, exam
/// attempt history, streak). Nothing here can be unlocked by tapping a
/// button — there is always a mastery/consistency requirement.
///
/// The engine is pure and deterministic: same evidence in, same evaluation
/// out. All rules are unit-testable without Flutter or Riverpod.
///
/// Chapter semantics: criteria reference chapter ORDINALS (1-based, by the
/// curriculum's `order`), not chapter ids, so one definition set works for
/// every Learn Mode language. Shipped 5-chapter curricula follow the same
/// arc: 1 Script · 2 Greetings & Introductions · 3 Daily Life · 4 Grammar
/// · 5 Reading & Writing. The legacy Sanskrit Exam Mode curriculum has 4
/// chapters — criteria referencing a missing ordinal simply stay locked
/// (they are reported as unsatisfiable, never fabricated).
library;

import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Minimum best-attempt fraction for a chapter exam to count as passed.
/// Mirrors [kExamPassFraction] from adaptive.dart (same constant value,
/// re-declared here to keep the domain files dependency-light).
const double kMilestoneExamPassFraction = 0.6;

/// Configurable evidence rule that unlocks a learning milestone.
///
/// Subclasses define both the unlock check and the honest progress
/// fraction (0.0–1.0) the UI renders while the milestone is locked.
abstract class MilestoneCriterion {
  const MilestoneCriterion();

  /// True when [evidence] demonstrates the competency fully.
  bool isSatisfiedBy(MilestoneEvidence evidence);

  /// Honest progress fraction (0.0–1.0) towards the criterion.
  double progressOf(MilestoneEvidence evidence);

  /// Human-readable current-evidence line for the locked state
  /// (e.g. "3 of 5 lessons · 8 of 12 exercises mastered").
  String evidenceLine(MilestoneEvidence evidence);
}

/// 🌱 First Words — the learner completed a lesson AND mastered at least
/// one practice exercise. Reading a lesson alone is not enough: the first
/// milestone certifies the first demonstrated (practised) words.
class FirstWordsCriterion extends MilestoneCriterion {
  const FirstWordsCriterion();

  @override
  bool isSatisfiedBy(MilestoneEvidence evidence) =>
      evidence.completedLessonCount >= 1 &&
      evidence.totalMasteredExercises >= 1;

  @override
  double progressOf(MilestoneEvidence evidence) {
    final lessonPart = evidence.completedLessonCount >= 1 ? 0.5 : 0.0;
    final practicePart = evidence.totalMasteredExercises >= 1 ? 0.5 : 0.0;
    return lessonPart + practicePart;
  }

  @override
  String evidenceLine(MilestoneEvidence evidence) {
    if (evidence.curriculum.isEmpty) return 'Pick a language to begin';
    return evidence.totalMasteredExercises >= 1
        ? '${evidence.completedLessonCount} lesson(s) with practice'
        : 'Complete a lesson and practise one exercise';
  }
}

/// Chapter competency — the core milestone criterion.
///
/// Requires, for the chapter at 1-based [chapterOrdinal] (chapters sorted
/// by their `order`):
///   1. every lesson in the chapter is completed, AND
///   2. every authored practice exercise in the chapter is mastered, AND
///   3. when the chapter ships exam questions: the best attempt across
///      them reaches [minExamFraction]. Chapters WITHOUT exam questions
///      (all Learn Mode language chapters today) satisfy the gate through
///      full practice mastery instead — the demonstrated-ability bar is
///      never silently dropped.
class ChapterCompetencyCriterion extends MilestoneCriterion {
  const ChapterCompetencyCriterion(this.chapterOrdinal,
      {this.minExamFraction = kMilestoneExamPassFraction});

  /// 1-based chapter position in curriculum order.
  final int chapterOrdinal;

  final double minExamFraction;

  @override
  bool isSatisfiedBy(MilestoneEvidence evidence) =>
      evidence.chapterCompletionFraction(chapterOrdinal) >= 1.0 &&
      evidence.chapterMasteryFraction(chapterOrdinal) >= 1.0 &&
      evidence.chapterExamFraction(chapterOrdinal) >= minExamFraction;

  @override
  double progressOf(MilestoneEvidence evidence) {
    final lessons = evidence.chapterCompletionFraction(chapterOrdinal);
    // A chapter with no authored exercises or quiz has satisfied gates only
    // after the learner has actually completed some of its lessons.  Do not
    // render two-thirds progress for a completely untouched chapter merely
    // because those gates are not applicable.
    if (lessons == 0) return 0;
    final mastery = evidence.chapterMasteryFraction(chapterOrdinal);
    final exam = evidence.chapterExamFraction(chapterOrdinal);
    return (lessons + mastery + exam) / 3;
  }

  @override
  String evidenceLine(MilestoneEvidence evidence) {
    final chapter = evidence.chapterAt(chapterOrdinal);
    if (chapter == null) return 'Not available in this curriculum';
    final lessons = evidence.lessonsCompletedInChapter(chapterOrdinal);
    final total = chapter.lessons.length;
    final mastery = evidence.masteredExercisesInChapter(chapterOrdinal);
    final exercises = evidence.exerciseCountInChapter(chapterOrdinal);
    return '$lessons of $total lessons · $mastery of $exercises exercises';
  }
}

/// 🏆/💎 Journey-level criterion — every lesson in the active curriculum
/// completed, every authored exercise mastered, and every chapter that
/// ships exam questions passed at [minExamFraction] (chapters without
/// exams count as satisfied — see [ChapterCompetencyCriterion]).
class JourneyCompleteCriterion extends MilestoneCriterion {
  const JourneyCompleteCriterion({this.minExamFraction = 0.8});

  final double minExamFraction;

  @override
  bool isSatisfiedBy(MilestoneEvidence evidence) =>
      evidence.overallLessonFraction >= 1.0 &&
      evidence.overallMasteryFraction >= 1.0 &&
      evidence.overallExamFraction >= minExamFraction;

  @override
  double progressOf(MilestoneEvidence evidence) =>
      (evidence.overallLessonFraction +
          evidence.overallMasteryFraction +
          evidence.overallExamFraction) /
      3;

  @override
  String evidenceLine(MilestoneEvidence evidence) {
    if (evidence.curriculum.isEmpty) return 'Pick a language to begin';
    final pct = (evidence.overallLessonFraction * 100).round();
    final mpct = (evidence.overallMasteryFraction * 100).round();
    return '$pct% lessons · $mpct% practice mastered';
  }
}

/// 🔥 Consistency criterion — an N-day streak of real daily activity.
/// Streaks are recorded by the profile repository only on genuine
/// app-open/learning days, so this cannot be farmed in one sitting.
class StreakCriterion extends MilestoneCriterion {
  const StreakCriterion(this.days);

  final int days;

  @override
  bool isSatisfiedBy(MilestoneEvidence evidence) => evidence.streakDays >= days;

  @override
  double progressOf(MilestoneEvidence evidence) =>
      days <= 0 ? 0 : (evidence.streakDays / days).clamp(0.0, 1.0);

  @override
  String evidenceLine(MilestoneEvidence evidence) =>
      '${evidence.streakDays.clamp(0, days)} of $days day streak';
}

/// A learning milestone definition. Immutable; instances live in
/// [MilestoneDefinitions] and are pure configuration — adding a milestone
/// is appending one entry, the engine and UI react automatically.
class MilestoneDefinition {
  const MilestoneDefinition({
    required this.id,
    required this.emoji,
    required this.title,
    required this.competency,
    required this.xpReward,
    required this.criterion,
  });

  /// Stable unique identifier (persisted unlock key prefix: `ms_<id>`).
  final String id;

  /// Emoji glyph rendered by the milestone UI (per the master brief's
  /// milestone vocabulary, e.g. 🌱 First Words).
  final String emoji;

  /// Short title shown on the milestone card.
  final String title;

  /// What the milestone CERTIFIES about the learner (shown as the card
  /// description). Wording is evidence-first, never participation-trophy.
  final String competency;

  /// Bonus XP awarded once on unlock (through the bonus-XP ledger).
  final int xpReward;

  /// The configurable evidence rule that unlocks this milestone.
  final MilestoneCriterion criterion;
}

/// The nine M7 learning milestones (Milestone 7 brief §22 vocabulary).
///
/// Ordinal mapping for the shipped 5-chapter Learn curricula:
///   1 Script · 2 Greetings & Introductions · 3 Daily Life · 4 Grammar ·
///   5 Reading & Writing.
abstract final class MilestoneDefinitions {
  static const List<MilestoneDefinition> all = [
    MilestoneDefinition(
      id: 'first_words',
      emoji: '🌱',
      title: 'First Words',
      competency: 'Completed your first lesson and practised it — '
          'your first mastered words in the language.',
      xpReward: 20,
      criterion: FirstWordsCriterion(),
    ),
    MilestoneDefinition(
      id: 'script_explorer',
      emoji: '🔤',
      title: 'Script Explorer',
      competency: 'Mastered the foundations chapter: every lesson read, '
          'every practice exercise correct, script fundamentals locked in.',
      xpReward: 40,
      criterion: ChapterCompetencyCriterion(1),
    ),
    MilestoneDefinition(
      id: 'first_conversation',
      emoji: '👋',
      title: 'First Conversation',
      competency: 'Completed the greetings & introductions chapter with '
          'full practice mastery — you can say hello and introduce yourself.',
      xpReward: 40,
      criterion: ChapterCompetencyCriterion(2),
    ),
    MilestoneDefinition(
      id: 'everyday_communicator',
      emoji: '💬',
      title: 'Everyday Communicator',
      competency: 'Completed the daily-life chapter with full practice '
          'mastery — everyday phrases are now yours to use.',
      xpReward: 40,
      criterion: ChapterCompetencyCriterion(3),
    ),
    MilestoneDefinition(
      id: 'grammar_builder',
      emoji: '🧠',
      title: 'Grammar Builder',
      competency: 'Completed the grammar chapter with full practice '
          'mastery — sentence building blocks demonstrated.',
      xpReward: 60,
      criterion: ChapterCompetencyCriterion(4),
    ),
    MilestoneDefinition(
      id: 'first_reader',
      emoji: '📖',
      title: 'First Reader',
      competency: 'Completed the reading & writing chapter with full '
          'practice mastery — demonstrated reading comprehension.',
      xpReward: 60,
      criterion: ChapterCompetencyCriterion(5),
    ),
    MilestoneDefinition(
      id: 'beginner_complete',
      emoji: '🏆',
      title: 'Beginner Complete',
      competency: 'Every lesson complete, every exercise mastered, and '
          'every chapter exam passed — the beginner journey is done.',
      xpReward: 100,
      criterion: JourneyCompleteCriterion(minExamFraction: 0.6),
    ),
    MilestoneDefinition(
      id: 'consistent_learner',
      emoji: '🔥',
      title: 'Consistent Learner',
      competency: 'Maintained a 7-day learning streak — showing up is '
          'the skill that carries everything else.',
      xpReward: 60,
      criterion: StreakCriterion(7),
    ),
    MilestoneDefinition(
      id: 'mastery_milestone',
      emoji: '💎',
      title: 'Mastery Milestone',
      competency: 'Full journey mastery: 100% lessons, 100% practice, '
          'and every exam passed at 80% or better.',
      xpReward: 150,
      criterion: JourneyCompleteCriterion(minExamFraction: 0.8),
    ),
  ];

  /// Lookup by id.
  static MilestoneDefinition? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Immutable snapshot of everything the milestone engine evaluates.
///
/// Built (see milestone_providers.dart) exclusively from persisted
/// repository state — never from UI guesses. All derived getters are pure
/// functions of these fields.
class MilestoneEvidence {
  const MilestoneEvidence({
    required this.curriculum,
    required this.completedLessonIds,
    required this.masteredByLesson,
    required this.exerciseCountByLesson,
    required this.quizIdsByChapter,
    required this.attemptsByQuizId,
    required this.streakDays,
  });

  /// Active curriculum chapters (Learn language, or legacy Sanskrit when
  /// no Learn language is selected). Empty when still loading / none.
  final List<Chapter> curriculum;

  final Set<String> completedLessonIds;

  /// lessonId -> mastered exercise ids (persisted practice mastery).
  final Map<String, List<String>> masteredByLesson;

  /// lessonId -> authored exercise count (from the content banks).
  final Map<String, int> exerciseCountByLesson;

  /// chapterId -> quiz ids in the Exam Mode bank (empty for Learn
  /// language chapters — they ship no exam questions today).
  final Map<String, List<String>> quizIdsByChapter;

  /// quizId -> persisted attempt history.
  final Map<String, List<QuizResult>> attemptsByQuizId;

  /// Current consecutive-day streak from the profile repository.
  final int streakDays;

  // ─── Derived: chapters ─────────────────────────────────────────────────

  /// Chapters sorted by their declared [Chapter.order] (stable base order
  /// for ordinals).
  List<Chapter> get orderedChapters {
    final sorted = [...curriculum]..sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  /// The chapter at 1-based [ordinal], or null when the curriculum is
  /// shorter (milestone not applicable).
  Chapter? chapterAt(int ordinal) {
    if (ordinal < 1) return null;
    final chapters = orderedChapters;
    if (ordinal > chapters.length) return null;
    return chapters[ordinal - 1];
  }

  // ─── Derived: per-chapter fractions ────────────────────────────────────

  int lessonsCompletedInChapter(int ordinal) {
    final chapter = chapterAt(ordinal);
    if (chapter == null) return 0;
    return chapter.lessons
        .where((l) => completedLessonIds.contains(l.id))
        .length;
  }

  double chapterCompletionFraction(int ordinal) {
    final chapter = chapterAt(ordinal);
    if (chapter == null || chapter.lessons.isEmpty) return 0;
    return lessonsCompletedInChapter(ordinal) / chapter.lessons.length;
  }

  int masteredExercisesInChapter(int ordinal) {
    final chapter = chapterAt(ordinal);
    if (chapter == null) return 0;
    var mastered = 0;
    for (final lesson in chapter.lessons) {
      mastered += (masteredByLesson[lesson.id]?.length ?? 0);
    }
    return mastered;
  }

  int exerciseCountInChapter(int ordinal) {
    final chapter = chapterAt(ordinal);
    if (chapter == null) return 0;
    var total = 0;
    for (final lesson in chapter.lessons) {
      total += (exerciseCountByLesson[lesson.id] ?? 0);
    }
    return total;
  }

  /// Practice mastery fraction for a chapter. A chapter with no authored
  /// exercises counts as fully mastered (nothing to demonstrate; lesson
  /// completion is the evidence) so milestones never dead-lock on stubs.
  double chapterMasteryFraction(int ordinal) {
    if (chapterAt(ordinal) == null) return 0;
    final total = exerciseCountInChapter(ordinal);
    if (total == 0) return 1;
    return (masteredExercisesInChapter(ordinal) / total).clamp(0.0, 1.0);
  }

  /// Best exam fraction across the chapter's quizzes. Chapters without
  /// exam questions return 1.0 — the gate is carried by practice mastery
  /// instead of being silently dropped (see [ChapterCompetencyCriterion]).
  double chapterExamFraction(int ordinal) {
    final chapter = chapterAt(ordinal);
    if (chapter == null) return 0;
    final quizIds = quizIdsByChapter[chapter.id] ?? const <String>[];
    if (quizIds.isEmpty) return 1;
    var best = 0.0;
    for (final quizId in quizIds) {
      for (final attempt in attemptsByQuizId[quizId] ?? const <QuizResult>[]) {
        if (attempt.percentage > best) best = attempt.percentage;
      }
    }
    return best;
  }

  // ─── Derived: journey-wide figures ─────────────────────────────────────

  int get totalLessons =>
      curriculum.fold<int>(0, (s, c) => s + c.lessons.length);

  int get completedLessonCount => completedLessonIds.length;

  int get totalMasteredExercises {
    var sum = 0;
    for (final ids in masteredByLesson.values) {
      sum += ids.length;
    }
    return sum;
  }

  double get overallLessonFraction => totalLessons == 0
      ? 0
      : (completedLessonCount / totalLessons).clamp(0.0, 1.0);

  double get overallMasteryFraction {
    final total = curriculum.fold<int>(
        0,
        (s, c) =>
            s +
            c.lessons.fold<int>(
                0, (s, l) => s + (exerciseCountByLesson[l.id] ?? 0)));
    if (total == 0) return 1;
    return (totalMasteredExercises / total).clamp(0.0, 1.0);
  }

  /// Mean exam fraction across chapters that HAVE exams; chapters without
  /// exams contribute 1.0 (satisfied via mastery, see above).
  double get overallExamFraction {
    if (curriculum.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 1; i <= orderedChapters.length; i++) {
      sum += chapterExamFraction(i);
    }
    return sum / orderedChapters.length;
  }
}

/// The engine's verdict for one milestone: whether the evidence satisfies
/// its criterion, whether it was ALREADY unlocked (persisted), and the
/// honest progress fraction for the locked state.
class MilestoneEvaluation {
  const MilestoneEvaluation({
    required this.definition,
    required this.isSatisfied,
    required this.alreadyUnlocked,
    required this.progress,
    required this.evidenceLine,
  });

  final MilestoneDefinition definition;

  /// True when the CURRENT evidence satisfies the criterion.
  final bool isSatisfied;

  /// True when the milestone was unlocked in a previous session
  /// (persisted unlock map). Persisted unlocks are never re-awarded.
  final bool alreadyUnlocked;

  /// 0.0–1.0 honest progress towards the criterion.
  final double progress;

  /// Current-evidence line for the locked card UI.
  final String evidenceLine;

  /// Effective UI state: unlocked when persisted OR satisfied right now.
  bool get isUnlocked => alreadyUnlocked || isSatisfied;
}

/// Pure milestone engine: evaluates every definition against [evidence],
/// tagging persisted unlocks. Deterministic; no side effects.
List<MilestoneEvaluation> evaluateMilestones({
  required List<MilestoneDefinition> definitions,
  required MilestoneEvidence evidence,
  required Set<String> unlockedIds,
}) {
  return [
    for (final definition in definitions)
      MilestoneEvaluation(
        definition: definition,
        isSatisfied: definition.criterion.isSatisfiedBy(evidence),
        alreadyUnlocked: unlockedIds.contains(definition.id),
        progress: definition.criterion.progressOf(evidence).clamp(0.0, 1.0),
        evidenceLine: definition.criterion.evidenceLine(evidence),
      ),
  ];
}
