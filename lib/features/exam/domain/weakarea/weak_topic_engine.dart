/// Exam Mode 2.0 — Weak-Topic Engine (M8 §21; M9 PYQ/mock feed)
///
/// The dedicated weak-area system. Tracks the §21 evidence list:
///   repeated wrong answers / low mastery / repeated misconception /
///   poor answer quality / forgotten concepts / slow performance
///   where relevant / weak PYQ performance / weak mock sections.
///
/// Hard rules encoded:
///  * §21 "Do not simply count wrong answers. Identify PATTERNS." —
///    findings are built FROM [ErrorPattern]s + mastery STAGES +
///    forgetting bands, never from a raw wrong-count;
///  * §30: severity is qualitative, evidence sentences never contain
///    percentages;
///  * honesty about missing evidence: the PYQ/mock signals (M9) are
///    DATA-GATED — they are emitted ONLY when real PYQ/mock
///    performance exists ([pyqPerformance]/[weakMockSections] with
///    evidence). With no data the report is identical to M8 (the
///    M8 mirror's no-data contract still holds);
///  * findings are capped (top [maxFindings]) — no overwhelming
///    dashboards (§48).
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart'
    show MockSectionResult;
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart'
    show PyqTopicPerformance;
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';

/// The §21 signal vocabulary.
enum WeakSignal {
  repeatedWrong,
  lowMastery,
  repeatedMisconception,
  poorAnswerQuality,
  forgottenConcept,
  slowPerformance,
  weakPyq,
  weakMock,
}

WeakSignal? weakSignalFromName(String? name) => switch (name) {
      'repeatedWrong' => WeakSignal.repeatedWrong,
      'lowMastery' => WeakSignal.lowMastery,
      'repeatedMisconception' => WeakSignal.repeatedMisconception,
      'poorAnswerQuality' => WeakSignal.poorAnswerQuality,
      'forgottenConcept' => WeakSignal.forgottenConcept,
      'slowPerformance' => WeakSignal.slowPerformance,
      'weakPyq' => WeakSignal.weakPyq,
      'weakMock' => WeakSignal.weakMock,
      _ => null,
    };

/// Signals that require PYQ/mock data (M9) — emitted only with real
/// performance evidence, never fabricated (§21/§30).
const Set<WeakSignal> pyqMockSignals = {
  WeakSignal.weakPyq,
  WeakSignal.weakMock,
};

/// Student-facing severity (qualitative — §29/§30 vocabulary).
enum WeakSeverity { watch, focus, needsAttention }

WeakSeverity weakSeverityFromName(String? name) => switch (name) {
      'focus' => WeakSeverity.focus,
      'needsAttention' => WeakSeverity.needsAttention,
      _ => WeakSeverity.watch,
    };

/// One weak topic + the evidence behind it (§21).
class WeakTopicFinding extends Equatable {
  const WeakTopicFinding({
    required this.topicId,
    required this.severity,
    required this.signals,
    required this.patternCategories,
    required this.evidenceSentence,
  });

  final String topicId;
  final WeakSeverity severity;
  final Set<WeakSignal> signals;
  final Set<ErrorCategory> patternCategories;

  /// §30-clean Hindi sentence: names the PATTERN, never a percentage,
  /// never shaming (§28).
  final String evidenceSentence;

  @override
  List<Object?> get props => [topicId, severity, signals, patternCategories];
}

/// The ranked weak-area report for one track.
class WeakAreaReport extends Equatable {
  const WeakAreaReport({
    required this.findings,
    required this.insufficientEvidence,
    required this.evidenceNote,
  });

  final List<WeakTopicFinding> findings;

  /// Honest when there is not yet enough performance evidence (§21
  /// patterns need repetition) — the app says so instead of guessing.
  final bool insufficientEvidence;
  final String evidenceNote;

  bool get hasFindings => findings.isNotEmpty;

  bool get hasAttentionFinding =>
      findings.any((f) => f.severity == WeakSeverity.needsAttention);

  List<WeakTopicFinding> get attentionFirst => [...findings]..sort((a, b) {
      final r = b.severity.index.compareTo(a.severity.index);
      if (r != 0) return r; // needsAttention > focus > watch
      return b.signals.length.compareTo(a.signals.length);
    });

