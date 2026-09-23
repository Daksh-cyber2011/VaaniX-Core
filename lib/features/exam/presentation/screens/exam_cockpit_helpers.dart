/// VaaniX Exam Cockpit — Truthful State Derivation Helpers (Phase 1)
///
/// All functions in this file are PURE FUNCTIONS of their inputs.
/// They translate real persisted/existing state (syllabus, exam hub
/// snapshot, weak-area overview, exam learner profile) into either:
///
///  * a student-facing summary backed by that state, OR
///  * an honest empty / not-started state when no legitimate source
///    exists for the metric they were going to render.
///
/// They MUST NOT introduce fabricated numbers. The Phase 1 audit named
/// every hardcoded value on the old cockpit screen (`74`, `78%`,
/// `+3.6%/wk`, `Based on 32 drills`, `'संधि एवं समास' 62%`, `'वाक्य
/// भेद' 78%`, `'High Prep Pace'`, `'TARGET READINESS 98%+'`,
/// `'MISSION DIRECTIVE • HIGH YIELD'`, `'Unfinished'`, `'Weightage:
/// 6-8 Marks'`, `'Target Speed: 1.8m/Ans'`, `'93% MATCH'`, `'Pada 3
/// has appeared in 4 out of the last 5 CBSE board papers'`, `'LATENCY:
/// 18ms'`) and these helpers are the only place the cockpit ever
/// chooses a value for them. Each old string is replaced either by a
/// derivation from real state, or by an honest empty-state line.
library;

import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart'
    show
        AssessmentType,
        CourseSyllabus,
        SyllabusChapter,
        SyllabusSection;
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart'
    show ExamLearnerProfile, TopicMastery, TopicStage;
import 'package:vaanix_app/features/exam/domain/hub/exam_hub_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/weak_topic_engine.dart';

// ─── public API ──────────────────────────────────────────────────────────────

/// Translates the active readiness-band into a number for the radial
/// gauge and an honest headline/subline for the student. Returns the
/// "no data" baseline when there is no real evidence.
ReadinessSummary readinessFromHub(ExamHubSnapshot? hub) {
  final daysLeft = hub?.readinessDaysLeft;
  if (hub == null || hub.profile == null) {
    return const ReadinessSummary(
      percent: 0,
      headline: 'No data yet',
      subline: 'Start your first session',
      deltaText: '—',
    );
  }
  if (daysLeft == null) {
    return const ReadinessSummary(
      percent: 0,
      headline: 'Set a readiness anchor',
      subline: 'Tell VaaniX when you want to be exam-ready',
      deltaText: '—',
    );
  }
  if (daysLeft < 0) {
    return const ReadinessSummary(
      percent: 0,
      headline: 'Anchor has passed',
      subline: 'Re-set your readiness anchor in Profile',
      deltaText: 'overdue',
    );
  }
  final pyq = hub.pyqAttemptedTotal;
  final mock = hub.mockCount;
  final activityLines = <String>[];
  if (pyq > 0) activityLines.add('$pyq PYQ attempt${pyq == 1 ? '' : 's'}');
  if (mock > 0) activityLines.add('$mock mock${mock == 1 ? '' : 's'}');
  final evidenceLine = activityLines.isEmpty
      ? 'No graded attempts yet'
      : activityLines.join(' · ');
  return ReadinessSummary(
    percent: 0,
    headline: daysLeft == 0
        ? 'Readiness target is today'
        : '$daysLeft day${daysLeft == 1 ? '' : 's'} to readiness',
    subline: evidenceLine,
    deltaText: '${daysLeft}d',
  );
}

/// Returns up to two diagnostic bars (the cockpit's "diagnostic
/// radar"). Bars come from real [WeakTopicFinding]s joined with the
/// matching [TopicMastery] (≥ 2 attempts per §21). Findings without
/// enough evidence are dropped — never faked.
List<DiagnosticBarDatum> diagnosticBars({
  required WeakAreaOverview? overview,
  required ExamLearnerProfile? learner,
  CourseSyllabus? syllabus,
}) {
  if (overview == null || learner == null) return const [];
  final lookup = TopicLookup.build(syllabus: syllabus);
  final rows = <_BarRow>[];
  for (final finding in overview.report.findings) {
    final mastery = learner.topics[finding.topicId];
    if (mastery == null || mastery.attemptCount < 2) continue;
    final pct = mastery.attemptCount == 0
        ? 0
        : ((mastery.correctCount / mastery.attemptCount) * 100)
            .round()
            .clamp(0, 100);
    rows.add(_BarRow(
      topicTitle: lookup.titleFor(finding.topicId),
      percent: pct,
      attempts: mastery.attemptCount,
      stage: mastery.stage,
    ));
  }
  rows.sort((a, b) => b.attempts.compareTo(a.attempts));
  return [
    for (final r in rows.take(2))
      DiagnosticBarDatum(
        topicTitle: r.topicTitle,
        percent: r.percent,
        stageLabel: _stageLabel(r.stage),
        attempts: r.attempts,
        isAlert: r.stage == TopicStage.needsAttention ||
            r.stage == TopicStage.needsReview,
      ),
  ];
}

