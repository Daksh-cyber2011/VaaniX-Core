/// Learning Milestones — Riverpod Wiring (Milestone 7)
///
/// Bridges the pure milestone engine to live progress data:
///
/// - [milestoneRepositoryProvider] — persistence for unlocked milestones
/// - [unlockedMilestonesProvider] — async map of unlocked milestone ids
/// - [milestoneEvidenceProvider] — [MilestoneEvidence] snapshot built from
///   REAL providers (active curriculum, completed lessons, per-lesson
///   practice mastery, exam attempt history, streak). Recomputes whenever
///   any input changes.
/// - [milestoneEvaluationsProvider] — engine output for the UI
/// - [milestoneCheckerProvider] — [MilestoneChecker], the unlock + reward
///   + analytics path (mirrors AchievementChecker's contract)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';

import 'package:vaanix_app/features/learn/data/bengali_exercises.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/features/learn/data/gujarati_exercises.dart';
import 'package:vaanix_app/features/learn/data/hindi_exercises.dart';
import 'package:vaanix_app/features/learn/data/marathi_exercises.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/data/tamil_exercises.dart';
import 'package:vaanix_app/features/learn/data/telugu_exercises.dart';
import 'package:vaanix_app/features/learn/data/urdu_exercises.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/data/milestone_repository.dart';
import 'package:vaanix_app/features/progress/domain/learning_milestones.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// The repository instance.
final milestoneRepositoryProvider = Provider<MilestoneRepository>((ref) {
  return MilestoneRepository(ref.watch(localStorageServiceProvider));
});

/// Async map of unlocked milestone IDs → unlock timestamps.
/// Invalidated by the checker when something unlocks.
final unlockedMilestonesProvider =
    FutureProvider<Map<String, DateTime>>((ref) async {
  final repo = ref.watch(milestoneRepositoryProvider);
  final result = await repo.getUnlocked();
  return result.fold((_) => <String, DateTime>{}, (v) => v);
});

/// Authored exercise count for [lessonId] across every shipped content
/// bank (Sanskrit + the seven Learn languages with banks). Lesson IDs are
/// globally unique, so at most one bank matches. As Parts H–J ship, their
/// banks join the chain the same way.
int _authoredExerciseCount(String lessonId) {
  return exercisesByLesson[lessonId]?.length ??
      hindiExercisesByLesson[lessonId]?.length ??
      bengaliExercisesByLesson[lessonId]?.length ??
      marathiExercisesByLesson[lessonId]?.length ??
      teluguExercisesByLesson[lessonId]?.length ??
      tamilExercisesByLesson[lessonId]?.length ??
      gujaratiExercisesByLesson[lessonId]?.length ??
      urduExercisesByLesson[lessonId]?.length ??
      0;
}

/// Live [MilestoneEvidence] snapshot. Watches exactly the providers the
/// adaptive engine already trusts, so milestone progress and the rest of
/// the app can never disagree about the learner's state.
final milestoneEvidenceProvider = Provider<MilestoneEvidence>((ref) {
  // The ACTIVE curriculum (selected Learn language; legacy Sanskrit when
  // none selected) — the journey the learner is actually on.
  final selectedLanguage = ref.watch(selectedLearnLanguageProvider);
  final curriculum = selectedLanguage == null
      ? ref.watch(curriculumProvider).valueOrNull ?? const <Chapter>[]
      : ref.watch(activeCurriculumProvider).valueOrNull ?? const <Chapter>[];

  final completed = ref.watch(completedLessonIdsProvider).toSet();
  final attemptsIndex = ref.watch(quizAttemptsIndexProvider);
  final streak = ref.watch(userProfileProvider).currentStreak;

  final masteredByLesson = <String, List<String>>{};
  final exerciseCounts = <String, int>{};
  for (final chapter in curriculum) {
    for (final lesson in chapter.lessons) {
      masteredByLesson[lesson.id] =
          ref.watch(masteredExercisesProvider(lesson.id));
      exerciseCounts[lesson.id] = _authoredExerciseCount(lesson.id);
    }
  }

  return MilestoneEvidence(
    curriculum: curriculum,
    completedLessonIds: completed,
    masteredByLesson: masteredByLesson,
    exerciseCountByLesson: exerciseCounts,
    quizIdsByChapter: ref.watch(quizIdsByChapterProvider),
    attemptsByQuizId: attemptsIndex,
    streakDays: streak,
  );
});

/// Engine output for the UI: every milestone with its satisfied state,
/// persisted-unlock state, honest progress fraction and evidence line.
final milestoneEvaluationsProvider = Provider<List<MilestoneEvaluation>>((ref) {
  final evidence = ref.watch(milestoneEvidenceProvider);
  final unlockedAsync = ref.watch(unlockedMilestonesProvider);
  final unlocked = unlockedAsync.valueOrNull?.keys.toSet() ?? const <String>{};
  return evaluateMilestones(
    definitions: MilestoneDefinitions.all,
    evidence: evidence,
    unlockedIds: unlocked,
  );
});

/// Count of unlocked milestones (for section headers).
final unlockedMilestonesCountProvider = Provider<int>((ref) {
  return ref
      .watch(milestoneEvaluationsProvider)
      .where((m) => m.isUnlocked)
      .length;
});

/// Evaluates milestones against live evidence and unlocks the newly
/// satisfied ones. The M7 counterpart of [AchievementChecker] — called
/// from the same lifecycle points (lesson completion, practice
/// completion, exam completion, streak update).
///
/// On each unlock:
///   1. persists via [MilestoneRepository.unlock] (idempotent),
///   2. awards the milestone's bonus XP through the progress repository's
///      bonus ledger (`ms_<id>` — once ever, never polluting lesson ids),
///   3. logs a typed analytics event,
///   4. returns the newly-unlocked definitions so the calling screen can
///      celebrate (one consolidated Van reaction + snackbar).
class MilestoneChecker {
  MilestoneChecker(this._ref);

  final Ref _ref;

  Future<List<MilestoneDefinition>> checkMilestones() async {
    // Authoritative persisted unlock map, awaited: the async provider may
    // still be pending right after app start (same reasoning as the
    // achievement checker).
    final persisted = await _ref.read(unlockedMilestonesProvider.future);
    final unlockedIds = persisted.keys.toSet();
    final evidence = _ref.read(milestoneEvidenceProvider);

    final newlyUnlocked = <MilestoneDefinition>[];
    for (final definition in MilestoneDefinitions.all) {
      if (unlockedIds.contains(definition.id)) continue;
      if (!definition.criterion.isSatisfiedBy(evidence)) continue;

      final result =
          await _ref.read(milestoneRepositoryProvider).unlock(definition.id);
      var unlockedNow = false;
      result.fold(
        (_) {}, // persistence failure: skip XP + celebration for safety
        (_) => unlockedNow = true,
      );
      if (!unlockedNow) continue;

      newlyUnlocked.add(definition);
      _ref.log(AnalyticsEvent(
        AnalyticsEventName.milestoneUnlocked,
        {'milestoneId': definition.id},
      ));

      if (definition.xpReward > 0) {
        final xpResult =
            await _ref.read(progressRepositoryProvider).awardBonusXp(
                  sourceId: 'ms_${definition.id}',
                  amount: definition.xpReward,
                );
        xpResult.fold(
          (_) {},
          (_) => _ref.invalidate(xpTotalProvider),
        );
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _ref.invalidate(unlockedMilestonesProvider);
    }
    return newlyUnlocked;
  }
}

/// Provider for the [MilestoneChecker].
final milestoneCheckerProvider = Provider<MilestoneChecker>((ref) {
  return MilestoneChecker(ref);
});
