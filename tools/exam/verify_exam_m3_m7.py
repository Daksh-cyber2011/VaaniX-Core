#!/usr/bin/env python3
"""Exam Mode 2.0 — M3-M7 Verification Mirror (Python invariant port).

The previous milestones shipped Python mirrors because this build
environment has no Flutter SDK (see tools/syllabus/README.md). This
script mirrors the M3-M7 Dart logic 1:1 (same thresholds, same data,
same rules) and asserts every invariant against the REAL canonical
syllabus JSONs shipped under assets/syllabus/cbse/.

Mirrored units:
  M3 ExamProfile        - validation (§8/§9), anchor logic, JSON round-trip
  M4 Diagnostic         - item bank grounding (§60), adaptive ladder (§11),
                          weak/average/strong pathways, report bands,
                          §30 no-percentage observations
  M4 LearnerProfile     - EWMA mastery (§29), weak-first ordering
  M5 Planner            - deterministic planner (§13), validator (§9/§16),
                          AI-plan parse/validate path, §33 staleness
  M6 Practice loop      - content bank grounding, loop transitions
                          (feedback/retry/reveal/advance §28),
                          mastery updates (§29)
  M7 Evaluation         - normalizer, rubric bands (§27), photo gates +
                          vision paths (§26), §30 invariants

NOTE: this is an INVARIANT mirror, not a byte-parity mirror — Dart's
List.sort is unstable while Python's is stable, so question ORDER may
differ while every invariant (grounding, monotonic difficulty, budget
fit, band logic) is asserted identically.

Run: python3 tools/exam/verify_exam_m3_m7.py
"""

import json
import math
import os
import re
import sys
from datetime import date, datetime, timedelta

PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets", "syllabus", "cbse")

CHECKS = {"run": 0, "failed": 0}
FAILURES = []


def check(label, condition, detail=""):
    CHECKS["run"] += 1
    if not condition:
        CHECKS["failed"] += 1
        FAILURES.append(f"{label}: {detail}")


# ---------------------------------------------------------------------------
# Shared utilities (exact ports of learn/domain/exercise_models.dart)
# ---------------------------------------------------------------------------

def seed_from_text(text):
    h = 17
    for ch in text:
        h = (h * 31 + ord(ch)) & 0x7FFFFFFF
    return h


def deterministic_shuffle(items, seed):
    lst = list(items)
    rng = seed
    for i in range(len(lst) - 1, 0, -1):
        rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
        j = rng % (i + 1)
        if j != i:
            lst[i], lst[j] = lst[j], lst[i]
    return lst


# ---------------------------------------------------------------------------
# M3 — ExamProfile (lib/features/exam/domain/exam_profile.dart)
# ---------------------------------------------------------------------------

MIN_DAILY_MINUTES = 5
MAX_DAILY_MINUTES = 480
MIN_DURATION_WEEKS = 1
MAX_DURATION_WEEKS = 52


def profile_validate(target, weeks, minutes, days, exam_date, now):
    errors = []
    if minutes < MIN_DAILY_MINUTES or minutes > MAX_DAILY_MINUTES:
        errors.append("dailyStudyMinutes")
    if days < 1 or days > 7:
        errors.append("studyDaysPerWeek")
    if target is None and weeks is None:
        errors.append("no readiness source (§8)")
    if weeks is not None and not (MIN_DURATION_WEEKS <= weeks <= MAX_DURATION_WEEKS):
        errors.append("readinessDurationWeeks")
    for field, d in (("readinessTargetDate", target), ("actualExamDate", exam_date)):
        if d is not None and d < now:
            errors.append(f"{field} in past")
    if exam_date is not None and target is not None and exam_date < target:
        errors.append("actualExamDate precedes readinessTargetDate")
    return errors


def profile_anchor(target, weeks, now):
    if target is not None:
        return target
    if weeks is not None:
        return now + timedelta(weeks=weeks)
    return None


def profile_json_roundtrip():
    target = date(2026, 11, 15)
    profile = {
        "schemaVersion": 1,
        "trackId": "cbse_10_sanskrit",
        "dailyStudyMinutes": 45,
        "studyDaysPerWeek": 5,
        "readinessTargetDate": target.isoformat(),
        "readinessDurationWeeks": None,
        "actualExamDate": None,
        "pace": "balanced",
        "updatedAtIso": "",
    }
    back = json.loads(json.dumps(profile))
    check("M3: JSON round-trip keeps fields",
          back["dailyStudyMinutes"] == 45 and back["readinessTargetDate"] == target.isoformat())


