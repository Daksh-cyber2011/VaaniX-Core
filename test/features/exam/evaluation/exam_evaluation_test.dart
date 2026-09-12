/// Exam Mode 2.0 — M7 Answer Evaluation Tests
///
/// Normalizer (Devanagari digits/danda/case/whitespace), rubric
/// evaluator bands (§27 — correct/partial/incorrect/uncertain, empty,
/// very long), photo pipeline paths (§26 — unreadable, ambiguous,
/// good, offline, timeout, poor quality, cropped), and §30
/// no-percentage invariants.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/data/evaluation/gemini_vision_evaluator.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_normalizer.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/rubric_evaluator.dart';

void main() {
  group('AnswerNormalizer (§27 comparison basis)', () {
    test('whitespace collapse + trim', () {
      expect(normalizeAnswer('  सन्धि   कार्य  '), 'सन्धि कार्य');
    });

    test('danda and double-danda stripped', () {
      expect(normalizeAnswer('रामः। गच्छति॥'), normalizeAnswer('रामः गच्छति'));
    });

    test('Devanagari digits fold to ASCII', () {
      expect(normalizeAnswer('अंक १०'), 'अंक 10');
      expect(normalizeAnswer('२५'), '25');
    });

    test('Latin case folding + punctuation', () {
      expect(normalizeAnswer('Sandhi-Karya!'), 'sandhi karya');
    });

    test('nukta folding: क़ → क', () {
      expect(normalizeAnswer('क़लम'), 'कलम');
    });

    test('zero-width OCR leftovers dropped', () {
      expect(normalizeAnswer('स\u200Bन\u200Dधि'), 'सन्धि');
    });

    test('empty stays empty', () {
      expect(normalizeAnswer(''), '');
      expect(tokenizeAnswer(''), isEmpty);
    });
  });

  group('RubricEvaluator — MCQ (§14 deterministic)', () {
    test('correct/incorrect with constructive feedback (§28)', () {
      final ok = RubricEvaluator.evaluateMcq(
          correctIndex: 2, selectedIndex: 2, correctOptionText: 'सन्धि');
      expect(ok.verdict, EvaluationVerdict.correct);
      expect(ok.feedback.contains('सही'), isTrue);

      final bad = RubricEvaluator.evaluateMcq(
          correctIndex: 2, selectedIndex: 0, correctOptionText: 'सन्धि');
      expect(bad.verdict, EvaluationVerdict.incorrect);
      expect(bad.feedback, isNot(equals('Wrong.')));
      expect(bad.retryAdvice, isNotNull);
    });
  });

  group('RubricEvaluator — typed (§27)', () {
    final data = RubricAnswerData(
      acceptedAnswers: ['सन्धिकार्यम्'],
      requiredPoints: ['स्वरसन्धिः', 'व्यञ्जनसन्धिः', 'विसर्गसन्धिः'],
    );

    test('full correct answer', () {
      final r = RubricEvaluator.evaluateTyped(
        questionPrompt: 'सन्धि के प्रकार बताएँ',
        studentAnswer:
            'सन्धिकार्यम् में स्वरसन्धिः व्यञ्जनसन्धिः और विसर्गसन्धिः आते हैं',
        answerData: data,
      );
      expect(r.verdict, EvaluationVerdict.correct);
      expect(r.rubricPoints.every((p) => p.met), isTrue);
    });

    test('accepted answer but missing rubric points → partial (§27)', () {
      final r = RubricEvaluator.evaluateTyped(
        questionPrompt: 'q',
        studentAnswer: 'सन्धिकार्यम् में केवल स्वरसन्धिः आता है',
        answerData: data,
      );
      expect(r.verdict, EvaluationVerdict.partiallyCorrect);
      expect(r.rubricPoints.where((p) => p.met).length, 1);
      expect(r.feedback.contains('छूट'), isTrue,
          reason: 'feedback must name the missing point (§28)');
    });

    test('empty answer → honest miss with advice (§26)', () {
      final r = RubricEvaluator.evaluateTyped(
          questionPrompt: 'q', studentAnswer: '', answerData: data);
      expect(r.verdict, EvaluationVerdict.incorrect);
      expect(r.issues, contains(EvaluationIssue.emptyAnswer));
      expect(r.retryAdvice, isNotNull);
    });

    test('gray-zone answer → UNCERTAIN, never a guess (§26)', () {
      final r = RubricEvaluator.evaluateTyped(
        questionPrompt: 'q',
        studentAnswer: 'सन्धि का कार्य कुछ इस तरह होता है',
        answerData: data,
      );
      expect(r.verdict, EvaluationVerdict.uncertain);
      expect(r.confidenceBand, ConfidenceBand.low);
      expect(r.needsRetry, isTrue);
    });

    test('very long answer flagged but evaluated', () {
      final r = RubricEvaluator.evaluateTyped(
        questionPrompt: 'q',
        studentAnswer: 'सन्धिकार्यम् ${'शब्द ' * 400}',
        answerData: data,
      );
      expect(r.issues, contains(EvaluationIssue.veryLongAnswer));
      // Still graded (partial — accepted words present, points not).
      expect(r.verdict.isGraded, isTrue);
    });

    test('§30: feedback never contains percentages', () {
      for (final answer in [
        'सन्धिकार्यम् स्वरसन्धिः व्यञ्जनसन्धिः विसर्गसन्धिः',
        'सन्धिकार्यम्',
        'पता नहीं',
        '',
      ]) {
        final r = RubricEvaluator.evaluateTyped(
            questionPrompt: 'q', studentAnswer: answer, answerData: data);
        expect(r.feedback.contains('%'), isFalse);
        expect(r.feedback.contains('प्रतिशत'), isFalse);
      }
    });
  });

  group('PhotoQualityGate (§26 pre-network gates)', () {
    final big = List<int>.filled(64 * 1024, 1);

    test('good photo passes', () {
      expect(
          PhotoQualityGate.check(bytes: big, width: 1200, height: 900), isNull);
    });

    test('tiny file rejected before network', () {
      expect(PhotoQualityGate.check(bytes: [1, 2, 3], width: 100, height: 100),
          EvaluationIssue.tooSmallPhoto);
    });

    test('extreme aspect ratio treated as crop', () {
      expect(PhotoQualityGate.check(bytes: big, width: 2000, height: 100),
          EvaluationIssue.croppedPhoto);
    });

    test('missing dimensions rejected', () {
      expect(
          PhotoQualityGate.check(bytes: big, width: 0, height: 0),
          EvaluationIssue.tooSmallPhoto);
    });
  });

  group('PhotoAnswerEvaluator (§26 end-to-end paths)', () {
    final big = List<int>.filled(64 * 1024, 1);

    PhotoAnswerEvaluator evaluatorFor(_FakeVision vision) =>
        PhotoAnswerEvaluator(
          questionPrompt: 'सन्धि के प्रकार?',
          acceptedAnswers: ['सन्धिकार्यम्'],
          requiredPoints: ['स्वरसन्धिः'],
          visionClient: vision,
        );

    test('unreadable photo → uncertain + retake advice, never a guess',
        () async {
      final r = await evaluatorFor(
              _FakeVision(const VisionExtraction(readable: false, confident: false)))
          .evaluate(photoBytes: big, mime: 'image/jpeg', width: 800, height: 600);
      expect(r.verdict, EvaluationVerdict.uncertain);
      expect(r.issues, contains(EvaluationIssue.unreadablePhoto));
      expect(r.retryAdvice, contains('दोबारा'));
    });

    test('ambiguous extraction → uncertain + type-instead advice', () async {
      final r = await evaluatorFor(_FakeVision(const VisionExtraction(
        readable: true,
        confident: false,
        text: 'सन्धि क...',
      ))).evaluate(photoBytes: big, mime: 'image/jpeg', width: 800, height: 600);
      expect(r.verdict, EvaluationVerdict.uncertain);
      expect(r.issues, contains(EvaluationIssue.ambiguousExtraction));
      expect(r.extractedText, 'सन्धि क...');
    });

    test('confident extraction with correct text → graded correct (§27)',
        () async {
      final r = await evaluatorFor(_FakeVision(const VisionExtraction(
        readable: true,
        confident: true,
        text: 'सन्धिकार्यम् — स्वरसन्धिः',
      ))).evaluate(photoBytes: big, mime: 'image/jpeg', width: 800, height: 600);
      expect(r.verdict, EvaluationVerdict.correct);
      expect(r.extractedText, contains('सन्धिकार्यम्'));
    });

    test('offline → typed-first guidance, never "app broken" (§17)',
        () async {
      final r = await evaluatorFor(_FakeVision(null, offline: true))
          .evaluate(photoBytes: big, mime: 'image/jpeg', width: 800, height: 600);
      expect(r.verdict, EvaluationVerdict.uncertain);
      expect(r.issues, contains(EvaluationIssue.offlinePhoto));
      expect(r.retryAdvice, contains('टाइप'));
    });

    test('timeout → uncertain with typed advice (§26)', () async {
      final r = await evaluatorFor(_FakeVision(null, timeout: true))
          .evaluate(photoBytes: big, mime: 'image/jpeg', width: 800, height: 600);
      expect(r.verdict, EvaluationVerdict.uncertain);
      expect(r.retryAdvice, contains('टाइप'));
    });

    test('poor-quality photo rejected before ANY network call', () async {
      var called = false;
      final vision = _FakeVision(const VisionExtraction(
          readable: true, confident: true, text: 'anything'),
          onCall: () => called = true);
      await evaluatorFor(vision).evaluate(
          photoBytes: [1, 2, 3], mime: 'image/jpeg', width: 100, height: 100);
      expect(called, isFalse,
          reason: '§18: garbage input must never cost a Gemini call');
    });
  });
}

class _FakeVision implements ExamVisionClient {
  _FakeVision(this.extraction, {this.offline = false, this.timeout = false, this.onCall});

  final VisionExtraction? extraction;
  final bool offline;
  final bool timeout;
  final void Function()? onCall;

  @override
  bool get isAvailable => !offline;

  @override
  Future<VisionExtraction> extract({
    required List<int> photoBytes,
    required String mime,
    required String questionPrompt,
  }) async {
    onCall?.call();
    if (timeout) throw TimeoutException('slow');
    final e = extraction;
    if (e == null) throw Exception('network down');
    return e;
  }
}
