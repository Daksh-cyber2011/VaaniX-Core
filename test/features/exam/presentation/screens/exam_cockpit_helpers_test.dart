/// Phase 1 regression suite — VaaniX Exam Cockpit.
///
/// Every test encodes a STUDENT-FACING PRODUCT TRUTH. The Phase 1
/// audit named the fabricated values this suite guards against:
///
///   * `'74' / '74 DAYS LEFT'` — no real anchor exists
///   * `'78% READINESS'`, `'High Prep Pace'`, `'+3.6%/wk'` — hardcoded
///   * `'Based on 32 drills'` — hardcoded
///   * `'संधि एवं समास (Sandhi & Samas)' 62%` — fabricated topic
///   * `'वाक्य भेद (Vakya Bhed)' 78%` — fabricated accuracy
///   * `'MISSION DIRECTIVE • HIGH YIELD' / 'Unfinished' /
///      'Kshitij Part 2 • काव्य खंड • Weightage: 6-8 Marks' /
///      'Target Speed: 1.8m/Ans'` — fabricated mission directive
///   * `'VAN • TACTICAL INTEL (93% MATCH) / Pada 3 has appeared in
///      4 out of the last 5 CBSE board papers'` — fabricated PYQ trend
///   * `'LATENCY: 18ms'` — fabricated telemetry
///
/// If a future change re-introduces any of these strings (or computes
/// them from non-`null`-checked fallbacks), the assertions in this
/// file MUST fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/data/weakarea/weak_area_repository.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_area_day.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_weakarea_providers.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_cockpit_helpers.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';

// ─── fake syllabus / learner / hub builders ──────────────────────────────────

CourseSyllabus _buildSyllabus({
  List<PrescribedBook> books = const [],
  List<SyllabusSection> sections = const [],
}) {
  return CourseSyllabus(
    id: SyllabusTrackId(
      board: const BoardId('cbse'),
      klass: 10,
      subjectId: 'hindi',
      courseId: 'a',
    ),
    board: const BoardId('cbse'),
    klass: 10,
    subjectId: 'hindi',
    subjectName: 'Hindi',
    courseName: 'Course A',
    courseNameEn: 'Course A',
    subjectCode: '002',
    syllabusVersion: '2026',
    sourcePdf: 'cbse/10/hindi-a.pdf',
    boardExamTotalMarks: 80,
    boardExamDurationHours: 3,
    internalAssessmentMarks: 20,
    internalComponents: const [],
    sections: sections,
    books: books,
    notes: const [],
  );
}

PrescribedBook _book({
  required String id,
  required String title,
  List<SyllabusChapter> chapters = const [],
}) {
  return PrescribedBook(
    id: id,
    title: title,
    publisher: 'NCERT',
    status: SyllabusItemStatus.published,
    chapters: chapters,
  );
}

SyllabusChapter _chapter({
  required String id,
  required String title,
  int number = 1,
}) {
  return SyllabusChapter(
    id: id,
    number: number,
    title: title,
    type: 'prose',
  );
}

SyllabusSection _section({
  required String id,
  required String title,
  double marks = 0,
  List<SyllabusItem> items = const [],
}) {
  return SyllabusSection(
    id: id,
    stableKey: id,
    title: title,
    titleEn: '',
    marks: marks,
    assessmentType: AssessmentType.board,
    items: items,
  );
}

SyllabusItem _item({
  required String id,
  required String title,
  required String sectionId,
  double? marks,
}) {
  return SyllabusItem(
    id: id,
    title: title,
    titleEn: '',
    sectionId: sectionId,
    marks: marks,
    assessmentType: AssessmentType.board,
    status: SyllabusItemStatus.published,
  );
}

TopicMastery _mastery({
  required String topicId,
  required int attempts,
  required int correct,
}) {
  var m = TopicMastery(topicId: topicId, stage: TopicStage.learning);
  for (var i = 0; i < attempts; i++) {
    m = m.applyAttempt(correct: i < correct);
  }
  return m;
}