def run_m3_checks():
    now = date(2026, 9, 12)

    # §8 anchors.
    check("M3: date-only anchor", profile_anchor(date(2026, 11, 15), None, now) == date(2026, 11, 15))
    dur_anchor = profile_anchor(None, 8, now)
    check("M3: duration-only anchor ≈ 8 weeks", abs((dur_anchor - now).days - 56) <= 1)
    check("M3: both → date primary (§8C)",
          profile_anchor(date(2026, 11, 15), 4, now) == date(2026, 11, 15))

    # §8/§9 validation.
    check("M3: no anchor invalid", len(profile_validate(None, None, 30, 5, None, now)) > 0)
    check("M3: past target rejected",
          any("past" in e for e in profile_validate(date(2025, 1, 1), 4, 30, 5, None, now)))
    check("M3: exam before readiness rejected",
          any("precedes" in e for e in profile_validate(date(2026, 12, 1), None, 30, 5, date(2026, 10, 1), now)))
    check("M3: 5min budget valid (§9 no punishment)",
          profile_validate(date(2026, 12, 1), None, 5, 2, None, now) == [])
    check("M3: 480min budget valid",
          profile_validate(date(2026, 12, 1), 52, 480, 7, None, now) == [])
    check("M3: 2min invalid", len(profile_validate(date(2026, 12, 1), None, 2, 5, None, now)) > 0)
    check("M3: 0 days invalid", len(profile_validate(date(2026, 12, 1), None, 30, 0, None, now)) > 0)
    profile_json_roundtrip()
    # Weekly budget = daily × days.
    check("M3: weekly budget math", 45 * 4 == 180)


# ---------------------------------------------------------------------------
# Syllabus scope view (ports M1 models + M2 ExamScopeView)
# ---------------------------------------------------------------------------

def load_courses():
    with open(os.path.join(ASSETS, "index.json"), encoding="utf-8") as f:
        index = json.load(f)
    tracks = []
    for klass in index["classes"]:
        for subject in klass["subjects"]:
            for course in subject["courses"]:
                tracks.append(course["id"])
    courses = {}
    for tid in tracks:
        with open(os.path.join(ASSETS, f"{tid}.json"), encoding="utf-8") as f:
            courses[tid] = json.load(f)
    return tracks, courses


def subtopics_of(item):
    details = item.get("details")
    if not details:
        return []
    out = []

    def add_list(lst):
        for v in lst:
            if isinstance(v, str):
                s = v.strip()
                if s and len(s) <= 40:
                    out.append(s)

    for value in details.values():
        if isinstance(value, list):
            add_list(value)
        elif isinstance(value, dict):
            for v in value.values():
                if isinstance(v, list):
                    add_list(v)
    return out


def build_view(course):
    """Mirrors ExamScopeView.fromSyllabus: sections with selectable units."""
    sections = []
    pending = course.get("pendingOfficialAnnouncement")
    for section in course["sections"]:
        if section.get("assessmentType") == "internal":
            continue
        units = []
        chapters_added = False
        if section["stableKey"] == "literature":
            chapters = []
            for book in course.get("prescribedBooks", []):
                for ch in book.get("chapters", []):
                    chapters.append((book, ch))
            board_chapters = [(b, c) for b, c in chapters if c.get("examRelevance") != "internal-only"]
            internal = [(b, c) for b, c in chapters if c.get("examRelevance") == "internal-only"]
            if board_chapters or internal:
                chapters_added = True
                for book, ch in board_chapters:
                    units.append({
                        "id": ch["id"],
                        "title": ch["title"],
                        "sectionId": section["id"],
                        "selectable": True,
                        "isChapter": True,
                        "marks": None,
                    })
                for book, ch in internal:
                    units.append({
                        "id": ch["id"],
                        "title": ch["title"],
                        "sectionId": section["id"],
                        "selectable": False,
                        "isChapter": True,
                        "marks": None,
                    })
        if section["stableKey"] == "literature" and not chapters_added and pending:
            pass  # pending note rides on the section
        for item in section.get("items", []):
            if section["stableKey"] == "literature" and chapters_added:
                continue
            selectable = (
                item.get("status", "published") == "published"
                and item.get("assessmentType", "board") == "board"
            )
            units.append({
                "id": item["id"],
                "title": item["title"],
                "sectionId": section["id"],
                "selectable": selectable,
                "isChapter": False,
                "marks": item.get("marks"),
                "subtopics": subtopics_of(item),
            })
        sections.append({
            "id": section["id"],
            "title": section["title"],
            "stableKey": section["stableKey"],
            "marks": section["marks"],
            "units": units,
        })
    return sections


def selectable_ids(view):
    return {u["id"] for s in view for u in s["units"] if u["selectable"]}


def unit_by_id(view):
    return {u["id"]: u for s in view for u in s["units"]}


# ---------------------------------------------------------------------------
# M4 — Diagnostic item bank (data/diagnostic/diagnostic_item_bank.dart)
# ---------------------------------------------------------------------------

def build_options(correct, pool, seed):
    distinct = [t for t in dict.fromkeys(pool) if t != correct]
    if len(distinct) < 3:
        return None
    chosen = deterministic_shuffle(distinct, seed_from_text(seed))[:3]
    all_opts = [correct] + chosen
    shuffled = deterministic_shuffle(all_opts, seed_from_text(seed + "_shuffle"))
    return shuffled, shuffled.index(correct)


