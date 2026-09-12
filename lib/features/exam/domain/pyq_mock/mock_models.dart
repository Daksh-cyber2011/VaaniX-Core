/// Exam Mode 2.0 — Mock Domain Models (M9, §25/§30/§41)
///
/// The mock ladder (master plan "mock progression"): mini → section →
/// full. Every paper is assembled from OFFICIAL structure data —
/// section marks and the board-exam total/duration come verbatim from
/// the canonical syllabus (§60); question content is grounded in the
/// official syllabus strings and runs on the M6 loop engine (MCQ +
/// typed, §24).
///
/// §41: mock RESULTS are critical state — scoring is deterministic
/// app logic (the M6/M7 evaluators), never AI. AI may only RECOMMEND.
///
/// §30: results and analysis are qualitative (bands, never
/// percentages); per-section weakness is tracked (§21 weak mock
/// sections) and feeds the weak-area engine + planner.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';

/// The mock ladder kinds.
enum MockKind { mini, section, full }

MockKind? mockKindFromName(String? name) => switch (name) {
      'mini' => MockKind.mini,
      'section' => MockKind.section,
      'full' => MockKind.full,
      _ => null,
    };

extension MockKindX on MockKind {
  String get label => switch (this) {
        MockKind.mini => 'मिनी mock (छोटा, 15 मिनट)',
        MockKind.section => 'खंड mock (एक पूरा खंड)',
        MockKind.full => 'पूरा mock (पूरा पेपर)',
      };

  String get description => switch (this) {
        MockKind.mini => 'एक खंड से कुछ प्रश्न — हल्की शुरुआत।',
        MockKind.section => 'एक पूरे खंड का अंक-भार — धीरे-धीरे बढ़ें।',
        MockKind.full => 'पूरा बोर्ड-पैटर्न — असली परीक्षा जैसा अभ्यास।',
      };
}

/// One section's slice inside a mock paper.
class MockSectionSlice extends Equatable {
  const MockSectionSlice({
    required this.sectionId,
    required this.title,
    required this.targetMarks,
    required this.questions,
  });

  final String sectionId;
  final String title;

  /// The OFFICIAL section marks this slice targets (from syllabus).
  final double targetMarks;
  final List<PracticeQuestion> questions;

  int get questionCount => questions.length;

  @override
  List<Object?> get props => [sectionId, questions];
}

/// A complete mock paper, ready to run on the M6 loop engine.
class MockPaper extends Equatable {
  const MockPaper({
    required this.id,
    required this.kind,
    required this.trackId,
    required this.sections,
    required this.totalMarks,
    required this.timeLimitMinutes,
    required this.createdAtIso,
  });

  final String id;
  final MockKind kind;
  final String trackId;
  final List<MockSectionSlice> sections;

  /// Official total marks (full = board total; section = the section's
  /// marks; mini = capped slice).
  final double totalMarks;

  /// Official duration scaled (full = board duration; others
  /// marks-proportional, ~2.25 min/mark, 15-min floor for mini).
  final int timeLimitMinutes;
  final String createdAtIso;

  List<PracticeQuestion> get allQuestions => [
        for (final s in sections) ...s.questions,
      ];

  int get questionCount => allQuestions.length;

  String get focusSectionTitle =>
      sections.isEmpty ? '' : sections.first.title;

  @override
  List<Object?> get props => [id, kind, sections];
}

/// One section's outcome inside a finished mock (§30 qualitative).
class MockSectionResult extends Equatable {
  const MockSectionResult({
    required this.sectionId,
    required this.title,
    required this.attempted,
    required this.correct,
  });

  final String sectionId;
  final String title;
  final int attempted;
  final int correct;

  bool get hasEvidence => attempted >= 2;

  /// §29-style band: strong / learning / needsAttention.
  String get band {
    if (!hasEvidence) return 'learning';
    final accuracy = correct / attempted;
    if (accuracy < 0.4) return 'needsAttention';
    if (accuracy >= 0.6) return 'strong';
    return 'learning';
  }

  /// §30-clean Hindi sentence (never a percentage).
  String get bandLabel => switch (band) {
        'needsAttention' => 'इस खंड पर अभी काम करना होगा।',
        'strong' => 'यह खंड ठीक चल रहा है।',
        _ => 'यह खंड बनता जा रहा है — थोड़ा और अभ्यास।',
      };

  factory MockSectionResult.fromJson(Map<String, dynamic> json) =>
      MockSectionResult(
        sectionId: json['sectionId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        attempted: (json['attempted'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'sectionId': sectionId,
        'title': title,
        'attempted': attempted,
        'correct': correct,
      };

  @override
  List<Object?> get props => [sectionId, attempted, correct];
}

/// The finished mock's outcome (§41 critical state — deterministic).
class MockResult extends Equatable {
  const MockResult({
    required this.paperId,
    required this.kind,
    required this.trackId,
    required this.sectionResults,
    required this.totalAttempted,
    required this.totalCorrect,
    required this.completedAtIso,
  });

  final String paperId;
  final MockKind kind;
  final String trackId;
  final List<MockSectionResult> sectionResults;
  final int totalAttempted;
  final int totalCorrect;
  final String completedAtIso;

  /// Overall §29-style qualitative band (never a percentage, §30).
  String get overallBand {
    if (totalAttempted < 2) return 'learning';
    final accuracy = totalCorrect / totalAttempted;
    if (accuracy < 0.4) return 'needsAttention';
    if (accuracy >= 0.6) return 'strong';
    return 'learning';
  }

  /// §21 "weak mock sections" — sections with a weak band AND
  /// evidence. Empty when the mock was too small to judge honestly.
  List<MockSectionResult> get weakSections => sectionResults
      .where((s) => s.hasEvidence && s.band == 'needsAttention')
      .toList();

  bool get hasWeakSection => weakSections.isNotEmpty;

  /// §28-style closing summary (constructive, no percentages).
  String get summary {
    if (totalAttempted == 0) {
      return 'इस बार कोई प्रश्न हल नहीं हुआ — अगली बार शांति से शुरू करें।';
    }
    if (!hasWeakSection) {
      return 'Mock पूरा हुआ — कोई खंड खास कमज़ोर नहीं दिखा। इसी गति से चलें।';
    }
    final titles = weakSections.map((s) => s.title).join(', ');
    return 'Mock पूरा हुआ — $titles पर अगले दिन थोड़ा काम करेंगे। '
        'बाक़ी ठीक चल रहा है।';
  }

  factory MockResult.fromJson(Map<String, dynamic> json) => MockResult(
        paperId: json['paperId'] as String? ?? '',
        kind: mockKindFromName(json['kind'] as String?) ?? MockKind.mini,
        trackId: json['trackId'] as String? ?? '',
        sectionResults: (json['sectionResults'] as List<dynamic>? ?? [])
            .map((e) => MockSectionResult.fromJson(
                (e as Map<String, dynamic>).cast<String, dynamic>()))
            .toList(),
        totalAttempted: (json['totalAttempted'] as num?)?.toInt() ?? 0,
        totalCorrect: (json['totalCorrect'] as num?)?.toInt() ?? 0,
        completedAtIso: json['completedAtIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'paperId': paperId,
        'kind': kind.name,
        'trackId': trackId,
        'sectionResults': [
          for (final s in sectionResults) s.toJson(),
        ],
        'totalAttempted': totalAttempted,
        'totalCorrect': totalCorrect,
        'completedAtIso': completedAtIso,
      };

  @override
  List<Object?> get props => [paperId, kind, sectionResults, completedAtIso];
}
