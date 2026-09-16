/// Exam Mode 2.0 — Gamification Providers (M10)
///
/// The bridge from finished exam-mode sessions to the app-wide
/// gamification the Nest already speaks:
///
///   finished session ──► XP (idempotent bonus ledger, bounded rules)
///                        day-completion (today's plan task done)
///                        streak evidence (recordDailyActivity)
///                        achievement + milestone checkers (real only)
///                        VAN reactions + typed analytics
///
/// Honesty rules:
///  * XP is awarded ONCE per session (fingerprint-keyed source id +
///    local ledger mirror for honest reporting).
///  * The achievement/milestone checkers run the REAL definitions —
///    exam-mode sessions usually unlock nothing (their criteria read
///    Learn-mode evidence), and the outcome then reports zero unlocks
///    instead of inventing exam-themed trophies (§30).
///  * A failure anywhere in this chain NEVER breaks the session flow
///    (§41 best-effort) — the outcome degrades to "no XP", never to
///    an exception.
///
/// Import-shape note: this file is a LEAF — it imports only core
/// services, the progress/achievement/profile providers, VAN and the
/// hub repository. The session controllers (practice / weak-area /
/// PYQ / mock / diagnostic) import THIS file; nothing here imports
/// them, so no provider cycles.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/achievements/presentation/providers/achievement_checker.dart';
import 'package:vaanix_app/features/exam/data/hub/exam_hub_repository.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/milestone_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/van/domain/van_event.dart';
import 'package:vaanix_app/features/van/presentation/providers/van_controller.dart';

final examHubRepositoryProvider = Provider<ExamHubRepository>((ref) {
  return ExamHubRepository(ref.watch(localStorageServiceProvider));
});

/// Plan task-types completed today for one track. Arg format:
/// '<trackId>|<yyyy-mm-dd>'. Invalidated by [ExamGamification] after
/// every recorded completion so hub check-marks update live.
final examDayCompletionsProvider =
    FutureProvider.family<Set<String>, String>((ref, arg) async {
  final parts = arg.split('|');
  if (parts.length != 2) return const <String>{};
  return ref
      .watch(examHubRepositoryProvider)
      .loadDayCompletions(parts[0], parts[1]);
});

/// The most recent session outcome per track — the finish screens
/// read this to render the honest "+N XP · streak" strip. Cleared by
/// the next session start.
final lastExamSessionOutcomeProvider =
    StateProvider<ExamSessionOutcome?>((ref) => null);

/// The M10 gamification service.
class ExamGamification {
  ExamGamification(this._ref);

  final Ref _ref;

