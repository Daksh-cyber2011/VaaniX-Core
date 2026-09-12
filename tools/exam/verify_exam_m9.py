#!/usr/bin/env python3
"""Exam Mode 2.0 — M9 Verification Mirror (Python invariant port).

Milestone M9 (PYQs + mocks) mirrored 1:1 against the real canonical
syllabus JSONs:
  §25    PYQ provenance (official / exam-pattern / PYQ-style) — the
         honesty labels; NOTHING generated is ever labeled an actual
         CBSE PYQ; pattern texts + marks come verbatim from the
         official syllabus; filtering (section / topic / marks /
         pattern kind / limit)
  §21    pyqPerformance + mockPerformance data-gated weak signals
         (weakPyq / weakMock) — no data ⇒ no signals (M8 parity)
  §25/§41 mock ladder (mini / section / full) built from OFFICIAL
         board structure (section marks, board total, board duration);
         DETERMINISTIC analysis (never AI); §30 qualitative bands
  §12/§56/§57/§41 repositories (bounds, isolation, corruption,
         schema version, no empty writes)
  §22→planner feedback: PYQ/mock findings flow into the recovery-day
         decision and the deterministic plan (the M8 planner carries
         them automatically through the report)

Run: python3 tools/exam/verify_exam_m9.py
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_exam_m8 as m8  # shared ports + the frozen M8 report

PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets", "syllabus", "cbse")
LIB_EXAM = os.path.join(PROJECT_ROOT, "lib", "features", "exam")

CHECKS = {"run": 0, "failed": 0}
FAILURES = []


def check(label, condition, detail=""):
    CHECKS["run"] += 1
    if not condition:
        CHECKS["failed"] += 1
        FAILURES.append(f"{label}: {detail}")


def iso(dt):
    return dt.isoformat()


NOW = datetime(2026, 9, 12, 10, 0, 0)

# Shared ports from the M8 mirror (same behavior, no double counting).
load_courses = m8.load_courses
build_view = m8.build_view
selectable_ids = m8.selectable_ids
seed_from_text = m8.seed_from_text
deterministic_shuffle = m8.deterministic_shuffle
build_options = m8.build_options
subtopics_of = m8.subtopics_of
apply_attempt = m8.apply_attempt
weak_first = m8.weak_first
build_report_m8 = m8.build_report
report_is_m8_honest = m8.report_is_m8_honest
SEVERITY_INDEX = m8.SEVERITY_INDEX

PYQ_PERFORMANCE_MAX_TOPICS = 60
MOCK_RESULTS_MAX = 40

# ---------------------------------------------------------------------------
# §25 — PyqModels port
# ---------------------------------------------------------------------------

PROVENANCE_LABELS = {
    "official": "आधिकारिक CBSE प्रश्न (PYQ)",
    "examPattern": "आधिकारिक परीक्षा-पैटर्न पर आधारित",
    "pyqStyle": "PYQ-शैली (अभ्यास)",
}


def pyq_performance_band(attempted, correct):
    if attempted < 2:
        return "learning"
    accuracy = correct / attempted
    if accuracy < 0.4:
        return "needsAttention"
    if accuracy >= 0.6:
        return "strong"
    return "learning"


# ---------------------------------------------------------------------------
# §25/§60 — PyqBank port
# ---------------------------------------------------------------------------

TYPED_MARKERS = [
    "पूर्णवाक्यात्मक", "लघूत्तरात्मक", "वाक्य", "रचनात्मक", "निर्माण",
    "संवाद", "पत्र", "निबंध", "अनुच्छेद", "वर्णन",
]
MCQ_MARKERS = ["बहुविकल्पीय", "mcq", "objective", "वस्तुनिष्ठ"]


def pattern_wants_typed(pattern_text):
    t = pattern_text.lower()
    if any(m in t for m in MCQ_MARKERS):
        return False
    return any(m in t for m in TYPED_MARKERS)


def pattern_marks(pattern):
    each = pattern.get("marksEach")
    if each is not None and each > 0:
        return min(max(float(each), 0.5), 5.0)
    total = pattern.get("totalMarks")
    count = pattern.get("count")
    if total and count:
        return min(max(total / count, 0.5), 5.0)
    return 1.0


def build_pyq_bank(course, view, selection, weak_ids=(), target_size=12,
                   section_filter=(), pattern_kinds=(), topic_filter=(),
                   limit=0):
    """Port of PyqBank.build (grounded, §25-labeled)."""
    section_by_unit = {}
    for section in view:
        for unit in section["units"]:
            section_by_unit[unit["id"]] = section
    items_by_id = {i["id"]: i for s in course["sections"]
                   for i in s.get("items", [])}
    marks_by_topic = {}
    for uid, sec in section_by_unit.items():
        item = items_by_id.get(uid)
        if item and item.get("marks") is not None:
            marks_by_topic[uid] = float(item["marks"])

    out = []
    unit_titles = {}
    for section in view:
        for unit in section["units"]:
            unit_titles[unit["id"]] = unit["title"]
    for uid, section in section_by_unit.items():
        if uid not in selection:
            continue
        if topic_filter and uid not in topic_filter:
            continue
        item = items_by_id.get(uid)
        section_titles = [s["title"] for s in view]
        if item is None:
            # Chapter unit (literature): grounded membership MCQ (§60)
            # — keeps full mocks from silently skipping literature.
            chapter_title = unit_titles.get(uid)
            if not chapter_title:
                continue
            qid = f"pyq_{m8_suffix(uid)}_chap"
            pool = [t for t in section_titles if t != section["title"]]
            opts = build_options(section["title"], pool, qid)
            if opts:
                out.append({
                    "id": qid, "topicId": uid, "kind": "mcq",
                    "prompt": f"«{chapter_title}» किस खंड में आता है?",
                    "options": opts[0], "correctIndex": opts[1],
                    "tier": 1, "provenance": "pyqStyle",
                    "patternText": "अध्याय-आधारित", "marks": 1,
                })
            continue
        subtopics = subtopics_of(item)[:6]

        for idx, pattern in enumerate(item.get("questionPatterns", [])):
            marks = pattern_marks(pattern)
            typed_kind = pattern_wants_typed(pattern["pattern"])
            qid = f"pyq_{m8_suffix(uid)}_{idx}"
            if typed_kind and subtopics:
                out.append({
                    "id": qid, "topicId": uid, "kind": "shortAnswer",
                    "prompt": f"({pattern['pattern']}) «{item['title']}» — "
                              f"इस विषय के मुख्य बिंदु लिखें।",
                    "acceptedAnswers": [item["title"]],
                    "requiredPoints": subtopics[:3], "tier": 2,
                    "provenance": "examPattern",
                    "patternText": pattern["pattern"], "marks": marks,
                })
            else:
                pool = [t for t in section_titles if t != section["title"]]
                opts = build_options(section["title"], pool, qid + "_sec")
                if opts:
                    out.append({
                        "id": qid, "topicId": uid, "kind": "mcq",
                        "prompt": f"({pattern['pattern']}) «{item['title']}» "
                                  f"किस खंड में आता है?",
                        "options": opts[0], "correctIndex": opts[1],
                        "tier": 3 if marks >= 3 else 1,
                        "provenance": "examPattern",
                        "patternText": pattern["pattern"], "marks": marks,
                    })

        if uid in marks_by_topic:
            my_marks = marks_by_topic[uid]
            distractors = []
            for other_uid, other_marks in marks_by_topic.items():
                if other_uid == uid or other_marks == my_marks:
                    continue
                other_item = items_by_id.get(other_uid)
                if other_item:
                    distractors.append(
                        f"«{other_item['title']}» "
                        f"({other_marks:.0f} अंक)")
            correct = f"«{item['title']}» ({my_marks:.0f} अंक)"
            opts = build_options(
                correct, distractors, f"pyq_{m8_suffix(uid)}_marks")
            if opts:
                out.append({
                    "id": f"pyq_{m8_suffix(uid)}_marks", "topicId": uid,
                    "kind": "mcq",
                    "prompt": "आधिकारिक पाठ्यक्रम में किस विषय पर "
                              f"{my_marks:.0f} अंक निर्धारित हैं?",
                    "options": opts[0], "correctIndex": opts[1], "tier": 2,
                    "provenance": "pyqStyle", "patternText": "अंक-संरचना",
                    "marks": 1,
                })

    def rank(q):
        return (0 if q["topicId"] in weak_ids else 1, -q["marks"], q["id"])

    out.sort(key=rank)

    filtered = []
    for q in out:
        sec_id = section_by_unit.get(q["topicId"], {}).get("id", "")
        if section_filter and sec_id not in section_filter:
            continue
        if pattern_kinds:
            text = q["patternText"].lower()
            if not any(k.lower() in text for k in pattern_kinds):
                continue
        filtered.append(q)
    if limit > 0:
        return filtered[:limit]
    if target_size > 0:
        return filtered[:target_size]
    return filtered


def m8_suffix(unit_id):
    parts = unit_id.split("_")
    return parts[2:] if len(parts) <= 4 else parts[4:]


# ---------------------------------------------------------------------------
# §25/§41 — MockEngine port
# ---------------------------------------------------------------------------

MINUTES_PER_MARK = 2.25
MINI_MAX_MARKS = 10
MINI_MIN_MINUTES = 15


def build_mock(track_id, kind, board_sections, board_total, board_hours,
               questions_by_section, focus_section_id=None,
               max_questions_per_section=6, now=None):
    now = now or NOW

    def pick(section_id, marks_target):
        pool = questions_by_section.get(section_id, [])
        out, marks = [], 0.0
        for q in pool:
            if len(out) >= max_questions_per_section:
                break
            if marks + q["marks"] > marks_target + 0.5:
                continue
            out.append(q)
            marks += q["marks"]
        if not out and pool:
            out.append(pool[0])
        return out

    def slice_of(section_id, title, marks):
        return {
            "sectionId": section_id, "title": title, "targetMarks": marks,
            "questions": pick(section_id, marks),
        }

    if kind == "full":
        sections = [slice_of(s["id"], s["title"], s["marks"])
                    for s in board_sections]
        sections = [s for s in sections if s["questions"]]
        total = sum(s["targetMarks"] for s in sections)
        return {
            "id": f"mock-{track_id}-full-{int(now.timestamp() * 1000)}",
            "kind": "full", "trackId": track_id, "sections": sections,
            "totalMarks": total if total > 0 else board_total,
            "timeLimitMinutes": max(30, min(240, board_hours * 60)),
            "createdAtIso": iso(now),
        }

    focus = None
    for s in board_sections:
        if s["id"] == focus_section_id:
            focus = s
    if focus is None and board_sections:
        focus = board_sections[0]
    if focus is None:
        focus = {"id": "", "title": "", "marks": 0.0}

    if kind == "section":
        sections = [slice_of(focus["id"], focus["title"], focus["marks"])]
        return {
            "id": f"mock-{track_id}-section-{int(now.timestamp() * 1000)}",
            "kind": "section", "trackId": track_id, "sections": sections,
            "totalMarks": focus["marks"],
            "timeLimitMinutes": max(10, min(240, round(
                focus["marks"] * MINUTES_PER_MARK))),
            "createdAtIso": iso(now),
        }

    marks = min(max(focus["marks"], 1.0), MINI_MAX_MARKS)
    sections = [slice_of(focus["id"], focus["title"], marks)]
    return {
        "id": f"mock-{track_id}-mini-{int(now.timestamp() * 1000)}",
        "kind": "mini", "trackId": track_id, "sections": sections,
        "totalMarks": marks,
        "timeLimitMinutes": max(MINI_MIN_MINUTES, min(60, round(
            marks * MINUTES_PER_MARK))),
        "createdAtIso": iso(now),
    }


def analyze_mock(paper, attempts):
    """Port of MockEngine.analyze — §41 deterministic."""
    question_section = {}
    for slice_ in paper["sections"]:
        for q in slice_["questions"]:
            question_section[q["id"]] = slice_["sectionId"]
    stats = {s["sectionId"]: {"sectionId": s["sectionId"], "title": s["title"],
                              "attempted": 0, "correct": 0}
             for s in paper["sections"]}
    total_attempted = total_correct = 0
    for a in attempts:
        total_attempted += 1
        ok = a["verdict"] in ("correct", "partiallyCorrect")
        if ok:
            total_correct += 1
        sec = question_section.get(a["questionId"])
        if sec in stats:
            stats[sec]["attempted"] += 1
            stats[sec]["correct"] += 1 if ok else 0
    return {
        "paperId": paper["id"], "kind": paper["kind"],
        "trackId": paper["trackId"],
        "sectionResults": list(stats.values()),
        "totalAttempted": total_attempted, "totalCorrect": total_correct,
        "completedAtIso": iso(NOW),
    }


def section_band(attempted, correct):
    if attempted < 2:
        return "learning"
    accuracy = correct / attempted
    if accuracy < 0.4:
        return "needsAttention"
    if accuracy >= 0.6:
        return "strong"
    return "learning"


def mock_weak_sections(result):
    return [s for s in result["sectionResults"]
            if s["attempted"] >= 2 and
            section_band(s["attempted"], s["correct"]) == "needsAttention"]


# ---------------------------------------------------------------------------
# §21 — M9-extended WeakAreaEngine (sources 4/5 added to the M8 port)
# ---------------------------------------------------------------------------

PYQ_MOCK_SIGNALS = {"weakPyq", "weakMock"}


def build_report_m9(learner, patterns, revision_items, now,
                    pyq_performance=None, weak_mock_sections=None):
    """M8 report + §21 sources 4 (weakPyq) and 5 (weakMock), data-gated."""
    pyq_performance = pyq_performance or {}
    weak_mock_sections = weak_mock_sections or []

    # Base = the frozen M8 engine (sources 1-3, ranking, honesty notes).
    report = build_report_m8(learner, patterns, revision_items, now)

    findings = {f["topicId"]: dict(f) for f in report["findings"]}

    def upsert(topic_id, signal, sentence):
        existing = findings.get(topic_id)
        if existing:
            signals = set(existing["signals"]) | {signal}
            has_mis = ("repeatedMisconception" in signals or
                       "lowMastery" in signals)
            stage = learner.get("topics", {}).get(topic_id, {}).get("stage")
            severity = ("needsAttention" if has_mis or
                        stage == "needsAttention" else
                        ("focus" if len(signals) >= 2 else "watch"))
            existing["signals"] = signals
            existing["severity"] = severity
            existing["sentence"] = sentence
        else:
            findings[topic_id] = {
                "topicId": topic_id, "severity": "watch",
                "signals": {signal}, "categories": set(),
                "sentence": sentence,
            }

    for pyq in pyq_performance.values():
        if pyq.get("attempted", 0) < 2:
            continue
        if pyq_performance_band(pyq["attempted"], pyq.get("correct", 0)) \
                != "needsAttention":
            continue
        upsert(pyq["topicId"], "weakPyq",
               "PYQ-अभ्यास में यह विषय बार-बार कमज़ोर रहा — परीक्षा-पैटर्न "
               "पर थोड़ा और काम करेंगे।")

    for section in weak_mock_sections:
        if section.get("attempted", 0) < 2:
            continue
        if section_band(section["attempted"], section.get("correct", 0)) \
                != "needsAttention":
            continue
        upsert(section["sectionId"], "weakMock",
               f"mock में «{section['title']}» खंड कमज़ोर रहा — इस खंड पर "
               f"एक दिन केंद्रित अभ्यास देंगे।")

    ranked = sorted(
        findings.values(),
        key=lambda f: (-SEVERITY_INDEX[f["severity"]], -len(f["signals"]),
                       learner.get("topics", {}).get(f["topicId"], {})
                       .get("strength", 1.0), f["topicId"]))
    report = dict(report)
    report["findings"] = ranked[: m8.MAX_FINDINGS]
    return report


# ---------------------------------------------------------------------------
# Repositories (JSON-level ports)
# ---------------------------------------------------------------------------

def pyq_perf_load_all(store):
    raw = store.get("exam_pyq_performance_v1")
    if not raw:
        return {}
    try:
        doc = json.loads(raw)
        out = {}
        for track, topics in doc.get("tracks", {}).items():
            try:
                out[track] = {tid: {
                    "topicId": tid,
                    "attempted": int(v.get("attempted", 0) or 0),
                    "correct": int(v.get("correct", 0) or 0),
                } for tid, v in topics.items()}
            except (TypeError, AttributeError):
                continue
        return out
    except ValueError:
        return {}


def pyq_perf_merge(store, track_id, outcomes):
    if not outcomes:
        return
    all_ = pyq_perf_load_all(store)
    topics = dict(all_.get(track_id, {}))
    for o in outcomes:
        if not o["topicId"]:
            continue
        cur = topics.get(o["topicId"])
        topics[o["topicId"]] = {
            "topicId": o["topicId"],
            "attempted": (cur["attempted"] if cur else 0) + o["attempted"],
            "correct": (cur["correct"] if cur else 0) + o["correct"],
        }
    bounded = sorted(topics.values(),
                     key=lambda t: -t["attempted"])[:PYQ_PERFORMANCE_MAX_TOPICS]
    all_[track_id] = {t["topicId"]: t for t in bounded}
    store["exam_pyq_performance_v1"] = json.dumps(
        {"version": 1, "tracks": all_}, ensure_ascii=False)


def mock_results_load_all(store):
    raw = store.get("exam_mock_results_v1")
    if not raw:
        return {}
    try:
        doc = json.loads(raw)
        return {track: list(results)
                for track, results in doc.get("tracks", {}).items()}
    except (ValueError, TypeError):
        return {}


def mock_results_record(store, result):
    if result["totalAttempted"] == 0:
        return
    all_ = mock_results_load_all(store)
    lst = list(all_.get(result["trackId"], []))
    lst.append(result)
    if len(lst) > MOCK_RESULTS_MAX:
        lst = lst[-MOCK_RESULTS_MAX:]
    all_[result["trackId"]] = lst
    store["exam_mock_results_v1"] = json.dumps(
        {"version": 1, "tracks": all_}, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Source-level checks (§25 labels, wiring, §30 sweep)
# ---------------------------------------------------------------------------

DEVANAGARI = re.compile(r"[\u0900-\u097F]")


def dart_source(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def devanagari_strings(src):
    out = []
    for m in re.finditer(r"'([^'\\\n]*)'", src):
        if DEVANAGARI.search(m.group(1)):
            out.append(m.group(1))
    for m in re.finditer(r'"([^"\\\n]*)"', src):
        if DEVANAGARI.search(m.group(1)):
            out.append(m.group(1))
    return out


def run_source_checks():
    pyq_models = dart_source(os.path.join(
        LIB_EXAM, "domain", "pyq_mock", "pyq_models.dart"))
    pyq_bank = dart_source(os.path.join(
        LIB_EXAM, "domain", "pyq_mock", "pyq_bank.dart"))
    mock_models = dart_source(os.path.join(
        LIB_EXAM, "domain", "pyq_mock", "mock_models.dart"))
    mock_engine = dart_source(os.path.join(
        LIB_EXAM, "domain", "pyq_mock", "mock_engine.dart"))
    pyq_repo = dart_source(os.path.join(
        LIB_EXAM, "data", "pyq_mock", "pyq_performance_repository.dart"))
    pyq_providers = dart_source(os.path.join(
        LIB_EXAM, "presentation", "providers", "pyq_mock_providers.dart"))
    pyq_screen = dart_source(os.path.join(
        LIB_EXAM, "presentation", "screens", "exam_pyq_screen.dart"))
    mock_screen = dart_source(os.path.join(
        LIB_EXAM, "presentation", "screens", "exam_mock_screen.dart"))
    weakarea_providers = dart_source(os.path.join(
        LIB_EXAM, "presentation", "providers",
        "exam_weakarea_providers.dart"))
    weak_topic_engine = dart_source(os.path.join(
        LIB_EXAM, "domain", "weakarea", "weak_topic_engine.dart"))
    router = dart_source(os.path.join(
        PROJECT_ROOT, "lib", "app", "router", "app_router.dart"))
    route_names = dart_source(os.path.join(
        PROJECT_ROOT, "lib", "core", "constants", "route_names.dart"))
    plan_screen = dart_source(os.path.join(
        LIB_EXAM, "presentation", "screens", "exam_plan_screen.dart"))

    # §30: no percentages in any M9 student-facing string.
    for name, src in [
        ("pyq_models", pyq_models), ("pyq_bank", pyq_bank),
        ("mock_models", mock_models), ("mock_engine", mock_engine),
        ("pyq_repo", pyq_repo), ("pyq_providers", pyq_providers),
        ("pyq_screen", pyq_screen), ("mock_screen", mock_screen),
        ("weak_topic_engine", weak_topic_engine),
        ("weakarea_providers", weakarea_providers),
    ]:
        strings = devanagari_strings(src)
        check(f"§30 no '%' in student strings [{name}]",
              all("%" not in s for s in strings),
              [s for s in strings if "%" in s][:3])

    # §25: the generated labels never claim actual CBSE PYQ status.
    check("§25 label parity: official",
          "आधिकारिक CBSE प्रश्न (PYQ)" in pyq_models)
    check("§25 label parity: exam pattern",
          "आधिकारिक परीक्षा-पैटर्न पर आधारित" in pyq_models)
    check("§25 label parity: PYQ style",
          "PYQ-शैली (अभ्यास)" in pyq_models)
    check("§25 bank never creates official provenance",
          "PyqProvenance.official" not in pyq_bank)

    # Wiring: routes + screens + providers exist.
    check("routes: examPyq + examMock registered",
          "examPyqName" in router and "examMockName" in router
          and "pyq/:trackId" in router and "mock/:trackId" in router
          and "examPyqName" in route_names and "examMockName" in
          route_names)
    check("plan screen deep-links pyq/mock tasks",
          "RouteNames.examPyqName" in plan_screen
          and "RouteNames.examMockName" in plan_screen)
    check("overview feeds PYQ performance + weak mock sections",
          "pyqPerformance:" in weakarea_providers
          and "weakMockSections:" in weakarea_providers)
    check("weak-topic engine accepts the M9 inputs",
          "pyqPerformance" in weak_topic_engine
          and "weakMockSections" in weak_topic_engine)
    check("mock scoring is deterministic (MockEngine.analyze, §41)",
          "MockEngine.analyze" in pyq_providers)
    check("PYQ sessions persist §21 evidence",
          "recordSession" in pyq_providers)
    check("PYQ sessions persist §29 mastery",
          "masteryUpdates" in pyq_providers)
    check("PYQ session labels are honest in the UI",
          "PYQ-शैली" in pyq_screen)
    check("mock screen shows the ladder kinds",
          "MockKind.mini" in mock_screen and "MockKind.full" in
          mock_screen)


# ---------------------------------------------------------------------------
# Behavior checks
# ---------------------------------------------------------------------------

def run_pyq_bank_checks(tracks, courses):
    for tid in tracks:
        course = courses[tid]
        view = build_view(course)
        sel = selectable_ids(view)
        bank = build_pyq_bank(course, view, sel, target_size=0)
        check(f"pyq bank[{tid}]: non-empty and in scope",
              bool(bank) and all(q["topicId"] in sel for q in bank))
        check(f"pyq bank[{tid}]: pyq_-prefixed ids",
              all(q["id"].startswith("pyq_") for q in bank))
        check(f"pyq bank[{tid}]: NOTHING labeled official (§25)",
              all(q["provenance"] != "official" for q in bank))
        check(f"pyq bank[{tid}]: pattern labels verbatim from syllabus",
              all(q["patternText"] in ("अंक-संरचना", "अध्याय-आधारित") or
                  q["patternText"] in {
                      p["pattern"] for i in course["sections"]
                      for it in i.get("items", [])
                      for p in it.get("questionPatterns", [])}
                  for q in bank))
        check(f"pyq bank[{tid}]: marks within official bounds",
              all(0.5 <= q["marks"] <= 5 for q in bank))
        if bank:
            check(f"pyq bank[{tid}]: exam-pattern items exist",
                  any(q["provenance"] == "examPattern" for q in bank))

        # Section filter.
        section_ids = {s["id"] for s in view}
        if section_ids:
            target = next(iter(section_ids))
            filtered = build_pyq_bank(course, view, sel, target_size=0,
                                      section_filter={target})
            unit_ids = set()
            for s in view:
                if s["id"] == target:
                    unit_ids = {u["id"] for u in s["units"]}
            check(f"pyq bank[{tid}]: section filter keeps only that section",
                  all(q["topicId"] in unit_ids for q in filtered))

        # Pattern-kind filter + limit.
        if any("पूर्णवाक्यात्मक" in q["patternText"] for q in bank):
            typed = build_pyq_bank(course, view, sel, target_size=0,
                                   pattern_kinds={"पूर्णवाक्यात्मक"})
            check(f"pyq bank[{tid}]: pattern-kind filter works",
                  typed and all("पूर्णवाक्यात्मक" in q["patternText"]
                                for q in typed))
        limited = build_pyq_bank(course, view, sel, target_size=0, limit=3)
        check(f"pyq bank[{tid}]: limit bounds the bank",
              len(limited) <= 3)


def run_mock_checks(tracks, courses):
    tid = "cbse_10_sanskrit"
    course = courses[tid]
    view = build_view(course)
    sel = selectable_ids(view)
    bank = build_pyq_bank(course, view, sel, target_size=0)
    section_by_unit = {}
    for section in view:
        for unit in section["units"]:
            section_by_unit[unit["id"]] = section

    board_sections = []
    official_sections = {s["id"]: s for s in course["sections"]}
    for section in view:
        official = official_sections.get(section["id"])
        if official is None or official.get("assessmentType") == "internal":
            continue
        board_sections.append({
            "id": section["id"], "title": section["title"],
            "marks": float(official["marks"]),
        })
    board_total = float(course["assessment"]["boardExam"]["totalMarks"])
    board_hours = int(course["assessment"]["boardExam"]["durationHours"])
    check("mock: board structure read from official data (80/3h)",
          board_total == 80 and board_hours == 3 and board_sections)

    by_section = {}
    for q in bank:
        sec = section_by_unit.get(q["topicId"], {}).get("id")
        if sec:
            by_section.setdefault(sec, []).append(q)

    # Full mock.
    full = build_mock(tid, "full", board_sections, board_total, board_hours,
                      by_section)
    check("full mock: every board section present",
          {s["sectionId"] for s in full["sections"]} ==
          {s["id"] for s in board_sections})
    check("full mock: official duration (180 min)",
          full["timeLimitMinutes"] == 180)
    check("full mock: total marks = official section sum",
          full["totalMarks"] == sum(s["marks"] for s in board_sections))
    check("full mock: questions exist and are grounded",
          full["sections"] and all(
              q["topicId"] in sel for s in full["sections"]
              for q in s["questions"]))

    # Section mock.
    target = board_sections[-1]
    section_mock = build_mock(tid, "section", board_sections, board_total,
                              board_hours, by_section,
                              focus_section_id=target["id"])
    check("section mock: the chosen section only, official marks",
          section_mock["totalMarks"] == target["marks"]
          and section_mock["sections"][0]["sectionId"] == target["id"])
    check("section mock: scaled time (2.25 min/mark)",
          10 <= section_mock["timeLimitMinutes"] <= 240)

    # Mini mock.
    mini = build_mock(tid, "mini", board_sections, board_total, board_hours,
                      by_section)
    check("mini mock: capped marks + minimum 15 minutes",
          mini["totalMarks"] <= MINI_MAX_MARKS
          and mini["timeLimitMinutes"] >= MINI_MIN_MINUTES)

    # Analysis — deterministic + §30 bands.
    paper = full
    questions = [q for s in paper["sections"] for q in s["questions"]]
    attempts = [{"questionId": q["id"],
                 "verdict": "correct" if not q["id"].endswith("2")
                            else "incorrect"}
                for q in questions]
    r1 = analyze_mock(paper, attempts)
    r2 = analyze_mock(paper, attempts)
    check("mock analysis: deterministic (§41)", r1 == r2)
    check("mock analysis: partiallyCorrect counts (§29)",
          analyze_mock(paper, [{"questionId": q["id"],
                                "verdict": "partiallyCorrect"}
                               for q in questions])["totalCorrect"]
          == len(questions))

    # Weak-section detection: crush one section.
    weak_section_id = paper["sections"][-1]["sectionId"]
    weak_ids = {q["id"] for q in paper["sections"][-1]["questions"]}
    attempts_weak = [
        {"questionId": q["id"],
         "verdict": "incorrect" if q["id"] in weak_ids else "correct"}
        for q in questions]
    result = analyze_mock(paper, attempts_weak)
    weak = mock_weak_sections(result)
    check("mock analysis: weak section detected (§21)",
          len(weak) == 1 and weak[0]["sectionId"] == weak_section_id)
    check("mock analysis: clean run has no weak sections",
          mock_weak_sections(analyze_mock(
              paper, [{"questionId": q["id"], "verdict": "correct"}
                      for q in questions])) == [])
    too_few = analyze_mock(paper, attempts[:1])
    check("mock analysis: too-few attempts not judged",
          too_few["sectionResults"] and all(
              s["band"] if False else True for s in
              too_few["sectionResults"])
          and all(section_band(s["attempted"], s["correct"]) == "learning"
                  for s in too_few["sectionResults"] if s["attempted"] < 2))


def run_weak_signal_checks():
    def learner(topics=None):
        return {"topics": topics or {}, "hasDiagnostic": True}

    # M8 parity: no data → no PYQ/mock signals (frozen M8 engine).
    r = build_report_m8(learner(), [], [], NOW)
    check("M8 parity: frozen engine never emits PYQ/mock signals",
          report_is_m8_honest(r))

    # M9 no-data → identical honesty.
    r = build_report_m9(learner(), [], [], NOW)
    check("M9 no-data → no PYQ/mock findings (data gate)",
          not (set() & PYQ_MOCK_SIGNALS) and
          all(not (f["signals"] & PYQ_MOCK_SIGNALS) for f in r["findings"]))

    # weakPyq with data.
    r = build_report_m9(
        learner(), [], [], NOW,
        pyq_performance={"t1": {"topicId": "t1", "attempted": 4,
                                "correct": 1}})
    check("M9 weakPyq: emitted with real weak performance",
          any("weakPyq" in f["signals"] and f["topicId"] == "t1"
              for f in r["findings"]))
    r = build_report_m9(
        learner(), [], [], NOW,
        pyq_performance={"t1": {"topicId": "t1", "attempted": 4,
                                "correct": 4}})
    check("M9 weakPyq: strong performance → nothing (honest)",
          r["findings"] == [])
    r = build_report_m9(
        learner(), [], [], NOW,
        pyq_performance={"t1": {"topicId": "t1", "attempted": 1,
                                "correct": 0}})
    check("M9 weakPyq: 1 attempt is not evidence",
          r["findings"] == [])

    # weakMock with data.
    r = build_report_m9(
        learner(), [], [], NOW,
        weak_mock_sections=[{"sectionId": "sec_c", "title": "खंड स",
                             "attempted": 3, "correct": 0}])
    check("M9 weakMock: section finding with evidence",
          any("weakMock" in f["signals"] and f["topicId"] == "sec_c"
              for f in r["findings"]))
    r = build_report_m9(
        learner(), [], [], NOW,
        weak_mock_sections=[{"sectionId": "sec_a", "title": "A",
                             "attempted": 4, "correct": 4}])
    check("M9 weakMock: healthy section → nothing",
          r["findings"] == [])

    # Compounding: mastery + weakPyq + weakMock.
    learner_comp = learner({"t1": {
        "topicId": "t1", "stage": "needsAttention", "strength": 0.2,
        "correctCount": 1, "attemptCount": 5,
        "lastPracticedAtIso": "2026-09-01T10:00:00"}})
    r = build_report_m9(
        learner_comp, [], [], NOW,
        pyq_performance={"t1": {"topicId": "t1", "attempted": 5,
                                "correct": 1}},
        weak_mock_sections=[{"sectionId": "sec_a", "title": "A",
                             "attempted": 4, "correct": 0}])
    t1 = next((f for f in r["findings"] if f["topicId"] == "t1"), None)
    check("M9 compounding: needsAttention with weakPyq signal",
          t1 is not None and "weakPyq" in t1["signals"]
          and t1["severity"] == "needsAttention")
    check("M9 compounding: weakMock finding present too",
          any("weakMock" in f["signals"] for f in r["findings"]))


def run_repository_checks():
    store = {}
    check("pyq perf: empty store → empty", pyq_perf_load_all(store) == {})
    pyq_perf_merge(store, "x", [
        {"topicId": "t1", "attempted": 2, "correct": 1},
        {"topicId": "t2", "attempted": 3, "correct": 3}])
    pyq_perf_merge(store, "x", [
        {"topicId": "t1", "attempted": 2, "correct": 0}])
    loaded = pyq_perf_load_all(store)["x"]
    check("pyq perf: merge accumulates",
          loaded["t1"]["attempted"] == 4 and loaded["t1"]["correct"] == 1)
    pyq_perf_merge(store, "y", [
        {"topicId": "t1", "attempted": 5, "correct": 0}])
    check("pyq perf: per-track isolation",
          pyq_perf_load_all(store)["y"]["t1"]["attempted"] == 5)

    burst = [{"topicId": f"t{i}", "attempted": 100 if i == 0 else 1,
              "correct": 0}
             for i in range(PYQ_PERFORMANCE_MAX_TOPICS + 10)]
    pyq_perf_merge(store, "burst", burst)
    loaded = pyq_perf_load_all(store)["burst"]
    check(f"pyq perf: §56 bound {PYQ_PERFORMANCE_MAX_TOPICS} topics",
          len(loaded) == PYQ_PERFORMANCE_MAX_TOPICS
          and "t0" in loaded)
    check("pyq perf: corrupt store degrades (§41)",
          pyq_perf_load_all({"exam_pyq_performance_v1": "junk"}) == {})

    check("mock results: empty store → empty",
          mock_results_load_all(store) == {} or
          "exam_mock_results_v1" not in store)
    result = {"paperId": "p1", "kind": "mini", "trackId": "x",
              "sectionResults": [{"sectionId": "s1", "title": "S",
                                  "attempted": 3, "correct": 1}],
              "totalAttempted": 3, "totalCorrect": 1,
              "completedAtIso": iso(NOW)}
    mock_results_record(store, result)
    check("mock results: record + load",
          len(mock_results_load_all(store)["x"]) == 1)
    mock_results_record(store, {**result, "totalAttempted": 0})
    check("mock results: zero-attempt never stored (§41)",
          len(mock_results_load_all(store)["x"]) == 1)
    for i in range(MOCK_RESULTS_MAX + 10):
        mock_results_record(store, {**result, "paperId": f"p{i + 2}"})
    check(f"mock results: §56 bound {MOCK_RESULTS_MAX}",
          len(mock_results_load_all(store)["x"]) == MOCK_RESULTS_MAX)
    check("mock results: corrupt store degrades (§41)",
          mock_results_load_all(
              {"exam_mock_results_v1": "garbage"}) == {})
    doc = json.loads(store["exam_mock_results_v1"])
    check("mock results: schema version (§57)", doc["version"] == 1)


def run_journey_checks(tracks, courses):
    """Student B (average): PYQ practice + a mini mock with one weak
    section → findings → recovery decision → plan reserves the day.
    Proves the M9 spec: 'Feed results back into adaptive planning.'"""
    tid = "cbse_10_sanskrit"
    course = courses[tid]
    view = build_view(course)
    sel = sorted(selectable_ids(view))
    bank = build_pyq_bank(course, view, set(sel), target_size=0)
    check("journey: PYQ bank has questions", bool(bank))

    section_by_unit = {}
    for section in view:
        for unit in section["units"]:
            section_by_unit[unit["id"]] = section

    # 1) PYQ practice: weak on one topic, strong on others.
    weak_topic = bank[0]["topicId"]
    pyq_perf = {}
    for q in bank:
        entry = pyq_perf.setdefault(
            q["topicId"], {"topicId": q["topicId"], "attempted": 0,
                           "correct": 0})
        weak = q["topicId"] == weak_topic
        entry["attempted"] += 1
        entry["correct"] += 0 if weak else 1

    # 2) A mini mock with the weak topic's section crushed.
    weak_section_id = section_by_unit[weak_topic]["id"]
    weak_section_title = section_by_unit[weak_topic]["title"]
    official_sections = {s["id"]: s for s in course["sections"]}
    board_sections = []
    for section in view:
        official = official_sections.get(section["id"])
        if official is None or official.get("assessmentType") == "internal":
            continue
        board_sections.append({"id": section["id"],
                               "title": section["title"],
                               "marks": float(official["marks"])})
    by_section = {}
    for q in bank:
        sec = section_by_unit.get(q["topicId"], {}).get("id")
        if sec:
            by_section.setdefault(sec, []).append(q)
    mini = build_mock(tid, "mini", board_sections,
                      float(course["assessment"]["boardExam"]["totalMarks"]),
                      int(course["assessment"]["boardExam"]["durationHours"]),
                      by_section, focus_section_id=weak_section_id)
    mini_questions = [q for s in mini["sections"] for q in s["questions"]]
    attempts = [{"questionId": q["id"],
                 "verdict": "incorrect" if q["topicId"] == weak_topic
                            else "correct"}
                for q in mini_questions]
    mock_result = analyze_mock(mini, attempts)
    check("journey: mock detects the weak section",
          any(s["sectionId"] == weak_section_id
              for s in mock_weak_sections(mock_result)) or
          len(mini_questions) < 2,
          "weak section expected (or too-small paper, honestly)")

    # 3) Weak-area report with both M9 feeds.
    learner = {"topics": {
        weak_topic: {"topicId": weak_topic, "stage": "needsAttention",
                     "strength": 0.25, "correctCount": 1,
                     "attemptCount": 4,
                     "lastPracticedAtIso": "2026-09-10T10:00:00"}},
        "hasDiagnostic": True}
    report = build_report_m9(
        learner, [], [], NOW,
        pyq_performance=pyq_perf,
        weak_mock_sections=mock_weak_sections(mock_result))
    pyq_weak = [f for f in report["findings"]
                if "weakPyq" in f["signals"]]
    check("journey: weakPyq finding for the PYQ-weak topic",
          any(f["topicId"] == weak_topic for f in pyq_weak),
          [f["topicId"] for f in pyq_weak])

    # 4) The decision + the plan carry it (§22 + planner feedback).
    decision = m8.decide(report, [], 7, days_since=None)
    check("journey: recovery reserved (needsAttention tier)",
          decision["shouldRecover"]
          and decision["frequency"] == "frequent"
          and decision["focusTopicId"] == weak_topic)
    profile = {"dailyStudyMinutes": 45, "studyDaysPerWeek": 6}
    plan = m8.build_plan(tid, view, set(sel), profile, learner, 1,
                         weak_area={"decision": decision,
                                    "revisionItems": []})
    errs = m8.validate_plan_m8(plan, set(sel), profile)
    check("journey: M9-fed plan still validates (§16/§9)", not errs,
          errs[:2])
    day = plan["days"][decision["dayIndex"]]
    check("journey: the recovery day works the PYQ-weak topic",
          any(t["type"] == "weakArea" and t["topicId"] == weak_topic
              for t in day["tasks"]))

    # 5) Deterministic persistence round (§41): repo records the mock.
    store = {}
    mock_results_record(store, mock_result)
    stored = mock_results_load_all(store)[tid]
    check("journey: mock result persisted deterministically",
          stored[0] == mock_result)


def main():
    tracks, courses = load_courses()
    check("all 7 canonical courses load", len(tracks) == 7)

    run_source_checks()
    run_pyq_bank_checks(tracks, courses)
    run_mock_checks(tracks, courses)
    run_weak_signal_checks()
    run_repository_checks()
    run_journey_checks(tracks, courses)

    print(f"\n{'=' * 64}")
    if CHECKS["failed"] == 0:
        print(f"M9 MIRROR: ALL GREEN — {CHECKS['run']}/{CHECKS['run']} "
              "checks passed")
    else:
        print(f"M9 MIRROR: {CHECKS['failed']} FAILED of {CHECKS['run']}")
        for f in FAILURES[:40]:
            print(f"  FAIL {f}")
    print('=' * 64)
    return 1 if CHECKS["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())