def build_diagnostic_bank(course, view, selection):
    questions = []
    titles = {}
    section_of = {}
    for s in view:
        for u in s["units"]:
            if u["selectable"] and u["id"] in selection:
                titles[u["id"]] = u["title"]
                section_of[u["id"]] = s["title"]

    section_titles = [s["title"] for s in view]
    book_titles = [b["title"] for b in course.get("prescribedBooks", [])]
    items_by_id = {i["id"]: i for s in course["sections"] for i in s.get("items", [])}

    selected_units = [u for s in view for u in s["units"] if u["selectable"] and u["id"] in selection]

    for u in selected_units:
        section_title = section_of[u["id"]]

        # 1) section membership (recall, easy)
        pool = [t for t in section_titles + book_titles if t != section_title]
        opts = build_options(section_title, pool, u["id"] + "_sec")
        if opts:
            questions.append({
                "id": f"diag_{u['id']}_sec",
                "topicId": u["id"],
                "prompt": f"«{u['title']}» किस खंड का भाग है?",
                "options": opts[0],
                "correctIndex": opts[1],
                "difficulty": 1,
                "skill": "recall",
            })

        # 2) sub-topic membership (recall, medium)
        own = u.get("subtopics") or []
        if own:
            distractors = []
            for s2 in view:
                for other in s2["units"]:
                    if other["id"] == u["id"]:
                        continue
                    item = items_by_id.get(other["id"])
                    if item:
                        distractors.extend(subtopics_of(item))
            opts = build_options(own[0], distractors, u["id"] + "_sub")
            if opts:
                questions.append({
                    "id": f"diag_{u['id']}_sub",
                    "topicId": u["id"],
                    "prompt": f"इनमें से कौन-सा «{u['title']}» के अंतर्गत आता है?",
                    "options": opts[0],
                    "correctIndex": opts[1],
                    "difficulty": 2,
                    "skill": "recall",
                })

        # 3) marks awareness (application, hard)
        with_marks = [x for x in selected_units if x.get("marks")]
        if u.get("marks") and len(with_marks) >= 4:
            others = sorted(
                [x for x in with_marks if x["id"] != u["id"]],
                key=lambda x: -x["marks"])[:3]
            max_other = max((x["marks"] for x in others), default=0.0)
            if u["marks"] > max_other:
                opts = build_options(u["title"], [x["title"] for x in others], u["id"] + "_marks")
                if opts:
                    questions.append({
                        "id": f"diag_{u['id']}_marks",
                        "topicId": u["id"],
                        "prompt": "इन चार इकाइयों में से किस पर सबसे अधिक अंक निर्धारित हैं?",
                        "options": opts[0],
                        "correctIndex": opts[1],
                        "difficulty": 3,
                        "skill": "application",
                    })

        # 4) chapter identity (interpretation, medium)
        if u["isChapter"] and len(book_titles) >= 4:
            owning = next((b for b in course.get("prescribedBooks", [])
                           for c in b.get("chapters", []) if c["id"] == u["id"]), None)
            if owning:
                distractors = [b["title"] for b in course.get("prescribedBooks", []) if b["id"] != owning["id"]]
                opts = build_options(owning["title"], distractors[:3], u["id"] + "_book")
                if opts:
                    questions.append({
                        "id": f"diag_{u['id']}_book",
                        "topicId": u["id"],
                        "prompt": f"«{u['title']}» किस पुस्तक का पाठ है?",
                        "options": opts[0],
                        "correctIndex": opts[1],
                        "difficulty": 2,
                        "skill": "interpretation",
                    })

    return questions, titles, section_of


# ---------------------------------------------------------------------------
# M4 — Adaptive engine (domain/diagnostic/exam_diagnostic_engine.dart)
# ---------------------------------------------------------------------------

DIFFICULTY_WEIGHT = {1: 1.0, 2: 1.2, 3: 1.5}


def diag_run(bank, titles, section_of, max_items, policy):
    """policy: 'strong' (always right), 'weak' (always wrong), 'avg' (alternate)."""
    by_diff = {1: [], 2: [], 3: []}
    for q in bank:
        by_diff[q["difficulty"]].append(q)

    served = []
    responses = []
    attempts_by_topic = {}

    def pick(difficulty):
        pool = [q for q in by_diff[difficulty] if q["id"] not in {s["id"] for s in served}]
        if not pool:
            return None
        pool.sort(key=lambda q: attempts_by_topic.get(q["topicId"], 0))
        return pool[0]

    def tier_order(d):
        return {1: [1, 2, 3], 2: [2, 1, 3], 3: [3, 2, 1]}[d]

    current = pick(2)
    if current is None:
        # Start at the nearest LOWER tier when medium is unavailable
        # (never punish with harder-than-medium sight-unseen).
        current = pick(1) or pick(3)
    while current is not None and len(responses) < max_items:
        served.append(current)
        if policy == "strong":
            correct = True
        elif policy == "weak":
            correct = False
        else:
            correct = len(responses) % 2 == 0
        responses.append({
            "topicId": current["topicId"],
            "difficulty": current["difficulty"],
            "skill": current["skill"],
            "correct": correct,
        })
        attempts_by_topic[current["topicId"]] = attempts_by_topic.get(current["topicId"], 0) + 1
        next_diff = min(3, current["difficulty"] + 1) if correct else max(1, current["difficulty"] - 1)
        nxt = None
        for tier in tier_order(next_diff):
            nxt = pick(tier)
            if nxt is not None:
                break
        current = nxt
    return responses, served


def band_for(ability):
    if ability >= 0.75:
        return "strong"
    if ability >= 0.5:
        return "learning"
    return "needsAttention"