  /// Runs the full chain for one FINISHED session. Never throws (§41).
  Future<ExamSessionOutcome> sessionFinished(ExamSessionRecord record) async {
    var xpAwarded = 0;
    var streakExtended = false;
    var streak = 0;
    var achievements = const <String>[];
    var milestones = const <String>[];

    // 1) XP — once ever, fingerprint-keyed.
    try {
      final hubRepo = _ref.read(examHubRepositoryProvider);
      final alreadyPaid = await hubRepo.isAwarded(record.xpSourceId);
      if (!alreadyPaid && record.award > 0) {
        final result = await _ref.read(progressRepositoryProvider).awardBonusXp(
              sourceId: record.xpSourceId,
              amount: record.award,
            );
        result.fold(
          (_) {},
          (_) {
            xpAwarded = record.award;
            _ref.invalidate(xpTotalProvider);
          },
        );
      }
      if (xpAwarded > 0) {
        await hubRepo.markAwarded(record.xpSourceId);
      }
    } catch (_) {
      // §41: award failure degrades to "no XP this session".
    }

    // 2) Day completion (today's plan task done).
    try {
      final taskType = record.planTaskTypeName;
      if (taskType != null) {
        await _ref.read(examHubRepositoryProvider).recordCompletion(
              record.trackId,
              record.dayKey,
              taskType,
            );
        _ref.invalidate(
            examDayCompletionsProvider('${record.trackId}|${record.dayKey}'));
      }
    } catch (_) {
      // §41: completion bookkeeping is UI-state aid, never critical.
    }

    // 3) Streak evidence (same-day repeats report no extension).
    try {
      final previous = _ref.read(userProfileProvider).currentStreak;
      streak =
          await _ref.read(userProfileProvider.notifier).recordDailyActivity();
      streakExtended = streak > previous;
    } catch (_) {
      // §41.
    }

    // 4) Real achievement + milestone evaluation (shared checkers).
    try {
      final unlocked =
          await _ref.read(achievementCheckerProvider).checkAchievements();
      achievements = [for (final a in unlocked) a.title];
    } catch (_) {
      // §41: the checkers must never break the session flow.
    }
    try {
      final unlockedMilestones =
          await _ref.read(milestoneCheckerProvider).checkMilestones();
      milestones = [for (final m in unlockedMilestones) m.title];
    } catch (_) {
      // §41.
    }

    final outcome = ExamSessionOutcome(
      trackId: record.trackId,
      kind: record.kind,
      xpAwarded: xpAwarded,
      streakExtended: streakExtended,
      currentStreak: streak,
      newAchievements: achievements,
      newMilestones: milestones,
    );

    // 5) VAN reactions (honest, consolidated — same dispatch contract
    //    the Nest and the legacy quiz use).
    try {
      final van = _ref.read(vanControllerProvider.notifier);
      if (xpAwarded > 0) {
        final perfect =
            record.correctCount == record.totalCount && record.totalCount >= 5;
        van.dispatch(VanEvent(
          perfect ? VanEventType.perfectScore : VanEventType.quizCompleted,
          message: perfect
              ? 'Perfect run — $xpAwarded XP!'
              : 'Session done — $xpAwarded XP earned.',
          payload: {
            'kind': record.kind.name,
            'trackId': record.trackId,
          },
        ));
      }
      if (streakExtended && streak > 0) {
        van.dispatch(VanEvent(
          VanEventType.streakExtended,
          message: '$streak-day streak — wonderful consistency!',
          payload: {'streak': streak},
        ));
      }
      if (achievements.isNotEmpty) {
        van.dispatch(VanEvent(
          VanEventType.achievementUnlocked,
          message: 'Achievement unlocked: ${achievements.first}!',
          payload: {'count': achievements.length},
        ));
      }
      if (milestones.isNotEmpty) {
        van.dispatch(VanEvent(
          VanEventType.milestoneUnlocked,
          message: 'Milestone unlocked: ${milestones.first}!',
          payload: {'count': milestones.length},
        ));
      }
    } catch (_) {
      // §41: VAN is presentation sugar — never critical.
    }

    // 6) Typed analytics (best-effort, ref.log already never throws).
    _ref.log(AnalyticsEvent(
      AnalyticsEventName.examCompleted,
      {
        'mode': 'exam2',
        'kind': record.kind.name,
        'correct': record.correctCount,
        'total': record.totalCount,
        'xp': xpAwarded,
      },
    ));

    try {
      _ref.read(lastExamSessionOutcomeProvider.notifier).state = outcome;
    } catch (_) {
      // §41.
    }

    return outcome;
  }

  /// Clears the "last outcome" strip (called when a new session
  /// starts, so the old finish line never lingers).
  void clearLastOutcome() {
    try {
      _ref.read(lastExamSessionOutcomeProvider.notifier).state = null;
    } catch (_) {
      // §41.
    }
  }
}

final examGamificationProvider = Provider<ExamGamification>((ref) {
  return ExamGamification(ref);
});

/// Day key helper shared with the controllers/screens (local date).
String examDayKeyOf(DateTime now) {
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Stable fingerprint of a finished session's questions + verdicts:
/// 'q1:correct,q2:incorrect,...' (order = session order). The same
/// re-rendered finish state produces the same key; a different
/// question set or a changed verdict is a different session.
String examSessionFingerprintOf(
  List<String> questionIds,
  List<String> verdicts,
) {
  final parts = <String>[];
  for (var i = 0; i < questionIds.length && i < verdicts.length; i++) {
    parts.add('${questionIds[i]}:${verdicts[i]}');
  }
  if (parts.isEmpty) return 'empty';
  // Keep the key bounded even for long mocks: fold the joined string
  // into a stable 32-bit value (FNV-1a) rendered as hex.
  final joined = parts.join(',');
  var hash = 0x811c9dc5;
  for (var i = 0; i < joined.length; i++) {
    hash ^= joined.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16);
}
