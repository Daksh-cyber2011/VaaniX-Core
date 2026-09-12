/// Exam Mode 2.0 — PYQ Bank Builder (M9, §25/§60)
///
/// Builds the PYQ-track question pool for a track, GROUNDED in the
/// canonical syllabus (§60 — no invented strings):
///
///  * every selected item's OFFICIAL question patterns are honored
///    (pattern text, marks, question kind): pattern-derived questions
///    carry [PyqProvenance.examPattern] — official structure, honest
///    label;
///  * supplementary marks-structure MCQs carry
///    [PyqProvenance.pyqStyle] — PYQ-style practice, honestly labeled;
///  * ids are `pyq_`-prefixed so attempt-log evidence from the PYQ
///    track is distinguishable from practice-track evidence;
///  * NOTHING here is ever labeled an actual CBSE PYQ (§25) — only
///    the (currently empty) official registry can produce those.
///
/// Question kinds (§24 — pattern decides, never forced):
///  * बहुविकल्पीय/MCQ patterns → MCQ;
///  * अतिलघूत्तरात्मक (very-short) patterns → MCQ (1-mark recall);
///  * पूर्णवाक्यात्मक/लघूत्तरात्मक/वाक्य/रचनात्मक/निर्माण patterns →
///    TYPED short answer graded by the M7 rubric (§27);
///  * no pattern data on the item → honest skip (nothing invented).
library;

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart'
    show seedFromText, deterministicShuffle;

class PyqBank {
  const PyqBank._();

  /// Builds the PYQ pool for the current scope (optionally filtered).
  static List<PyqQuestion> build({
    required CourseSyllabus syllabus,
    required ExamScopeView view,
    required ExamScopeSelection selection,
    Set<String> weakTopicIds = const {},
    PyqFilter filter = const PyqFilter(),
    int targetSize = 12,
  }) {
    final sectionByUnit = <String, ScopeSection>{};
    for (final section in view.sections) {
      for (final unit in section.selectableUnits) {
        sectionByUnit[unit.id] = section;
      }
    }

    final out = <PyqQuestion>[];
    final sectionTitles =
        view.sections.map((s) => s.title).toList(growable: false);
    final itemByTopic = {
      for (final item in syllabus.allItems) item.id: item,
    };

    // --- Official marks structure for the marks-aware MCQs.
    final marksByTopic = <String, double>{};
    for (final entry in sectionByUnit.entries) {
      final item = itemByTopic[entry.key];
      if (item?.marks != null) marksByTopic[entry.key] = item!.marks!;
    }

    for (final entry in sectionByUnit.entries) {
      final unitId = entry.key;
      final section = entry.value;
      if (!selection.isSelected(unitId)) continue;
      final item = itemByTopic[unitId];
      if (item == null) {
        // Chapter unit (literature): grounded membership MCQ —
        // official chapter title, official section titles (§60).
        // Without this, full mocks would silently skip the
        // literature section's marks.
        final chapter =
            section.selectableUnits.where((u) => u.id == unitId).firstOrNull;
        if (chapter == null) continue;
        final pool = [...sectionTitles]..remove(section.title);
        final options = _options(
          correct: section.title,
          pool: pool,
          seed: 'pyq_${_suffix(unitId)}_chap',
        );
        if (options != null) {
          out.add(PyqQuestion(
            question: PracticeQuestion(
              id: 'pyq_${_suffix(unitId)}_chap',
              topicId: unitId,
              topicTitle: chapter.title,
              kind: PracticeQuestionKind.mcq,
              prompt: '«${chapter.title}» किस खंड में आता है?',
              options: options.$1,
              correctIndex: options.$2,
              explanation: '«${chapter.title}» ${section.title} खंड का '
                  'भाग है (आधिकारिक पाठ्यक्रम अनुसार)।',
              difficultyTier: 1,
            ),
            provenance: PyqProvenance.pyqStyle,
            patternText: 'अध्याय-आधारित',
            marks: 1,
          ));
        }
        continue;
      }

      final subtopics = _subtopicsOf(item).take(6).toList();
      final patterns = item.questionPatterns;

      // 1) Pattern-derived questions (official structure honored).
      for (final pattern in patterns) {
        final marks = _marksOf(pattern);
        final isTypedKind = _patternWantsTyped(pattern.pattern);
        final id = 'pyq_${_suffix(unitId)}_${patterns.indexOf(pattern)}';

        if (isTypedKind && subtopics.isNotEmpty) {
          out.add(PyqQuestion(
            question: PracticeQuestion(
              id: id,
              topicId: unitId,
              topicTitle: item.title,
              kind: PracticeQuestionKind.shortAnswer,
              prompt: '(${pattern.pattern}) «${item.title}» — इस विषय के '
                  'मुख्य बिंदु लिखें।',
              acceptedAnswers: [item.title],
              requiredPoints: subtopics.take(3).toList(),
              explanation: '«${item.title}» के आधिकारिक बिंदु: '
                  '${subtopics.take(3).join(', ')}।',
              difficultyTier: 2,
            ),
            provenance: PyqProvenance.examPattern,
            patternText: pattern.pattern,
            marks: marks,
          ));
        } else {
          // MCQ honoring the pattern (recall/membership, grounded).
          final pool = [...sectionTitles]..remove(section.title);
          final options = _options(
            correct: section.title,
            pool: pool,
            seed: id + '_sec',
          );
          if (options != null) {
            out.add(PyqQuestion(
              question: PracticeQuestion(
                id: id,
                topicId: unitId,
                topicTitle: item.title,
                kind: PracticeQuestionKind.mcq,
                prompt: '(${pattern.pattern}) «${item.title}» किस खंड में '
                    'आता है?',
                options: options.$1,
                correctIndex: options.$2,
                explanation: '«${item.title}» ${section.title} खंड का भाग '
                    'है (आधिकारिक पाठ्यक्रम अनुसार)।',
                difficultyTier: marks >= 3 ? 3 : 1,
              ),
              provenance: PyqProvenance.examPattern,
              patternText: pattern.pattern,
              marks: marks,
            ));
          }
        }
      }

      // 2) Marks-structure MCQ (PYQ-style, grounded in official marks).
      if (marksByTopic.containsKey(unitId)) {
        final myMarks = marksByTopic[unitId]!;
        final distractorMarks = marksByTopic.entries
            .where((e) => e.key != unitId && e.value != myMarks)
            .map((e) => '«${itemByTopic[e.key]?.title ?? e.key}» '
                '(${e.value.toStringAsFixed(0)} अंक)')
            .toList();
        final correct = '«${item.title}» (${myMarks.toStringAsFixed(0)} अंक)';
        final options = _options(
          correct: correct,
          pool: distractorMarks,
          seed: 'pyq_${_suffix(unitId)}_marks',
        );
        if (options != null) {
          out.add(PyqQuestion(
            question: PracticeQuestion(
              id: 'pyq_${_suffix(unitId)}_marks',
              topicId: unitId,
              topicTitle: item.title,
              kind: PracticeQuestionKind.mcq,
              prompt: 'आधिकारिक पाठ्यक्रम में किस विषय पर '
                  '${myMarks.toStringAsFixed(0)} अंक निर्धारित हैं?',
              options: options.$1,
              correctIndex: options.$2,
              explanation: '«${item.title}» पर '
                  '${myMarks.toStringAsFixed(0)} अंक निर्धारित हैं।',
              difficultyTier: 2,
            ),
            provenance: PyqProvenance.pyqStyle,
            patternText: 'अंक-संरचना',
            marks: 1,
          ));
        }
      }
    }

    // Weak topics first (§22), then higher marks (exam weight), then id.
    final ranked = [...out]..sort((a, b) {
        final aw = weakTopicIds.contains(a.topicId) ? 0 : 1;
        final bw = weakTopicIds.contains(b.topicId) ? 0 : 1;
        if (aw != bw) return aw.compareTo(bw);
        final m = b.marks.compareTo(a.marks);
        if (m != 0) return m;
        return a.id.compareTo(b.id);
      });

    // §25 filter application (section id resolved from the unit map).
    final filtered = ranked
        .where((q) => filter.matches(q, sectionByUnit[q.topicId]?.id ?? ''))
        .toList();
    if (filter.limit > 0) {
      return filtered.take(filter.limit).toList();
    }
    if (targetSize > 0 && filtered.length > targetSize) {
      return filtered.sublist(0, targetSize);
    }
    return filtered;
  }

