/// Exam Mode 2.0 — Answer Normalizer (M7, §27)
///
/// Deterministic normalization for TYPED and photo-EXTRACTED answers
/// before rubric comparison. Handles the real-world variance of
/// Devanagari + Latin student input:
///
///  * leading/trailing whitespace, collapsed inner whitespace;
///  * Devanagari and Latin punctuation (।, ॥, danda), hyphens,
///    quotes — stripped;
///  * Devanagari digits ०-९ → ASCII 0-9;
///  * Latin case folding;
///  * common Devanagari variant spellings that carry zero semantic
///    weight in school answers (anusvara ं vs ँ nasalization blends,
///    ऽ avagraha, zero-width joiner leftovers from photo OCR).
///
/// Deliberately NOT done: synonym folding, semantic expansion — that
/// is the rubric evaluator's job with TRUSTED accepted-answer lists
/// (§27: never naive string equality, never blind fuzzy matching).
///
/// Pure Dart — no Flutter imports.
library;

/// Normalizes one answer string for comparison.
String normalizeAnswer(String raw) {
  var text = raw;
  if (text.isEmpty) return '';

  // Zero-width characters (common OCR leftovers) — dropped first.
  text = text
      .replaceAll('\u200B', '')
      .replaceAll('\u200C', '')
      .replaceAll('\u200D', '')
      .replaceAll('\uFEFF', '');

  // Devanagari digits → ASCII (०१२३४५६७८९).
  const devDigits =
      '\u0966\u0967\u0968\u0969\u096A\u096B\u096C\u096D\u096E\u096F';
  const asciiDigits = '0123456789';
  final sb = StringBuffer();
  for (final ch in text.codeUnits) {
    final idx = devDigits.indexOf(String.fromCharCode(ch));
    if (idx >= 0) {
      sb.write(asciiDigits[idx]);
    } else {
      sb.writeCharCode(ch);
    }
  }
  text = sb.toString();

  // Devanagari-specific folds.
  text = text
      .replaceAll('\u093D', "'") // avagraha → apostrophe (then stripped)
      .replaceAll('\u0901', '\u0902') // chandrabindu → anusvara
      .replaceAll('\u0933', '\u0932') // lateral fold for comparison
      .replaceAll('\u093C', ''); // nukta: क़→क, ज़→ज, फ़→फ

  // Punctuation that never changes meaning in school answers.
  const strip = '\u0964\u0965!.,;:?\'"()[]{}<>-\u2013\u2014_/\\+*=|\u00B7';
  for (final c in strip.split('')) {
    text = text.replaceAll(c, ' ');
  }

  // Case fold (Latin; Devanagari has no case).
  text = text.toLowerCase();

  // Collapse all whitespace runs to single spaces + trim.
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  return text;
}

/// Tokenizes a normalized answer into comparison tokens.
List<String> tokenizeAnswer(String raw) {
  final normalized = normalizeAnswer(raw);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ').where((t) => t.isNotEmpty).toList();
}

/// Token-level overlap between a student answer and one expected
/// phrasing: |intersection| / |expected| (0..1). Used by the rubric
/// evaluator for required-point matching (§27 completeness).
double tokenCoverage(List<String> expected, List<String> answer) {
  if (expected.isEmpty) return 0;
  if (answer.isEmpty) return 0;
  final pool = List<String>.from(answer);
  var hits = 0;
  for (final token in expected) {
    final idx = pool.indexOf(token);
    if (idx >= 0) {
      hits++;
      pool.removeAt(idx);
    }
  }
  return hits / expected.length;
}