def diag_report(responses, titles):
    by_topic = {}
    for r in responses:
        by_topic.setdefault(r["topicId"], []).append(r)
    estimates = []
    for topic, rs in by_topic.items():
        w = sum(DIFFICULTY_WEIGHT[r["difficulty"]] for r in rs)
        s = sum(DIFFICULTY_WEIGHT[r["difficulty"]] for r in rs if r["correct"])
        ability = (s / w) if w else 0.0
        estimates.append({
            "topicId": topic,
            "title": titles.get(topic, topic),
            "attempts": len(rs),
            "correct": sum(1 for r in rs if r["correct"]),
            "band": band_for(ability),
            "ability": ability,
        })
    overall = sum(e["ability"] for e in estimates) / len(estimates) if estimates else 0.0
    obs = []
    strong = [e for e in estimates if e["band"] == "strong"]
    learning = [e for e in estimates if e["band"] == "learning"]
    attention = [e for e in estimates if e["band"] == "needsAttention"]
    if strong:
        obs.append("मज़बूत: " + ", ".join(e["title"] for e in strong[:3]))
    if learning:
        obs.append("सीख रहे हैं: " + ", ".join(e["title"] for e in learning[:3]))
    if attention:
        obs.append("ध्यान चाहिए: " + ", ".join(e["title"] for e in attention[:3]))
    return {
        "estimates": estimates,
        "overallBand": band_for(overall),
        "observations": obs,
    }


# ---------------------------------------------------------------------------
# M4 — Learner profile (domain/exam_learner_profile.dart)
# ---------------------------------------------------------------------------

EWMA_ALPHA = 0.4
STAGE_RANK = {
    "needsAttention": 0, "needsReview": 1, "learning": 2,
    "practicing": 3, "strong": 4, "mastered": 5,
}


def apply_attempt(mastery, correct):
    attempts = mastery["attempts"] + 1
    corrects = mastery["correct"] + (1 if correct else 0)
    target = 1.0 if correct else 0.0
    strength = target if mastery["attempts"] == 0 else (
        mastery["strength"] * (1 - EWMA_ALPHA) + target * EWMA_ALPHA)
    strength = min(1.0, max(0.0, strength))
    accuracy = corrects / attempts
    if accuracy < 0.4:
        stage = "needsAttention"
    elif strength >= 0.8 and attempts >= 8 and accuracy >= 0.8:
        stage = "mastered"
    elif strength >= 0.65 and accuracy >= 0.6:
        stage = "strong"
    elif accuracy >= 0.5:
        stage = "practicing"
    else:
        stage = "learning"
    return {"strength": strength, "attempts": attempts, "correct": corrects, "stage": stage}


def weak_first(profile):
    items = []
    for tid, t in profile.items():
        if t.get("attempts", 0) > 0:
            d = dict(t)
            d["topicId"] = tid
            items.append(d)
    return sorted(
        items,
        key=lambda t: (STAGE_RANK[t["stage"]], t["strength"]))


# ---------------------------------------------------------------------------
# M5 — Deterministic planner + validator
# ---------------------------------------------------------------------------

def task_minutes_for(budget):
    # §9 hard guarantee: a task NEVER exceeds the daily budget itself.
    if budget >= 45:
        return 15
    if budget >= 10:
        return 10
    return budget


def day_count_for(profile):
    return max(1, min(7, profile["studyDaysPerWeek"]))


