# VaaniX Exam Mode 2.0 — M1 Syllabus Ingestion Report

**Milestone:** M1 — Syllabus Ingestion
**Date:** 2026-09-12
**Input:** the six official CBSE 2026–27 curriculum PDFs supplied by the product owner
**Output:** canonical, validated, board-agnostic syllabus data shipped inside the app

```
assets/syllabus/cbse/index.json
assets/syllabus/cbse/cbse_9_hindi_r1.json
assets/syllabus/cbse/cbse_9_hindi_r2.json
assets/syllabus/cbse/cbse_9_sanskrit.json
assets/syllabus/cbse/cbse_10_hindi_a.json
assets/syllabus/cbse/cbse_10_hindi_b.json
assets/syllabus/cbse/cbse_10_sanskrit.json
assets/syllabus/cbse/cbse_10_sanskrit_communicative.json
```

Dart layer: `lib/features/exam/data/syllabus/` (models, catalog index, loader + Riverpod providers).
Tests: `test/features/exam/syllabus/` (models + catalog/loader). Invariant mirror (executed in this environment): `scripts/verify_syllabus_data.py` — **432/432 checks passing**.

---

## 1. Rule zero — the PDF is the authority

Nothing in this dataset was invented. Every section, mark, topic, sub-topic, book, and chapter below is traceable to a page of the supplied PDFs. Where the PDF is silent (Class 9 literature), the data carries an explicit `pendingOfficialAnnouncement` status rather than a guess. Where a source glyph could not be machine-verified with full confidence, the item carries `ocrUncertain: true` and appears in §5 for human verification.

## 2. Extraction methodology

1. **Text layer** (PyMuPDF + pdftotext): all six PDFs were extracted. Every PDF has a Devanagari font whose embedded encoding is damaged for conjuncts (यण्, क्रि, द्वि … come out as Latin substitutes). Text-layer output is reliable for **structure, numbering, and marks** (Arabic digits and tables), but NOT for content strings.
2. **OCR verification**: every load-bearing Devanagari string (chapter names, grammar topics, exclusion lists) was re-read from 300–400 DPI rasterized page renders with Tesseract (`hin` + `san` models), often at word-level zoom (up to 24×) with multiple binarization thresholds. A string was accepted only when OCR readings agreed across settings.
3. **Cross-table reconciliation**: where a PDF prints the same facts twice (marks tables vs. detailed layouts), both were compared; conflicts are documented (§4) and resolved in favor of the internally-consistent table.
4. **Automated validation**: the generator enforces mark-arithmetic invariants — board sections sum to 80, section items sum to section marks, internal components sum to 20, IDs are unique and namespaced per course — and refuses to write files when any invariant fails.

## 3. Source mapping — six PDFs → seven canonical courses

| # | Official PDF | Class | Course(s) ingested | Subject code | Board sections (marks) | Literature |
|---|---|---|---|---|---|---|
| 1 | Hindi_SecP1IX_2026-27.pdf (10 pp.) | 9 | `cbse_9_hindi_r1` — हिन्दी आर-1 | — | अपठित बोध 14 · व्यावहारिक व्याकरण 16 · पाठ्यपुस्तक 30 · रचनात्मक लेखन 20 | **Pending** (NCF-2023 textbook, no chapter list published) |
| 2 | Hindi_SecP1IX_2026-27.pdf (same document) | 9 | `cbse_9_hindi_r2` — हिन्दी आर-2 | — | अपठित बोध 14 · व्यावहारिक व्याकरण 16 · पाठ्यपुस्तक 30 · रचनात्मक लेखन 20 | **Pending** (same) |
| 3 | Sanskrit_SecP1IX_2026-27.pdf (10 pp.) | 9 | `cbse_9_sanskrit` — संस्कृतम् | — | अपठितावबोधनम् 10 · रचनात्मककार्यम् 15 · अनुप्रयुक्तव्याकरणम् 25 · पठितावबोधनम् 30 | **Pending** — “शीघ्रमेव सूचयिष्यते” (PDF p. 8) |
| 4 | Hindi_A_SecP1_2026-27.pdf (11 pp.) | 10 | `cbse_10_hindi_a` — हिन्दी मातृभाषा (अ) | 002 | अपठित बोध 14 · व्यावहारिक व्याकरण 16 · पाठ्यपुस्तक एवं पूरक 30 · रचनात्मक लेखन 20 | Published — books + official exclusion list |
| 5 | Hindi_B_SecP1_2026-27.pdf (9 pp.) | 10 | `cbse_10_hindi_b` — हिन्दी ब | 085 | अपठित बोध 14 · व्यावहारिक व्याकरण 16 · पाठ्यपुस्तक एवं पूरक 28 · रचनात्मक लेखन 22 | Published — books + official exclusion list |
| 6 | Sanskrit_SecP1_2026-27.pdf (9 pp.) | 10 | `cbse_10_sanskrit` — संस्कृतम् | 122 | अपठितावबोधनम् 10 · रचनात्मककार्यम् 15 · अनुप्रयुक्तव्याकरणम् 25 · पठितावबोधनम् 30 | Published — 9 chapters (1–8, 10) |
| 7 | Sanskrit_Communiucative_SecP1_2026-27.pdf (10 pp.) | 10 | `cbse_10_sanskrit_communicative` — संस्कृतम् (संप्रेषणात्मकम्) | 119 | अपठितावबोधनम् 10 · रचनात्मककार्यम् 15 · अनुप्रयुक्तव्याकरणम् 25 · पठितावबोधनम् 30 | Published — 11 chapters (10 & 11 internal-only) |

