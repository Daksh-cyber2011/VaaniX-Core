/// Exam Mode 2.0 — M8 Weak-Area Recovery Day Tests (§22/§50)
///
/// Frequency tiers, gap rules, no back-to-back recovery, honest floor
/// (no evidence → no recovery day), blueprint structure, decision
/// rationale presence.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';

WeakAreaReport reportOf(WeakSeverity severity, {int count = 1}) =>
    WeakAreaReport(
      findings: [
        for (var i = 0; i < count; i++)
          WeakTopicFinding(
            topicId: 't$i',
            severity: severity,
            signals: {WeakSignal.repeatedWrong},
            patternCategories: const {},
            evidenceSentence: 'evidence $i',
          ),
      ],
      insufficientEvidence: false,
      evidenceNote: 'note',
    );

RevisionItem dueSoon(String topicId, DateTime now) => RevisionItem(
      topicId: topicId,
      intervalIndex: 1,
      lastReviewedIso: now.toIso8601String(),
      dueIso: now.toIso8601String(),
    );

RevisionItem overdue(String topicId, DateTime now) => RevisionItem(
      topicId: topicId,
      intervalIndex: 1,
      lastReviewedIso: '',
      dueIso: now.subtract(const Duration(days: 5)).toIso8601String(),
    );

void main() {
  final t = DateTime(2026, 9, 12);

  group('frequency tiers (§22)', () {
    test('needsAttention finding → frequent tier', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        now: t,
      );
      expect(d.frequency, RecoveryFrequency.frequent);
      expect(d.shouldRecover, isTrue);
      expect(d.dayIndex, greaterThanOrEqualTo(0));
      expect(d.focusTopicId, 't0');
    });

    test('focus finding → occasional tier', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.focus),
        revisionItems: const [],
        dayCount: 7,
        now: t,
      );
      expect(d.frequency, RecoveryFrequency.occasional);
    });

    test('two overdue revisions (no findings) → occasional recovery', () {
      final d = WeakAreaDayEngine.decide(
        report: WeakAreaReport(
            findings: const [], insufficientEvidence: false, evidenceNote: ''),
        revisionItems: [overdue('a', t), overdue('b', t)],
        dayCount: 7,
        now: t,
      );
      expect(d.shouldRecover, isTrue);
      expect(d.frequency, RecoveryFrequency.occasional);
    });

    test('only watch findings → at-most-weekly tier', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.watch),
        revisionItems: const [],
        dayCount: 7,
        now: t,
      );
      expect(d.frequency, RecoveryFrequency.none);
      expect(d.shouldRecover, isTrue);
    });

    test('nothing weak, nothing due → NO recovery day (§22)', () {
      final d = WeakAreaDayEngine.decide(
        report: WeakAreaReport(
            findings: const [], insufficientEvidence: false, evidenceNote: ''),
        revisionItems: [
          dueSoon('a', t).copyWith(
            dueIso: t.add(const Duration(days: 2)).toIso8601String(),
          ),
        ],
        dayCount: 7,
        now: t,
      );
      expect(d.shouldRecover, isFalse);
      expect(d.rationale, isNotEmpty);
    });
  });

  group('gap rules (§22 "not every day")', () {
    test('never had recovery → eligible from day 1', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        daysSinceLastRecovery: null,
        now: t,
      );
      expect(d.dayIndex, 1); // day 0 keeps the §13 normal flow
    });

    test('gap not served → no recovery this window', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        daysSinceLastRecovery: 1, // frequent tier needs >= 3
        now: t,
      );
      expect(d.shouldRecover, isFalse);
    });

    test('gap served → recovery happens', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        daysSinceLastRecovery: 3,
        now: t,
      );
      expect(d.shouldRecover, isTrue);
    });

    test('hard cap: never back-to-back within the window', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        lastRecoveryDayIndex: 2,
        now: t,
      );
      expect(d.dayIndex, greaterThan(3)); // ≥ lastRecovery + 2
    });

    test('recovery day pushed past the window → none this window', () {
      final d = WeakAreaDayEngine.decide(
        report: reportOf(WeakSeverity.needsAttention),
        revisionItems: const [],
        dayCount: 7,
        lastRecoveryDayIndex: 6,
        now: t,
      );
      expect(d.shouldRecover, isFalse);
    });
  });

  group('honest floor (§22 no fake recovery)', () {
    test('empty focus + zero days → no recovery', () {
      final d = WeakAreaDayEngine.decide(
        report: WeakAreaReport(
            findings: const [], insufficientEvidence: true, evidenceNote: ''),
        revisionItems: const [],
        dayCount: 0,
        now: t,
      );
      expect(d.shouldRecover, isFalse);
    });
  });

  group('blueprint (§22 structure)', () {
    test('four phases in the official order', () {
      final b =
          WeakAreaDayEngine.blueprintFor('t1', 'Sandhi', rationale: 'why');
      expect(b.phases, [
        RecoveryPhase.recap,
        RecoveryPhase.mistakeRetry,
        RecoveryPhase.targetedPractice,
        RecoveryPhase.recheck,
      ]);
      expect(b.topicId, 't1');
      expect(b.topicTitle, 'Sandhi');
      expect(b.rationale, 'why');
      expect(b.totalMinutes, 40);
    });

    test('phase labels are student-facing Hindi (§28)', () {
      for (final p in RecoveryPhase.values) {
        expect(p.label, isNotEmpty);
      }
      expect(recoveryPhaseFromName('recap'), RecoveryPhase.recap);
      expect(recoveryPhaseFromName('bogus'), RecoveryPhase.recap);
      expect(recoveryFrequencyFromName('frequent'), RecoveryFrequency.frequent);
      expect(recoveryFrequencyFromName(null), RecoveryFrequency.none);
    });
  });

  group('decision carries a rationale (§50 explainability)', () {
    test('every tier decision ships an explanation', () {
      final cases = [
        reportOf(WeakSeverity.needsAttention),
        reportOf(WeakSeverity.focus),
        reportOf(WeakSeverity.watch),
        WeakAreaReport(
            findings: const [], insufficientEvidence: false, evidenceNote: ''),
      ];
      for (final r in cases) {
        final d = WeakAreaDayEngine.decide(
          report: r,
          revisionItems: const [],
          dayCount: 7,
          now: t,
        );
        expect(d.rationale, isNotEmpty);
        expect(d.rationale.contains('%'), isFalse);
      }
    });
  });
}
