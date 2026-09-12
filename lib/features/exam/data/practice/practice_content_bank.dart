/// Exam Mode 2.0 — Practice Content Bank (M6 data layer, §15/§24/§60)
///
/// Deterministic, offline-first practice questions GROUNDED in the
/// canonical syllabus (trusted curated core, §15) for the student's
/// selected scope. Every prompt, option, accepted answer and rubric
/// point comes from official syllabus data — the §60 no-invention
/// rule applies to practice content exactly as it did to the
/// diagnostic bank.
///
/// Question kinds (mixed for the loop, §24):
///  * MCQ — section-membership and sub-topic membership (same
///    grounding as the diagnostic bank, distinct ids/pools).
///  * SHORT ANSWER (typed) — "«subtopic» किस विषय का भाग है?" with
///    the official topic title as accepted answer + its official
///    sub-topics as required points (completeness rubric, §27). Typed
///    answers flow through the M7 rubric evaluator.
///  * MARKS MCQ — exam-pattern awareness (application).
library;

import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart'
    show seedFromText, deterministicShuffle;

class PracticeContentBank {
  const PracticeContentBank._();

  /// Builds the grounded practice set for the current scope.
  /// Mixes MCQs and typed questions; weak topics (from the learner
  /// profile) come FIRST when provided (§22 weak-area priority).
  ///
  /// [topicFilter] (M8): restricts the bank to specific scope units —
  /// the weak-area recovery/revision sessions build their pools this
  /// way. Empty = the whole selection (the M6 behavior, unchanged).
  static List<PracticeQuestion> build({
    required CourseSyllabus syllabus,
    required ExamScopeView view,
    required ExamScopeSelection selection,
    Set<String> weakTopicIds = const {},
    int targetSize = 12,
    Set<String> topicFilter = const {},
  }) {
    final selectedUnits = <ScopeUnit>[];
    // M8: distractors stay GROUNDED in the whole selected scope — a
    // topic-filtered pool (recovery/revision) still builds its tier-3
    // membership MCQs against official sub-topics of OTHER in-scope
    // units, so single-topic pools keep up to 3 questions.
    final scopeUnits = <ScopeUnit>[];
    for (final section in view.sections) {
      for (final unit in section.selectableUnits) {
        if (topicFilter.isNotEmpty && !topicFilter.contains(unit.id)) {
          if (selection.isSelected(unit.id)) scopeUnits.add(unit);
          continue;
        }
        if (selection.isSelected(unit.id)) {
          selectedUnits.add(unit);
          scopeUnits.add(unit);
        }
      }
    }

    final sectionTitles =
        view.sections.map((s) => s.title).toList(growable: false);
    final bookTitles =
        syllabus.books.map((b) => b.title).toList(growable: false);

    final mcqs = <PracticeQuestion>[];
    final typed = <PracticeQuestion>[];

    for (final unit in selectedUnits) {
      final section =
          view.sections.firstWhere((s) => s.id == unit.sectionId);
      final item = syllabus.allItems
          .where((i) => i.id == unit.id)
          .firstOrNull;
      final subtopics = item == null
          ? const <String>[]
          : _subtopicsOf(item).take(6).toList();

      // 1) MCQ: section membership (recall, tier 1).
      {
        final pool = [...sectionTitles, ...bookTitles]
            .where((t) => t != section.title)
            .toList();
        final options = _options(
          correct: section.title,
          pool: pool,
          seed: unit.id + '_psec',
        );
        if (options != null) {
          mcqs.add(PracticeQuestion(
            id: 'prac_${_suffix(unit.id)}_sec',
            topicId: unit.id,
            topicTitle: unit.title,
            kind: PracticeQuestionKind.mcq,
            prompt: '«${unit.title}» किस खंड में आता है?',
            options: options.$1,
            correctIndex: options.$2,
            explanation: '«${unit.title}» ${section.title} खंड का भाग है '
                '(आधिकारिक पाठ्यक्रम अनुसार)।',
            difficultyTier: 1,
          ));
        }
      }

      // 2) TYPED short answer: sub-topic → topic (tier 2). The M7
      //    rubric evaluator grades these; accepted answer = the
      //    official topic title; required points = official
      //    sub-topics (completeness evidence).
      if (subtopics.isNotEmpty) {
        typed.add(PracticeQuestion(
          id: 'prac_${_suffix(unit.id)}_typed',
          topicId: unit.id,
          topicTitle: unit.title,
          kind: PracticeQuestionKind.shortAnswer,
          prompt: '«${subtopics.first}» किस विषय के अंतर्गत आता है? '
              '(नाम लिखें)',
          acceptedAnswers: [unit.title],
          requiredPoints: subtopics.take(3).toList(),
          explanation: '«${subtopics.first}» «${unit.title}» का भाग है।',
          difficultyTier: 2,
        ));
      }

      // 3) MCQ: sub-topic membership (tier 3, application).
      if (subtopics.length >= 2) {
        final correct = subtopics.first;
        final distractorPool = <String>[];
        for (final other in scopeUnits) {
          if (other.id == unit.id) continue;
          final otherItem = syllabus.allItems
              .where((i) => i.id == other.id)
              .firstOrNull;
          if (otherItem == null) continue;
          distractorPool.addAll(_subtopicsOf(otherItem).take(3));
        }
        final options = _options(
          correct: correct,
          pool: distractorPool.where((s) => s != correct).toList(),
          seed: unit.id + '_psub',
        );
        if (options != null) {
          mcqs.add(PracticeQuestion(
            id: 'prac_${_suffix(unit.id)}_sub',
            topicId: unit.id,
            topicTitle: unit.title,
            kind: PracticeQuestionKind.mcq,
            prompt: 'इनमें से कौन-सा «${unit.title}» से संबंधित है?',
            options: options.$1,
            correctIndex: options.$2,
            explanation: '«$correct» «${unit.title}» के अंतर्गत आता है।',
            difficultyTier: 3,
          ));
        }
      }
    }

    // Weak topics first (§22), then tier — applied WITHIN each kind so
    // the final mix keeps both question types (§24) even when the MCQ
    // pool is large: typed questions reserve at least a third of the
    // session when the data supports them.
    int rank(PracticeQuestion a) {
      final aWeak = weakTopicIds.contains(a.topicId) ? 0 : 1;
      return aWeak * 10 + a.difficultyTier;
    }

    typed.sort((a, b) => rank(a).compareTo(rank(b)));
    mcqs.sort((a, b) => rank(a).compareTo(rank(b)));

    // clamp(2, typed.length) is only valid when typed.length >= 2 —
    // a one-typed-question pool (single-topic recovery scope, M8) or
    // a one-typed-unit selection must NOT throw (§41 defensive).
    final typedCount = typed.isEmpty
        ? 0
        : (typed.length == 1
            ? 1
            : (targetSize ~/ 3).clamp(2, typed.length));
    final selected = [
      ...typed.take(typedCount),
      ...mcqs.take(targetSize - typedCount),
    ];
    return selected;
  }

  static List<String> _subtopicsOf(SyllabusItem item) {
    final details = item.details;
    if (details == null) return const [];
    final out = <String>[];
    void addList(List<dynamic> list) {
      for (final v in list) {
        final s = v is String ? v.trim() : '';
        if (s.isNotEmpty && s.length <= 40) out.add(s);
      }
    }

    for (final value in details.values) {
      if (value is List) {
        addList(value);
      } else if (value is Map) {
        value.forEach((_, v) {
          if (v is List) addList(v);
        });
      }
    }
    return out;
  }

  static (List<String>, int)? _options({
    required String correct,
    required List<String> pool,
    required String seed,
  }) {
    final distinct = pool.toSet().toList()..remove(correct);
    if (distinct.length < 3) return null;
    final chosen =
        deterministicShuffle(distinct, seedFromText(seed)).take(3).toList();
    final all = [correct, ...chosen];
    final shuffled =
        deterministicShuffle(all, seedFromText(seed + '_shuffle'));
    return (shuffled, shuffled.indexOf(correct));
  }

  static String _suffix(String unitId) {
    final parts = unitId.split('_');
    return parts.length <= 4
        ? parts.sublist(2).join('_')
        : parts.sublist(4).join('_');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