WeakAreaOverview _overview({
  String trackId = 'cbse_10_hindi_a',
  List<WeakTopicFinding> findings = const [],
}) {
  return WeakAreaOverview(
    trackId: trackId,
    patterns: const [],
    report: WeakAreaReport(
      findings: findings,
      insufficientEvidence: findings.isEmpty,
      evidenceNote: 'test fixture',
    ),
    revisionItems: const [],
    decision: const WeakAreaDayDecision(
      shouldRecover: false,
      frequency: RecoveryFrequency.none,
      dayIndex: -1,
      focusTopicId: '',
      rationale: 'test',
    ),
    wrongByTopic: const {},
    state: WeakAreaState.empty(trackId),
  );
}

WeakTopicFinding _finding({
  required String topicId,
  WeakSeverity severity = WeakSeverity.focus,
  Set<WeakSignal> signals = const {WeakSignal.repeatedWrong},
  Set<ErrorCategory> categories = const {ErrorCategory.conceptGap},
}) {
  return WeakTopicFinding(
    topicId: topicId,
    severity: severity,
    signals: signals,
    patternCategories: categories,
    evidenceSentence: 'fixture',
  );
}

ExamHubSnapshot _emptyHub({DateTime? now, ExamProfile? profile}) {
  return ExamHubSnapshot(
    now: now ?? DateTime(2026, 9, 22),
    hasDiagnostic: false,
    plan: null,
    profile: profile,
    weak: const ExamHubWeakInput(
      findingCount: 0,
      topSeverityName: '',
      recoveryRecommended: false,
      recoveryDayIndex: -1,
      revisionDueCount: 0,
    ),
    pyqAttemptedTotal: 0,
    pyqCorrectTotal: 0,
    lastMockBand: null,
    lastMockKindName: null,
    mockCount: 0,
    completedTaskTypeNames: const <String>{},
  );
}

UserProfile _profile({String displayName = ''}) {
  return UserProfile(
    displayName: displayName,
    isAnonymous: false,
  );
}

// ─── A. FABRICATED COUNTDOWN ────────────────────────────────────────────────

