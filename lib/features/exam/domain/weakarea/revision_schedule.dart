/// Exam Mode 2.0 — Forgetting-aware Revision Schedule (M8, §23)
///
/// Evidence-based spaced repetition — the master plan explicitly
/// forbids "Revise every Sunday" style blanket rules:
///
///   "Use evidence. Track: last mastered, last practiced, performance,
///    difficulty, forgetting risk, recent mistakes, confidence
///    demonstrated through performance. Schedule review appropriately."
///
/// Design:
///  * an expanding interval ladder [1, 2, 4, 7, 15, 30] days per topic;
///  * the ladder position (stability) is EARNED by demonstrated
///    retention (successful recheck/review ⇒ expand, failure ⇒
///    contract sharply — relearning, §23);
///  * strong/mastered topics start higher on the ladder (their
///    diagnostic/practice history IS retention evidence);
///  * previously-wrong topics re-enter as RELEARNING items at the
///    bottom of the ladder (due tomorrow);
///  * risk bands are qualitative (fresh / due / overdue) — internal
///    due-dates exist for scheduling, students never see a "retention
///    62%" number (§30).
///
/// Review sessions built from this schedule mix recall + application +
/// mixed practice + previously-wrong questions (§23), and are NEVER
/// identical to the original lesson (§23) — see [RevisionEngine.reviewMix].
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';

/// The expanding interval ladder, in days (§23 spaced repetition).
const List<int> kRevisionIntervalDays = [1, 2, 4, 7, 15, 30];

/// Qualitative forgetting-risk band (§30 — never a percentage).
enum RevisionRiskBand { fresh, due, overdue }

RevisionRiskBand revisionRiskBandFromName(String? name) => switch (name) {
      'due' => RevisionRiskBand.due,
      'overdue' => RevisionRiskBand.overdue,
      _ => RevisionRiskBand.fresh,
    };

/// One topic's revision state (persisted, §12).
class RevisionItem extends Equatable {
  const RevisionItem({
    required this.topicId,
    required this.intervalIndex,
    required this.lastReviewedIso,
    required this.dueIso,
  });

  final String topicId;

  /// Position on [kRevisionIntervalDays] (0 = relearning, max =
  /// monthly review).
  final int intervalIndex;

  /// When the topic was last successfully reviewed/mastered.
  final String lastReviewedIso;

  final String dueIso;

  int get intervalDays => kRevisionIntervalDays[
      intervalIndex.clamp(0, kRevisionIntervalDays.length - 1)];

  /// Qualitative band vs [now] (§30).
  RevisionRiskBand bandOf(DateTime now) {
    final due = DateTime.tryParse(dueIso);
    if (due == null) return RevisionRiskBand.due;
    final deltaDays = now.difference(due).inDays;
    if (deltaDays >= 1) return RevisionRiskBand.overdue;
    if (now.isAfter(due) || now == due) return RevisionRiskBand.due;
    return RevisionRiskBand.fresh;
  }

  /// Student-facing, §30-clean label.
  String get bandLabel => switch (bandOf(DateTime.now())) {
        RevisionRiskBand.fresh => 'ताज़ा — अभी दोहराने की ज़रूरत नहीं',
        RevisionRiskBand.due => 'दोहराव का समय आ गया है',
        RevisionRiskBand.overdue => 'देर हो रही है — भूलने का ख़तरा',
      };

  RevisionItem copyWith({
    int? intervalIndex,
    String? lastReviewedIso,
    String? dueIso,
  }) =>
      RevisionItem(
        topicId: topicId,
        intervalIndex: intervalIndex ?? this.intervalIndex,
        lastReviewedIso: lastReviewedIso ?? this.lastReviewedIso,
        dueIso: dueIso ?? this.dueIso,
      );

  factory RevisionItem.fromJson(Map<String, dynamic> json) => RevisionItem(
        topicId: json['topicId'] as String? ?? '',
        intervalIndex: (json['intervalIndex'] as num?)?.toInt() ?? 0,
        lastReviewedIso: json['lastReviewedIso'] as String? ?? '',
        dueIso: json['dueIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'intervalIndex': intervalIndex,
        'lastReviewedIso': lastReviewedIso,
        'dueIso': dueIso,
      };

  @override
  List<Object?> get props => [topicId, intervalIndex, dueIso];
}

/// Deterministic forgetting-aware scheduler (§23).
class RevisionEngine {
  const RevisionEngine._();

  /// Recheck passing expands the interval (retention demonstrated —
  /// §23 "confidence demonstrated through performance"); failing
  /// contracts it sharply (relearning), floor = 1 day.
  static const int contractStep = 2;

  static RevisionItem expand(RevisionItem item, DateTime now) {
    final nextIndex =
        (item.intervalIndex + 1).clamp(0, kRevisionIntervalDays.length - 1);
    final days = kRevisionIntervalDays[nextIndex];
    return item.copyWith(
      intervalIndex: nextIndex,
      lastReviewedIso: now.toIso8601String(),
      dueIso: now.add(Duration(days: days)).toIso8601String(),
    );
  }

  static RevisionItem contract(RevisionItem item, DateTime now) {
    final nextIndex = (item.intervalIndex - contractStep)
        .clamp(0, kRevisionIntervalDays.length - 1);
    final days = kRevisionIntervalDays[nextIndex];
    return item.copyWith(
      intervalIndex: nextIndex,
      lastReviewedIso: now.toIso8601String(),
      dueIso: now.add(Duration(days: days)).toIso8601String(),
    );
  }

