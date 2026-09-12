/// Exam Mode 2.0 — Diagnostic Item Bank (M4 data layer, §10/§11/§60)
///
/// Builds the diagnostic question bank DETERMINISTICALLY from the
/// canonical syllabus + the student's selected scope. Every string in
/// every question comes from the official syllabus JSON (§60 NO
/// CURRICULUM INVENTION — no AI, no fabricated options, no guessing).
///
/// Question kinds (all MCQ, 4 options, exactly one correct):
///  * section-membership (recall, easy): "«unit» किस खंड में आता है?"
///    — options are the course's real section titles (+ book titles
///    when fewer than 4 sections exist).
///  * sub-topic membership (recall, medium): "इनमें से कौन «unit» का
///    भाग है?" — options are real sub-topics from the unit's official
///    details; distractors are real sub-topics of OTHER units.
///  * marks awareness (application, hard): "किस इकाई पर सबसे अधिक
///    अंक हैं?" — options are real units with official marks.
///  * chapter identity (interpretation, medium): "«chapter» किस
///    पुस्तक का पाठ है?" — options are the course's real books.
///
/// Determinism: option order is seeded from question ids (stable in
/// tests — same seed, same order), reusing the Learn engine's
/// [seedFromText]/[deterministicShuffle] utilities (extend, don't
/// duplicate).
library;

import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_models.dart';
import 'package:vaanix_app/features/learn/domain/exercise_models.dart'
    show seedFromText, deterministicShuffle;

class DiagnosticItemBank {
  DiagnosticItemBank._();

