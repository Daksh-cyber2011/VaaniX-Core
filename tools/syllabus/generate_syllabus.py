#!/usr/bin/env python3
"""
VaaniX Exam Mode 2.0 — M1 Syllabus Ingestion Generator
=======================================================

Generates the canonical, structured CBSE syllabus data for the seven V1
course files (from the six official 2026-27 CBSE PDFs) plus the course
index, into the Flutter project's assets directory:

    assets/syllabus/cbse/index.json
    assets/syllabus/cbse/cbse_9_hindi_r1.json
    assets/syllabus/cbse/cbse_9_hindi_r2.json
    assets/syllabus/cbse/cbse_9_sanskrit.json
    assets/syllabus/cbse/cbse_10_hindi_a.json
    assets/syllabus/cbse/cbse_10_hindi_b.json
    assets/syllabus/cbse/cbse_10_sanskrit.json
    assets/syllabus/cbse/cbse_10_sanskrit_communicative.json

RULES ENCODED HERE (from the master plan):
  * The official PDF is the ONLY authority. Nothing is invented.
  * Every item has a stable ID; display names are never used as IDs.
  * Items the PDF has not published (Class 9 literature chapters) are
    flagged `pendingOfficialAnnouncement` — never fabricated.
  * Items whose source glyph could not be machine-verified with high
    confidence carry `ocrUncertain: true` and are listed in the
    ingestion report for human verification.
  * Internal-assessment components are preserved but classified
    `internal` (not board-exam scope).
"""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "syllabus", "cbse")

SCHEMA_VERSION = 1
SYLLABUS_VERSION = "2026-27"

BOARD = {"id": "cbse", "name": "Central Board of Secondary Education", "nameHi": "केन्द्रीय माध्यमिक शिक्षा बोर्ड"}


def q(pattern, marks_each=1, count=None, total=None):
    """Build a questionPattern object."""
    p = {"pattern": pattern, "marksEach": marks_each}
    if count is not None:
        p["count"] = count
    if total is not None:
        p["totalMarks"] = total
    return p


def item(track, section, key, title, title_en, marks=None, question_patterns=None,
         details=None, status="published", ocr_uncertain=False, note=None,
         exam_relevance="board", source_pages=None, content_tags=None):
    it = {
        "id": f"{track}_{section}_{key}",
        "title": title,
        "titleEn": title_en,
        "sectionId": f"{track}_{section}",
        "assessmentType": exam_relevance,
        "status": "published" if status == "published" else status,
    }
    if marks is not None:
        it["marks"] = marks
    if question_patterns:
        it["questionPatterns"] = question_patterns
    if details:
        it["details"] = details
    if ocr_uncertain:
        it["ocrUncertain"] = True
    if note:
        it["note"] = note
    if source_pages:
        it["sourceRef"] = {"pdf": source_pages[0], "pages": source_pages[1]}
    if content_tags:
        it["contentTags"] = content_tags
    return it


def section(track, key, title, title_en, marks, exam_relevance="board", items=None, note=None):
    s = {
        "id": f"{track}_{key}",
        "stableKey": key,
        "title": title,
        "titleEn": title_en,
        "marks": marks,
        "assessmentType": exam_relevance,
    }
    if note:
        s["note"] = note
    s["items"] = items if items else []
    return s


def course(track_id, class_num, subject, course_name, course_name_en,
           pdf_name, sections, books=None, pending=None, internal=None,
           duration_hours=3, notes=None, exam_total=80, subject_code=None):
    c = {
        "schemaVersion": SCHEMA_VERSION,
        "id": track_id,
        "board": BOARD,
        "class": class_num,
        "subject": subject,
        "course": {
            "id": track_id,
            "name": course_name,
            "nameEn": course_name_en,
            **({"subjectCode": subject_code} if subject_code else {}),
        },
        "syllabusVersion": SYLLABUS_VERSION,
        "source": {
            "authority": "Official CBSE curriculum document",
            "pdf": pdf_name,
            "extraction": "text-layer + OCR dual verification (see docs/Syllabus/INGESTION_REPORT.md)",
        },
        "assessment": {
            "boardExam": {
                "totalMarks": exam_total,
                "durationHours": duration_hours,
            },
            "internalAssessment": internal if internal else {"totalMarks": 20},
        },
        "sections": sections,
    }
    if books:
        c["prescribedBooks"] = books
    if pending:
        c["pendingOfficialAnnouncement"] = pending
    if notes:
        c["notes"] = notes
    return c