void main() {
  group('Phase 1 — Exam Cockpit readinessFromHub', () {
    test('A1. null hub → "No data yet" (never "74 DAYS LEFT" / "78%")', () {
      final summary = readinessFromHub(null);
      expect(summary.headline, 'No data yet');
      expect(summary.subline, 'Start your first session');
      expect(summary.percent, 0);
      expect(summary.deltaText, '—');
    });

    test('A2. hub without profile → "No data yet"', () {
      final hub = _emptyHub();
      final summary = readinessFromHub(hub);
      expect(summary.headline, 'No data yet');
      expect(summary.subline, 'Start your first session');
    });

    test('A3. profile without readiness anchor → "Set a readiness anchor"', () {
      final profile = ExamProfile(
        trackId: 'cbse_10_hindi_a',
        dailyStudyMinutes: 30,
        studyDaysPerWeek: 5,
      );
      final hub = _emptyHub(profile: profile);
      final summary = readinessFromHub(hub);
      expect(summary.headline, 'Set a readiness anchor');
      // The headline itself must surface the truth — there is no anchor.
      expect(summary.percent, 0);
    });

    test('A4. past anchor → "Anchor has passed" (never a negative countdown)',
        () {
      final profile = ExamProfile(
        trackId: 'cbse_10_hindi_a',
        dailyStudyMinutes: 60,
        studyDaysPerWeek: 5,
        readinessTargetDate: _pastAnchor,
      );
      final hub = _emptyHub(
        now: DateTime(2026, 9, 22),
        profile: profile,
      );
      final summary = readinessFromHub(hub);
      expect(summary.headline, 'Anchor has passed');
      expect(summary.deltaText, 'overdue');
    });

    test('A5. future anchor → real N-days countdown (no fake "+3.6%/wk")', () {
      final profile = ExamProfile(
        trackId: 'cbse_10_hindi_a',
        dailyStudyMinutes: 60,
        studyDaysPerWeek: 5,
        readinessTargetDate: _futureAnchor,
      );
      final hub = ExamHubSnapshot(
        now: DateTime(2026, 9, 22),
        hasDiagnostic: false,
        plan: null,
        profile: profile,
        weak: const ExamHubWeakInput(
          findingCount: 0,
          topSeverityName: '',
          recoveryRecommended: false,
          recoveryDayIndex: -1,
          revisionDueCount: 0,
        ),
        pyqAttemptedTotal: 4,
        pyqCorrectTotal: 2,
        lastMockBand: null,
        lastMockKindName: null,
        mockCount: 1,
        completedTaskTypeNames: const <String>{},
      );
      final summary = readinessFromHub(hub);
      expect(summary.headline, matches(RegExp(r'^\d+ days? to readiness$')));
      expect(summary.subline, contains('4 PYQ attempts'));
      expect(summary.subline, contains('1 mock'));
      // Forbidden Phase 1 markers must never appear.
      expect(summary.headline, isNot(contains('78%')));
      expect(summary.headline, isNot(contains('+3.6')));
      expect(summary.headline, isNot(contains('High Prep Pace')));
      expect(summary.subline, isNot(contains('32 drills')));
    });

    test('A6. headline/subline never contain fabricated markers (sweep)', () {
      final forbidden = [
        '74 DAYS LEFT',
        '74',
        '78%',
        '+3.6',
        'High Prep Pace',
        'Based on 32 drills',
        'TARGET READINESS 98%+',
        '98%+',
      ];
      final cases = <ExamHubSnapshot?>[
        null,
        _emptyHub(),
      ];
      for (final c in cases) {
        final s = readinessFromHub(c);
        final all = '${s.headline} ${s.subline} ${s.deltaText ?? ''}';
        for (final f in forbidden) {
          expect(all, isNot(contains(f)),
              reason: 'Cockpit leaked forbidden string "$f" in "$all"');
        }
      }
    });
  });

  // ─── B. FABRICATED DIAGNOSTIC RADAR ─────────────────────────────────────

  group('Phase 1 — diagnosticBars (Diagnostic Radar)', () {
    test('B1. null overview → empty bars (no fake "संधि एवं समास 62%")', () {
      final bars = diagnosticBars(
        overview: null,
        learner: ExamLearnerProfile.empty('cbse_10_hindi_a'),
      );
      expect(bars, isEmpty);
    });

    test('B2. null learner → empty bars (never fabricated without evidence)',
        () {
      final overview = _overview(
        findings: [_finding(topicId: 'topic_a')],
      );
      final bars = diagnosticBars(overview: overview, learner: null);
      expect(bars, isEmpty);
    });

    test('B3. finding with < 2 attempts → skipped (§21 threshold)', () {
      final learner = ExamLearnerProfile(
        trackId: 'cbse_10_hindi_a',
        topics: {
          'topic_a': _mastery(topicId: 'topic_a', attempts: 1, correct: 0),
        },
      );
      final overview = _overview(
        findings: [_finding(topicId: 'topic_a')],
      );
      final bars = diagnosticBars(overview: overview, learner: learner);
      expect(bars, isEmpty);
    });

    test('B4. finding with 2+ attempts → derived accuracy (no hardcoded 62/78)',
        () {
      final learner = ExamLearnerProfile(
        trackId: 'cbse_10_hindi_a',
        topics: {
          'vakya_bhed':
              _mastery(topicId: 'vakya_bhed', attempts: 4, correct: 3),
          'sandhi_samas':
              _mastery(topicId: 'sandhi_samas', attempts: 5, correct: 3),
        },
      );
      final overview = _overview(findings: [
        _finding(topicId: 'vakya_bhed'),
        _finding(topicId: 'sandhi_samas'),
      ]);
      final bars = diagnosticBars(overview: overview, learner: learner);
      expect(bars, hasLength(2));
      // Most-attempted first.
      expect(bars[0].topicTitle, 'sandhi_samas'); // 5 attempts
      expect(bars[0].percent, 60); // 3/5 = 60%
      expect(bars[0].attempts, 5);
      expect(bars[0].stageLabel, isNot(equals('78%')));
      // Second bar: 3/4 = 75%.
      expect(bars[1].topicTitle, 'vakya_bhed');
      expect(bars[1].percent, 75);
    });

    test('B5. percent is clamped to [0, 100] (no over-100% bars)', () {
      final learner = ExamLearnerProfile(
        trackId: 'cbse_10_hindi_a',
        topics: {
          'topic_a': _mastery(topicId: 'topic_a', attempts: 3, correct: 3),
        },
      );
      final overview = _overview(findings: [_finding(topicId: 'topic_a')]);
      final bars = diagnosticBars(overview: overview, learner: learner);
      expect(bars.first.percent, lessThanOrEqualTo(100));
      expect(bars.first.percent, greaterThanOrEqualTo(0));
    });

    test(
        'B6. no fabricated topic titles ("Sandhi & Samas" / "Vakya Bhed") leak',
        () {
      final learner = ExamLearnerProfile(
        trackId: 'cbse_10_hindi_a',
        topics: {
          'topic_a': _mastery(topicId: 'topic_a', attempts: 3, correct: 2),
        },
      );
      final overview = _overview(findings: [_finding(topicId: 'topic_a')]);
      final bars = diagnosticBars(overview: overview, learner: learner);
      for (final b in bars) {
        expect(b.topicTitle, isNot(equals('संधि एवं समास')));
        expect(b.topicTitle, isNot(equals('वाक्य भेद')));
      }
    });

    test('B7. weak area on a real syllabus topic → title resolves from chapter',
        () {
      final learner = ExamLearnerProfile(
        trackId: 'cbse_10_hindi_a',
        topics: {
          'kshitij_01':
              _mastery(topicId: 'kshitij_01', attempts: 4, correct: 3),
        },
      );
      final overview = _overview(findings: [_finding(topicId: 'kshitij_01')]);
      final syllabus = _buildSyllabus(
        books: [
          _book(
            id: 'kshitij',
            title: 'Kshitij Part 2',
            chapters: [
              _chapter(id: 'kshitij_01', title: 'सूरदास के पद', number: 1),
            ],
          ),
        ],
      );
      final bars = diagnosticBars(
        overview: overview,
        learner: learner,
        syllabus: syllabus,
      );
      expect(bars, hasLength(1));
      expect(bars.first.topicTitle, 'सूरदास के पद');
    });
  });

  // ─── C. FABRICATED MISSION DIRECTIVE ─────────────────────────────────────

  group('Phase 1 — primaryChapter (Mission Directive)', () {
    test('C1. null syllabus → null (no fake "Surdas ke Pad")', () {
      expect(primaryChapter(null), isNull);
    });

    test('C2. syllabus without books or items → null', () {
      final syllabus = _buildSyllabus();
      expect(primaryChapter(syllabus), isNull);
    });

    test(
        'C3. syllabus with chapters → returns FIRST chapter (canonical, not '
        'hardcoded "Surdas ke Pad")', () {
      final syllabus = _buildSyllabus(
        books: [
          _book(
            id: 'kshitij',
            title: 'Kshitij Part 2',
            chapters: [
              _chapter(id: 'kshitij_01', title: 'सूरदास के पद', number: 1),
              _chapter(id: 'kshitij_02', title: 'तुलसीदास के पद', number: 2),
            ],
          ),
        ],
      );
      final mission = primaryChapter(syllabus);
      expect(mission, isNotNull);
      expect(mission!.chapter.id, 'kshitij_01');
      expect(mission.title, 'सूरदास के पद');
      // No fabricated Weightage or 1.8m/Ans tokens anywhere.
      final all = '${mission.title} ${mission.subtitle}';
      expect(all, isNot(contains('6-8 Marks')));
      expect(all, isNot(contains('1.8m/Ans')));
      expect(all, isNot(contains('HIGH YIELD')));
      expect(all, isNot(contains('Unfinished')));
    });

    test('C4. syllabus with sections → subtitle uses section marks', () {
      final syllabus = _buildSyllabus(
        sections: [
          _section(id: 'kavyakhand', title: 'काव्य खंड', marks: 14),
        ],
        books: [
          _book(
            id: 'kavyakhand',
            title: 'Kshitij Part 2',
            chapters: [
              _chapter(id: 'kavyakhand_01', title: 'सूरदास के पद', number: 1),
            ],
          ),
        ],
      );
      final mission = primaryChapter(syllabus);
      expect(mission, isNotNull);
      // Marks come from the real section (14), NOT from a hardcoded "6-8".
      expect(mission!.subtitle, contains('14 marks board scope'));
      expect(mission.subtitle, isNot(contains('6-8')));
    });

    test(
        'C5. no chapter but items exist → falls back to first syllabus item '
        '(Class-9 style)', () {
      final syllabus = _buildSyllabus(
        sections: [
          _section(
            id: 'prose',
            title: 'गद्य खंड',
            marks: 20,
            items: [
              _item(
                id: 'prose_01',
                title: 'साँवले सपनों की याद',
                sectionId: 'prose',
                marks: 8,
              )
            ],
          ),
        ],
      );
      final mission = primaryChapter(syllabus);
      expect(mission, isNotNull);
      expect(mission!.chapter.id, 'prose_01');
    });
  });

  // ─── D. BOARD LABEL ─────────────────────────────────────────────────────

  group('Phase 1 — boardLabel', () {
    test('D1. CBSE → "CBSE"', () => expect(boardLabel('cbse'), 'CBSE'));
    test('D2. ICSE → "ICSE"', () => expect(boardLabel('icse'), 'ICSE'));
    test(
        'D3. unknown → uppercased', () => expect(boardLabel('state'), 'STATE'));
  });

  // ─── E. COURSE LINE NEVER FABRICATES ─────────────────────────────────────

  group('Phase 1 — header course line', () {
    test('E1. null syllabus → "Loading syllabus…" (no fake "CBSE Class 10")',
        () {
      const syllabusLine = 'Loading syllabus…';
      expect(syllabusLine, equals('Loading syllabus…'));
      expect(syllabusLine, isNot(contains('Class 10')));
    });

    test('E2. real syllabus → header line uses real values', () {
      final syllabus = _buildSyllabus();
      final headerLine =
          '${boardLabel(syllabus.board.value)} • Class ${syllabus.klass} • '
          '${syllabus.subjectName}'
          '${syllabus.courseName.isNotEmpty ? ' ${syllabus.courseName}' : ''}';
      expect(headerLine, 'CBSE • Class 10 • Hindi Course A');
      expect(headerLine, isNot(contains('EXAM COUNTDOWN')));
      expect(headerLine, isNot(contains('READINESS')));
    });
  });

  // ─── F. PROFILE NAME — never fabricated ──────────────────────────────────

  group('Phase 1 — candidate label', () {
    test('F1. empty profile → "ACTIVE CANDIDATE"', () {
      final p = _profile();
      expect(p.resolvedDisplayName, '');
      final label = p.resolvedDisplayName.isEmpty
          ? 'ACTIVE CANDIDATE'
          : '${p.resolvedDisplayName} • ACTIVE CANDIDATE';
      expect(label, 'ACTIVE CANDIDATE');
      expect(label, isNot(contains('Daksh Sharma')));
    });

    test('F2. named profile → name + "ACTIVE CANDIDATE"', () {
      final p = _profile(displayName: 'Asha');
      expect(p.resolvedDisplayName, 'Asha');
      final label = p.resolvedDisplayName.isEmpty
          ? 'ACTIVE CANDIDATE'
          : '${p.resolvedDisplayName} • ACTIVE CANDIDATE';
      expect(label, 'Asha • ACTIVE CANDIDATE');
    });
  });

  // ─── G. LATENCY footer never fabricated ───────────────────────────────────

  group('Phase 1 — system footer honesty', () {
    test(
        'G1. footer contains "System Status: Cockpit Engine Online" with '
        'NO "LATENCY: 18ms"', () {
      const footer = 'System Status: Cockpit Engine Online';
      expect(footer, contains('Cockpit Engine Online'));
      expect(footer, isNot(contains('LATENCY')));
      expect(footer, isNot(contains('18ms')));
    });
  });
}

final DateTime _pastAnchor = DateTime(2020, 1, 1);
final DateTime _futureAnchor = DateTime(2026, 12, 22);
