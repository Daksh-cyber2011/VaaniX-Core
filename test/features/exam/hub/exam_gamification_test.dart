/// Exam Mode 2.0 — M10 Gamification Tests
///
/// Covers the pure XP rules (§M10 honesty: deterministic, bounded,
/// once-per-session), the session record key material, the day
/// completion repository (bounds, isolation, corruption) and the
/// outcome headline (reports only what actually happened).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/hub/exam_hub_repository.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_gamification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamSessionXp (deterministic, bounded)', () {
    test('per-kind correct XP + completion bonus', () {
      expect(ExamSessionXp.correctXp(ExamSessionKind.practice, 5), 10);
      expect(ExamSessionXp.correctXp(ExamSessionKind.mock, 5), 20);
      expect(ExamSessionXp.completionBonus(ExamSessionKind.diagnostic), 5);
      expect(ExamSessionXp.completionBonus(ExamSessionKind.recovery), 8);
    });

    test('practice session totals', () {
      // 6 correct of 8: 12 + 3 = 15 (no perfect bonus).
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.practice, correctCount: 6, totalCount: 8),
        15,
      );
      // All 8 correct: 16 + 3 + 5 = 24.
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.practice, correctCount: 8, totalCount: 8),
        24,
      );
    });

    test('perfect bonus needs a real-sized session', () {
      // 1/1 "perfect" is one click, not a demonstration.
      expect(
        ExamSessionXp.deservesPerfectBonus(1, 1),
        isFalse,
      );
      expect(ExamSessionXp.deservesPerfectBonus(5, 5), isTrue);
    });

    test('mock totals scale but stay capped', () {
      // 20/25: 80 + 15 = 95.
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.mock, correctCount: 20, totalCount: 25),
        95,
      );
      // Corrupt counts can never mint more than the cap.
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.mock, correctCount: 400, totalCount: 400),
        ExamSessionXp.capOf(ExamSessionKind.mock),
      );
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.practice, correctCount: -3, totalCount: 10),
        0,
      );
      expect(
        ExamSessionXp.total(
            kind: ExamSessionKind.pyq, correctCount: 2, totalCount: 0),
        0,
      );
    });
  });

  group('ExamSessionRecord (once-ever keys, day key, task mapping)', () {
    final t = DateTime(2026, 9, 12, 10, 30);

    ExamSessionRecord record(ExamSessionKind kind, String fp) =>
        ExamSessionRecord(
          kind: kind,
          trackId: 'cbse_10_sanskrit',
          correctCount: 4,
          totalCount: 6,
          questionFingerprint: fp,
          finishedAt: t,
        );

    test('day key is calendar-local yyyy-mm-dd', () {
      expect(record(ExamSessionKind.practice, 'x').dayKey, '2026-09-12');
    });

    test('xp source id encodes kind + track + fingerprint', () {
      final r = record(ExamSessionKind.pyq, 'abc123');
      expect(
        r.xpSourceId,
        'exam_xp_pyq_cbse_10_sanskrit_abc123',
      );
    });

    test('plan task mapping: diagnostic marks nothing', () {
      expect(record(ExamSessionKind.diagnostic, 'x').planTaskTypeName, isNull);
      expect(
          record(ExamSessionKind.recovery, 'x').planTaskTypeName, 'weakArea');
      expect(record(ExamSessionKind.revision, 'x').planTaskTypeName, 'review');
      expect(record(ExamSessionKind.pyq, 'x').planTaskTypeName, 'pyq');
    });

    test('award is the pure formula', () {
      expect(record(ExamSessionKind.practice, 'x').award, 11); // 8 + 3
    });
  });

  group('ExamSessionOutcome headline (honest)', () {
    const base = ExamSessionOutcome(
      trackId: 't',
      kind: ExamSessionKind.practice,
      xpAwarded: 0,
      streakExtended: false,
      currentStreak: 0,
      newAchievements: [],
      newMilestones: [],
    );

    test('all-zero outcome stays silent', () {
      expect(base.headline, isEmpty);
    });

    test('reports exactly what happened', () {
      expect(
        base.copyWith(xpAwarded: 12).headline,
        '+12 XP',
      );
      expect(
        base
            .copyWith(xpAwarded: 12, streakExtended: true, currentStreak: 3)
            .headline,
        '+12 XP · 3-day streak',
      );
      expect(
        base.copyWith(
          xpAwarded: 12,
          streakExtended: true,
          currentStreak: 3,
          newAchievements: const ['Dedicated Learner'],
        ).headline,
        '+12 XP · 3-day streak · 1 achievement',
      );
    });
  });

  group('ExamHubRepository (§12/§56/§57)', () {
    Future<LocalStorageService> freshPrefs(
        [Map<String, Object> initial = const {}]) async {
      SharedPreferences.setMockInitialValues(initial);
      return LocalStorageService(await SharedPreferences.getInstance());
    }

    test('empty store → empty completions', () async {
      final repo = ExamHubRepository(await freshPrefs());
      expect(await repo.loadDayCompletions('t', '2026-09-12'), isEmpty);
    });

    test('record + load round-trip, idempotent union', () async {
      final repo = ExamHubRepository(await freshPrefs());
      await repo.recordCompletion('t', '2026-09-12', 'practice');
      await repo.recordCompletion('t', '2026-09-12', 'practice');
      await repo.recordCompletion('t', '2026-09-12', 'pyq');
      expect(await repo.loadDayCompletions('t', '2026-09-12'),
          {'practice', 'pyq'});
    });

    test('per-track and per-day isolation', () async {
      final repo = ExamHubRepository(await freshPrefs());
      await repo.recordCompletion('a', '2026-09-12', 'practice');
      await repo.recordCompletion('b', '2026-09-12', 'mock');
      await repo.recordCompletion('a', '2026-09-13', 'review');
      expect(await repo.loadDayCompletions('a', '2026-09-12'), {'practice'});
      expect(await repo.loadDayCompletions('b', '2026-09-12'), {'mock'});
      expect(await repo.loadDayCompletions('a', '2026-09-13'), {'review'});
    });

    test('§56 bound: oldest day keys dropped', () async {
      final repo = ExamHubRepository(await freshPrefs());
      for (var i = 0; i < ExamHubRepository.maxDayKeys + 5; i++) {
        await repo.recordCompletion(
            't', 'd${i.toString().padLeft(3, '0')}', 'practice');
      }
      expect(
        await repo.loadDayCompletions('t', 'd000'),
        isEmpty,
        reason: 'the oldest key must have been dropped',
      );
      expect(
        await repo.loadDayCompletions('t',
            'd${(ExamHubRepository.maxDayKeys + 4).toString().padLeft(3, '0')}'),
        {'practice'},
      );
    });

    test('§57 corruption degrades to empty, never throws', () async {
      final repo = ExamHubRepository(await freshPrefs({
        'exam_hub_day_completions_v1': jsonEncode('not a map'),
      }));
      expect(await repo.loadDayCompletions('t', 'd'), isEmpty);
      await repo.recordCompletion('t', 'd', 'practice');
      expect(await repo.loadDayCompletions('t', 'd'), {'practice'});

      final repo2 = ExamHubRepository(await freshPrefs({
        'exam_hub_xp_ledger_v1': jsonEncode({'nope': 1}),
      }));
      expect(await repo2.isAwarded('k'), isFalse);
    });

    test('XP ledger: isAwarded / markAwarded / bound', () async {
      final repo = ExamHubRepository(await freshPrefs());
      expect(await repo.isAwarded('k1'), isFalse);
      await repo.markAwarded('k1');
      expect(await repo.isAwarded('k1'), isTrue);
      await repo.markAwarded('k1'); // idempotent
      for (var i = 0; i < ExamHubRepository.maxLedgerEntries + 10; i++) {
        await repo.markAwarded('k$i');
      }
      // Bounded FIFO: the earliest keys were dropped, recent survive.
      expect(await repo.isAwarded('k0'), isFalse);
      expect(await repo.isAwarded('k1'), isFalse);
      expect(
        await repo.isAwarded('k${ExamHubRepository.maxLedgerEntries - 1}'),
        isTrue,
      );
    });
  });
}

extension _CopyWith on ExamSessionOutcome {
  ExamSessionOutcome copyWith({
    int? xpAwarded,
    bool? streakExtended,
    int? currentStreak,
    List<String>? newAchievements,
    List<String>? newMilestones,
  }) =>
      ExamSessionOutcome(
        trackId: trackId,
        kind: kind,
        xpAwarded: xpAwarded ?? this.xpAwarded,
        streakExtended: streakExtended ?? this.streakExtended,
        currentStreak: currentStreak ?? this.currentStreak,
        newAchievements: newAchievements ?? this.newAchievements,
        newMilestones: newMilestones ?? this.newMilestones,
      );
}
