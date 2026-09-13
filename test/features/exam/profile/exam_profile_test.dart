/// Exam Mode 2.0 — M3 Exam Profile Tests
///
/// Mirrors the invariant set of tools/exam/verify_exam_m3_m7.py
/// (Python runs in CI; these run under `flutter test`).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/domain/exam_profile.dart';

void main() {
  group('ExamProfile domain (§8/§9/§12)', () {
    final now = DateTime(2026, 9, 12);

    ExamProfile profile({
      DateTime? target,
      int? weeks,
      int minutes = 30,
      int days = 5,
      DateTime? examDate,
    }) =>
        ExamProfile(
          trackId: 'cbse_10_sanskrit',
          dailyStudyMinutes: minutes,
          studyDaysPerWeek: days,
          readinessTargetDate: target,
          readinessDurationWeeks: weeks,
          actualExamDate: examDate,
        );

    test('date-only readiness anchors to the date', () {
      final p = profile(target: DateTime(2026, 11, 15));
      expect(p.readinessAnchor(now), DateTime(2026, 11, 15));
      expect(p.weeksToAnchor(now), 10);
    });

    test('duration-only readiness derives the anchor (§8 option B)', () {
      final p = profile(weeks: 8);
      final anchor = p.readinessAnchor(now)!;
      expect(anchor.difference(now).inDays, closeTo(56, 1));
    });

    test('both provided → target DATE is primary (§8 option C)', () {
      final p = profile(target: DateTime(2026, 11, 15), weeks: 4);
      expect(p.readinessAnchor(now), DateTime(2026, 11, 15));
    });

    test('no readiness source is INVALID (§8 requires an anchor)', () {
      expect(profile().validate(), isNotEmpty);
      expect(profile().isValid, isFalse);
    });

    test('past target dates are rejected', () {
      final p = profile(target: DateTime(2025, 1, 1), weeks: 4);
      expect(p.validate(now: now), anyElement(contains('past')));
    });

    test('actual exam date before readiness target is a data error', () {
      final p = profile(
        target: DateTime(2026, 12, 1),
        examDate: DateTime(2026, 10, 1),
      );
      expect(p.validate(now: now), anyElement(contains('precedes')));
    });

    test('§9 bounds: 5..480 minutes, 1..7 days', () {
      expect(profile(minutes: 2, weeks: 4).validate(), isNotEmpty);
      expect(profile(minutes: 600, weeks: 4).validate(), isNotEmpty);
      expect(profile(days: 0, weeks: 4).validate(), isNotEmpty);
      expect(profile(days: 8, weeks: 4).validate(), isNotEmpty);
      expect(profile(minutes: 5, weeks: 1).validate(), isEmpty);
      expect(profile(minutes: 480, weeks: 52).validate(), isEmpty);
    });

    test('JSON round-trip keeps every field', () {
      final p = profile(
        target: DateTime(2026, 11, 15),
        examDate: DateTime(2027, 2, 1),
      );
      final back = ExamProfile.fromJson(p.toJson());
      expect(back.dailyStudyMinutes, p.dailyStudyMinutes);
      expect(back.studyDaysPerWeek, p.studyDaysPerWeek);
      expect(back.readinessDurationWeeks, isNull);
      expect(back.readinessTargetDate, p.readinessTargetDate);
      expect(back.actualExamDate, p.actualExamDate);
      expect(back.trackId, p.trackId);
    });

    test('§57 migration safety: corrupt values degrade, never throw', () {
      final back = ExamProfile.fromJson({
        'trackId': 'x',
        'dailyStudyMinutes': -5,
        'readinessDurationWeeks': 99,
        'readinessTargetDate': 'not-a-date',
        'pace': 'unknown-pace',
      });
      expect(back.dailyStudyMinutes, ExamProfile.minDailyMinutes);
      expect(back.readinessDurationWeeks, ExamProfile.maxDurationWeeks);
      expect(back.readinessTargetDate, isNull);
      expect(back.pace, StudyPace.balanced);
    });

    test('weekly budget = daily × days', () {
      expect(profile(minutes: 45, days: 4).weeklyStudyMinutes, 180);
    });
  });
}