All seven courses: board exam 80 marks / 3 hours + internal assessment 20 marks. Every course file embeds per-item `sourceRef` (PDF + page numbers).

Note: the six V1 "tracks" of the master plan map to six PDFs; the Class 9 Hindi PDF defines **two course variants** (आर-1 / आर-2), hence seven canonical course files.

## 4. Discrepancies & judgment calls (all flagged in the data)

| # | Finding | Resolution | Where flagged |
|---|---|---|---|
| D1 | **Class 9 Sanskrit खंड-घ internal inconsistency**: the section-marks table (p. 4) gives items 17/18 = 5/4 (दीर्घोत्तरात्मक 5×1 / 4×1) summing to 30; the “वार्षिकं मूल्याङ्कम्” layout’s side numbers (p. 7) read 4/3 (sum 28). | Adopted the p. 4 table — it is the one whose explicit question patterns sum exactly to the section total (30) and matches the paper-wide question-type distribution table (“2+2+2+5+4=15”). | Section note in `cbse_9_sanskrit.json` + here |
| D2 | **Class 10 Sanskrit (122) chapter table skips पाठ 9** — the official table lists chapters 1–8 then 10. | Recorded exactly as printed (9 chapters). Chapter 9 was NOT added. | Book note in `cbse_10_sanskrit.json` |
| D3 | Class 9 Hindi (both variants) reference the NCERT textbook “issued under राष्ट्रीय पाठ्यचया रूपरेखा 2023” but publish no titles/chapters. | Literature modeled as pending; no book invented. | `pendingOfficialAnnouncement` blocks |
| D4 | Class 10 Hindi A/B publish the exclusion list (छूट पाठ) but not full chapter lists. | Literature scope modeled at book-section granularity + official exclusion lists (Hindi A: 2 गद्य + 3 काव्य + 2 कृतिका; Hindi B: 2 काव्य + 1 गद्य स्पर्श; संचयन untouched). Chapter-level lists must come from the books themselves in a later milestone (content layer), never invented here. | Literature item details |
| D5 | Sanskrit Communicative (119) chapters 10 (कालोऽहम्) and 11 (किं किम् उपादेयम्) are marked “केवलम् आन्तरिकमूल्याङ्कनाय” in the PDF. | Chapters ingested with `examRelevance: internal-only`. | Chapter records |

## 5. OCR-uncertainty register (human verification recommended)

These strings are the ONLY ones whose PDF glyph could not be confirmed with full automatic confidence. The recorded reading is the best OCR consensus; each carries `ocrUncertain: true` in the data and displays in app diagnostics when needed.

