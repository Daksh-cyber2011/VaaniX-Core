# Syllabus Ingestion Tools (M1)

Re-ingestion pipeline for the canonical Exam Mode syllabus data
(`assets/syllabus/cbse/`). Use when CBSE publishes the pending Class 9
chapter lists or when any syllabus PDF is revised.

## Files
- `generate_syllabus.py` — the single source that produces the canonical
  JSON (data embedded, validated before write; refuses to write on any
  mark-arithmetic failure).
- `verify_syllabus_data.py` — 432-check invariant mirror of the Dart test
  suite; run it after any data edit (`python3 tools/syllabus/verify_syllabus_data.py`
  from the repo root after pointing ROOT at this project).

## Workflow
1. Update the data in `generate_syllabus.py` from the official PDF
   (text-layer + OCR dual verification — see
   `docs/Syllabus/INGESTION_REPORT.md` §2).
2. Run it; ensure validation passes.
3. Run `verify_syllabus_data.py` and the Dart suite
   (`flutter test test/features/exam/syllabus/`).

## M2 additions
- `verify_exam_scope.py` — 124-check mirror of the M2 scope-domain test
  suite (view building, selection semantics, isolation, coverage rules).
