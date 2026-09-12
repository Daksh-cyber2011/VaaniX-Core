/// Exam Mode 2.0 — Photo Answer Vision Pipeline (M7, §26/§27/§42)
///
/// The photo-answer path (§26): student photographs a handwritten
/// answer → input quality gates → Gemini VISION extraction (the ONLY
/// network hop, rate-limited, timeout-bounded) → honest confidence
/// handling → the extracted text enters the SAME deterministic M7
/// rubric evaluator as typed answers (§27: rubric-grounded, §14
/// deterministic structures control scoring).
///
/// Uncertainty handling (§26 — "Do not pretend OCR is perfect"):
///  * too-small / extreme-aspect photos are rejected BEFORE any
///    network call (croppedPhoto / tooSmallPhoto advice);
///  * unreadable or ambiguous extraction ⇒ UNCERTAIN verdict +
///    retake-or-type advice — never a guessed grade;
///  * offline / unconfigured ⇒ clear typed-first guidance, NEVER
///    "AI failed so the app is broken" (§17).
///
/// The vision call goes through `google_generative_ai` with an
/// [InlineDataPart] (base64 inline image) — the same SDK and API key
/// discipline as the chat adapter and planner clients (§42).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/features/ai/data/ai_rate_limiter.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/answer_models.dart';
import 'package:vaanix_app/features/exam/domain/evaluation/rubric_evaluator.dart';

/// What the vision pipeline can conclude about a photo.
class VisionExtraction {
  const VisionExtraction({
    required this.readable,
    required this.confident,
    this.text = '',
    this.issues = const [],
  });

  /// Whether handwriting text could be extracted at all.
  final bool readable;

  /// Whether the extraction is unambiguous (§26 low confidence → not
  /// confident; the pipeline then refuses to grade).
  final bool confident;
  final String text;
  final List<EvaluationIssue> issues;
}

/// The boundary between the evaluation service and the vision
/// backend (fake-able in tests, same discipline as
/// PlannerTextClient).
abstract class ExamVisionClient {
  bool get isAvailable;

  /// Extracts handwriting from a photo. THROWS on failure — the
  /// service converts everything to typed results or honest
  /// uncertain verdicts.
  Future<VisionExtraction> extract({
    required List<int> photoBytes,
    required String mime,
    required String questionPrompt,
  });
}

/// Gemini implementation of [ExamVisionClient].
class GeminiExamVisionClient implements ExamVisionClient {
  GeminiExamVisionClient({AiRateLimiter? rateLimiter})
      : _rateLimiter = rateLimiter ?? AiRateLimiter();

  @visibleForTesting
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Photos below this byte count are almost certainly thumbnails/
  /// crops — rejected before any network cost.
  @visibleForTesting
  static const int minPhotoBytes = 8 * 1024;

  final AiRateLimiter _rateLimiter;
  GenerativeModel? _model;

  @override
  bool get isAvailable => AppEnvironment.isGeminiConfigured;

  @override
  Future<VisionExtraction> extract({
    required List<int> photoBytes,
    required String mime,
    required String questionPrompt,
  }) async {
    await _rateLimiter.awaitSlot();
    final model = _modelFor();
    final response = await model.generateContent([
      Content.multi([
        TextPart(_extractionPrompt(questionPrompt)),
        // Inline multimodal part — image bytes (§42).
        if (photoBytes.isNotEmpty)
          DataPart(mime, Uint8List.fromList(photoBytes)),
      ])
    ]).timeout(requestTimeout);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      return const VisionExtraction(
        readable: false,
        confident: false,
        issues: [EvaluationIssue.unreadablePhoto],
      );
    }
    return _interpret(text.trim());
  }

  GenerativeModel _modelFor() {
    final existing = _model;
    if (existing != null) return existing;
    final apiKey = AppEnvironment.geminiApiKey;
    if (apiKey.isEmpty) {
      throw StateError('Gemini API key not configured');
    }
    _model = GenerativeModel(
      model: AppEnvironment.geminiModel,
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.0, // extraction: deterministic reads
        maxOutputTokens: 1024,
      ),
    );
    return _model!;
  }

  static const String _systemInstruction =
      'You are a careful OCR assistant for VaaniX. You read handwritten '
      'student answers. You NEVER guess unreadable text. You answer ONLY '
      'with a strict JSON object.';

  static String _extractionPrompt(String questionPrompt) =>
      'The photo is a student\'s handwritten answer to this question:\n'
      '"$questionPrompt"\n'
      'Transcribe the handwritten answer EXACTLY. If any part is '
      'unreadable, do NOT guess it. Respond ONLY as JSON:\n'
      '{"readable": true|false, "confident": true|false, "text": "..."}\n'
      '"confident" is false when ANY word was uncertain or the photo is '
      'partially cropped.';

  /// Parses the model's JSON verdict defensively (§16 spirit).
  static VisionExtraction _interpret(String raw) {
    Map<String, dynamic>? json;
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) json = decoded;
      }
    } catch (_) {
      json = null;
    }
    if (json == null) {
      return const VisionExtraction(
        readable: false,
        confident: false,
        issues: [EvaluationIssue.ambiguousExtraction],
      );
    }
    final readable = json['readable'] == true;
    final confident = json['confident'] == true;
    final text = (json['text'] as String?) ?? '';
    return VisionExtraction(
      readable: readable && text.trim().isNotEmpty,
      confident: confident,
      text: text,
      issues: [
        if (!readable) EvaluationIssue.unreadablePhoto,
        if (readable && !confident) EvaluationIssue.ambiguousExtraction,
      ],
    );
  }
}

