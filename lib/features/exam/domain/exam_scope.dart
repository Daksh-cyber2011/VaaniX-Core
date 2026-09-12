/// Exam Mode 2.0 — Exam Scope Domain (M2)
///
/// The student's EXAM SCOPE (master plan §5–§6): the exact set of official
/// syllabus units they want to prepare, for one course (track). The scope is
/// dynamic — it can be edited at any time (add/remove units, select or clear
/// whole sections), and every change bumps a revision counter that later
/// milestones (planner, replanning) will use as the "scope changed" trigger.
///
/// Selection units are of two kinds, unified by [ScopeUnit]:
///  * syllabus items (grammar topics, writing tasks, comprehension blocks,
///    Hindi book-sections), and
///  * book chapters (Class 10 Sanskrit literature chapters).
///
/// Safety rules encoded here:
///  * Course isolation (§38): every selected id MUST belong to the scope's
///    own track. Ids from another course are rejected, never silently kept.
///  * Only officially published units are selectable. Pending literature
///    (Class 9) and internal-only chapters are NEVER selectable.
///  * Board scope only: internal-assessment units never enter exam scope
///    (Class 10 board prep prioritizes board scope — §7).
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';

/// A unified selectable scope unit.
class ScopeUnit extends Equatable {
  const ScopeUnit({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.sectionId,
    required this.selectable,
    this.marks,
    this.subtitle,
    this.isChapter = false,
    this.note,
    this.info,
  });

  /// Stable id (syllabus item id or chapter id).
  final String id;
  final String title;
  final String titleEn;
  final String sectionId;

  /// False for pending/internal-only units — rendered but not checkable.
  final bool selectable;
  final double? marks;

  /// Secondary line (question pattern or author/type info).
  final String? subtitle;
  final bool isChapter;

  /// Warning-toned note (OCR-uncertainty).
  final String? note;

  /// Neutral informational line (e.g. official excluded chapters).
  final String? info;

  @override
  List<Object?> get props => [id, selectable];
}

/// One section of the scope-selection tree (with its selectable units).
class ScopeSection extends Equatable {
  const ScopeSection({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.stableKey,
    required this.marks,
    required this.units,
    this.pendingNote,
  });

  final String id;
  final String title;
  final String titleEn;
  final String stableKey;
  final double marks;
  final List<ScopeUnit> units;

  /// Non-null when this section awaits official content (Class 9
  /// literature) — shown with the pending announcement reason.
  final String? pendingNote;

  List<ScopeUnit> get selectableUnits =>
      units.where((u) => u.selectable).toList();

  bool get isPending => selectableUnits.isEmpty && pendingNote != null;

  @override
  List<Object?> get props => [id, marks, units];
}

/// The full selection tree for one course, built from [CourseSyllabus].
///
/// Building rules:
///  * every section's published items become units;
///  * literature sections with chapter-bearing books get the chapters as
///    units (Sanskrit tracks); internal-only chapters render unselectable;
///  * pending literature sections keep their (unselectable) items plus the
///    pending note;
///  * excluded chapters (Hindi A/B) surface as unit subtitles, since the
///    official exclusion list is part of the book-section unit.
class ExamScopeView extends Equatable {
  const ExamScopeView({
    required this.trackId,
    required this.sections,
    required this.boardMarks,
  });

