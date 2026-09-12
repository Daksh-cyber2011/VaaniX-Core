/// Exam Mode 2.0 — PYQ Domain Models (M9, master plan §25)
///
/// §25 separates OFFICIAL PYQs from AI/APP-GENERATED PYQ-STYLE
/// questions — "Never label AI-generated content as an actual CBSE
/// PYQ." VaaniX's canonical data contains the official syllabus and
/// each item's official QUESTION PATTERNS (e.g. अतिलघूत्तरात्मकौ 2×1)
/// but NOT the text of past exam papers. The design is therefore:
///
///  * [PyqProvenance.examPattern] — the question's structure (pattern
///    label, marks, count) comes VERBATIM from the official CBSE
///    syllabus: honest official STRUCTURE, honest label
///    "आधिकारिक पैटर्न" (exam pattern).
///  * [PyqProvenance.pyqStyle] — the question TEXT is generated from
///    official syllabus strings (§60 grounding), honestly labeled
///    "PYQ-शैली" — NEVER "actual CBSE PYQ" (§25).
///  * [PyqProvenance.official] — a REAL past-paper question, loadable
///    only through the official registry (year/source/marks preserved
///    per §25). The shipped registry is EMPTY — no official paper
///    text is fabricated (§60). The field exists so ingestion is a
///    data drop, not a code change.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';

/// §25 provenance — the honesty label every PYQ question carries.
enum PyqProvenance { official, examPattern, pyqStyle }

PyqProvenance? pyqProvenanceFromName(String? name) => switch (name) {
      'official' => PyqProvenance.official,
      'examPattern' => PyqProvenance.examPattern,
      _ => PyqProvenance.pyqStyle,
    };

extension PyqProvenanceX on PyqProvenance {
  /// Student-facing honesty label (§25/§30 — no fake provenance).
  String get label => switch (this) {
        PyqProvenance.official => 'आधिकारिक CBSE प्रश्न (PYQ)',
        PyqProvenance.examPattern => 'आधिकारिक परीक्षा-पैटर्न पर आधारित',
        PyqProvenance.pyqStyle => 'PYQ-शैली (अभ्यास)',
      };

  /// True only for real past-paper questions (registry-loaded).
  bool get isOfficial => this == PyqProvenance.official;
}

/// One PYQ-track question: the practice question + its official
/// pattern identity (marks, pattern text) + provenance.
class PyqQuestion extends Equatable {
  const PyqQuestion({
    required this.question,
    required this.provenance,
    required this.patternText,
    required this.marks,
    this.officialYear,
    this.sourceNote,
  });

  /// The underlying M6-loop question (MCQ or typed, §24).
  final PracticeQuestion question;

  final PyqProvenance provenance;

  /// The official pattern string verbatim from the syllabus (§60),
  /// e.g. 'अतिलघूत्तरात्मकौ 2×1'. Empty for registry-official items
  /// whose pattern was not recorded.
  final String patternText;

  /// Marks this question carries (from the official pattern's
  /// marksEach; default 1).
  final double marks;

  /// §25 official fields — only meaningful for
  /// [PyqProvenance.official] (registry items). Never fabricated.
  final String? officialYear;
  final String? sourceNote;

  String get id => question.id;
  String get topicId => question.topicId;

  /// Honest one-line identity shown in the UI (§25).
  String get identityLine {
    final marksLabel = marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toString();
    final base = '$patternText • $marksLabel अंक';
    return switch (provenance) {
      PyqProvenance.official =>
        '$base • ${officialYear ?? ''} ${sourceNote ?? ''}'.trim(),
      _ => base,
    };
  }

  @override
  List<Object?> get props => [question, provenance, marks];
}

/// §25 filtering: PYQ lists are filterable by section, marks and
/// pattern kind. All filters are optional (empty = everything).
class PyqFilter extends Equatable {
  const PyqFilter({
    this.sectionIds = const {},
    this.topicIds = const {},
    this.minMarks = 0,
    this.maxMarks = 0,
    this.patternKinds = const {},
    this.limit = 0,
  });

  final Set<String> sectionIds;
  final Set<String> topicIds;
  final double minMarks;
  final double maxMarks;

  /// Pattern-kind keywords, matched against the official pattern
  /// text (e.g. mcq / बहुविकल्पीय, अतिलघूत्तरात्मक, पूर्णवाक्यात्मक).
  final Set<String> patternKinds;

  /// 0 = no limit.
  final int limit;

  bool get isEmpty =>
      sectionIds.isEmpty &&
      topicIds.isEmpty &&
      minMarks == 0 &&
      maxMarks == 0 &&
      patternKinds.isEmpty &&
      limit == 0;

  /// Applies every non-empty criterion (AND semantics).
  bool matches(PyqQuestion q, String sectionId) {
    if (sectionIds.isNotEmpty && !sectionIds.contains(sectionId)) {
      return false;
    }
    if (topicIds.isNotEmpty && !topicIds.contains(q.topicId)) return false;
    if (minMarks > 0 && q.marks < minMarks) return false;
    if (maxMarks > 0 && q.marks > maxMarks) return false;
    if (patternKinds.isNotEmpty) {
      final text = q.patternText.toLowerCase();
      final hit = patternKinds.any((k) => text.contains(k.toLowerCase()));
      if (!hit) return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [sectionIds, topicIds, minMarks, maxMarks,
      patternKinds, limit];
}

/// Per-topic PYQ performance snapshot (§21 pyqPerformance evidence).
class PyqTopicPerformance extends Equatable {
  const PyqTopicPerformance({
    required this.topicId,
    required this.attempted,
    required this.correct,
  });

  final String topicId;
  final int attempted;
  final int correct;

  bool get hasEvidence => attempted >= 2;

  /// §29-style qualitative band (never a percentage, §30).
  String get band {
    if (!hasEvidence) return 'learning';
    final accuracy = correct / attempted;
    if (accuracy < 0.4) return 'needsAttention';
    if (accuracy >= 0.6) return 'strong';
    return 'learning';
  }

  factory PyqTopicPerformance.fromJson(Map<String, dynamic> json) =>
      PyqTopicPerformance(
        topicId: json['topicId'] as String? ?? '',
        attempted: (json['attempted'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'topicId': topicId, 'attempted': attempted, 'correct': correct};

  PyqTopicPerformance merge(PyqTopicPerformance other) =>
      PyqTopicPerformance(
        topicId: topicId,
        attempted: attempted + other.attempted,
        correct: correct + other.correct,
      );

  @override
  List<Object?> get props => [topicId, attempted, correct];
}