  /// Builds the schedule from evidence:
  ///  * persisted history wins (kept, bands recomputed);
  ///  * newly-mastered/strong topics enter the ladder by stage
  ///    (mastered higher — their history is retention evidence);
  ///  * topics with active error patterns re-enter as relearning
  ///    items due tomorrow (§23 "previously wrong questions" feed);
  ///  * topics whose stage decayed to needsReview (was strong, now
  ///    not) enter as due-now items — the §21 "forgotten concepts"
  ///    signal source.
  static List<RevisionItem> schedule({
    required ExamLearnerProfile learner,
    required List<ErrorPattern> patterns,
    required Map<String, RevisionItem> history,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final out = <String, RevisionItem>{};

    // 1) Persisted history is authoritative for its topics.
    history.forEach((topicId, item) {
      out[topicId] = item;
    });

    // 2) Error-pattern topics → relearning (due tomorrow), unless
    //    history already holds an even SOONER due item.
    for (final p in patterns) {
      final existing = out[p.topicId];
      final relearning = RevisionItem(
        topicId: p.topicId,
        intervalIndex: 0,
        lastReviewedIso: t.toIso8601String(),
        dueIso: t.add(const Duration(days: 1)).toIso8601String(),
      );
      if (existing == null) {
        out[p.topicId] = relearning;
      } else {
        final existingDue = DateTime.tryParse(existing.dueIso);
        final relearnDue = DateTime.tryParse(relearning.dueIso);
        if (existingDue == null || relearnDue == null) {
          out[p.topicId] = relearning;
        } else if (relearnDue.isBefore(existingDue)) {
          out[p.topicId] = relearning;
        }
      }
    }

    // 3) Mastery evidence seeds fresh items (stage-earned ladder
    //    position) only when no history/pattern entry exists.
    for (final mastery in learner.topics.values) {
      if (!mastery.hasEvidence) continue;
      if (out.containsKey(mastery.topicId)) continue;
      final stage = mastery.stage;
      if (stage != TopicStage.strong && stage != TopicStage.mastered) {
        continue; // learning topics are covered by weak-area work.
      }
      final startIndex = stage == TopicStage.mastered ? 2 : 1;
      final lastPracticed = DateTime.tryParse(mastery.lastPracticedAtIso);
      final anchor = (lastPracticed ?? t).isAfter(t) ? t : (lastPracticed ?? t);
      out[mastery.topicId] = RevisionItem(
        topicId: mastery.topicId,
        intervalIndex: startIndex,
        lastReviewedIso: anchor.toIso8601String(),
        dueIso: anchor
            .add(Duration(days: kRevisionIntervalDays[startIndex]))
            .toIso8601String(),
      );
    }

    // Deterministic order: overdue → due → fresh; then topicId.
    final items = out.values.toList()
      ..sort((a, b) {
        final bandA = a.bandOf(t).index;
        final bandB = b.bandOf(t).index;
        // overdue(2) → due(1) → fresh(0): descending index.
        final r = bandB.compareTo(bandA);
        if (r != 0) return r;
        return a.topicId.compareTo(b.topicId);
      });
    return items;
  }

  /// Topics needing attention this study day (§23 schedule): overdue
  /// first, then due. Fresh topics are excluded — no blanket revision.
  static List<RevisionItem> dueToday(List<RevisionItem> items, DateTime now,
      {int limit = 3}) {
    final due = items
        .where((i) =>
            i.bandOf(now) != RevisionRiskBand.fresh)
        .toList();
    due.sort((a, b) {
      // overdue before due; then earlier dueIso; then topicId.
      final ba = a.bandOf(now).index;
      final bb = b.bandOf(now).index;
      final r = bb.compareTo(ba);
      if (r != 0) return r;
      return a.topicId.compareTo(b.topicId);
    });
    return due.take(limit).toList();
  }

  /// The §23 review MIX: previously-wrong questions first (mistake
  /// re-encounter), then mixed recall + application questions ACROSS
  /// topics — never the original lesson's sequence/order, and never a
  /// single-topic drill (§23 "Do not make revision identical to the
  /// original lesson").
  ///
  /// [questions] is the full grounded pool for the due topics; the mix
  /// interleaves topics deterministically (round-robin by topic).
  static List<PracticeQuestion> reviewMix({
    required List<PracticeQuestion> questions,
    required Set<String> previouslyWrongQuestionIds,
    required Set<String> dueTopicIds,
    int targetSize = 8,
  }) {
    final inScope =
        questions.where((q) => dueTopicIds.contains(q.topicId)).toList();

    // Mistake re-encounters first (only due-topic questions).
    final wrongFirst = inScope
        .where((q) => previouslyWrongQuestionIds.contains(q.id))
        .toList();

    // Round-robin across topics → mixed practice, not a block drill.
    final byTopic = <String, List<PracticeQuestion>>{};
    for (final q in inScope) {
      if (previouslyWrongQuestionIds.contains(q.id)) continue;
      byTopic.putIfAbsent(q.topicId, () => []).add(q);
    }
    final mixed = <PracticeQuestion>[];
    var added = true;
    while (added) {
      added = false;
      for (final topicId in byTopic.keys.toList()..sort()) {
        final list = byTopic[topicId]!;
        if (list.isNotEmpty) {
          mixed.add(list.removeAt(0));
          added = true;
        }
      }
    }

    final seen = <String>{};
    final out = <PracticeQuestion>[];
    for (final q in [...wrongFirst, ...mixed]) {
      if (seen.contains(q.id)) continue;
      seen.add(q.id);
      out.add(q);
      if (out.length >= targetSize) break;
    }
    return out;
  }
}