  factory ExamScopeView.fromSyllabus(CourseSyllabus syllabus) {
    final sections = <ScopeSection>[];

    for (final section in syllabus.boardSections) {
      final units = <ScopeUnit>[];
      String? pendingNote;
      // True only when book CHAPTERS became the literature units
      // (Class 10 Sanskrit tracks) — NOT when item units are present.
      var chaptersAdded = false;

      // Literature chapters become the selectable units when the course's
      // books publish them (Class 10 Sanskrit tracks).
      if (section.stableKey == 'literature') {
        final chapters = syllabus.allChapters;
        final internalOnly = chapters.where((c) => c.isInternalOnly).toList();
        final boardChapters = chapters.where((c) => !c.isInternalOnly).toList();

        if (boardChapters.isNotEmpty || internalOnly.isNotEmpty) {
          chaptersAdded = true;
          for (final ch in boardChapters) {
            units.add(ScopeUnit(
              id: ch.id,
              title: ch.title,
              titleEn: 'Chapter ${ch.number}',
              sectionId: section.id,
              selectable: true,
              isChapter: true,
              subtitle: ch.type == 'poetry' ? 'काव्य खंड' : 'गद्य खंड',
            ));
          }
          for (final ch in internalOnly) {
            units.add(ScopeUnit(
              id: ch.id,
              title: ch.title,
              titleEn: 'Chapter ${ch.number}',
              sectionId: section.id,
              selectable: false,
              isChapter: true,
              subtitle: 'आंतरिक मूल्यांकन हेतु (बोर्ड परीक्षा दायरे से बाहर)',
              note: ch.ocrUncertain ? 'OCR-अस्पष्ट शीर्षक' : null,
            ));
          }
        }
      }

      // Section items. For Sanskrit tracks whose literature is
      // chapter-based, the question-format items are replaced by the
      // chapters above; for pending literature (Class 9 — including
      // literature sections with NO items yet) they stay visible but
      // unselectable.
      if (section.stableKey == 'literature' &&
          !chaptersAdded &&
          syllabus.pending != null) {
        pendingNote = _pendingNoteFor(syllabus);
      }
      for (final item in section.items) {
        if (section.stableKey == 'literature' && chaptersAdded) {
          continue;
        }
        final selectable = item.isSelectable &&
            item.assessmentType == AssessmentType.board;
        units.add(ScopeUnit(
          id: item.id,
          title: item.title,
          titleEn: item.titleEn,
          sectionId: section.id,
          selectable: selectable,
          marks: item.marks,
          subtitle: _itemSubtitle(item),
          note: item.ocrUncertain ? 'OCR-सत्यापन लंबित' : null,
          info: _excludedChaptersNote(item),
        ));
      }

      sections.add(ScopeSection(
        id: section.id,
        title: section.title,
        titleEn: section.titleEn,
        stableKey: section.stableKey,
        marks: section.marks,
        units: units,
        pendingNote: pendingNote,
      ));
    }

    return ExamScopeView(
      trackId: syllabus.id.value,
      sections: sections,
      boardMarks: syllabus.boardExamTotalMarks,
    );
  }

  static String? _pendingNoteFor(CourseSyllabus syllabus) {
    final p = syllabus.pending;
    if (p == null) return null;
    return 'आधिकारिक अध्याय सूची जारी होने बाकी है — ${p.reason}';
  }

  /// Hindi A/B literature: the official exclusion list rides on the
  /// book-section items — surfaced as an info line (not selectable, not
  /// a warning): "छोड़े गए पाठ: ...".
  static String? _excludedChaptersNote(SyllabusItem item) {
    final details = item.details;
    if (details == null) return null;
    final excluded = details['excludedChapters'];
    if (excluded is! List || excluded.isEmpty) return null;
    final names = excluded.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final author = m['author'] as String?;
      final chapter = m['chapter'] as String? ?? '';
      return author == null || author.isEmpty
          ? chapter
          : '$author — $chapter';
    }).join('; ');
    return 'छोड़े गए पाठ (इनसे प्रश्न नहीं): $names';
  }

  static String _itemSubtitle(SyllabusItem item) {
    final marks = item.marks == null ? '' : '${_fmt(item.marks!)} अंक';
    final pattern = item.questionPatterns.isEmpty
        ? null
        : item.questionPatterns.first.pattern;
    if (pattern != null && marks.isNotEmpty) return '$marks · $pattern';
    if (pattern != null) return pattern;
    return marks;
  }

  static String _fmt(double m) =>
      m == m.roundToDouble() ? m.toInt().toString() : m.toString();

  final String trackId;
  final List<ScopeSection> sections;
  final double boardMarks;

  /// All selectable unit ids (course-safe by construction).
  Set<String> get selectableUnitIds =>
      sections.expand((s) => s.selectableUnits).map((u) => u.id).toSet();

  ScopeUnit? unitById(String id) {
    for (final s in sections) {
      for (final u in s.units) {
        if (u.id == id) return u;
      }
    }
    return null;
  }

  bool get hasPendingSections => sections.any((s) => s.isPending);

  /// True when every selectable unit carries item-level marks, i.e. a
  /// covered-marks TOTAL is exact. Sanskrit literature chapters share one
  /// section-level marks pool (the PDF allocates 30 marks to the whole
  /// section), so those tracks must NOT show a misleading marks total —
  /// their marks stay per-section. Pending tracks (Class 9 literature
  /// awaiting the official chapter list) likewise show section engagement:
  /// their 80-mark total is unreachable until chapters are published.
  bool get marksCoverageExact =>
      !hasPendingSections &&
      sections.every((s) =>
          s.selectableUnits.isEmpty ||
          s.selectableUnits.every((u) => u.marks != null));

  /// Sections with at least one selected unit (engagement count).
  int engagedSections(ExamScopeSelection selection) => sections
      .where((s) => s.selectableUnits
          .any((u) => selection.isSelected(u.id)))
      .length;

  @override
  List<Object?> get props => [trackId, sections];
}

/// The persisted student selection for one track.
class ExamScopeSelection extends Equatable {
  const ExamScopeSelection({
    required this.trackId,
    required this.selectedUnitIds,
    required this.revision,
    required this.updatedAtIso,
  });