/// Returns the first prescribed-book chapter of the active track (or
/// the first syllabus item when chapters are absent). Never a
/// hardcoded "सूरदास के पद" / "6-8 Marks" / "1.8m/Ans" — only what the
/// canonical syllabus provides.
PrimaryChapter? primaryChapter(CourseSyllabus? syllabus) {
  if (syllabus == null) return null;
  for (final book in syllabus.books) {
    if (book.chapters.isEmpty) continue;
    final chapter = book.chapters.first;
    final section = _findSectionForBook(syllabus, book.id);
    return PrimaryChapter(
      chapter: chapter,
      bookTitle: book.title,
      sectionTitle: section?.title ?? '',
      sectionMarks: section?.marks,
    );
  }
  final items = syllabus.allItems;
  if (items.isNotEmpty) {
    final first = items.first;
    final section = _findSectionForItem(syllabus, first.sectionId);
    final marks = section is _EmptySection ? null : section?.marks;
    return PrimaryChapter(
      chapter: SyllabusChapter(
        id: first.id,
        number: 0,
        title: first.title.isNotEmpty ? first.title : first.id,
        type: 'item',
      ),
      bookTitle: section == null ? '' : (section.title),
      sectionTitle: section == null ? '' : (section.title),
      sectionMarks: marks,
    );
  }
  return null;
}

String boardLabel(String boardId) {
  switch (boardId) {
    case 'cbse':
      return 'CBSE';
    case 'icse':
      return 'ICSE';
    default:
      return boardId.toUpperCase();
  }
}

// ─── value objects ────────────────────────────────────────────────────────────

/// Honest readiness summary — every field is real existing state OR
/// the truthful "no data yet" baseline.
class ReadinessSummary {
  const ReadinessSummary({
    required this.percent,
    required this.headline,
    required this.subline,
    required this.deltaText,
  });

  /// 0..100 (clamped, integer). 0 when no evidence OR no anchor.
  final int percent;

  /// Qualitative headline.
  final String headline;

  /// Honest context line.
  final String subline;

  /// Small label shown inside the radial gauge.
  final String? deltaText;
}

/// One row in the diagnostic radar — derived from a real
/// [WeakTopicFinding] + matching [TopicMastery].
class DiagnosticBarDatum {
  const DiagnosticBarDatum({
    required this.topicTitle,
    required this.percent,
    required this.stageLabel,
    required this.attempts,
    required this.isAlert,
  });

  final String topicTitle;

  /// 0..100, rounded. Derived from `correctCount/attemptCount*100`.
  final int percent;

  /// Honest qualitative band label.
  final String stageLabel;

  /// Real attempt count behind the band.
  final int attempts;

  /// True when the student should focus on this topic next.
  final bool isAlert;
}

/// The cockpit's primary chapter — first prescribed-book chapter of
/// the active track.
class PrimaryChapter {
  const PrimaryChapter({
    required this.chapter,
    required this.bookTitle,
    required this.sectionTitle,
    required this.sectionMarks,
  });

  final SyllabusChapter chapter;
  final String bookTitle;
  final String sectionTitle;
  final double? sectionMarks;

  String get title => chapter.title;

  String get subtitle {
    final parts = <String>[];
    if (bookTitle.isNotEmpty) parts.add(bookTitle);
    if (sectionTitle.isNotEmpty && sectionTitle != bookTitle) {
      parts.add(sectionTitle);
    }
    final m = sectionMarks ?? 0;
    if (m > 0) {
      parts.add('${m.toInt()} marks board scope');
    }
    return parts.isEmpty
        ? 'No metadata yet — open syllabus for chapter details'
        : parts.join(' • ');
  }
}

// ─── internals ───────────────────────────────────────────────────────────────

/// Resolves a friendly title for a `topicId` from the canonical
/// syllabus (chapter title → syllabus item title → topicId fallback).
class TopicLookup {
  const TopicLookup._(this._chapterTitles, this._itemTitles);

  final Map<String, String> _chapterTitles;
  final Map<String, String> _itemTitles;

  factory TopicLookup.build({CourseSyllabus? syllabus}) {
    if (syllabus == null) {
      return const TopicLookup._({}, {});
    }
    final chapters = <String, String>{};
    final items = <String, String>{};
    for (final book in syllabus.books) {
      for (final c in book.chapters) {
        if (c.title.isNotEmpty) chapters[c.id] = c.title;
      }
    }
    for (final s in syllabus.sections) {
      for (final i in s.items) {
        if (i.title.isNotEmpty) items[i.id] = i.title;
      }
    }
    return TopicLookup._(chapters, items);
  }

  String titleFor(String topicId) =>
      _chapterTitles[topicId] ?? _itemTitles[topicId] ?? topicId;
}

class _BarRow {
  const _BarRow({
    required this.topicTitle,
    required this.percent,
    required this.attempts,
    required this.stage,
  });

  final String topicTitle;
  final int percent;
  final int attempts;
  final TopicStage stage;
}

class _EmptySection extends SyllabusSection {
  const _EmptySection()
      : super(
          id: '',
          stableKey: '',
          title: '',
          titleEn: '',
          marks: 0,
          assessmentType: AssessmentType.board,
        );
}

String _stageLabel(TopicStage stage) {
  switch (stage) {
    case TopicStage.learning:
      return 'Learning';
    case TopicStage.practicing:
      return 'Practicing';
    case TopicStage.strong:
      return 'Strong';
    case TopicStage.mastered:
      return 'Mastered';
    case TopicStage.needsAttention:
      return 'Needs attention';
    case TopicStage.needsReview:
      return 'Needs review';
  }
}

SyllabusSection? _findSectionForBook(
    CourseSyllabus syllabus, String bookId) {
  final id = bookId.toLowerCase();
  for (final s in syllabus.sections) {
    final sid = s.id.toLowerCase();
    if (sid.contains(id) || id.contains(sid)) return s;
  }
  return syllabus.sections.isNotEmpty ? syllabus.sections.first : null;
}

SyllabusSection? _findSectionForItem(
    CourseSyllabus syllabus, String sectionId) {
  for (final s in syllabus.sections) {
    if (s.id == sectionId) return s;
  }
  return syllabus.sections.isNotEmpty ? syllabus.sections.first : null;
}
