/// VaaniX Progress - Gamification helpers
///
/// Pure, deterministic XP -> level mapping and curriculum planning helpers
/// used by the Home command center, Progress screen and tests. No I/O and
/// no Riverpod dependencies: everything here is a function of its inputs,
/// so every rule is unit-testable.
///
/// Level curve: level N requires 100 * (N-1) cumulative-ish XP per the
/// formula below. Level 1 starts at 0 XP; each level needs `100 * level`
/// XP to reach the next one (L1->L2 needs 100, L2->L3 needs 200, ...).
library;

import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Total XP required to REACH [level] (level 1 = 0 XP).
int cumulativeXpForLevel(int level) {
  if (level <= 1) return 0;
  return 100 * level * (level - 1) ~/ 2;
}

/// The learner's current level for a given XP total (never below 1).
int levelFromXp(int xp) {
  var level = 1;
  while (xp >= cumulativeXpForLevel(level + 1)) {
    level += 1;
  }
  return level;
}

/// XP earned inside the current level (0 .. xpForNextLevel-1).
int xpIntoLevel(int xp) => xp - cumulativeXpForLevel(levelFromXp(xp));

/// XP required to advance from [level] to the next.
int xpForNextLevel(int level) => 100 * level;

/// Progress (0.0 - 1.0) towards the next level from the current XP.
double levelProgress(int xp) {
  final level = levelFromXp(xp);
  final into = xpIntoLevel(xp);
  final needed = xpForNextLevel(level);
  if (needed <= 0) return 0;
  return (into / needed).clamp(0.0, 1.0);
}

/// The next lesson the learner should study: the first lesson (in
/// chapter/lesson order) whose id is NOT in [completedLessonIds].
///
/// Returns null when every lesson is complete.
Lesson? nextLessonInCurriculum(
  List<Chapter> chapters,
  Set<String> completedLessonIds,
) {
  final ordered = <Lesson>[];
  final sortedChapters = [...chapters]
    ..sort((a, b) => a.order.compareTo(b.order));
  for (final chapter in sortedChapters) {
    final sortedLessons = [...chapter.lessons]
      ..sort((a, b) => a.order.compareTo(b.order));
    ordered.addAll(sortedLessons);
  }
  for (final lesson in ordered) {
    if (!completedLessonIds.contains(lesson.id)) return lesson;
  }
  return null;
}