/// Input quality gates (pure, pre-network — §18 efficiency).
class PhotoQualityGate {
  const PhotoQualityGate._();

  static const int minBytes = GeminiExamVisionClient.minPhotoBytes;

  /// Returns the issue that disqualifies the photo, or null when it
  /// passes. Extreme aspect ratios (very thin strips) are treated as
  /// crops; tiny files as thumbnails (§26 cropped image handling).
  static EvaluationIssue? check({
    required List<int> bytes,
    required int width,
    required int height,
  }) {
    if (bytes.length < minBytes) {
      return EvaluationIssue.tooSmallPhoto;
    }
    if (width <= 0 || height <= 0) {
      return EvaluationIssue.tooSmallPhoto;
    }
    final ratio = width > height ? width / height : height / width;
    if (ratio > 6) {
      return EvaluationIssue.croppedPhoto;
    }
    return null;
  }
}

/// The photo evaluation service: gates → vision → rubric.
///
/// Rubric inputs are passed as plain typed fields (the caller in the
/// presentation layer reads them off the current [PracticeQuestion]).
class PhotoAnswerEvaluator {
  PhotoAnswerEvaluator({
    required this.questionPrompt,
    required this.acceptedAnswers,
    required this.requiredPoints,
    ExamVisionClient? visionClient,
  }) : _visionClient = visionClient ?? GeminiExamVisionClient();

  final String questionPrompt;
  final List<String> acceptedAnswers;
  final List<String> requiredPoints;

  final ExamVisionClient _visionClient;

  /// Evaluates a photo submission end-to-end. Never throws: every
  /// failure path produces a typed [EvaluationResult] (uncertain with
  /// §26 advice, or offline typed-first guidance).
  Future<EvaluationResult> evaluate({
    required List<int> photoBytes,
    required String mime,
    int photoWidth = 0,
    int photoHeight = 0,
    bool isRetry = false,
  }) async {
    // Gate 1: input quality (no network cost for garbage input).
    final issue = PhotoQualityGate.check(
      bytes: photoBytes,
      width: photoWidth,
      height: photoHeight,
    );
    if (issue != null) {
      return _uncertain([issue], issue.studentAdvice);
    }

    // Gate 2: availability (§17 — never "app broken").
    if (!_visionClient.isAvailable) {
      return _uncertain(
        [EvaluationIssue.offlinePhoto],
        EvaluationIssue.offlinePhoto.studentAdvice,
      );
    }

    // Gate 3: vision extraction (network, rate-limited, timeout).
    VisionExtraction extraction;
    try {
      extraction = await _visionClient.extract(
        photoBytes: photoBytes,
        mime: mime,
        questionPrompt: questionPrompt,
      );
    } on TimeoutException {
      return _uncertain(
        const [],
        'फ़ोटो पढ़ने में समय लग गया — कृपया उत्तर टाइप करें और आगे बढ़ें।',
      );
    } catch (e) {
      return _uncertain(
        const [],
        'फ़ोटो अभी पढ़ी नहीं जा सकी — कृपया उत्तर टाइप करें (आपकी '
        'प्रगति सुरक्षित है)।',
      );
    }

    // Gate 4: honest uncertainty (§26 — never pretend OCR is perfect).
    if (!extraction.readable) {
      return _uncertain(
        extraction.issues.isEmpty
            ? const [EvaluationIssue.unreadablePhoto]
            : extraction.issues,
        EvaluationIssue.unreadablePhoto.studentAdvice,
      );
    }
    if (!extraction.confident) {
      return _uncertain(
        extraction.issues.isEmpty
            ? const [EvaluationIssue.ambiguousExtraction]
            : extraction.issues,
        EvaluationIssue.ambiguousExtraction.studentAdvice,
        extractedText: extraction.text,
      );
    }

    // Graded path: the SAME rubric evaluator as typed answers (§27).
    final graded = RubricEvaluator.evaluateTyped(
      questionPrompt: questionPrompt,
      studentAnswer: extraction.text,
      answerData: RubricAnswerData(
        acceptedAnswers: acceptedAnswers,
        requiredPoints: requiredPoints,
      ),
      isRetry: isRetry,
    );
    return EvaluationResult(
      verdict: graded.verdict,
      feedback: graded.feedback,
      rubricPoints: graded.rubricPoints,
      confidenceBand: graded.confidenceBand,
      extractedText: extraction.text,
      issues: const [],
      retryAdvice: graded.retryAdvice,
    );
  }

  EvaluationResult _uncertain(
    List<EvaluationIssue> issues,
    String advice, {
    String? extractedText,
  }) {
    return EvaluationResult(
      verdict: EvaluationVerdict.uncertain,
      feedback: advice,
      rubricPoints: const [],
      confidenceBand: ConfidenceBand.low,
      extractedText: extractedText,
      issues: issues,
      retryAdvice: advice,
    );
  }
}