  /// Builds the grounded bank for [selection] on [view]/[syllabus].
  /// Returns per-topic maps the engine needs (titles + sections).
  static DiagnosticItemBankResult build({
    required CourseSyllabus syllabus,
    required ExamScopeView view,
    required ExamScopeSelection selection,
  }) {
    final questions = <DiagnosticQuestion>[];
    final topicTitles = <String, String>{};
    final topicSections = <String, String>{};

    final selectedUnits = <ScopeUnit>[];
    for (final section in view.sections) {
      for (final unit in section.selectableUnits) {
        if (selection.isSelected(unit.id)) {
          selectedUnits.add(unit);
          topicTitles[unit.id] = unit.title;
          topicSections[unit.id] = section.title;
        }
      }
    }

    // Real section titles + book titles as option pools (grounded).
    final sectionTitles =
        view.sections.map((s) => s.title).toList(growable: false);
    final bookTitles =
        syllabus.books.map((b) => b.title).toList(growable: false);

    // Real sub-topic strings per unit (from official item details).
    Map<String, List<String>> unitIdToSubtopics(String sectionId) {
      final result = <String, List<String>>{};
      final section =
          syllabus.sections.where((s) => s.id == sectionId).firstOrNull;
      if (section == null) return result;
      for (final item in section.items) {
        final subs = _subtopicsOf(item);
        if (subs.isNotEmpty) result[item.id] = subs;
      }
      return result;
    }

    for (final unit in selectedUnits) {
      // Kinds only make sense with enough grounded distractors —
      // skipped otherwise (isValid also guards, but skipping early
      // keeps ids clean).

      // 1) Section membership — recall, easy.
      {
        final pool = [...sectionTitles, ...bookTitles];
        final correct =
            view.sections.firstWhere((s) => s.id == unit.sectionId).title;
        final options = _options(
          correct: correct,
          pool: pool.where((t) => t != correct).toList(),
          seed: unit.id + '_sec',
        );
        if (options != null) {
          questions.add(DiagnosticQuestion(
            id: 'diag_${_suffix(unit.id)}_sec',
            topicId: unit.id,
            topicTitle: unit.title,
            sectionTitle: topicSections[unit.id] ?? '',
            prompt: '«${unit.title}» किस खंड का भाग है?',
            options: options.$1,
            correctIndex: options.$2,
            difficulty: DiagnosticDifficulty.easy,
            skill: DiagnosticSkill.recall,
          ));
        }
      }

      // 2) Sub-topic membership — recall, medium.
      {
        final subtopicsByUnit = unitIdToSubtopics(unit.sectionId);
        final own = subtopicsByUnit[unit.id] ?? const <String>[];
        if (own.isNotEmpty) {
          final distractorPool = <String>[];
          subtopicsByUnit.forEach((id, subs) {
            if (id != unit.id) distractorPool.addAll(subs);
          });
          final correct = own.first;
          final options = _options(
            correct: correct,
            pool: distractorPool.where((s) => s != correct).toList(),
            seed: unit.id + '_sub',
          );
          if (options != null) {
            questions.add(DiagnosticQuestion(
              id: 'diag_${_suffix(unit.id)}_sub',
              topicId: unit.id,
              topicTitle: unit.title,
              sectionTitle: topicSections[unit.id] ?? '',
              prompt: 'इनमें से कौन-सा «${unit.title}» के अंतर्गत आता है?',
              options: options.$1,
              correctIndex: options.$2,
              difficulty: DiagnosticDifficulty.medium,
              skill: DiagnosticSkill.recall,
            ));
          }
        }
      }

      // 3) Marks awareness — application, hard.
      {
        final withMarks = selectedUnits
            .where((u) => u.marks != null && u.marks! > 0)
            .toList();
        if (unit.marks != null && unit.marks! > 0 && withMarks.length >= 4) {
          // Pick only strictly lower-marked units as distractors. The
          // previous global-descending sample made this question valid for
          // just one unit in a course, starving the hard adaptive tier.
          final lowerMarked = withMarks
              .where((u) => u.id != unit.id && u.marks! < unit.marks!)
              .toList()
            ..sort((a, b) => b.marks!.compareTo(a.marks!));
          if (lowerMarked.length >= 3) {
            final options = _options(
              correct: unit.title,
              pool: lowerMarked.take(3).map((u) => u.title).toList(),
              seed: unit.id + '_marks',
            );
            if (options != null) {
              questions.add(DiagnosticQuestion(
                id: 'diag_${_suffix(unit.id)}_marks',
                topicId: unit.id,
                topicTitle: unit.title,
                sectionTitle: topicSections[unit.id] ?? '',
                prompt:
                    'इन चार इकाइयों में से किस पर सबसे अधिक अंक निर्धारित हैं?',
                options: options.$1,
                correctIndex: options.$2,
                difficulty: DiagnosticDifficulty.hard,
                skill: DiagnosticSkill.application,
              ));
            }
          }
        }
      }

      // 4) Chapter identity — interpretation, medium.
      if (unit.isChapter && syllabus.books.length >= 4) {
        final owningBook = syllabus.books
            .where((b) => b.chapters.any((c) => c.id == unit.id))
            .firstOrNull;
        if (owningBook != null) {
          final distractors = syllabus.books
              .where((b) => b.id != owningBook.id)
              .map((b) => b.title)
              .toList();
          if (distractors.length >= 3) {
            final options = _options(
              correct: owningBook.title,
              pool: distractors.take(3).toList(),
              seed: unit.id + '_book',
            );
            if (options != null) {
              questions.add(DiagnosticQuestion(
                id: 'diag_${_suffix(unit.id)}_book',
                topicId: unit.id,
                topicTitle: unit.title,
                sectionTitle: topicSections[unit.id] ?? '',
                prompt: '«${unit.title}» किस पुस्तक का पाठ है?',
                options: options.$1,
                correctIndex: options.$2,
                difficulty: DiagnosticDifficulty.medium,
                skill: DiagnosticSkill.interpretation,
              ));
            }
          }
        }
      }
    }

    return DiagnosticItemBankResult(
      questions: questions,
      topicTitles: topicTitles,
      topicSections: topicSections,
    );
  }

  /// Official sub-topic strings of an item (top-level lists in
  /// `details`, plus list values one level deep for map-shaped
  /// details like संकेताः).
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

  /// Builds 4 shuffled options (correct + 3 distractors). Null when
  /// fewer than 3 distinct grounded distractors exist.
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
    // cbse_10_sanskrit_grammar_sandhi → grammar_sandhi (stable, short).
    final parts = unitId.split('_');
    return parts.length <= 4
        ? parts.sublist(2).join('_')
        : parts.sublist(4).join('_');
  }
}

class DiagnosticItemBankResult {
  const DiagnosticItemBankResult({
    required this.questions,
    required this.topicTitles,
    required this.topicSections,
  });

  final List<DiagnosticQuestion> questions;
  final Map<String, String> topicTitles;
  final Map<String, String> topicSections;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