  /// Section ids that actually carry PYQ questions (for filter chips).
  static Set<String> availableSections({
    required CourseSyllabus syllabus,
    required ExamScopeView view,
    required ExamScopeSelection selection,
  }) {
    final out = <String>{};
    for (final section in view.sections) {
      for (final unit in section.selectableUnits) {
        if (selection.isSelected(unit.id)) {
          final item =
              syllabus.allItems.where((i) => i.id == unit.id).firstOrNull;
          if (item != null &&
              (item.questionPatterns.isNotEmpty || item.marks != null)) {
            out.add(section.id);
          }
        }
      }
    }
    return out;
  }

  /// Marks of one pattern (marksEach → total/count → 1; bounded).
  static double _marksOf(QuestionPattern pattern) {
    final each = pattern.marksEach;
    if (each != null && each > 0) return each.clamp(0.5, 5.0).toDouble();
    final total = pattern.totalMarks;
    final count = pattern.count;
    if (total != null && total > 0 && count != null && count > 0) {
      return (total / count).clamp(0.5, 5.0).toDouble();
    }
    return 1;
  }

  /// §24: the official pattern text decides the question kind.
  static bool _patternWantsTyped(String patternText) {
    final t = patternText.toLowerCase();
    const typedMarkers = [
      'पूर्णवाक्यात्मक',
      'लघूत्तरात्मक',
      'वाक्य',
      'रचनात्मक',
      'निर्माण',
      'संवाद',
      'पत्र',
      'निबंध',
      'अनुच्छेद',
      'वर्णन',
    ];
    const mcqMarkers = ['बहुविकल्पीय', 'mcq', 'objective', 'वस्तुनिष्ठ'];
    if (mcqMarkers.any(t.contains)) return false;
    return typedMarkers.any(t.contains);
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
    final shuffled = deterministicShuffle(all, seedFromText(seed + '_shuffle'));
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