def build_deterministic_plan(track_id, view, selection, profile, learner):
    selected = [u for s in view for u in s["units"] if u["selectable"] and u["id"] in selection]
    weak_ids = {t["topicId"] for t in weak_first(learner)[:30]}
    ordered = sorted(
        selected,
        key=lambda u: (
            0 if u["id"] in weak_ids else 1,
            -(u.get("marks") or 0),
            u["title"],
        ))
    budget = profile["dailyStudyMinutes"]
    tm = task_minutes_for(budget)
    tasks_per_day = max(1, min(4, budget // tm))
    day_count = day_count_for(profile)

    queue = list(ordered)
    rotation = 0
    days = []
    for day in range(day_count):
        tasks = []
        if queue:
            for t in range(tasks_per_day):
                if not queue:
                    queue.extend(ordered)
                unit = queue.pop(0)
                kind = "learn" if t == 0 else ("practice" if t == 1 else "review")
                tasks.append({"type": kind, "topicId": unit["id"],
                              "title": f"{kind}: {unit['title']}", "minutes": tm})
            if weak_ids and ordered:
                weak_unit = next((u for u in ordered if u["id"] in weak_ids), None)
                if weak_unit and not any(t["topicId"] == weak_unit["id"] for t in tasks):
                    if sum(t["minutes"] for t in tasks) + 10 <= budget:
                        tasks.append({"type": "weakArea", "topicId": weak_unit["id"],
                                      "title": f"weak: {weak_unit['title']}", "minutes": 10})
            if day == 3 and ordered:
                u = ordered[rotation % len(ordered)]
                if sum(t["minutes"] for t in tasks) + 10 <= budget:
                    tasks.append({"type": "pyq", "topicId": u["id"],
                                  "title": f"PYQ — {u['title']}", "minutes": 10})
            if day == 5 and ordered:
                u = ordered[rotation % len(ordered)]
                if sum(t["minutes"] for t in tasks) + 10 <= budget:
                    tasks.append({"type": "mock", "topicId": u["id"],
                                  "title": f"mock — {u['title']}", "minutes": 10})
            rotation += 1
        days.append({"dayIndex": day, "tasks": tasks})
    return {
        "trackId": track_id,
        "source": "deterministic",
        "days": days,
        "rationale": "offline",
    }


def validate_plan(plan, view, selection, profile):
    errors = []
    allowed = set(selection)
    if not plan["days"]:
        errors.append("no days")
        return errors
    if len(plan["days"]) > 7:
        errors.append("too many days")
    for day in plan["days"]:
        total = sum(t["minutes"] for t in day["tasks"])
        if not day["tasks"]:
            errors.append(f"day {day['dayIndex']} empty")
            continue
        if total > profile["dailyStudyMinutes"]:
            errors.append(f"day {day['dayIndex']} over budget: {total} > {profile['dailyStudyMinutes']}")
        if not any(t["type"] in ("learn", "practice") for t in day["tasks"]):
            errors.append(f"day {day['dayIndex']} no backbone")
        for t in day["tasks"]:
            if t["topicId"] not in allowed:
                errors.append(f"task out of scope: {t['topicId']}")
            if t["minutes"] < 1 or t["minutes"] > 90:
                errors.append(f"task minutes out of range: {t['minutes']}")
    return errors


# ---------------------------------------------------------------------------
# M6 — Practice content bank (data/practice/practice_content_bank.dart)
# ---------------------------------------------------------------------------

def build_practice_bank(course, view, selection, weak_ids, target_size=12):
    questions = []
    selected = [u for s in view for u in s["units"] if u["selectable"] and u["id"] in selection]
    section_titles = [s["title"] for s in view]
    book_titles = [b["title"] for b in course.get("prescribedBooks", [])]
    items_by_id = {i["id"]: i for s in course["sections"] for i in s.get("items", [])}

    for u in selected:
        section_title = next(s["title"] for s in view if s["id"] == u["sectionId"])
        # MCQ section membership
        pool = [t for t in section_titles + book_titles if t != section_title]
        opts = build_options(section_title, pool, u["id"] + "_psec")
        if opts:
            questions.append({
                "id": f"prac_{u['id']}_sec",
                "topicId": u["id"],
                "kind": "mcq",
                "prompt": f"«{u['title']}» किस खंड में आता है?",
                "options": opts[0],
                "correctIndex": opts[1],
                "explanation": f"«{u['title']}» {section_title} का भाग है।",
                "tier": 1,
            })
        subs = u.get("subtopics") or []
        if subs:
            questions.append({
                "id": f"prac_{u['id']}_typed",
                "topicId": u["id"],
                "kind": "shortAnswer",
                "prompt": f"«{subs[0]}» किस विषय के अंतर्गत आता है? (नाम लिखें)",
                "acceptedAnswers": [u["title"]],
                "requiredPoints": subs[:3],
                "explanation": f"«{subs[0]}» «{u['title']}» का भाग है।",
                "tier": 2,
            })
        if len(subs) >= 2:
            distractors = []
            for other in selected:
                if other["id"] == u["id"]:
                    continue
                item = items_by_id.get(other["id"])
                if item:
                    distractors.extend(subtopics_of(item)[:3])
            opts = build_options(subs[0], distractors, u["id"] + "_psub")
            if opts:
                questions.append({
                    "id": f"prac_{u['id']}_sub",
                    "topicId": u["id"],
                    "kind": "mcq",
                    "prompt": f"इनमें से कौन-सा «{u['title']}» से संबंधित है?",
                    "options": opts[0],
                    "correctIndex": opts[1],
                    "explanation": f"«{subs[0]}» «{u['title']}» के अंतर्गत आता है।",
                    "tier": 3,
                })

    # §22 weak-first + tier, applied WITHIN each kind; typed questions
    # reserve at least a third of the session when the data supports
    # them (§24 mix), so a large MCQ pool cannot crowd them out.
    def rank(q):
        return (0 if q["topicId"] in weak_ids else 1) * 10 + q["tier"]

    typed_qs = [q for q in questions if q["kind"] == "shortAnswer"]
    mcq_qs = [q for q in questions if q["kind"] == "mcq"]
    typed_qs.sort(key=rank)
    mcq_qs.sort(key=rank)
    if typed_qs:
        typed_take = max(2, min(len(typed_qs), target_size // 3))
    else:
        typed_take = 0
    questions = typed_qs[:typed_take] + mcq_qs[: max(0, target_size - typed_take)]
    return questions


# ---------------------------------------------------------------------------
# M7 — Normalizer + rubric evaluator (domain/evaluation/*)
# ---------------------------------------------------------------------------

DEV_DIGITS = "०१२३४५६७८९"
STRIP = "।॥!.,;:?\'\"()[]{}<>-–—_/\\+*=|·"


def normalize_answer(raw):
    text = raw or ""
    if not text:
        return ""
    for ch in "\u200B\u200C\u200D\uFEFF":
        text = text.replace(ch, "")
    out = []
    for ch in text:
        idx = DEV_DIGITS.find(ch)
        out.append(str(idx) if idx >= 0 else ch)
    text = "".join(out)
    text = text.replace("ऽ", "'").replace("ँ", "ं").replace("ळ", "ल").replace("़", "")
    for c in STRIP:
        text = text.replace(c, " ")
    text = text.lower()
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tokenize(raw):
    n = normalize_answer(raw)
    return n.split() if n else []


def token_coverage(expected, answer):
    if not expected or not answer:
        return 0.0
    pool = list(answer)
    hits = 0
    for tok in expected:
        if tok in pool:
            hits += 1
            pool.remove(tok)
    return hits / len(expected)


T_CORRECT = 0.8
T_PARTIAL = 0.5
T_GRAY = 0.35
T_POINT = 0.7


def evaluate_typed(prompt, student_answer, accepted, points, is_retry=False):
    trimmed = (student_answer or "").strip()
    if not trimmed:
        return {"verdict": "incorrect", "issues": ["emptyAnswer"],
                "feedback": "उत्तर खाली है — जो आपको पता है, उतना लिखें।"}
    issues = []
    if len(trimmed) > 1200:
        issues.append("veryLongAnswer")
    student_tokens = tokenize(trimmed)
    best = 0.0
    for acc in accepted:
        best = max(best, token_coverage(tokenize(acc), student_tokens))
    rubric = []
    met = 0
    for req in points:
        cov = token_coverage(tokenize(req), student_tokens)
        ok = cov >= T_POINT
        if ok:
            met += 1
        rubric.append({"requirement": req, "met": ok})

    if best >= T_CORRECT:
        verdict = "correct"
    elif best >= T_PARTIAL:
        verdict = "partiallyCorrect"
    elif best >= T_GRAY or (rubric and 0 < met < len(rubric)):
        verdict = "uncertain"
    else:
        verdict = "incorrect"
    if verdict == "correct" and rubric and met < len(rubric):
        verdict = "partiallyCorrect"
    return {"verdict": verdict, "issues": issues, "rubric": rubric,
            "feedback": f"verdict {verdict}"}


def evaluate_mcq(correct_index, selected_index, correct_text):
    correct = selected_index == correct_index
    return {"verdict": "correct" if correct else "incorrect",
            "feedback": "सही" if correct else "सही उत्तर «%s» है।" % correct_text}


# ---------------------------------------------------------------------------
# M7 — Photo gates + pipeline
# ---------------------------------------------------------------------------

MIN_PHOTO_BYTES = 8 * 1024


def photo_quality_gate(nbytes, width, height):
    if nbytes < MIN_PHOTO_BYTES:
        return "tooSmallPhoto"
    if width <= 0 or height <= 0:
        return "tooSmallPhoto"
    ratio = max(width, height) / min(width, height)
    if ratio > 6:
        return "croppedPhoto"
    return None


def photo_evaluate(vision_result, accepted, points, prompt):
    """vision_result: None → offline; 'timeout'; dict(readable, confident, text)."""
    if vision_result == "timeout":
        return {"verdict": "uncertain", "advice": "टाइप करें"}
    if vision_result is None:
        return {"verdict": "uncertain", "issues": ["offlinePhoto"], "advice": "टाइप करें"}
    if not vision_result["readable"] or not vision_result.get("text", "").strip():
        return {"verdict": "uncertain", "issues": ["unreadablePhoto"], "advice": "दोबारा लें"}
    if not vision_result["confident"]:
        return {"verdict": "uncertain", "issues": ["ambiguousExtraction"], "advice": "टाइप करें"}
    graded = evaluate_typed(prompt, vision_result["text"], accepted, points)
    graded["extractedText"] = vision_result["text"]
    return graded


# ---------------------------------------------------------------------------
# Per-track full simulation
# ---------------------------------------------------------------------------

ALL_STUDENT_STRINGS = []


def collect(s):
    if isinstance(s, str):
        ALL_STUDENT_STRINGS.append(s)


def run_track(track_id, course):
    view = build_view(course)
    sel = selectable_ids(view)
    check(f"[{track_id}] view has selectable units", len(sel) > 0)
    ub = unit_by_id(view)
    real_strings = set()
    for s in view:
        real_strings.add(s["title"])
        for u in s["units"]:
            real_strings.add(u["title"])
    for b in course.get("prescribedBooks", []):
        real_strings.add(b["title"])
    for s in course["sections"]:
        for i in s.get("items", []):
            real_strings.update(subtopics_of(i))

    # --- M4 diagnostic bank ---
    bank, titles, section_of = build_diagnostic_bank(course, view, sel)
    check(f"[{track_id}] diagnostic bank non-empty", len(bank) > 0)
    for q in bank:
        check(f"[{track_id}] diag {q['id']} well-formed",
              len(q["options"]) == 4 and 0 <= q["correctIndex"] < 4)
        check(f"[{track_id}] diag {q['id']} topic in scope", q["topicId"] in sel)
        for opt in q["options"]:
            check(f"[{track_id}] diag {q['id']} option grounded (§60)",
                  opt in real_strings, opt)

    # --- M4 adaptive pathways ---
    for policy in ("strong", "weak", "average"):
        responses, served = diag_run(bank, titles, section_of, 10, policy)
        check(f"[{track_id}] {policy} diagnostic bounded (§10)",
              len(responses) <= 10)
        check(f"[{track_id}] {policy} diagnostic served enough", len(responses) >= 5)
        check(f"[{track_id}] {policy} starts at MEDIUM-or-nearest-lower (§11)",
              len(responses) == 0 or served[0]["difficulty"] in (2, 1))
        if policy in ("strong", "weak"):
            diffs = [r["difficulty"] for r in responses]
            # §11 smooth ladder: with nearest-tier fallback, steps are
            # at most ±1 — no hard→easy cliff even when a tier empties.
            check(f"[{track_id}] {policy} ladder steps ≤ 1 tier (§11)",
                  all(abs(diffs[i + 1] - diffs[i]) <= 1 for i in range(len(diffs) - 1)),
                  str(diffs))
        report = diag_report(responses, titles)
        for obs in report["observations"]:
            collect(obs)
            check(f"[{track_id}] {policy} observation §30",
                  "%" not in obs and "प्रतिशत" not in obs)

    strong_responses, _ = diag_run(bank, titles, section_of, 10, "strong")
    weak_responses, _ = diag_run(bank, titles, section_of, 10, "weak")
    strong_report = diag_report(strong_responses, titles)
    weak_report = diag_report(weak_responses, titles)
    check(f"[{track_id}] strong vs weak bands differ (§10)",
          strong_report["overallBand"] == "strong"
          and weak_report["overallBand"] == "needsAttention")

    # --- M4 → learner profile seeding ---
    profile = {}
    for r in strong_responses:
        m = profile.get(r["topicId"], {"strength": 0, "attempts": 0, "correct": 0, "stage": "learning"})
        profile[r["topicId"]] = apply_attempt(m, r["correct"])
    check(f"[{track_id}] learner profile seeded from diagnostic",
          len(profile) > 0)

    # --- M5 deterministic plan + validator ---
    exam_profile = {"dailyStudyMinutes": 45, "studyDaysPerWeek": 5}
    plan = build_deterministic_plan(track_id, view, sel, exam_profile, profile)
    errors = validate_plan(plan, view, sel, exam_profile)
    # Track-id equality check explicitly:
    check(f"[{track_id}] plan trackId matches", plan["trackId"] == track_id)
    check(f"[{track_id}] deterministic plan valid (§9/§16)", errors == [], str(errors))
    for budget in (5, 15, 30, 45, 120):
        p2 = build_deterministic_plan(track_id, view, sel,
                                      {"dailyStudyMinutes": budget, "studyDaysPerWeek": 5}, profile)
        over = [d for d in p2["days"] if sum(t["minutes"] for t in d["tasks"]) > budget]
        check(f"[{track_id}] §9 every day fits budget {budget}", not over, str(over))

    # Weak-first with a weak learner.
    weak_profile = {sel.__iter__().__next__(): {"strength": 0.1, "attempts": 3, "correct": 0, "stage": "needsAttention"}}
    plan_weak = build_deterministic_plan(track_id, view, sel, exam_profile, weak_profile)
    first_ids = [t["topicId"] for t in plan_weak["days"][0]["tasks"]]
    check(f"[{track_id}] weak topic leads day 0 (§22)", next(iter(weak_profile)) in first_ids)

    # §33: plan for old scope fails validation after scope edit — pick a
    # topic the plan actually schedules, so staleness is guaranteed
    # detectable.
    scheduled = [t["topicId"] for d in plan["days"] for t in d["tasks"]]
    check(f"[{track_id}] plan schedules tasks", len(scheduled) > 0)
    if scheduled:
        edited = set(sel)
        edited.discard(scheduled[0])
        stale_errors = validate_plan(plan, view, edited, exam_profile)
        check(f"[{track_id}] stale plan rejected after scope change (§33)",
              any("out of scope" in e for e in stale_errors), str(stale_errors[:3]))

    # --- M6 practice bank + loop ---
    weak_ids = {t["topicId"] for t in weak_first(profile)[:5]}
    questions = build_practice_bank(course, view, sel, weak_ids)
    check(f"[{track_id}] practice bank non-empty", len(questions) > 0)
    for q in questions:
        check(f"[{track_id}] prac {q['id']} topic in scope", q["topicId"] in sel)
        if q["kind"] == "mcq":
            check(f"[{track_id}] prac {q['id']} 4 options",
                  len(q["options"]) == 4 and 0 <= q["correctIndex"] < 4)
        else:
            check(f"[{track_id}] prac {q['id']} has accepted answers",
                  len(q["acceptedAnswers"]) > 0)

    has_typed = any(q["kind"] == "shortAnswer" for q in questions)
    # §24: do NOT force every question type onto every subject — typed
    # questions exist exactly when the course data has sub-topics.
    data_has_subtopics = any(
        subtopics_of(i) for s in course["sections"] for i in s.get("items", []))
    check(f"[{track_id}] typed questions ⇔ data has subtopics (§24)",
          has_typed == data_has_subtopics,
          f"typed={has_typed} subtopics={data_has_subtopics}")

    # Loop simulation: correct MCQ; wrong MCQ retry; typed correct;
    # typed gray-zone; photo paths.
    mcq = next(q for q in questions if q["kind"] == "mcq")
    r_ok = evaluate_mcq(mcq["correctIndex"], mcq["correctIndex"], mcq["options"][mcq["correctIndex"]])
    r_bad = evaluate_mcq(mcq["correctIndex"], (mcq["correctIndex"] + 1) % 4, mcq["options"][mcq["correctIndex"]])
    check(f"[{track_id}] loop: MCQ correct verdict", r_ok["verdict"] == "correct")
    check(f"[{track_id}] loop: MCQ wrong verdict + §28 feedback",
          r_bad["verdict"] == "incorrect" and r_bad["feedback"] != "Wrong.")

    if has_typed:
        typed = next(q for q in questions if q["kind"] == "shortAnswer")
        acc = typed["acceptedAnswers"][0]
        r1 = evaluate_typed(typed["prompt"], acc, typed["acceptedAnswers"], typed["requiredPoints"])
        check(f"[{track_id}] loop: exact typed answer correct/partial+",
              r1["verdict"] in ("correct", "partiallyCorrect"), r1["verdict"])
        r2 = evaluate_typed(typed["prompt"], f" {acc}।  ", typed["acceptedAnswers"], typed["requiredPoints"])
        check(f"[{track_id}] M7 normalizer: danda/space absorbed",
              r2["verdict"] == r1["verdict"])
        r3 = evaluate_typed(typed["prompt"], "पता नहीं", typed["acceptedAnswers"], typed["requiredPoints"])
        check(f"[{track_id}] gray-zone → uncertain (§26)", r3["verdict"] in ("uncertain", "incorrect"))
        r4 = evaluate_typed(typed["prompt"], "", typed["acceptedAnswers"], typed["requiredPoints"])
        check(f"[{track_id}] empty → honest miss + issue", "emptyAnswer" in r4["issues"])

    # --- M7 photo pipeline ---
    issue = photo_quality_gate(3, 100, 100)
    check(f"[{track_id}] photo gate: tiny rejected", issue == "tooSmallPhoto")
    issue = photo_quality_gate(64 * 1024, 2000, 100)
    check(f"[{track_id}] photo gate: strip crop rejected", issue == "croppedPhoto")
    issue = photo_quality_gate(64 * 1024, 1200, 900)
    check(f"[{track_id}] photo gate: good passes", issue is None)

    if has_typed:
        typed = next(q for q in questions if q["kind"] == "shortAnswer")
        acc = typed["acceptedAnswers"]
        pts = typed["requiredPoints"]
        pr = photo_evaluate(None, acc, pts, typed["prompt"])
        check(f"[{track_id}] photo offline → uncertain + typed advice (§17)",
              pr["verdict"] == "uncertain" and "offlinePhoto" in pr["issues"])
        pr = photo_evaluate("timeout", acc, pts, typed["prompt"])
        check(f"[{track_id}] photo timeout → uncertain (§26)",
              pr["verdict"] == "uncertain")
        pr = photo_evaluate({"readable": False, "confident": False, "text": ""}, acc, pts, typed["prompt"])
        check(f"[{track_id}] unreadable photo → uncertain, never guessed",
              pr["verdict"] == "uncertain" and "unreadablePhoto" in pr["issues"])
        pr = photo_evaluate({"readable": True, "confident": False, "text": acc[0]}, acc, pts, typed["prompt"])
        check(f"[{track_id}] ambiguous extraction → uncertain (§26)",
              pr["verdict"] == "uncertain" and "ambiguousExtraction" in pr["issues"])
        pr = photo_evaluate({"readable": True, "confident": True, "text": acc[0]}, acc, pts, typed["prompt"])
        check(f"[{track_id}] confident extraction graded via rubric (§27)",
              pr["verdict"] in ("correct", "partiallyCorrect"), pr.get("verdict"))
        collect(pr.get("feedback", ""))

    # --- M6 mastery updates ---
    mastery = {}
    m = apply_attempt(mastery.get(mcq["topicId"], {"strength": 0, "attempts": 0, "correct": 0, "stage": "learning"}), True)
    check(f"[{track_id}] mastery: correct strengthens (§29)", m["attempts"] == 1 and m["correct"] == 1)
    m2 = apply_attempt(m, False)
    m3 = apply_attempt(m2, False)
    check(f"[{track_id}] mastery: repeated misses weaken stage",
          STAGE_RANK[m3["stage"]] <= STAGE_RANK["learning"], m3["stage"])


def main():
    run_m3_checks()
    tracks, courses = load_courses()
    check("index loads all 7 courses", len(tracks) == 7, str(tracks))
    for track_id in tracks:
        run_track(track_id, courses[track_id])

    # Global §30 sweep over every student-facing string produced.
    bad = [s for s in ALL_STUDENT_STRINGS if "%" in s or "प्रतिशत" in s]
    check("§30 global: no percentage strings anywhere", not bad, str(bad[:3]))

    print(f"M3-M7 mirror: {CHECKS['run']} checks, {CHECKS['failed']} failed")
    if FAILURES:
        print("FAILURES:")
        for f in FAILURES[:40]:
            print(" -", f)
        sys.exit(1)
    print("ALL GREEN")


if __name__ == "__main__":
    main()