| Course | Item / field | Recorded reading | Confidence & note |
|---|---|---|---|
| cbse_9_sanskrit | कारक-उपपद सूचियाँ | तृतीया: सदृश; चतुर्थी: रुच्, दा (यच्छ्), स्वस्ति; पञ्चमी: रक्ष्; सप्तमी: स्पृह् | सदृश zoom-OCR clear; स्वस्ति/रक्ष्/स्पृह् plausible readings of degraded glyphs — verify against print PDF |
| cbse_9_sanskrit | शब्दरूप पुंल्लिङ्ग अंतिम शब्द | पाणिनः | Consistent psm-8/13 OCR at multiple thresholds; raw glyph garbled. Verify. |
| cbse_9_sanskrit | धातुरूप परस्मैपदिन tail | क्री, ध्रु(श्रु) | OCR read “क्री”, “श्रु”; raw glyph suggests ध्रु possible. Verify. |
| cbse_9_sanskrit | कृदन्त? उदाहरणानि शीर्षक (item 12) | उदाहरणानि | OCR-verified spelling; item purpose (उदाहरण-based drill) clear. |
| cbse_9_sanskrit | अव्ययानि कालबोधक/अव्यय उपसूचियाँ | (कुछ पद) | Partially verified; कालबोधक 9th/8th items अपि/इदानीम्/सद्यः inferred from glyph context |
| cbse_10_sanskrit | तद्धित 3rd प्रत्यय | त्व | Consistent OCR; linguistically unusual — verify |
| cbse_10_sanskrit | स्त्रीप्रत्यय 2nd | ङीप् | Raw glyph ङ…प् supports ङीप् (classical form); OCR misreads as डीप् |
| cbse_10_sanskrit | वाच्यपरिवर्तन parenthetical | (कर्तृ-कर्म-क्रिया) | OCR consistent ×6; note: textbooks usually say कर्तृ-कर्म-भाव — PDF text-layer decodes ि…या = क्रिया (confirmed via 3 independent occurrences). Recorded as printed. |
| cbse_10_sanskrit | अव्ययपदानि list | (कुछ पद) | OCR-verified; अलं-तराम्/यावत्-किञ्चित् compound readings |
| cbse_10_sanskrit | शेमुषी अध्याय 6 | सौहार्द प्रकृतेः शोभा | High-zoom OCR “सौहार्द”; could be सौहृद in print — verify |
| cbse_10_sanskrit_communicative | तद्धित 3rd / स्त्री 2nd | त्व / ङीप् | Glyph degraded; same list as 122 (adopted from 122 OCR) |
| cbse_10_sanskrit_communicative | मणिका अध्याय 6 | राष्ट्रं संरक्ष्यमेव हि | OCR “राष्ट्रं संरक्ष्यमेव हि” ×2; verify |
| cbse_10_sanskrit_communicative | अव्ययानि list | (कुछ पद, दोहराव संभव) | Long list OCR’d with duplicates; verify against print |
| cbse_10_hindi_a | क्षितिज काव्य छूट-पाठ author | गिरिजाकुमार माथुर (छाया मत छूना) | OCR clean; flagged because raw text layer garbled |

**Nothing in this register blocks M2.** All entries are display/grounding strings for topics that remain officially in-scope; the marks, structure, IDs, and question patterns are fully verified.

## 6. What is NOT in this dataset (by design)

- No PYQs (M9 scope). No trusted teaching content (Layer 2, later milestones). No AI-generated material (Layer 3, later milestones). Layer labels per master plan §61 will be introduced when those layers land.
- No ICSE data. The loader and models are board-agnostic (`assets/syllabus/<board>/…`), CBSE is pure data — ICSE drops in later without engine changes.
- No Class 9 literature chapters — **because the official PDFs have not published them yet.** When CBSE/NCERT announces the lists, rerun `scripts/generate_syllabus.py` with the new source data; the schema and UI contract already model the pending state.

## 7. Verification summary

| Check | Result |
|---|---|
| Generator mark-arithmetic validation (7 courses) | PASS |
| Python invariant mirror of the Dart suite (432 checks) | PASS — 432/432 |
| Dart syntax smoke check (6 new files) | PASS |
| Board section sums = 80 for all 7 courses | PASS |
| Section item sums = section marks (all sections) | PASS |
| Internal components sum = 20 (where published) | PASS |
| ID uniqueness + per-course namespacing | PASS |
| Course isolation (A/B, 122/119, class 9/10) | PASS |
| Class 9 pending flags; Class 10 published | PASS |
| `flutter analyze` / `flutter test` | **NOT RUN — no Flutter SDK in the agent environment.** Run locally: `flutter test test/features/exam/syllabus/` (the tests mirror the 432 passing checks above). |

## 8. Files added/changed in this milestone

**Added (project):**
- `assets/syllabus/cbse/` — 8 JSON files (index + 7 courses)
- `lib/features/exam/data/syllabus/` — `syllabus_models.dart`, `syllabus_index.dart`, `syllabus_loader.dart`, `syllabus.dart`
- `test/features/exam/syllabus/` — `syllabus_models_test.dart`, `syllabus_loader_test.dart`
- `docs/Syllabus/INGESTION_REPORT.md` (this file)

**Modified (additive only, no behavior change):**
- `pubspec.yaml` — registered `assets/syllabus/cbse/` asset directory

**Untouched:** all existing app code, Learn Mode, VAN, gamification, AI stack, the existing exam screen and its 4 tests. Existing users' XP/streak/attempt data is unaffected (no storage or progress code changed).