  @override
  List<Object?> get props => [findings, insufficientEvidence];
}

/// Deterministic weak-topic engine (§21).
class WeakAreaEngine {
  const WeakAreaEngine._();

  /// §48: never overwhelm — at most 5 findings surfaced.
  static const int maxFindings = 5;

  /// Repeated-wrong accuracy floor (evidence-based, from mastery
  /// counts — the pattern layer, not the raw count, drives findings).
  static const double repeatedWrongAccuracy = 0.4;

  static WeakAreaReport build({
    required ExamLearnerProfile learner,
    required List<ErrorPattern> patterns,
    required List<RevisionItem> revisionItems,
    Map<String, PyqTopicPerformance> pyqPerformance = const {},
    List<MockSectionResult> weakMockSections = const [],
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final patternByTopic = <String, List<ErrorPattern>>{};
    for (final p in patterns) {
      patternByTopic.putIfAbsent(p.topicId, () => []).add(p);
    }
    final overdueByTopic = <String, RevisionItem>{};
    for (final item in revisionItems) {
      if (item.bandOf(t) == RevisionRiskBand.overdue) {
        overdueByTopic[item.topicId] = item;
      }
    }

    final candidates = <String, WeakTopicFinding>{};

    void upsert(
      String topicId,
      Set<WeakSignal> addSignals,
      Set<ErrorCategory> addCategories,
      String sentence,
    ) {
      final existing = candidates[topicId];
      final signals = <WeakSignal>{
        ...?existing?.signals,
        ...addSignals,
      };
      final categories = <ErrorCategory>{
        ...?existing?.patternCategories,
        ...addCategories,
      };
      // Severity ladder (§29/§30 vocabulary):
      //   needsAttention = stage or misconception;
      //   focus = 2+ signals;
      //   watch = single signal.
      final severity = (signals
                  .map((s) =>
                      s == WeakSignal.repeatedMisconception ||
                      s == WeakSignal.lowMastery)
                  .any((b) => b) ||
              learner.topics[topicId]?.stage == TopicStage.needsAttention)
          ? WeakSeverity.needsAttention
          : (signals.length >= 2 ? WeakSeverity.focus : WeakSeverity.watch);
      candidates[topicId] = WeakTopicFinding(
        topicId: topicId,
        severity: severity,
        signals: signals,
        patternCategories: categories,
        evidenceSentence: sentence,
      );
    }

    // --- Evidence source 1: mastery stages + accuracy (§21 low
    //     mastery, repeated wrong). Pattern-grade: needs ≥ 2 attempts
    //     (stage itself needs 2, so single mistakes never land here).
    for (final mastery in learner.topics.values) {
      if (!mastery.hasEvidence) continue;
      final accuracy = mastery.attemptCount == 0
          ? 0.0
          : mastery.correctCount / mastery.attemptCount;

      if (mastery.stage == TopicStage.needsAttention) {
        upsert(
          mastery.topicId,
          {WeakSignal.lowMastery},
          const {},
          'इस विषय में लगातार कठिनाई दिख रही है — इसे पहले ठीक करेंगे।',
        );
      } else if (mastery.stage == TopicStage.needsReview) {
        // Was strong, decayed → forgotten concept (§21).
        upsert(
          mastery.topicId,
          {WeakSignal.forgottenConcept},
          const {},
          'पहले यह अच्छा आता था, अब धुंधला हो रहा है — हल्का दोहराव काफ़ी है।',
        );
      } else if (mastery.attemptCount >= 3 &&
          accuracy < repeatedWrongAccuracy) {
        upsert(
          mastery.topicId,
          {WeakSignal.repeatedWrong},
          const {},
          'यहाँ गलतियाँ दोहराई जा रही हैं — चुनिंदा अभ्यास से सुधर आएगा।',
        );
      }
    }

    // --- Evidence source 2: error PATTERNS (§21/§47 — the pattern
    //     layer, never a raw wrong count).
    patternByTopic.forEach((topicId, topicPatterns) {
      for (final p in topicPatterns) {
        switch (p.category) {
          case ErrorCategory.misconception:
            upsert(
              topicId,
              {WeakSignal.repeatedMisconception},
              {p.category},
              p.evidenceSentence,
            );
          case ErrorCategory.structureError:
          case ErrorCategory.incompleteAnswer:
            upsert(
              topicId,
              {WeakSignal.poorAnswerQuality},
              {p.category},
              p.evidenceSentence,
            );
          case ErrorCategory.conceptGap:
          case ErrorCategory.applicationGap:
          case ErrorCategory.recallGap:
          case ErrorCategory.questionInterpretation:
          case ErrorCategory.carelessMistake:
            upsert(
              topicId,
              {WeakSignal.repeatedWrong},
              {p.category},
              p.evidenceSentence,
            );
          case ErrorCategory.grammarError:
          case ErrorCategory.timeIssue:
            // Unfabricatable — no data, no signal (§21 honesty).
            break;
        }
      }
    });

    // --- Evidence source 3: forgetting risk (§23 overdue items).
    overdueByTopic.forEach((topicId, item) {
      upsert(
        topicId,
        {WeakSignal.forgottenConcept},
        const {},
        'इस विषय का दोहराव समय पर नहीं हुआ — भूलने का ख़तरा है।',
      );
    });

    // --- Evidence source 4 (M9, §21 weak PYQ performance): topics
    //     with real PYQ evidence in the weak band. DATA-GATED — with
    //     no pyqPerformance this source emits nothing (M8 parity).
    for (final pyq in pyqPerformance.values) {
      if (!pyq.hasEvidence) continue;
      if (pyq.band != 'needsAttention') continue;
      upsert(
        pyq.topicId,
        {WeakSignal.weakPyq},
        const {},
        'PYQ-अभ्यास में यह विषय बार-बार कमज़ोर रहा — परीक्षा-पैटर्न पर '
        'थोड़ा और काम करेंगे।',
      );
    }

    // --- Evidence source 5 (M9, §21 weak mock sections): sections
    //     that finished weak in a real mock (deterministic results
    //     only, §41). Findings are keyed by sectionId.
    for (final section in weakMockSections) {
      if (!section.hasEvidence || section.band != 'needsAttention') {
        continue;
      }
      upsert(
        section.sectionId,
        {WeakSignal.weakMock},
        const {},
        'mock में «${section.title}» खंड कमज़ोर रहा — इस खंड पर एक दिन '
        'केंद्रित अभ्यास देंगे।',
      );
    }

    // --- Ranking (deterministic): severity desc, then signal count
    //     desc, then strength asc (weakest first), then topicId.
    final ranked = candidates.values.toList()
      ..sort((a, b) {
        final r = b.severity.index.compareTo(a.severity.index);
        if (r != 0) return r;
        final s = b.signals.length.compareTo(a.signals.length);
        if (s != 0) return s;
        final sa = learner.topics[a.topicId]?.strength ?? 1.0;
        final sb = learner.topics[b.topicId]?.strength ?? 1.0;
        final st = sa.compareTo(sb);
        if (st != 0) return st;
        return a.topicId.compareTo(b.topicId);
      });
    final findings = ranked.take(maxFindings).toList();

    // --- Honesty: insufficient evidence (never guess, §21).
    final hasAnyEvidence = findings.isNotEmpty ||
        learner.topics.values.any((t) => t.attemptCount >= 2);
    final insufficient = findings.isEmpty && !hasAnyEvidence;
    final note = findings.isNotEmpty
        ? 'ये निष्कर्ष आपके असली अभ्यास से निकले हैं — अंदाज़ा नहीं।'
        : (insufficient
            ? 'अभी इतना अभ्यास नहीं हुआ कि कमज़ोरी बता सकें — कुछ दिन '
                'अभ्यास के बाद यहीं दिखेगा।'
            : 'फ़िलहाल कोई खास कमज़ोरी नहीं दिख रही — बढ़िया चल रहा है!');
    return WeakAreaReport(
      findings: findings,
      insufficientEvidence: insufficient,
      evidenceNote: note,
    );
  }

  /// The §21 PYQ/mock signals are produced ONLY when PYQ/mock
  /// performance evidence exists (M9 data). A report built without
  /// that data never contains them — the M8 honesty contract.
  static bool reportIsM8Honest(WeakAreaReport report) =>
      report.findings.every((f) => f.signals.none(pyqMockSignals.contains));
}

extension _NoneX<T> on Iterable<T> {
  bool none(bool Function(T) test) => every((e) => !test(e));
}