  /// Empty selection for a track.
  factory ExamScopeSelection.empty(String trackId) => ExamScopeSelection(
        trackId: trackId,
        selectedUnitIds: const <String>{},
        revision: 0,
        updatedAtIso: '',
      );

  factory ExamScopeSelection.fromJson(Map<String, dynamic> json) =>
      ExamScopeSelection(
        trackId: json['trackId'] as String,
        selectedUnitIds: (json['selectedUnitIds'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toSet(),
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        updatedAtIso: json['updatedAtIso'] as String? ?? '',
      );

  final String trackId;

  /// Selected unit ids — all namespaced by [trackId] (course isolation).
  final Set<String> selectedUnitIds;

  /// Increments on every change — the scope-changed trigger for future
  /// replanning (master plan §33).
  final int revision;

  final String updatedAtIso;

  bool get isEmpty => selectedUnitIds.isEmpty;

  bool isSelected(String unitId) => selectedUnitIds.contains(unitId);

  int selectedCount(Iterable<String> eligible) =>
      eligible.where(selectedUnitIds.contains).length;

  /// Selects or deselects one unit. Returns `null` when [unitId] does not
  /// belong to this track (course isolation — reject, never absorb).
  ExamScopeSelection? toggle(String unitId) {
    if (!_belongsToTrack(unitId)) return null;
    final next = {...selectedUnitIds};
    if (!next.remove(unitId)) next.add(unitId);
    return _copy(next);
  }

  /// SELECT ALL — every eligible (published, board) unit id.
  ExamScopeSelection selectAll(Iterable<String> eligibleUnitIds) {
    final next = <String>{...selectedUnitIds};
    for (final id in eligibleUnitIds) {
      if (_belongsToTrack(id)) next.add(id);
    }
    return _copy(next);
  }

  /// CLEAR ALL.
  ExamScopeSelection clearAll() => _copy(<String>{});

  /// Selects/deselects an entire section's selectable units. Deselects
  /// when every selectable unit is already selected; selects otherwise.
  /// Foreign ids in [unitIds] are ignored (isolation).
  ExamScopeSelection toggleSection(Iterable<String> unitIds) {
    final eligible = unitIds.where(_belongsToTrack).toSet();
    if (eligible.isEmpty) return this;
    final allSelected = eligible.every(selectedUnitIds.contains);
    final next = <String>{...selectedUnitIds};
    if (allSelected) {
      next.removeAll(eligible);
    } else {
      next.addAll(eligible);
    }
    return _copy(next);
  }

  /// Data-integrity pass on load: drops stored ids that no longer exist in
  /// the current syllabus view (e.g. after a syllabus version update).
  /// Returns the same instance when nothing changes.
  ExamScopeSelection pruneTo(ExamScopeView view) {
    final valid = view.selectableUnitIds;
    final kept = selectedUnitIds.where(valid.contains).toSet();
    if (kept.length == selectedUnitIds.length) return this;
    return ExamScopeSelection(
      trackId: trackId,
      selectedUnitIds: kept,
      revision: revision,
      updatedAtIso: updatedAtIso,
    );
  }

  /// Marks coverage: sum of marks of selected eligible units over the
  /// board total. Units without marks (chapters) count 0.
  double coveredMarks(ExamScopeView view) {
    double sum = 0;
    for (final id in selectedUnitIds) {
      final unit = view.unitById(id);
      if (unit != null && unit.selectable) sum += unit.marks ?? 0;
    }
    return sum;
  }

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'selectedUnitIds': selectedUnitIds.toList()..sort(),
        'revision': revision,
        'updatedAtIso': updatedAtIso,
      };

  bool _belongsToTrack(String unitId) {
    if (!unitId.startsWith('${trackId}_')) return false;
    // Prefix equality is NOT enough: cbse_10_sanskrit is a prefix of
    // cbse_10_sanskrit_communicative. The canonical id schema is
    // `<track>_<sectionStableKey>_<key>` (items) or `<track>_ch_…`
    // (chapters), so the first segment after the track must be a known
    // section key — a foreign course segment (e.g. `communicative_…`)
    // fails this check and is rejected.
    final remainder = unitId.substring(trackId.length + 1);
    final firstSegment = remainder.split('_').first;
    return SyllabusSchema.knownSectionStableKeys.contains(firstSegment) ||
        firstSegment == 'ch';
  }

  ExamScopeSelection _copy(Set<String> next) => ExamScopeSelection(
        trackId: trackId,
        selectedUnitIds: next,
        revision: revision + 1,
        updatedAtIso: DateTime.now().toIso8601String(),
      );

  @override
  List<Object?> get props => [trackId, selectedUnitIds, revision];
}