# ---------------------------------------------------------------------------
# TRACK 1: CBSE Class 9 Hindi — आर-1 (first language track)
# ---------------------------------------------------------------------------
T = "cbse_9_hindi_r1"
hi9_r1 = course(
    track_id=T, class_num=9,
    subject={"id": "hindi", "name": "हिन्दी"},
    course_name="हिन्दी आर-1", course_name_en="Hindi R-1 (First Language)",
    pdf_name="Hindi_SecP1IX_2026-27.pdf",
    internal={"totalMarks": 20, "components": None,
              "note": "PDF specifies 20 marks आंतरिक परीक्षा without a published component breakdown for 2026-27."},
    sections=[
        section(T, "unread", "अपठित बोध", "Unseen Comprehension", 14, items=[
            item(T, "unread", "prose", "अपठित गद्यांश (लगभग 200 शब्द)", "Unseen prose passage (~200 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=(T, [3, 4]), content_tags=["reading"]),
            item(T, "unread", "poetry", "अपठित काव्यांश (लगभग 80–100 शब्द)", "Unseen poetry passage (~80–100 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=(T, [4]), content_tags=["reading", "poetry"]),
        ]),
        section(T, "grammar", "व्यावहारिक व्याकरण", "Applied Grammar", 16,
                 note="कुल 20 प्रश्न पूछे जाएँगे; केवल 16 के उत्तर देने होंगे (1×16)।", items=[
            item(T, "grammar", "word_formation", "शब्द-निर्माण — उपसर्ग (2 अंक) एवं प्रत्यय (2 अंक)", "Word formation — prefixes & suffixes", 4,
                 [q("5 में से 4 प्रश्न", 1, 4, 4)],
                 details={"उपसर्ग": "2 अंक", "प्रत्यय": "2 अंक"},
                 source_pages=(T, [4]), content_tags=["grammar"]),
            item(T, "grammar", "parts_of_speech", "संज्ञा, सर्वनाम, विशेषण, क्रिया", "Noun, pronoun, adjective, verb", 4,
                 [q("5 में से 4 प्रश्न", 1, 4, 4)], source_pages=(T, [4]), content_tags=["grammar"]),
            item(T, "grammar", "sentence_types_meaning", "अर्थ की दृष्टि से वाक्य-भेद", "Sentence types by meaning", 4,
                 [q("5 में से 4 प्रश्न", 1, 4, 4)], source_pages=(T, [4, 5]), content_tags=["grammar"]),
            item(T, "grammar", "alankar", "अलंकार — शब्दालंकार: अनुप्रास, यमक, श्लेष", "Figures of speech — word-level: anupras, yamak, shlesh", 4,
                 [q("5 में से 4 प्रश्न", 1, 4, 4)],
                 details={"शब्दालंकार": ["अनुप्रास", "यमक", "श्लेष"]},
                 source_pages=(T, [5]), content_tags=["grammar", "poetics"]),
        ]),
        section(T, "literature", "पाठ्यपुस्तक", "Prescribed Textbook", 30,
                 note="NCERT पाठ्यपुस्तक (राष्ट्रीय पाठ्यचया रूपरेखा 2023 आधारित) — अध्याय सूची PDF में जारी नहीं है।",
                 items=[]),
        section(T, "writing", "रचनात्मक लेखन", "Creative Writing", 20, items=[
            item(T, "writing", "paragraph", "अनुच्छेद लेखन (लगभग 120 शब्द)", "Paragraph writing (~120 words)", 5,
                 source_pages=(T, [5]), content_tags=["writing"]),
            item(T, "writing", "letter_informal", "पत्र लेखन — अनौपचारिक (लगभग 100 शब्द, विकल्प सहित)", "Informal letter (~100 words, with choice)", 5,
                 source_pages=(T, [5]), content_tags=["writing"]),
            item(T, "writing", "dialogue", "संवाद लेखन (लगभग 80 शब्द, विकल्प सहित)", "Dialogue writing (~80 words, with choice)", 5,
                 source_pages=(T, [5]), content_tags=["writing"]),
            item(T, "writing", "notice", "सूचना लेखन (लगभग 80 शब्द, विकल्प सहित)", "Notice writing (~80 words, with choice)", 5,
                 source_pages=(T, [5]), content_tags=["writing"]),
        ]),
    ],
    pending={
        "appliesTo": "literature",
        "reason": "PDF (2026-27) prescribes the NCERT textbook issued under राष्ट्रीय पाठ्यचया रूपरेखा 2023 but does not publish book titles or chapter lists.",
        "sourceQuote": "राष्ट्रीय शैक्षणिक अनुसंधान परिषद की ओर द्वारा राष्ट्रीय पाठ्यचया की रूपरेखा 2023 के आधार पर जारी की गई पाठ्यपुस्तक के आधार पर साहित्य से संबंधित अध्ययन किया जाए।",
        "sourcePages": [5, 10],
        "action": "Chapter list must be ingested when CBSE/NCERT publishes it. Do NOT invent chapters.",
    },
    notes=["Class 9 Hindi (2026-27) is restructured under NCF-SE 2023 into आर-1 / आर-2 tracks; both come from the same official PDF."],
)

# ---------------------------------------------------------------------------
# TRACK 2: CBSE Class 9 Hindi — आर-2 (second language track)
# ---------------------------------------------------------------------------
T = "cbse_9_hindi_r2"
hi9_r2 = course(
    track_id=T, class_num=9,
    subject={"id": "hindi", "name": "हिन्दी"},
    course_name="हिन्दी आर-2", course_name_en="Hindi R-2 (Second Language)",
    pdf_name="Hindi_SecP1IX_2026-27.pdf",
    internal={"totalMarks": 20, "components": None,
              "note": "PDF specifies 20 marks आंतरिक परीक्षा without a published component breakdown for 2026-27."},
    sections=[
        section(T, "unread", "अपठित बोध", "Unseen Comprehension", 14,
                 note="दो अपठित गद्यांश (प्रत्येक लगभग 200 शब्द) — 7+7।", items=[
            item(T, "unread", "prose_a", "अपठित गद्यांश 1 (लगभग 200 शब्द)", "Unseen prose passage 1 (~200 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=(T, [9]), content_tags=["reading"]),
            item(T, "unread", "prose_b", "अपठित गद्यांश 2 (लगभग 200 शब्द)", "Unseen prose passage 2 (~200 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=(T, [9]), content_tags=["reading"]),
        ]),
        section(T, "grammar", "व्यावहारिक व्याकरण", "Applied Grammar", 16,
                 note="कुल 20 प्रश्न पूछे जाएँगे; केवल 16 के उत्तर देने होंगे (1×16)।", items=[
            item(T, "grammar", "word_bank", "शब्द भंडार — समानार्थक शब्द (2) एवं मुहावरे (2), पाठ्यपुस्तक के आधार पर", "Vocabulary — synonyms & idioms (textbook-based)", 4,
                 details={"समानार्थक शब्द": "2 अंक (3 में से 2)", "मुहावरे": "2 अंक (3 में से 2)", "आधार": "पाठ्यपुस्तक"},
                 source_pages=(T, [9]), content_tags=["vocabulary", "grammar"]),
            item(T, "grammar", "word_formation", "शब्द-निर्माण — उपसर्ग (2 अंक) एवं प्रत्यय (2 अंक)", "Word formation — prefixes & suffixes", 4,
                 [q("5 में से 4 प्रश्न", 1, 4, 4)],
                 details={"उपसर्ग": "2 अंक", "प्रत्यय": "2 अंक"},
                 source_pages=(T, [9]), content_tags=["grammar"]),
            item(T, "grammar", "punctuation", "विराम चिह्न", "Punctuation marks", 2,
                 [q("3 में से 2 प्रश्न", 1, 2, 2)], source_pages=(T, [9]), content_tags=["grammar", "orthography"]),
            item(T, "grammar", "noun_pronoun_nipat", "संज्ञा (2), सर्वनाम (2), निपात (2)", "Noun, pronoun & nipāta particles", 6,
                 [q("7 में से 6 प्रश्न", 1, 6, 6)],
                 details={"संज्ञा": "2 अंक", "सर्वनाम": "2 अंक", "निपात": "2 अंक"},
                 source_pages=(T, [9]), content_tags=["grammar"]),
        ]),
        section(T, "literature", "पाठ्यपुस्तक", "Prescribed Textbook", 30,
                 note="NCERT पाठ्यपुस्तक (राष्ट्रीय पाठ्यचया रूपरेखा 2023 आधारित) — अध्याय सूची PDF में जारी नहीं है।",
                 items=[]),
        section(T, "writing", "रचनात्मक लेखन", "Creative Writing", 20, items=[
            item(T, "writing", "paragraph", "अनुच्छेद लेखन (लगभग 100 शब्द)", "Paragraph writing (~100 words)", 5,
                 source_pages=(T, [10]), content_tags=["writing"]),
            item(T, "writing", "letter_informal", "पत्र लेखन — अनौपचारिक (लगभग 100 शब्द, विकल्प सहित)", "Informal letter (~100 words, with choice)", 5,
                 source_pages=(T, [10]), content_tags=["writing"]),
            item(T, "writing", "dialogue", "संवाद लेखन (लगभग 80 शब्द, विकल्प सहित)", "Dialogue writing (~80 words, with choice)", 5,
                 source_pages=(T, [10]), content_tags=["writing"]),
            item(T, "writing", "picture_composition", "किसी चित्र/घटना के आधार पर लेखन (लगभग 80 शब्द, बिना विकल्प के)", "Picture/event-based composition (~80 words, no choice)", 5,
                 source_pages=(T, [10]), content_tags=["writing"]),
        ]),
    ],
    pending={
        "appliesTo": "literature",
        "reason": "PDF (2026-27) prescribes the NCERT textbook issued under राष्ट्रीय पाठ्यचया रूपरेखा 2023 but does not publish book titles or chapter lists.",
        "sourceQuote": "राष्ट्रीय शैक्षणिक अनुसंधान परिषद की ओर द्वारा राष्ट्रीय पाठ्यचया की रूपरेखा 2023 के आधार पर जारी की गई पाठ्यपुस्तक के आधार पर साहित्य से संबंधित अध्ययन किया जाए।",
        "sourcePages": [5, 10],
        "action": "Chapter list must be ingested when CBSE/NCERT publishes it. Do NOT invent chapters.",
    },
    notes=["आर-2 is the second-language track per the PDF: ‘राष्ट्रीय पाठ्यचया की रूपरेखा 2023 के अनुसार द्वितीय भाषा के रूप में हिन्दी आर 2 के रूप में पढ़ाई जाएगी।’"],
)

# ---------------------------------------------------------------------------
# TRACK 3: CBSE Class 9 Sanskrit (नवमी)
# ---------------------------------------------------------------------------
T = "cbse_9_sanskrit"
sk9 = course(
    track_id=T, class_num=9,
    subject={"id": "sanskrit", "name": "संस्कृतम्"},
    course_name="संस्कृतम्", course_name_en="Sanskrit",
    pdf_name="Sanskrit_SecP1IX_2026-27.pdf",
    internal={"totalMarks": 20, "components": [
        {"id": f"{T}_internal_periodic", "title": "आवर्तक परीक्षा (पीरियडाइड टेस्ट, असैसमेंट)", "titleEn": "Periodic tests", "marks": 5},
        {"id": f"{T}_internal_subject_enrichment", "title": "विषयविध मूल्याङ्कन", "titleEn": "Subject enrichment", "marks": 5},
        {"id": f"{T}_internal_portfolio", "title": "निवेशसूचिका (पोर्टफोलियो)", "titleEn": "Portfolio", "marks": 5},
        {"id": f"{T}_internal_language_activities", "title": "भाषा-संवर्धनाय गतिविधयः (श्रवण-भाषण-लेखन)", "titleEn": "Language development activities", "marks": 5},
    ]},
    sections=[
        section(T, "unread", "अपठितावबोधनम्", "Unseen Comprehension", 10, items=[
            item(T, "unread", "gadyansh", "एकः गद्यांशः (80–100 शब्दपरिमितः), सरलकथा वा", "One unseen prose passage (80–100 words)", 10,
                 [q("अतिलघूत्तरात्मक 2×1", 1, 2, 2), q("दीर्घोत्तरात्मक 2×2", 2, 2, 4),
                  q("शीर्षकलेखनम् (लघूत्तरात्मक) 1×1", 1, 1, 1), q("अनुच्छेदाधारितं भाषिकं कार्यम् (बहुविकल्पीय) 3×1", 1, 3, 3)],
                 details={"भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "कतृ-क्रिया-अन्वितिः", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 source_pages=(T, [3]), content_tags=["reading"]),
        ]),
        section(T, "writing", "रचनात्मककार्यम्", "Creative Writing", 15, items=[
            item(T, "writing", "letter", "संकेताधारितम् औपचारिकम् अथवा अनौपचारिकं पत्रलेखनम्", "Cue-based formal/informal letter", 5,
                 [q("निबन्धात्मकः (मञ्जषायाः सहायतया रिक्तस्थानपूर्तिमाध्यमेन) 10×½", 0.5, 10, 5)],
                 details={"माध्यम": "मञ्जषा (शब्द-सहायता) + रिक्तस्थानपूर्ति"},
                 source_pages=(T, [3, 6]), content_tags=["writing"]),
            item(T, "writing", "picture_or_paragraph", "चित्राधारितं वर्णनम् अथवा अनुच्छेदलेखनम्", "Picture description or paragraph", 5,
                 details={"माध्यम": "मञ्जषायाः सहायतया"},
                 source_pages=(T, [3, 6]), content_tags=["writing"]),
            item(T, "writing", "dialogue_or_story", "संवादपूर्तिः / कथापूर्तिः", "Dialogue or story completion", 5,
                 [q("निबन्धात्मकः 10×½", 0.5, 10, 5)],
                 details={"कथा": "छात्रस्तरानुगुणम् एव भवेत्", "माध्यम": "मञ्जषा + रिक्तस्थानपूर्तिः"},
                 source_pages=(T, [3, 6]), content_tags=["writing"]),
        ]),
        section(T, "grammar", "अनुप्रयुक्तव्याकरणम्", "Applied Grammar", 25, items=[
            item(T, "grammar", "sandhi", "सन्धिः", "Sandhi (euphonic junctions)", 3,
                 [q("लघूत्तरात्मकाः 3×1", 1, 3, 3)],
                 details={
                     "स्वरसन्धिः": ["दीर्घः", "गुणः", "वृद्धिः", "यण्", "अयादि", "पूर्वरूपम्"],
                     "व्यञ्जनसन्धिः": ["जश्त्वसन्धिः", "‘म्’ स्थाने अनुस्वारः", "तुगागमः"],
                     "विसर्गसन्धिः": ["उत्", "विसर्गं स्थाने स्, श्, ष्", "रत्"],
                 },
                 source_pages=(T, [3, 6]), content_tags=["grammar"]),
            item(T, "grammar", "karaka", "कारक-उपपद-विभक्तयः", "Kāraka–upapada–vibhakti", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={
                     "द्वितीया": ["उभयतः", "अधिक्", "परितः", "समया", "निकषा", "प्रति", "विना"],
                     "तृतीया": ["सह", "साकम्", "समम्", "सार्धम्", "विना", "अलम्", "सदृश", "हीन"],
                     "चतुर्थी": ["रुच्", "दा (यच्छ्)", "नमः", "कुप्", "स्वस्ति"],
                     "पञ्चमी": ["विना", "बहिः", "भी", "रक्ष्", "ऋते"],
                     "षष्ठी": ["उपरि", "अधः", "पुरतः", "पृष्ठतः", "निर्धारणे"],
                     "सप्तमी": ["स्पृह्", "निपुणः", "विश्वस्", "पटु"],
                 },
                 ocr_uncertain=True,
                 note="कारक-उपपद सूचियों की पुष्टि OCR द्वारा की गई; कुछ शब्द (सदृश, स्वस्ति, रक्ष्, स्पृह्) OCR-अस्पष्ट हैं — docs/Syllabus/INGESTION_REPORT.md देखें।",
                 source_pages=(T, [6]), content_tags=["grammar"]),
            item(T, "grammar", "shabdarupa", "शब्दरूपाणि", "Noun declensions", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={
                     "पुंल्लिङ्गशब्दाः": ["बालकवत्", "कविवत्", "साधुवत्", "पितृवत्", "राजन्", "भवत्", "विश्वस्", "पाणिनः"],
                     "स्त्रीलिङ्गशब्दाः": ["लतावत्", "मतिवत्", "नदीवत्", "मातृवत्", "धेनुवत्"],
                     "नपुंसकलिङ्गशब्दाः": ["फलवत्", "वारि", "जगत्", "मनस्", "चक्षुष्"],
                     "सर्वनामशब्दाः": ["तत्", "इदम्", "किम् (त्रिषु लिङ्गेषु)", "अस्मद्", "युष्मद्"],
                 },
                 ocr_uncertain=True,
                 note="अंतिम पुंल्लिङ्ग शब्द OCR से ‘पाणिनः’ पढ़ा गया — रिपोर्ट में ध्वजित।",
                 source_pages=(T, [6]), content_tags=["grammar"]),
            item(T, "grammar", "dhaturupa", "धातुरूपाणि", "Verb conjugations", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={
                     "परस्मैपदिनः": ["पठ्", "गम्", "वद्", "भू", "क्रीड्", "नी", "दृश्", "शक्", "ज्ञा", "अस्", "कृ", "दा", "क्री", "ध्रु", "पा (पिब्)"],
                     "आत्मनेपदिनः": ["सेव्", "लभ्", "रुच्", "मुद्", "वृध्"],
                     "उभयपदिनः": ["कृ", "पच्", "नी", "कृष्", "वह्", "भज्"],
                     "लकाराः": "परस्मैपदिनः — पञ्चसु लकारेषु; आत्मनेपदिनः — लट्-लृट्-लोट्-लङ्-लकारेषु; उभयपदिनः — केवलं लट्लकारे",
                 },
                 ocr_uncertain=True,
                 note="क्री/ध्रु/दृश् तथा लकार-सीमाएँ OCR-सत्यापित; रिपोर्ट में ध्वजित।",
                 source_pages=(T, [6]), content_tags=["grammar"]),
            item(T, "grammar", "kridanta", "कृदन्तः — क्त्वा, तुमुन्, ल्यप्, क्त, क्तवतु, शतृ, शानच्", "Kṛdanta participles", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={"कृत्-प्रत्ययाः": ["क्त्वा", "तुमुन्", "ल्यप्", "क्त", "क्तवतु", "शतृ", "शानच्"]},
                 source_pages=(T, [6]), content_tags=["grammar"]),
            item(T, "grammar", "samasa", "समासः — तत्पुरुषः (विभक्ति-नञ्-उपपद-कर्मधारय)", "Samāsa — tatpuruṣa compounds", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={"तत्पुरुषभेदाः": ["विभक्ति-तत्पुरुषः", "नञ्-तत्पुरुषः", "उपपद-तत्पुरुषः", "कर्मधारयः"]},
                 source_pages=(T, [7]), content_tags=["grammar"]),
            item(T, "grammar", "sankhya", "सङ्ख्या — 1 से 100 (1–4 केवलं प्रथमा-विभक्तौ)", "Numbers 1–100", 3,
                 [q("लघूत्तरात्मकाः 3×1", 1, 3, 3)],
                 source_pages=(T, [7]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "udaharanani", "उदाहरणानि", "Example usage", 2,
                 [q("लघूत्तरात्मकाः 4×½", 0.5, 4, 2)],
                 ocr_uncertain=True,
                 note="शीर्षक OCR-सत्यापित ‘उदाहरणानि’; अस्पष्ट होने पर रिपोर्ट देखें।",
                 source_pages=(T, [4, 7]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "avyayani", "अव्ययानि", "Indeclinables", 2,
                 [q("लघूत्तरात्मकाः 4×½", 0.5, 4, 2)],
                 details={
                     "स्थानबोधकानि": ["इतः", "तत्र", "अन्यत्र", "सर्वत्र", "यत्र", "एकत्र", "उभयत्र"],
                     "कालबोधकानि": ["यदा", "तदा", "सर्वदा", "एकदा", "पुरा", "अधुना", "अपि", "इदानीम्", "सद्यः"],
                     "प्रश्नबोधकानि": ["किम्", "कुत्र", "कः", "कदा", "कुतः", "कथम्", "किमर्थम्"],
                     "अव्ययानि": ["च", "अपि", "यदि", "तर्हि", "यथा", "तथा", "एव", "तु"],
                 },
                 ocr_uncertain=True,
                 note="कालबोधक/अव्यय उपसूचियाँ आंशिक OCR-सत्यापित; रिपोर्ट देखें।",
                 source_pages=(T, [7]), content_tags=["grammar", "vocabulary"]),
        ]),
        section(T, "literature", "पठितावबोधनम्", "Prescribed Text Comprehension", 30,
                 note="निधारित पाठ्यपुस्तक: ‘शीघ्रमेव सूचयिष्यते’ — अध्याय सूची अभी जारी नहीं हुई। खंड-घ तालिका (PDF पृष्ठ 4) के अंक 5+5+5+5+4+3+3=30; ‘वार्षिकं मूल्याङ्कम्’ लेआउट (पृष्ठ 7) के साइड-अंक से सामान्य अंतर दिखता है — आधिकारिक अंक-पैटर्न योग के अनुरूप पृष्ठ 4 की तालिका ली गई (रिपोर्ट में ध्वजित)।", items=[
            item(T, "literature", "gadyansh", "गद्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Prose-passage comprehension", 5,
                 [q("अतिलघूत्तरात्मकौ 2×½", 0.5, 2, 1), q("दीर्घोत्तरात्मकौ 2×1", 1, 2, 2), q("लघूत्तरात्मकौ (भाषिककार्यम्) 2×1", 1, 2, 2)],
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कर्तृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 status="pendingOfficialAnnouncement",
                 source_pages=(T, [7]), content_tags=["literature", "reading"]),
            item(T, "literature", "padyansh", "पद्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Poetry-passage comprehension", 5,
                 [q("अतिलघूत्तरात्मकौ 2×½", 0.5, 2, 1), q("दीर्घोत्तरात्मकौ 2×1", 1, 2, 2), q("लघूत्तरात्मकौ (भाषिककार्यम्) 2×1", 1, 2, 2)],
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कर्तृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 status="pendingOfficialAnnouncement",
                 source_pages=(T, [7]), content_tags=["literature", "poetry"]),
            item(T, "literature", "natyansh", "नाट्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Drama-excerpt comprehension", 5,
                 [q("अतिलघूत्तरात्मकौ 2×½", 0.5, 2, 1), q("दीर्घोत्तरात्मकौ 2×1", 1, 2, 2), q("लघूत्तरात्मकौ (भाषिककार्यम्) 2×1", 1, 2, 2)],
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 status="pendingOfficialAnnouncement",
                 source_pages=(T, [7]), content_tags=["literature", "drama"]),
            item(T, "literature", "question_formation", "वाक्येषु रेखाङ्कितपदानि अधिकृत्य उचितप्रश्ननिर्माणम्", "Question formation from underlined words", 5,
                 [q("दीर्घोत्तरात्मकाः 5×1", 1, 5, 5)],
                 status="pendingOfficialAnnouncement", source_pages=(T, [4, 7]), content_tags=["literature", "grammar"]),
            item(T, "literature", "anvaya_bharth", "अन्वयः अथवा भावार्थः", "Anvaya or bhāvārtha", 4,
                 [q("दीर्घोत्तरात्मकः 4×1", 1, 4, 4)],
                 status="pendingOfficialAnnouncement", source_pages=(T, [4, 7]), content_tags=["literature", "poetry"]),
            item(T, "literature", "katha_purti", "पाठाधारित-कथापूर्तिः (मञ्जषापदसहायतया)", "Story completion with word-pool", 3,
                 [q("निबन्धात्मकः 6×½", 0.5, 6, 3)],
                 status="pendingOfficialAnnouncement", source_pages=(T, [4, 7]), content_tags=["literature", "writing"]),
            item(T, "literature", "artha_chayanam", "प्रसङ्गानुकूलम् अर्थचयनम्", "Context-appropriate meaning selection", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 status="pendingOfficialAnnouncement", source_pages=(T, [4, 7]), content_tags=["literature", "vocabulary"]),
        ]),
    ],
    books=[
        {"id": f"{T}_book_textbook", "title": "निधारित पाठ्यपुस्तक — शीघ्रमेव सूचयिष्यते", "publisher": "राष्ट्रीय शैक्षणिक अनुसंधान एवं प्रशिक्षण परिषद् (NCERT)", "status": "pendingOfficialAnnouncement"},
    ],
    pending={
        "appliesTo": "literature",
        "reason": "PDF states the prescribed textbook and chapter list will be announced shortly (शीघ्रमेव सूचयिष्यते).",
        "sourceQuote": "परीक्षायै निर्धारिताः पाठाः — शीघ्रमेव सूचयिष्यन्ते। निधारितपाठ्यपुस्तकम् — पाठ्यपुस्तकम् शीघ्रमेव सूचयिष्यते (प्रकाशनम् – रा.शै.अनु.प्र.परि.)। पुस्तकपाठादिसहितं पूर्णः पाठ्यक्रमः शीघ्रमेव सूचयिष्यते।",
        "sourcePages": [8],
        "action": "Ingest chapter list when announced. Literature items carry status=pendingOfficialAnnouncement until then.",
    },
    notes=[
        "CBSE has restructured Class 9 Sanskrit for 2026-27; chapter list pending official announcement — never invent.",
        "अनुप्रयुक्तव्याकरणस्य अंशानां चयनं यथासम्भवं पाठ्यपुस्तकात् करणीयम् (per PDF अवधेयम्).",
    ],
)

# ---------------------------------------------------------------------------
# TRACK 4: CBSE Class 10 Hindi A (code 002)
# ---------------------------------------------------------------------------
T = "cbse_10_hindi_a"
hi10a = course(
    track_id=T, class_num=10,
    subject={"id": "hindi", "name": "हिन्दी", "course": "A"},
    course_name="हिन्दी मातृभाषा (अ)", course_name_en="Hindi A (Mother Tongue)",
    subject_code="002",
    pdf_name="Hindi_A_SecP1_2026-27.pdf",
    internal={"totalMarks": 20, "components": [
        {"id": f"{T}_internal_periodic", "title": "सामयिक आकलन", "titleEn": "Periodic assessment", "marks": 5},
        {"id": f"{T}_internal_multiform", "title": "बहुविध आकलन", "titleEn": "Multiple assessment", "marks": 5},
        {"id": f"{T}_internal_portfolio", "title": "पोर्टफोलियो", "titleEn": "Portfolio", "marks": 5},
        {"id": f"{T}_internal_listen_speak", "title": "श्रवण एवं वाचन (परीक्षण 2.5+2.5)", "titleEn": "Listening & speaking", "marks": 5},
    ]},
    sections=[
        section(T, "unread", "अपठित बोध", "Unseen Comprehension", 14, items=[
            item(T, "unread", "prose", "अपठित गद्यांश (लगभग 250 शब्द)", "Unseen prose passage (~250 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [9]), content_tags=["reading"]),
            item(T, "unread", "poetry", "अपठित काव्यांश (लगभग 120 शब्द)", "Unseen poetry passage (~120 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [9]), content_tags=["reading", "poetry"]),
        ]),
        section(T, "grammar", "व्यावहारिक व्याकरण", "Applied Grammar", 16,
                 note="कुल 20 प्रश्न पूछे जाएँगे; केवल 16 के उत्तर देने होंगे (1×16)।", items=[
            item(T, "grammar", "vakya_bhed", "रूप के आधार पर वाक्य भेद", "Sentence types by form", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [9]), content_tags=["grammar"]),
            item(T, "grammar", "vachya", "वाच्य", "Voice", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [9]), content_tags=["grammar"]),
            item(T, "grammar", "pad_parichay", "पद परिचय", "Word identification", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [9]), content_tags=["grammar"]),
            item(T, "grammar", "alankar", "अलंकार — अर्थालंकार: उपमा, रूपक, उत्प्रेक्षा, अतिशयोक्ति, मानवीकरण", "Figures of speech (meaning-level)", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)],
                 details={"अर्थालंकार": ["उपमा", "रूपक", "उत्प्रेक्षा", "अतिशयोक्ति", "मानवीकरण"]},
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [10]), content_tags=["grammar", "poetics"]),
        ]),
        section(T, "literature", "पाठ्यपुस्तक एवं पूरक पाठ्यपुस्तक", "Prescribed & Supplementary Books", 30, items=[
            item(T, "literature", "kshitij_prose", "गद्य खंड — क्षितिज भाग 2 (निर्धारित पाठ)", "Prose — Kshitij Part 2", 11,
                 [q("बहुविकल्पीय 1×5", 1, 5, 5), q("लघूत्तरात्मक (25–30 शब्द, 4 में से 3) 2×3", 2, 3, 6)],
                 details={"excludedChapters": [
                     {"author": "महावीरप्रसाद द्विवेदी", "chapter": "स्त्री-शिक्षा के विरोधी कुतर्कों का खंडन", "scope": "पूरा पाठ छोड़ा गया"},
                     {"author": "सर्वेश्वर दयाल सक्सेना", "chapter": "मानवीय करुणा की दिव्य चमक", "scope": "पूरा पाठ छोड़ा गया"},
                 ]},
                 note="अध्याय-स्तरीय सूची PDF में नहीं है; दायरा पुस्तक-खंड स्तर पर, आधिकारिक छूट सूची सहित।",
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [10, 11]), content_tags=["literature", "prose"]),
            item(T, "literature", "kshitij_poetry", "काव्य खंड — क्षितिज भाग 2 (निर्धारित कविताएँ)", "Poetry — Kshitij Part 2", 11,
                 [q("बहुविकल्पीय 1×5", 1, 5, 5), q("लघूत्तरात्मक (25–30 शब्द, 4 में से 3) 2×3", 2, 3, 6)],
                 details={"excludedChapters": [
                     {"author": "देव", "chapter": "सवैया, कवित्त", "scope": "पूरा पाठ छोड़ा गया"},
                     {"author": "गिरिजाकुमार माथुर", "chapter": "छाया मत छूना", "scope": "पूरा पाठ छोड़ा गया", "ocrUncertain": True},
                     {"author": "ऋतुराज", "chapter": "कन्यादान", "scope": "पूरा पाठ छोड़ा गया"},
                 ]},
                 note="छोड़े गए काव्य खंड के लेखक/पाठ OCR-सत्यापित।",
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [11]), content_tags=["literature", "poetry"]),
            item(T, "literature", "kritika", "पूरक पाठ्यपुस्तक — कृतिका भाग 2 (निर्धारित पाठ)", "Supplementary — Kritika Part 2", 8,
                 [q("प्रश्न (50–60 शब्द, 3 में से 2) 4×2", 4, 2, 8)],
                 details={"excludedChapters": [
                     {"chapter": "एही ठैयाँ झुलनी हेरानी हो रामा!", "scope": "पूरा पाठ छोड़ा गया"},
                     {"chapter": "जार्ज पंचम की नाक", "scope": "पूरा पाठ छोड़ा गया"},
                 ]},
                 source_pages=("Hindi_A_SecP1_2026-27.pdf", [10, 11]), content_tags=["literature", "prose"]),
        ]),
        section(T, "writing", "रचनात्मक लेखन", "Creative Writing", 20, items=[
            item(T, "writing", "paragraph", "अनुच्छेद लेखन (लगभग 120 शब्द, संकेत-बिंदु आधारित, 3 विषयों में से 1)", "Paragraph writing (~120 words)", 6,
                 [q("6×1", 6, 1, 6)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [10]), content_tags=["writing"]),
            item(T, "writing", "letter", "पत्र लेखन — औपचारिक अथवा अनौपचारिक (लगभग 100 शब्द)", "Formal or informal letter (~100 words)", 5,
                 [q("5×1", 5, 1, 5)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [10]), content_tags=["writing"]),
            item(T, "writing", "swavritt_or_email", "स्ववृत्त लेखन (लगभग 80 शब्द) अथवा ई-मेल लेखन (लगभग 80 शब्द)", "Résumé or e-mail writing (~80 words)", 5,
                 [q("5×1", 5, 1, 5)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [10]), content_tags=["writing"]),
            item(T, "writing", "ad_or_message", "विज्ञापन लेखन (लगभग 40 शब्द) अथवा संदेश लेखन (लगभग 40 शब्द)", "Advertisement or message writing (~40 words)", 4,
                 [q("4×1", 4, 1, 4)], source_pages=("Hindi_A_SecP1_2026-27.pdf", [10, 11]), content_tags=["writing"]),
        ]),
    ],
    books=[
        {"id": f"{T}_book_kshitij", "title": "क्षितिज, भाग–2", "publisher": "एन.सी.ई.आर.टी. (NCERT), नई दिल्ली — नवीनतम संस्करण", "status": "published"},
        {"id": f"{T}_book_kritika", "title": "कृतिका, भाग–2", "publisher": "एन.सी.ई.आर.टी. (NCERT), नई दिल्ली — नवीनतम संस्करण", "status": "published"},
    ],
    notes=[
        "विस्तृत प्रश्न-पत्र प्रारूप हेतु बोर्ड की वेबसाइट पर जारी आदर्श प्रश्न-पत्र देखें (PDF नोट)।",
        "नोट: निम्नलिखित पाठों से प्रश्न नहीं पूछे जाएँगे — क्षितिज काव्य: देव (सवैया, कवित्त), गिरिजाकुमार माथुर (छाया मत छूना), ऋतुराज (कन्यादान); गद्य: महावीरप्रसाद द्विवेदी (स्त्री-शिक्षा के विरोधी कुतर्कों का खंडन), सर्वेश्वर दयाल सक्सेना (मानवीय करुणा की दिव्य चमक); कृतिका: एही ठैयाँ झुलनी हेरानी हो रामा!, जार्ज पंचम की नाक।",
    ],
)

# ---------------------------------------------------------------------------
# TRACK 5: CBSE Class 10 Hindi B (code 085)
# ---------------------------------------------------------------------------
T = "cbse_10_hindi_b"
hi10b = course(
    track_id=T, class_num=10,
    subject={"id": "hindi", "name": "हिन्दी", "course": "B"},
    course_name="हिन्दी ब", course_name_en="Hindi B",
    subject_code="085",
    pdf_name="Hindi_B_SecP1_2026-27.pdf",
    internal={"totalMarks": 20, "components": [
        {"id": f"{T}_internal_periodic", "title": "सामयिक आकलन", "titleEn": "Periodic assessment", "marks": 5},
        {"id": f"{T}_internal_multiform", "title": "बहुविध आकलन", "titleEn": "Multiple assessment", "marks": 5},
        {"id": f"{T}_internal_portfolio", "title": "पोर्टफोलियो", "titleEn": "Portfolio", "marks": 5},
        {"id": f"{T}_internal_listen_speak", "title": "श्रवण एवं वाचन (परीक्षण 2.5+2.5)", "titleEn": "Listening & speaking", "marks": 5},
    ]},
    sections=[
        section(T, "unread", "अपठित बोध (बहुविकल्पीय प्रश्न)", "Unseen Comprehension (MCQ)", 14,
                 note="दो अपठित गद्यांश (प्रत्येक लगभग 200 शब्द) — 7+7।", items=[
            item(T, "unread", "prose_a", "अपठित गद्यांश 1 (लगभग 200 शब्द)", "Unseen prose passage 1 (~200 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["reading"]),
            item(T, "unread", "prose_b", "अपठित गद्यांश 2 (लगभग 200 शब्द)", "Unseen prose passage 2 (~200 words)", 7,
                 [q("बहुविकल्पीय (MCQ) 1×3", 1, 3, 3), q("अतिलघूत्तरात्मक / लघूत्तरात्मक 2×2", 2, 2, 4)],
                 source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["reading"]),
        ]),
        section(T, "grammar", "व्यावहारिक व्याकरण", "Applied Grammar", 16,
                 note="कुल 20 प्रश्न पूछे जाएँगे; केवल 16 के उत्तर देने होंगे (1×16)।", items=[
            item(T, "grammar", "padbandh", "पदबंध", "Phrases", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
            item(T, "grammar", "vakya_roopantaran", "रूप के आधार पर वाक्य रूपांतरण", "Sentence transformation by form", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
            item(T, "grammar", "samasa", "समास", "Compounds", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
            item(T, "grammar", "muhavare", "मुहावरे", "Idioms", 4,
                 [q("5 में से 4 प्रश्न 1×4", 1, 4, 4)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [7]), content_tags=["grammar", "vocabulary"]),
        ]),
        section(T, "literature", "पाठ्यपुस्तक एवं पूरक पाठ्यपुस्तक", "Prescribed & Supplementary Books", 28, items=[
            item(T, "literature", "sparsh_prose", "गद्य खंड — स्पर्श भाग 2 (निर्धारित पाठ)", "Prose — Sparsh Part 2", 11,
                 [q("बहुविकल्पीय 1×5", 1, 5, 5), q("लघूत्तरात्मक (25–30 शब्द, 4 में से 3) 2×3", 2, 3, 6)],
                 details={"excludedChapters": [
                     {"author": "अंतोन चेखव", "chapter": "गिरगिट", "scope": "पूरा पाठ छोड़ा गया"},
                 ]},
                 source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["literature", "prose"]),
            item(T, "literature", "sparsh_poetry", "काव्य खंड — स्पर्श भाग 2 (निर्धारित कविताएँ)", "Poetry — Sparsh Part 2", 11,
                 [q("बहुविकल्पीय 1×5", 1, 5, 5), q("लघूत्तरात्मक (25–30 शब्द, 4 में से 3) 2×3", 2, 3, 6)],
                 details={"excludedChapters": [
                     {"author": "बिहारी", "chapter": "बिहारी-दोहे", "scope": "पूरा पाठ छोड़ा गया"},
                     {"author": "महादेवी वर्मा", "chapter": "मधुर-मधुर मेरे दीपक जल", "scope": "पूरा पाठ छोड़ा गया"},
                 ]},
                 source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["literature", "poetry"]),
            item(T, "literature", "sanchayan", "पूरक पाठ्यपुस्तक — संचयन भाग 2 (निर्धारित पाठ)", "Supplementary — Sanchayan Part 2", 6,
                 [q("प्रश्न (50–60 शब्द, 3 में से 2) 3×2", 3, 2, 6)],
                 details={"note": "पुस्तक में कोई परिवर्तन नहीं — कोई भी पाठ नहीं हटाया गया है।"},
                 source_pages=("Hindi_B_SecP1_2026-27.pdf", [8, 9]), content_tags=["literature", "prose"]),
        ]),
        section(T, "writing", "रचनात्मक लेखन", "Creative Writing", 22, items=[
            item(T, "writing", "paragraph", "अनुच्छेद लेखन (लगभग 120 शब्द, 3 विषयों में से 1)", "Paragraph writing (~120 words)", 5,
                 [q("5×1", 5, 1, 5)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["writing"]),
            item(T, "writing", "letter_formal", "पत्र लेखन — औपचारिक (लगभग 100 शब्द, विकल्प सहित)", "Formal letter (~100 words, with choice)", 5,
                 [q("5×1", 5, 1, 5)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["writing"]),
            item(T, "writing", "suchna", "सूचना लेखन (लगभग 60 शब्द, विकल्प सहित)", "Notice writing (~60 words, with choice)", 4,
                 [q("4×1", 4, 1, 4)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["writing"]),
            item(T, "writing", "advertisement", "विज्ञापन लेखन (लगभग 40 शब्द, विकल्प सहित)", "Advertisement writing (~40 words, with choice)", 3,
                 [q("3×1", 3, 1, 3)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [8]), content_tags=["writing"]),
            item(T, "writing", "email_or_story", "ई-मेल लेखन (लगभग 80 शब्द) अथवा लघुकथा लेखन (लगभग 100 शब्द)", "E-mail (~80 words) or short story (~100 words)", 5,
                 [q("5×1", 5, 1, 5)], source_pages=("Hindi_B_SecP1_2026-27.pdf", [8, 9]), content_tags=["writing"]),
        ]),
    ],
    books=[
        {"id": f"{T}_book_sparsh", "title": "स्पर्श, भाग–2", "publisher": "एन.सी.ई.आर.टी. (NCERT), नई दिल्ली — नवीनतम संस्करण", "status": "published"},
        {"id": f"{T}_book_sanchayan", "title": "संचयन, भाग–2", "publisher": "एन.सी.ई.आर.टी. (NCERT), नई दिल्ली — नवीनतम संस्करण", "status": "published"},
    ],
    notes=[
        "विस्तृत प्रश्न-पत्र प्रारूप हेतु बोर्ड की वेबसाइट पर जारी आदर्श प्रश्न-पत्र देखें (PDF नोट)।",
        "नोट: निम्नलिखित पाठों से प्रश्न नहीं पूछे जाएँगे — स्पर्श: बिहारी-दोहे, महादेवी वर्मा (मधुर-मधुर मेरे दीपक जल), अंतोन चेखव (गिरगिट)। संचयन: कोई परिवर्तन नहीं, कोई पाठ हटाया नहीं गया।",
    ],
)

# ---------------------------------------------------------------------------
# TRACK 6: CBSE Class 10 Sanskrit (code 122)
# ---------------------------------------------------------------------------
T = "cbse_10_sanskrit"
sk10 = course(
    track_id=T, class_num=10,
    subject={"id": "sanskrit", "name": "संस्कृतम्"},
    course_name="संस्कृतम्", course_name_en="Sanskrit",
    subject_code="122",
    pdf_name="Sanskrit_SecP1_2026-27.pdf",
    internal={"totalMarks": 20, "components": [
        {"id": f"{T}_internal_periodic", "title": "आवर्तक परीक्षा (पीरियोडाइड टेस्ट, असैसमेंट)", "titleEn": "Periodic tests", "marks": 5},
        {"id": f"{T}_internal_subject_enrichment", "title": "विषयविध मूल्याङ्कन", "titleEn": "Subject enrichment", "marks": 5},
        {"id": f"{T}_internal_portfolio", "title": "निवेशसूचिका (पोर्टफोलियो)", "titleEn": "Portfolio", "marks": 5},
        {"id": f"{T}_internal_language_activities", "title": "भाषा-संवर्धनाय गतिविधयः (श्रवण-भाषण-लेखन)", "titleEn": "Language development activities", "marks": 5},
    ]},
    sections=[
        section(T, "unread", "अपठितावबोधनम्", "Unseen Comprehension", 10, items=[
            item(T, "unread", "gadyansh", "एकः गद्यांशः (80–100 शब्दपरिमितः), सरलकथा वणननम् वा", "One unseen prose passage (80–100 words)", 10,
                 [q("अतिलघूत्तरात्मकौ 2×1", 1, 2, 2), q("पूर्णवाक्यात्मकौ 2×2", 2, 2, 4),
                  q("शीर्षकलेखनम् (लघूत्तरात्मकः) 1×1", 1, 1, 1), q("अनुच्छेदाधारितं भाषिकं कार्यम् (बहुविकल्पीयाः) 3×1", 1, 3, 3)],
                 details={"भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "कतृ-क्रिया-अन्वितिः", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [3, 5]), content_tags=["reading"]),
        ]),
        section(T, "writing", "रचनात्मककार्यम्", "Creative Writing", 15, items=[
            item(T, "writing", "letter", "संकेताधारितम् औपचारिकम् अथवा अनौपचारिकं पत्रलेखनम् (मञ्जषायाः सहायतया पूर्णं पत्रं लेखनीयम्)", "Cue-based formal/informal letter (full letter from word-pool)", 5,
                 [q("निबन्धात्मकः 10×½", 0.5, 10, 5)],
                 details={"संकेताः": {
                     "औपचारिकम्": ["संस्कृतभाषा-संवर्धनाय", "शिक्षामहालयाय", "नामसंशोधनाय नगरनिगमाय", "धनादेश-असमर्थतायै सूचनायै विद्यालयविभागाय", "शुचिनिवारणार्थं स्वास्थ्याधिकारिणे", "प्रकाशकाय"],
                     "अनौपचारिकम्": ["कुशलसमाचारपत्रम्", "वधार्थं पत्रम्", "निमन्त्रणपत्रम्", "परिणामसूचनापत्रम्", "विद्यालयवर्णनम्"],
                 }},
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [3, 5]), content_tags=["writing"]),
            item(T, "writing", "picture_or_diary", "चित्राधारितं वर्णनम् अथवा अनुच्छेदलेखनम् (मञ्जषायाः सहायतया)", "Picture description or paragraph (with word-pool)", 5,
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [3, 6]), content_tags=["writing"]),
            item(T, "writing", "translation", "हिन्दीभाषायाम् आङ्ग्लभाषायां वा लिखितानां पूर्ववाक्यानां संस्कृतभाषायाम् अनुवादः", "Translation of sentences (from Hindi/English into Sanskrit)", 5,
                 [q("पूर्णवाक्यात्मकाः 5×1", 1, 5, 5)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [3]), content_tags=["writing", "translation"]),
        ]),
        section(T, "grammar", "अनुप्रयुक्तव्याकरणम्", "Applied Grammar", 25, items=[
            item(T, "grammar", "sandhi", "सन्धिकार्यम्", "Sandhi", 4,
                 [q("लघूत्तरात्मकाः 4×1", 1, 4, 4)],
                 details={
                     "स्वरसन्धिः": ["यण्", "अयादि", "पूर्वरूपसन्धिः"],
                     "व्यञ्जनसन्धिः": ["वर्गीयप्रथमवर्णं तृतीयवर्णं परिवर्तनम्", "प्रथमवर्णं पञ्चमवर्णं परिवर्तनम्"],
                     "विसर्गसन्धिः": ["विसर्गं उत्", "रत्", "विसर्गलोपः", "विसर्गं स्थाने स्, श्, ष्"],
                 },
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
            item(T, "grammar", "samasa", "समासः — वाक्येषु समापदानां विग्रहः विग्रहपदानां च समासः", "Samāsa — vigraha and synthesis", 4,
                 [q("बहुविकल्पीयाः 4×1", 1, 4, 4)],
                 details={
                     "तत्पुरुषः": ["विभक्ति-तत्पुरुषः", "उपपद-तत्पुरुषः", "कर्मधारयः"],
                     "बहुव्रीहिः": [],
                     "अव्ययीभावः": ["अनु", "उप", "सह", "निर्", "प्रति", "यथा"],
                     "द्वन्द्वः": [],
                 },
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
            item(T, "grammar", "kridanta", "कृदन्ताः — कृत्प्रत्ययाः, तद्धिताः, स्त्रीप्रत्ययौ", "Kṛdanta — participles & suffixes", 4,
                 [q("बहुविकल्पीयाः 4×1", 1, 4, 4)],
                 details={
                     "कृत्प्रत्ययाः": ["तव्यत्", "अनीयर्", "क्त", "क्तवतु"],
                     "तद्धिताः": ["मतुप्", "ठक्", "त्व", "तल्"],
                     "स्त्रीप्रत्ययौ": ["टाप्", "ङीप्"],
                 },
                 ocr_uncertain=True,
                 note="तद्धित ‘त्व’ तथा स्त्री ‘ङीप्’ OCR-सत्यापित — रिपोर्ट देखें।",
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
            item(T, "grammar", "vachya", "वाच्यपरिवर्तनम् — केवलं लट्लकारे (कर्तृ-कर्म-क्रिया)", "Voice transformation (laṭ only)", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
            item(T, "grammar", "samaya", "समयः — अङ्कानां स्थाने शब्देषु समयलेखनम् (सामान्य-सपाद-सार्ध-पादोन)", "Writing time in words", 4,
                 [q("लघूत्तरात्मकाः 4×1", 1, 4, 4)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "avyayapadani", "अव्ययपदानि", "Indeclinables", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 details={"अव्ययानि": ["उच्चैः", "च", "नीचैः", "मृदुना", "अपि", "अलं-तराम्", "यावत्-किञ्चित्", "इदानीम्", "अधुना", "सद्यः", "साक्षात्", "यदा", "तदा", "कदा", "सहसा", "वृथा", "शनैः", "अपि", "कुतः", "इतरतः", "यदि-तर्हि", "यावत्-तावत्"]},
                 ocr_uncertain=True,
                 note="अव्यय-सूची OCR-सत्यापित; कुछ पद अस्पष्ट — रिपोर्ट देखें।",
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "ashuddhi", "अशुद्धि-संशोधनम् (वचन-लिङ्ग-पुरुष-लकार-विभक्तिदृष्ट्या संशोधनम्)", "Error correction", 3,
                 [q("बहुविकल्पीयाः 3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
        ]),
        section(T, "literature", "पठितावबोधनम्", "Prescribed Text Comprehension", 30, items=[
            item(T, "literature", "gadyansh", "गद्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Prose-passage comprehension", 5,
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "reading"]),
            item(T, "literature", "padyansh", "पद्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Poetry-passage comprehension", 5,
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "poetry"]),
            item(T, "literature", "natyansh", "नाट्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Drama-excerpt comprehension", 5,
                 details={"प्रश्नप्रकाराः": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्", "सर्वनामस्थाने संज्ञाप्रयोगः"]},
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "drama"]),
            item(T, "literature", "prashnanirmana", "वाक्येषु रेखाङ्कितपदानि अधिकृत्य चतुर्णां प्रश्नानां निर्माणम्", "Question formation from underlined words", 4,
                 [q("पूर्णवाक्यात्मकाः 4×1", 1, 4, 4)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "grammar"]),
            item(T, "literature", "shlokanvaya", "श्लोकान्वयः — एकस्य श्लोकस्य संस्कृतेन भावार्थलेखनम्", "Śloka anvaya — Sanskrit bhāvārtha", 4,
                 [q("पूर्णवाक्यात्मकाः 4×1", 1, 4, 4)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "poetry"]),
            item(T, "literature", "kathalekhanam", "घटनाक्रमानुसारं कथालेखनम्", "Event-order story writing", 4,
                 [q("पूर्णवाक्यात्मकाः 8×½", 0.5, 8, 4)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "writing"]),
            item(T, "literature", "arthalekhanam", "प्रसङ्गानुकूलम् अर्थलेखनम् (पाठान् आधृत्य लघूत्तरात्मकाः प्रश्नाः)", "Context-appropriate meaning", 3,
                 [q("लघूत्तरात्मकाः 3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_SecP1_2026-27.pdf", [7]), content_tags=["literature", "vocabulary"]),
        ]),
    ],
    books=[
        {"id": f"{T}_book_shemushi", "title": "शेमुषी पाठ्यपुस्तकम् भाग-2 (संशोधितसंस्करणम्)", "publisher": "रा.शै.अनु.प्र.परि. (NCERT)", "status": "published",
         "chapters": [
             {"number": 1, "id": f"{T}_ch_shemushi_1", "title": "शुचिपर्यावरणम्", "type": "prose"},
             {"number": 2, "id": f"{T}_ch_shemushi_2", "title": "बुद्धिर्बलवती सदा", "type": "poetry"},
             {"number": 3, "id": f"{T}_ch_shemushi_3", "title": "शिशुलालनम्", "type": "prose"},
             {"number": 4, "id": f"{T}_ch_shemushi_4", "title": "जननी तुल्यवत्सला", "type": "poetry"},
             {"number": 5, "id": f"{T}_ch_shemushi_5", "title": "सुभाषितानि", "type": "poetry"},
             {"number": 6, "id": f"{T}_ch_shemushi_6", "title": "सौहार्द प्रकृतेः शोभा", "type": "prose", "ocrUncertain": True},
             {"number": 7, "id": f"{T}_ch_shemushi_7", "title": "विचित्रः साक्षी", "type": "prose"},
             {"number": 8, "id": f"{T}_ch_shemushi_8", "title": "सूक्तयः", "type": "poetry"},
             {"number": 10, "id": f"{T}_ch_shemushi_10", "title": "अन्योक्तयः", "type": "poetry"},
         ],
         "note": "पाठ 9 (नवमः) आधिकारिक तालिका में सूचित नहीं है — तालिका 1–8 तथा 10 पाठ दर्ज करती है। पाठ 9 जोड़ा नहीं गया (अनुमान वर्जित)।"},
        {"id": f"{T}_book_abhyasvan", "title": "अभ्यासवान् भव — द्वितीयो भागः (व्याकरणपुस्तकम्)", "publisher": "रा.शै.अनु.प्र.परि. (NCERT)", "status": "published"},
        {"id": f"{T}_book_vyakaranavithi", "title": "व्याकरणवीथिः (व्याकरणपुस्तकम्)", "publisher": "रा.शै.अनु.प्र.परि. (NCERT)", "status": "published"},
    ],
    notes=[
        "अवधेयम्: अनुप्रयुक्तव्याकरणस्य अंशानां चयनं यथासम्भवं ‘शेमुषी-द्वितीयो भागः’ पाठ्यपुस्तकात् करणीयम्; यदि ततः न सम्भवति तर्हि ‘अभ्यासवान् भव-द्वितीयो भागः’ इत्यस्मात् चेतुं शक्यते।",
    ],
)

# ---------------------------------------------------------------------------
# TRACK 7: CBSE Class 10 Sanskrit Communicative (code 119)
# ---------------------------------------------------------------------------
T = "cbse_10_sanskrit_communicative"
sk10c = course(
    track_id=T, class_num=10,
    subject={"id": "sanskrit", "name": "संस्कृतम्", "course": "communicative"},
    course_name="संस्कृतम् (संप्रेषणात्मकम्)", course_name_en="Sanskrit Communicative",
    subject_code="119",
    pdf_name="Sanskrit_Communiucative_SecP1_2026-27.pdf",
    internal={"totalMarks": 20, "components": [
        {"id": f"{T}_internal_periodic", "title": "आवर्तक परीक्षा (पीरियोडाइड टेस्ट, असैसमेंट)", "titleEn": "Periodic tests", "marks": 5},
        {"id": f"{T}_internal_subject_enrichment", "title": "विषयविध मूल्याङ्कन", "titleEn": "Subject enrichment", "marks": 5},
        {"id": f"{T}_internal_portfolio", "title": "निवेशसूचिका (पोर्टफोलियो)", "titleEn": "Portfolio", "marks": 5},
        {"id": f"{T}_internal_language_activities", "title": "भाषा-संवर्धनाय गतिविधयः (श्रवण-भाषण-लेखन)", "titleEn": "Language development activities", "marks": 5},
    ]},
    sections=[
        section(T, "unread", "अपठितावबोधनम्", "Unseen Comprehension", 10, items=[
            item(T, "unread", "gadyansh", "एकः गद्यांशः (80–100 शब्दपरिमितः), सरलकथा", "One unseen prose passage (80–100 words)", 10,
                 [q("अतिलघूत्तरात्मकौ 2×1", 1, 2, 2), q("पूर्णवाक्यात्मकौ 2×2", 2, 2, 4),
                  q("शीर्षकलेखनम् (लघूत्तरात्मकः) 1×1", 1, 1, 1), q("गद्यांशाधारितं भाषिकं कार्यम् (बहुविकल्पीयाः) 3×1", 1, 3, 3)],
                 details={"भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्"]},
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [3, 6]), content_tags=["reading"]),
        ]),
        section(T, "writing", "रचनात्मककार्यम्", "Creative Writing", 15, items=[
            item(T, "writing", "letter", "संकेताधारितम् औपचारिकम् अथवा अनौपचारिकं पत्रलेखनम् (मञ्जषायाः सहायतया पूर्णं पत्रं लेखनीयम्)", "Cue-based formal/informal letter", 5,
                 [q("निबन्धात्मकः 10×½", 0.5, 10, 5)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [3, 6]), content_tags=["writing"]),
            item(T, "writing", "picture_or_diary", "चित्राधारितं वर्णनम् अथवा अनुच्छेदलेखनम् (मञ्जषायाः सहायतया)", "Picture description or paragraph", 5,
                 [q("पूर्णवाक्यात्मकः 5×1", 1, 5, 5)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [3, 6]), content_tags=["writing"]),
            item(T, "writing", "dialogue_or_story", "संवादपूर्तिः / कथापूर्तिः (कथा छात्रस्तरानुगुणम् एव भवेत्)", "Dialogue or story completion", 5,
                 [q("निबन्धात्मकः 10×½", 0.5, 10, 5)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [3, 6]), content_tags=["writing"]),
        ]),
        section(T, "grammar", "अनुप्रयुक्तव्याकरणम्", "Applied Grammar", 25, items=[
            item(T, "grammar", "sandhi", "सन्धिकार्यम् (1+1+2)", "Sandhi", 4,
                 [q("4×1", 1, 4, 4)],
                 details={
                     "स्वरसन्धिः": ["वृद्धिः", "यण्", "अयादि", "पूर्वरूपम्"],
                     "व्यञ्जनसन्धिः": ["परसवर्णः (अनुस्वारस्थाने पञ्चमवर्णप्रयोगः)", "तुगागमः", "वर्गीयप्रथमवर्णं तृतीयवर्णं परिवर्तनम्"],
                     "विसर्गसन्धिः": ["उत्", "रत्", "विसर्गलोपः", "विसर्गं स्थाने स्, श्, ष्"],
                 },
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [6]), content_tags=["grammar"]),
            item(T, "grammar", "samasa", "समासाः — वाक्येषु समापदानां विग्रहः विग्रहपदानां च समासः (2+1+1)", "Samāsa — vigraha and synthesis", 4,
                 [q("4×1", 1, 4, 4)],
                 details={
                     "तत्पुरुषः": ["विभक्तिः", "नञ्", "उपपदः"],
                     "द्वन्द्वः": [],
                     "अव्ययीभावः": ["अनु", "उप", "सह", "निर्", "प्रति", "यथा"],
                 },
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [6, 7]), content_tags=["grammar"]),
            item(T, "grammar", "kridanta", "कृदन्ताः (1+2+1)", "Kṛdanta", 4,
                 [q("4×1", 1, 4, 4)],
                 details={
                     "कृत्-प्रत्ययाः": ["तव्यत्", "अनीयर्"],
                     "तद्धिताः": ["मतुप्", "ठक्", "त्व", "तल्"],
                     "स्त्री-प्रत्ययौ": ["टाप्", "ङीप्"],
                 },
                 ocr_uncertain=True,
                 note="तद्धित तृतीय प्रत्यय तथा ङीप् OCR-अस्पष्ट — रिपोर्ट देखें।",
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
            item(T, "grammar", "vachya", "वाच्यपरिवर्तनम् — केवलं लट्लकारे (कर्तृ-कर्म-क्रिया)", "Voice transformation (laṭ only)", 3,
                 [q("3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
            item(T, "grammar", "samaya", "समयः — अङ्कानां स्थाने शब्देषु समयलेखनम् (सामान्य-सपाद-सार्ध-पादोन)", "Writing time in words", 3,
                 [q("3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "avyayani", "अव्ययानि", "Indeclinables", 4,
                 [q("4×1", 1, 4, 4)],
                 details={"अव्ययानि": ["इव", "उच्चैः", "एव", "नूनम्", "इतरतः", "विना", "तु", "सहसा", "वृथा", "शनैः", "इति", "मा", "यत्", "अथ", "सद्यः", "इदानीम्", "अधुना", "यावत्-तावत्", "बहिः", "कदापि", "तु", "च", "अपि", "पुरा", "अलं-तराम्", "यथा-तथा", "कदा", "अपि", "नीचैः", "परनीचैः", "नीचैः", "परनीचैः", "नीचैः", "किमर्थम्", "कुत्र", "यदि-तर्हि", "अतः"]},
                 ocr_uncertain=True,
                 note="अव्यय-सूची OCR-सत्यापित; दोहराव/अस्पष्ट पद संभव — रिपोर्ट देखें।",
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["grammar", "vocabulary"]),
            item(T, "grammar", "ashuddhi", "अशुद्धि-संशोधनम् (वचन-विलिङ्ग(?)-पुरुष-लकार-विभक्तिदृष्ट्या संशोधनम्)", "Error correction", 3,
                 [q("3×1", 1, 3, 3)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["grammar"]),
        ]),
        section(T, "literature", "पठितावबोधनम्", "Prescribed Text Comprehension", 30, items=[
            item(T, "literature", "gadyansh", "गद्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Prose-passage comprehension", 5,
                 details={"प्रश्ननिर्माणम्": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्"]},
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["literature", "reading"]),
            item(T, "literature", "padyansh", "पद्यम् (श्लोकम्/श्लोकौ) अधिकृत्य अवबोधनात्मकं कार्यम्", "Poetry (śloka) comprehension", 5,
                 details={"प्रश्ननिर्माणम्": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्"]},
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["literature", "poetry"]),
            item(T, "literature", "natyansh", "नाट्यांशम् अधिकृत्य अवबोधनात्मकं कार्यम्", "Drama-excerpt comprehension", 5,
                 details={"प्रश्ननिर्माणम्": "एकपदेन पूर्णवाक्येन च", "भाषिककार्यम्": ["वाक्ये कतृ-क्रियापदचयनम्", "विशेषण-विशेष्यचयनम्", "पर्याय-विलोमपदचयनम्"]},
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7]), content_tags=["literature", "drama"]),
            item(T, "literature", "prashnanirmana", "वाक्येषु रेखाङ्कितपदानि अधिकृत्य चतुर्णां प्रश्नानां निर्माणम्", "Question formation from underlined words", 5,
                 [q("पूर्णवाक्यात्मकाः 5×1", 1, 5, 5)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [4, 7]), content_tags=["literature", "grammar"]),
            item(T, "literature", "shloka_bharth", "एकस्य श्लोकस्य अन्वयः अथवा भावार्थः (मञ्जषायाः सहायतया)", "Anvaya or bhāvārtha of one śloka", 2,
                 [q("निबन्धात्मकः 4×½", 0.5, 4, 2)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [7, 8]), content_tags=["literature", "poetry"]),
            item(T, "literature", "prashnachayanam", "प्रसङ्गानुसारम् अर्थचयनम् (पाठान् आधृत्य बहुविकल्पीयाः प्रश्नाः)", "Context-appropriate meaning (MCQ)", 4,
                 [q("4×1", 1, 4, 4)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [8]), content_tags=["literature", "vocabulary"]),
            item(T, "literature", "katha_purti", "पाठाधारित-कथापूर्तिः (मञ्जषापदसहायतया)", "Story completion with word-pool", 4,
                 [q("निबन्धात्मकः 8×½", 0.5, 8, 4)],
                 source_pages=("Sanskrit_Communiucative_SecP1_2026-27.pdf", [8]), content_tags=["literature", "writing"]),
        ]),
    ],
    books=[
        {"id": f"{T}_book_manika", "title": "मणिका — द्वितीयो भागः (पाठ्यपुस्तकम्)", "publisher": "केन्द्रीय माध्यमिक शिक्षा बोर्ड (CBSE), भारतम्", "status": "published",
         "chapters": [
             {"number": 1, "id": f"{T}_ch_manika_1", "title": "वाङ्मयं तपः", "type": "prose"},
             {"number": 2, "id": f"{T}_ch_manika_2", "title": "नास्ति त्यागसमं सुखम्", "type": "prose"},
             {"number": 3, "id": f"{T}_ch_manika_3", "title": "रमणीया हि सृष्टिः एषा", "type": "poetry"},
             {"number": 4, "id": f"{T}_ch_manika_4", "title": "आज्ञा गुरूणां हि अविचारणीया", "type": "prose"},
             {"number": 5, "id": f"{T}_ch_manika_5", "title": "अभ्यासवशगं मनः", "type": "poetry"},
             {"number": 6, "id": f"{T}_ch_manika_6", "title": "राष्ट्रं संरक्ष्यमेव हि", "type": "poetry", "ocrUncertain": True},
             {"number": 7, "id": f"{T}_ch_manika_7", "title": "साधुवृत्तं समाचरेत्", "type": "poetry"},
             {"number": 8, "id": f"{T}_ch_manika_8", "title": "तिरुक्कुरल्-सूक्ति-सौरभम्", "type": "poetry"},
             {"number": 9, "id": f"{T}_ch_manika_9", "title": "सुस्वागतं भो! अरुणाचलेऽस्मिन्", "type": "prose"},
             {"number": 10, "id": f"{T}_ch_manika_10", "title": "कालोऽहम्", "type": "prose", "examRelevance": "internal-only"},
             {"number": 11, "id": f"{T}_ch_manika_11", "title": "किं किम् उपादेयम्", "type": "prose", "examRelevance": "internal-only"},
         ],
         "note": "पाठ 10 तथा 11 ‘केवलम् आन्तरिकमूल्याङ्कनाय’ चिह्नित हैं (PDF स्वयं)।"},
        {"id": f"{T}_book_manika_abhyas", "title": "मणिका-अभ्यासपुस्तकम् — द्वितीयो भागः", "publisher": "केन्द्रीय माध्यमिक शिक्षा बोर्ड (CBSE), भारतम्", "status": "published"},
    ],
    notes=[
        "अवधेयम्: अनुप्रयुक्तव्याकरणस्य अंशानां चयनं यथासम्भवं ‘मणिका-द्वितीयो भागः’ पाठ्यपुस्तकात् करणीयम्; यदि ततः न सम्भवति तर्हि ‘मणिका-अभ्यासपुस्तकम् द्वितीयो भागः’ इत्यस्मात् चेतुं शक्यते।",
    ],
)

# ---------------------------------------------------------------------------
# Index + write
# ---------------------------------------------------------------------------
COURSES = [hi9_r1, hi9_r2, sk9, hi10a, hi10b, sk10, sk10c]

index = {
    "schemaVersion": SCHEMA_VERSION,
    "board": BOARD,
    "syllabusVersion": SYLLABUS_VERSION,
    "description": "VaaniX canonical syllabus index. Official CBSE 2026-27 curriculum documents are the sole authority; see docs/Syllabus/INGESTION_REPORT.md.",
    "classes": [
        {
            "class": 9,
            "subjects": [
                {"id": "hindi", "name": "हिन्दी", "courses": [
                    {"id": "cbse_9_hindi_r1", "name": "हिन्दी आर-1", "nameEn": "Hindi R-1 (First Language)", "file": "cbse_9_hindi_r1.json", "literatureStatus": "pendingOfficialAnnouncement"},
                    {"id": "cbse_9_hindi_r2", "name": "हिन्दी आर-2", "nameEn": "Hindi R-2 (Second Language)", "file": "cbse_9_hindi_r2.json", "literatureStatus": "pendingOfficialAnnouncement"},
                ]},
                {"id": "sanskrit", "name": "संस्कृतम्", "courses": [
                    {"id": "cbse_9_sanskrit", "name": "संस्कृतम्", "nameEn": "Sanskrit", "file": "cbse_9_sanskrit.json", "literatureStatus": "pendingOfficialAnnouncement"},
                ]},
            ],
        },
        {
            "class": 10,
            "subjects": [
                {"id": "hindi", "name": "हिन्दी", "courses": [
                    {"id": "cbse_10_hindi_a", "name": "हिन्दी मातृभाषा (अ)", "nameEn": "Hindi A", "subjectCode": "002", "file": "cbse_10_hindi_a.json", "literatureStatus": "published"},
                    {"id": "cbse_10_hindi_b", "name": "हिन्दी ब", "nameEn": "Hindi B", "subjectCode": "085", "file": "cbse_10_hindi_b.json", "literatureStatus": "published"},
                ]},
                {"id": "sanskrit", "name": "संस्कृतम्", "courses": [
                    {"id": "cbse_10_sanskrit", "name": "संस्कृतम्", "nameEn": "Sanskrit", "subjectCode": "122", "file": "cbse_10_sanskrit.json", "literatureStatus": "published"},
                    {"id": "cbse_10_sanskrit_communicative", "name": "संस्कृतम् (संप्रेषणात्मकम्)", "nameEn": "Sanskrit Communicative", "subjectCode": "119", "file": "cbse_10_sanskrit_communicative.json", "literatureStatus": "published"},
                ]},
            ],
        },
    ],
}

os.makedirs(OUT, exist_ok=True)


def validate(course):
    """Invariants that must hold for every generated course file."""
    errors = []
    # 1. Section marks sum to board total (only board sections)
    board_marks = sum(s["marks"] for s in course["sections"] if s["assessmentType"] == "board")
    expect = course["assessment"]["boardExam"]["totalMarks"]
    if board_marks != expect:
        errors.append(f"board sections sum {board_marks} != {expect}")
    # 2. Item marks within a section sum to section marks (when items declare marks)
    for s in course["sections"]:
        with_marks = [i for i in s.get("items", []) if i.get("marks") is not None]
        if with_marks:
            total = sum(i["marks"] for i in with_marks)
            if total != s["marks"]:
                errors.append(f"section {s['id']}: items sum {total} != {s['marks']}")
        else:
            if s.get("items"):
                errors.append(f"section {s['id']}: has items but none declare marks")
    # 3. Internal components sum
    ia = course["assessment"]["internalAssessment"]
    if ia.get("components"):
        csum = sum(c["marks"] for c in ia["components"])
        if csum != ia["totalMarks"]:
            errors.append(f"internal components sum {csum} != {ia['totalMarks']}")
    # 4. Unique IDs
    ids = [s["id"] for s in course["sections"]]
    for s in course["sections"]:
        ids += [i["id"] for i in s.get("items", [])]
    for b in course.get("prescribedBooks", []):
        ids.append(b["id"])
        ids += [c["id"] for c in b.get("chapters", [])]
    dupes = {x for x in ids if ids.count(x) > 1}
    if dupes:
        errors.append(f"duplicate ids: {dupes}")
    # 5. Item -> section linkage
    for s in course["sections"]:
        for i in s.get("items", []):
            if i["sectionId"] != s["id"]:
                errors.append(f"item {i['id']} sectionId mismatch")
    return errors


print("=" * 70)
print("VALIDATION RESULTS")
print("=" * 70)
all_ok = True
for c in COURSES:
    errs = validate(c)
    n_sec = len(c["sections"])
    n_items = sum(len(s.get("items", [])) for s in c["sections"])
    n_ch = sum(len(b.get("chapters", [])) for b in c.get("prescribedBooks", []))
    status = "OK " if not errs else "FAIL"
    print(f"[{status}] {c['id']}: {n_sec} sections, {n_items} items, {n_ch} chapters, "
          f"board={c['assessment']['boardExam']['totalMarks']}")
    for e in errs:
        print(f"        - {e}")
        all_ok = False

if not all_ok:
    raise SystemExit("VALIDATION FAILED — not writing files")

with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

for c in COURSES:
    with open(os.path.join(OUT, f"{c['id']}.json"), "w", encoding="utf-8") as f:
        json.dump(c, f, ensure_ascii=False, indent=2)
    print(f"wrote {c['id']}.json")

print("\nAll files written to", OUT)
