/// Exam Mode 2.0 — M6 Practice Loop Tests
///
/// Loop transitions (correct → advance, wrong → retry, budget spent →
/// reveal, empty bank → finished), mastery updates (§29), and content
/// grounding against the real assets (§60).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/practice/practice_content_bank.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_models.dart';
import 'package:vaanix_app/features/exam/domain/practice/practice_session_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CourseSyllabus syllabus;
  late ExamScopeView view;
  late ExamScopeSelection selection;
  late List<PracticeQuestion> questions;
  const engine = PracticeSessionEngine();

  setUpAll(() async {
    final raw =
        await rootBundle.loadString('assets/syllabus/cbse/cbse_10_sanskrit.json');
    syllabus =
        CourseSyllabus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    view = ExamScopeView.fromSyllabus(syllabus);
    selection = ExamScopeSelection.empty(view.trackId)
        .selectAll(view.selectableUnitIds);
    questions = PracticeContentBank.build(
        syllabus: syllabus, view: view, selection: selection);
  });

  test('content bank: grounded, mixed types, bounded (§24/§60)', () {
    expect(questions, isNotEmpty);
    expect(questions.length, lessThanOrEqualTo(20));
    for (final q in questions) {
      expect(q.isValid, isTrue, reason: 'invalid question ${q.id}');
      expect(selection.isSelected(q.topicId), isTrue,
          reason: 'out-of-scope topic');
    }
    // The loop drives both MCQ and typed questions when the syllabus
    // provides sub-topic data (Class 10 Sanskrit does).
    expect(questions.any((q) => q.kind == PracticeQuestionKind.mcq), isTrue);
    expect(
        questions.any((q) => q.kind == PracticeQuestionKind.shortAnswer),
        isTrue);
  });

  test('loop: correct MCQ → feedback shown, then advance', () {
    var s = engine.start(questions.take(2).toList());
    final q = s.current!;
    s = engine.submitMcq(s, q.correctIndex!);
    expect(s.awaitingNext, isTrue);
    expect(s.currentVerdict, 'correct');
    expect(s.currentVerdictText, isNotNull);
    expect(s.attempts, isEmpty, reason: 'attempt recorded on advance');

    s = engine.advance(s);
    expect(s.attempts.length, 1);
    expect(s.attempts.first.verdict, 'correct');
    expect(s.index, 1);
  });

  test('loop: wrong MCQ → one invited retry → budget spent → final reveal',
      () {
    var s = engine.start(questions.take(1).toList());
    final q = s.current!;
    final wrong = (q.correctIndex! + 1) % q.options.length;

    s = engine.submitMcq(s, wrong);
    expect(s.awaitingNext, isFalse, reason: 'retry should be offered first');
    expect(s.currentRetryCount, 1);

    // §28: "Try again" re-opens input on the SAME question.
    s = engine.retryAttempt(s);
    expect(s.currentVerdictText, isNull);
    expect(s.currentRetryCount, 1, reason: 'retry budget is consumed');

    // Second wrong answer → budget spent → final + explanation.
    s = engine.submitMcq(s, wrong);
    expect(s.awaitingNext, isTrue);
    expect(s.currentVerdict, 'incorrect');

    s = engine.advance(s);
    expect(s.finished, isTrue);
    expect(s.attempts.single.verdict, 'incorrect');
  });

  test('loop: typed correct answer via M7 rubric (§27)', () {
    final typed = questions
        .firstWhere((q) => q.kind == PracticeQuestionKind.shortAnswer);
    var s = engine.start([typed]);
    s = engine.submitTyped(s, typed.acceptedAnswers.first);
    expect(s.awaitingNext, isTrue);
    expect(s.currentVerdict, 'correct');
  });

  test('loop: typed empty answer → honest empty feedback (§26)', () {
    final typed = questions
        .firstWhere((q) => q.kind == PracticeQuestionKind.shortAnswer);
    var s = engine.start([typed]);
    s = engine.submitTyped(s, '   ');
    expect(s.currentVerdictText, isNotNull);
    expect(s.currentRetryCount, 1, reason: 'empty counts as a miss');
  });

  test('loop: typed devanagari-normalized match (M7 normalizer)', () {
    final typed = questions
        .firstWhere((q) => q.kind == PracticeQuestionKind.shortAnswer);
    var s = engine.start([typed]);
    // Same answer with danda, extra spaces, danda punctuation.
    s = engine.submitTyped(s, ' ${typed.acceptedAnswers.first}।  ');
    expect(s.currentVerdict, 'correct',
        reason: 'normalization must absorb danda/whitespace');
  });

  test('reveal path: counts as not-correct for honest mastery (§29)', () {
    var s = engine.start(questions.take(1).toList());
    s = engine.reveal(s);
    expect(s.awaitingNext, isTrue);
    expect(s.currentVerdict, 'revealed');
    s = engine.advance(s);
    expect(PracticeSessionEngine.masteryUpdates(s).values.single, isFalse);
  });

  test('mastery updates: correct strengthens, wrong weakens (§29)', () {
    var s = engine.start(questions.take(2).toList());
    final q1 = s.current!;
    s = engine.submitMcq(s, q1.correctIndex!);
    s = engine.advance(s);
    final q2 = s.current!;
    s = engine.submitMcq(s, (q2.correctIndex! + 1) % q2.options.length);
    s = engine.retryAttempt(s);
    s = engine.submitMcq(s, (q2.correctIndex! + 2) % q2.options.length);
    s = engine.advance(s);

    final updates = PracticeSessionEngine.masteryUpdates(s);
    expect(updates[q1.topicId], isTrue);
    expect(updates[q2.topicId], isFalse);
  });

  test('empty bank → immediately finished (honest empty state)', () {
    final s = engine.start(const []);
    expect(s.finished, isTrue);
    expect(
        PracticeSessionEngine.summary(s), contains('कोई प्रश्न हल नहीं'));
  });

  test('§30: summary is constructive and percentage-free', () {
    var s = engine.start(questions.take(3).toList());
    while (!s.finished) {
      final q = s.current!;
      if (q.kind == PracticeQuestionKind.mcq) {
        s = engine.submitMcq(s, q.correctIndex!);
      } else {
        s = engine.submitTyped(s, q.acceptedAnswers.first);
      }
      s = engine.advance(s);
    }
    final text = PracticeSessionEngine.summary(s);
    expect(text.contains('%'), isFalse);
    expect(text.contains('प्रतिशत'), isFalse);
  });
}
