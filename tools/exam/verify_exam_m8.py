#!/usr/bin/env python3
"""Exam Mode 2.0 — M8 Verification Mirror (Python invariant port).

The M8 milestone (weak areas + revision) shipped with the same no-Flutter-
SDK constraint as M3-M7 (see tools/syllabus/README.md): this script
mirrors the M8 Dart logic 1:1 (same thresholds, same rules, same data)
and asserts every invariant against the REAL canonical syllabus JSONs
under assets/syllabus/cbse/.

Mirrored units:
  §47/§21 ErrorIntelligence — classification, pattern thresholds,
      misconception escalation, no-fabrication, deterministic order
  §21    WeakAreaEngine     — signal sources, severity ladder, ranking,
      §48 cap, insufficient-evidence honesty, M8 PYQ/mock honesty
  §23    RevisionEngine     — expanding/contracting ladder, schedule
      seeding, dueToday, reviewMix (mistake-first, round-robin)
  §22    WeakAreaDayEngine  — frequency tiers, gap rules, hard caps,
      blueprint phases, §50 rationale
  §22    RemediationEngine  — phase split, held-aside fresh recheck,
      mastery-recheck judging
  §12/§56 Repositories      — attempt-log bounds/isolation/corruption,
      weak-area state round-trips + outcome cap
  §22/§23 Planner connection — the AMENDED deterministic planner
      (recovery-day reservation + first-slot revision reviews), the
      amended validator (weakArea is an active backbone task), budget
      fit across every course × budget × weak-area shape, and the
      Gemini prompt digest presence/absence
  §60    PracticeContentBank — topicFilter grounding + the M8 fix for
      the single-typed-question clamp crash (latent M6 bug)

Like the M3-M7 mirror this is an INVARIANT mirror, not a byte-parity
mirror: Dart's List.sort is unstable while Python's is stable, so
question ORDER may differ while every invariant is asserted identically.

Run: python3 tools/exam/verify_exam_m8.py
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, date

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


def parse_iso(s):
    try:
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


NOW = datetime(2026, 9, 12, 10, 0, 0)


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


def build_options(correct, pool, seed):
    distinct = [t for t in dict.fromkeys(pool) if t != correct]
    if len(distinct) < 3:
        return None
    chosen = deterministic_shuffle(distinct, seed_from_text(seed))[:3]
    all_opts = [correct] + chosen
    shuffled = deterministic_shuffle(all_opts, seed_from_text(seed + "_shuffle"))
    return (shuffled, shuffled.index(correct))


# ---------------------------------------------------------------------------
# §47/§21 — ErrorIntelligence (domain/weakarea/error_intelligence.dart)
# ---------------------------------------------------------------------------

PATTERN_THRESHOLD = 2
MISCONCEPTION_THRESHOLD = 3
UNFABRICATABLE = {"grammarError", "timeIssue"}
CATEGORY_RANK = {
    "misconception": 0, "conceptGap": 1, "applicationGap": 2,
    "structureError": 3, "incompleteAnswer": 4, "recallGap": 5,
    "questionInterpretation": 6, "carelessMistake": 7,
}


def ev_classify(e):
    """Port of ErrorIntelligence.classify."""
    if e["verdict"] == "uncertain":
        return None  # input problem (§26)
    if e["verdict"] == "correct":
        return "carelessMistake" if e["retries"] >= 1 else None
    if e["verdict"] == "revealed":
        return "recallGap"
    if e["verdict"] == "partiallyCorrect":
        if e["kind"] == "mcq":
            return "questionInterpretation"
        return "structureError" if e["retries"] >= 1 else "incompleteAnswer"
    # incorrect
    if e["retries"] >= 1:
        return "conceptGap"
    return "applicationGap" if e["kind"] == "typed" else "recallGap"


def ev_is_wrong(e):
    return e["verdict"] in ("incorrect", "revealed", "partiallyCorrect")


def analyze(evidence):
    """Port of ErrorIntelligence.analyze (patterns, never counts)."""
    by_topic_category = {}
    for e in evidence:
        cat = ev_classify(e)
        if cat is None:
            continue
        by_topic_category.setdefault(e["topicId"], {}).setdefault(cat, []).append(e)

    patterns = []
    for topic_id, categories in by_topic_category.items():
        for cat, lst in categories.items():
            wrongs = len(lst)
            if wrongs < PATTERN_THRESHOLD:
                continue
            wrong_after_retry = sum(
                1 for e in lst if ev_is_wrong(e) and e["retries"] >= 1)
            if cat == "conceptGap" and (
                    wrongs >= MISCONCEPTION_THRESHOLD or wrong_after_retry >= 2):
                patterns.append(_pattern_of("misconception", topic_id, lst))
                continue
            patterns.append(_pattern_of(cat, topic_id, lst))

    # Deterministic order: misconception first, occurrences desc, topic.
    patterns.sort(key=lambda p: (
        CATEGORY_RANK.get(p["category"], 9), -p["occurrences"], p["topicId"]))
    return patterns


def _pattern_of(category, topic_id, lst):
    s = sorted(lst, key=lambda e: e["atIso"])
    return {
        "category": category, "topicId": topic_id, "occurrences": len(s),
        "questionIds": [e["questionId"] for e in s],
        "firstSeenIso": s[0]["atIso"], "lastSeenIso": s[-1]["atIso"],
    }


# ---------------------------------------------------------------------------
# §21 — WeakAreaEngine (domain/weakarea/weak_topic_engine.dart)
# ---------------------------------------------------------------------------

MAX_FINDINGS = 5
REPEATED_WRONG_ACCURACY = 0.4
PYQ_MOCK_SIGNALS = {"weakPyq", "weakMock"}
SEVERITY_INDEX = {"watch": 0, "focus": 1, "needsAttention": 2}


def build_report(learner, patterns, revision_items, now):
    """Port of WeakAreaEngine.build."""
    pattern_by_topic = {}
    for p in patterns:
        pattern_by_topic.setdefault(p["topicId"], []).append(p)
    overdue_by_topic = {}
    for item in revision_items:
        if band_of(item, now) == "overdue":
            overdue_by_topic[item["topicId"]] = item

    candidates = {}

    def upsert(topic_id, add_signals, add_categories, sentence):
        existing = candidates.get(topic_id)
        signals = set(existing["signals"]) if existing else set()
        signals |= set(add_signals)
        categories = set(existing["categories"]) if existing else set()
        categories |= set(add_categories)
        has_misconception_signal = (
            "repeatedMisconception" in signals or "lowMastery" in signals)
        stage = learner["topics"].get(topic_id, {}).get("stage")
        if has_misconception_signal or stage == "needsAttention":
            severity = "needsAttention"
        elif len(signals) >= 2:
            severity = "focus"
        else:
            severity = "watch"
        candidates[topic_id] = {
            "topicId": topic_id, "severity": severity, "signals": signals,
            "categories": categories, "sentence": sentence,
        }

    # Source 1: mastery stages + accuracy (§21 low mastery, repeated wrong).
    for mastery in learner["topics"].values():
        if mastery.get("attemptCount", 0) <= 0:
            continue
        accuracy = (mastery["correctCount"] / mastery["attemptCount"]
                    if mastery["attemptCount"] else 0.0)
        stage = mastery["stage"]
        if stage == "needsAttention":
            upsert(mastery["topicId"], {"lowMastery"}, set(),
                   "इस विषय में लगातार कठिनाई दिख रही है — इसे पहले ठीक करेंगे।")
        elif stage == "needsReview":
            upsert(mastery["topicId"], {"forgottenConcept"}, set(),
                   "पहले यह अच्छा आता था, अब धुंधला हो रहा है — हल्का दोहराव काफ़ी है।")
        elif (mastery["attemptCount"] >= 3
              and accuracy < REPEATED_WRONG_ACCURACY):
            upsert(mastery["topicId"], {"repeatedWrong"}, set(),
                   "यहाँ गलतियाँ दोहराई जा रही हैं — चुनिंदा अभ्यास से सुधर आएगा।")

    # Source 2: error PATTERNS (§21/§47).
    for topic_id, topic_patterns in pattern_by_topic.items():
        for p in topic_patterns:
            cat = p["category"]
            if cat == "misconception":
                upsert(topic_id, {"repeatedMisconception"}, {cat},
                       PATTERN_SENTENCES[cat])
            elif cat in ("structureError", "incompleteAnswer"):
                upsert(topic_id, {"poorAnswerQuality"}, {cat},
                       PATTERN_SENTENCES[cat])
            elif cat in ("conceptGap", "applicationGap", "recallGap",
                         "questionInterpretation", "carelessMistake"):
                upsert(topic_id, {"repeatedWrong"}, {cat},
                       PATTERN_SENTENCES[cat])
            else:
                pass  # unfabricatable — no data, no signal (§21 honesty)

    # Source 3: forgetting risk (§23 overdue items).
    for topic_id in overdue_by_topic:
        upsert(topic_id, {"forgottenConcept"}, set(),
               "इस विषय का दोहराव समय पर नहीं हुआ — भूलने का ख़तरा है।")

    ranked = sorted(
        candidates.values(),
        key=lambda f: (-SEVERITY_INDEX[f["severity"]], -len(f["signals"]),
                       learner["topics"].get(f["topicId"], {}).get("strength", 1.0),
                       f["topicId"]))
    findings = ranked[:MAX_FINDINGS]

    has_any_evidence = bool(findings) or any(
        t.get("attemptCount", 0) >= 2 for t in learner["topics"].values())
    insufficient = not findings and not has_any_evidence
    note = ("ये निष्कर्ष आपके असली अभ्यास से निकले हैं — अंदाज़ा नहीं।"
            if findings else
            ("अभी इतना अभ्यास नहीं हुआ कि कमज़ोरी बता सकें — कुछ दिन अभ्यास "
             "के बाद यहीं दिखेगा।" if insufficient else
             "फ़िलहाल कोई खास कमज़ोरी नहीं दिख रही — बढ़िया चल रहा है!"))
    return {"findings": findings, "insufficientEvidence": insufficient,
            "evidenceNote": note}


PATTERN_SENTENCES = {
    "conceptGap": ("यह विषय दो बार समझने के बाद भी गड़बड़ा रहा है — छोटा "
                   "concept-gap है, आदत नहीं।"),
    "recallGap": ("याद रखने में दो बार अटके — recall को हल्के दोहराव से "
                  "पक्का करेंगे।"),
    "applicationGap": ("लागू करने (apply) वाले सवालों में दो बार गलती — "
                       "अभ्यास की दिशा बदलेंगे।"),
    "questionInterpretation": ("प्रश्न के अर्थ से दो बार भटके — सवाल धीरे "
                               "पढ़ने की आदत बनाएँगे।"),
    "carelessMistake": ("बताने पर सुधार कर लेते हैं, पर पहली बार में दो बार "
                        "फिसले — सावधानी का अभ्यास।"),
    "structureError": ("उत्तर की बनावट में दो बार कमी आई — structure पर छोटा "
                       "focus।"),
    "incompleteAnswer": ("उत्तर दो बार अधूरे रहे — मुख्य बिंदु गिनकर लिखने की "
                         "आदत।"),
    "misconception": ("एक ही गलतफहमी बार-बार लौट रही है — पहले उसे साफ़ "
                      "करेंगे, फिर अभ्यास।"),
    "grammarError": "",  # unfabricatable — never rendered
    "timeIssue": "",     # unfabricatable — never rendered
}


def report_is_m8_honest(report):
    return all(not (f["signals"] & PYQ_MOCK_SIGNALS) for f in report["findings"])


def report_has_attention(report):
    return any(f["severity"] == "needsAttention" for f in report["findings"])


def attention_first(report):
    return sorted(
        report["findings"],
        key=lambda f: (-SEVERITY_INDEX[f["severity"]], -len(f["signals"])))


# ---------------------------------------------------------------------------
# §23 — RevisionEngine (domain/weakarea/revision_schedule.dart)
# ---------------------------------------------------------------------------

INTERVAL_DAYS = [1, 2, 4, 7, 15, 30]
BAND_INDEX = {"fresh": 0, "due": 1, "overdue": 2}
CONTRACT_STEP = 2


def interval_days(item):
    idx = item["intervalIndex"]
    return INTERVAL_DAYS[min(max(idx, 0), len(INTERVAL_DAYS) - 1)]


def band_of(item, now):
    due = parse_iso(item["dueIso"])
    if due is None:
        return "due"
    delta_days = (now - due).days
    if delta_days >= 1:
        return "overdue"
    if now >= due:
        return "due"
    return "fresh"


def band_label(item):
    return {
        "fresh": "ताज़ा — अभी दोहराने की ज़रूरत नहीं",
        "due": "दोहराव का समय आ गया है",
        "overdue": "देर हो रही है — भूलने का ख़तरा",
    }[band_of(item, NOW)]


def rev_expand(item, now):
    next_index = min(item["intervalIndex"] + 1, len(INTERVAL_DAYS) - 1)
    days = INTERVAL_DAYS[next_index]
    return {**item, "intervalIndex": next_index,
            "lastReviewedIso": iso(now),
            "dueIso": iso(now + timedelta(days=days))}


def rev_contract(item, now):
    next_index = max(item["intervalIndex"] - CONTRACT_STEP, 0)
    days = INTERVAL_DAYS[next_index]
    return {**item, "intervalIndex": next_index,
            "lastReviewedIso": iso(now),
            "dueIso": iso(now + timedelta(days=days))}


def rev_schedule(learner, patterns, history, now):
    """Port of RevisionEngine.schedule."""
    out = dict(history)

    for p in patterns:
        relearning = {
            "topicId": p["topicId"], "intervalIndex": 0,
            "lastReviewedIso": iso(now),
            "dueIso": iso(now + timedelta(days=1)),
        }
        existing = out.get(p["topicId"])
        if existing is None:
            out[p["topicId"]] = relearning
        else:
            existing_due = parse_iso(existing["dueIso"])
            relearn_due = parse_iso(relearning["dueIso"])
            if existing_due is None or relearn_due is None:
                out[p["topicId"]] = relearning
            elif relearn_due < existing_due:
                out[p["topicId"]] = relearning

    for mastery in learner["topics"].values():
        if mastery.get("attemptCount", 0) <= 0:
            continue
        if mastery["topicId"] in out:
            continue
        stage = mastery["stage"]
        if stage not in ("strong", "mastered"):
            continue
        start_index = 2 if stage == "mastered" else 1
        lp = parse_iso(mastery.get("lastPracticedAtIso", ""))
        anchor = NOW if (lp is None or lp > now) else lp
        out[mastery["topicId"]] = {
            "topicId": mastery["topicId"], "intervalIndex": start_index,
            "lastReviewedIso": iso(anchor),
            "dueIso": iso(anchor + timedelta(days=INTERVAL_DAYS[start_index])),
        }

    items = sorted(
        out.values(),
        key=lambda i: (-BAND_INDEX[band_of(i, now)], i["topicId"]))
    return items


def due_today(items, now, limit=3):
    due = [i for i in items if band_of(i, now) != "fresh"]
    # Port of the Dart sort: band desc, then topicId (NOT dueIso).
    due.sort(key=lambda i: (-BAND_INDEX[band_of(i, now)], i["topicId"]))
    return due[:limit]


def review_mix(questions, wrong_ids, due_topics, target_size=8):
    """Port of RevisionEngine.reviewMix (§23 never the original lesson)."""
    in_scope = [q for q in questions if q["topicId"] in due_topics]
    wrong_first = [q for q in in_scope if q["id"] in wrong_ids]

    by_topic = {}
    for q in in_scope:
        if q["id"] in wrong_ids:
            continue
        by_topic.setdefault(q["topicId"], []).append(q)

    mixed = []
    added = True
    while added:
        added = False
        for topic in sorted(by_topic.keys()):
            lst = by_topic[topic]
            if lst:
                mixed.append(lst.pop(0))
                added = True

    out, seen = [], set()
    for q in wrong_first + mixed:
        if q["id"] in seen:
            continue
        seen.add(q["id"])
        out.append(q)
        if len(out) >= target_size:
            break
    return out


# ---------------------------------------------------------------------------
# §22 — WeakAreaDayEngine (domain/weakarea/weak_area_day.dart)
# ---------------------------------------------------------------------------

FREQ_GAP = {"frequent": 3, "occasional": 5, "none": 7}
FREQ_INDEX = {"none": 0, "occasional": 1, "frequent": 2}


def decide(report, revision_items, day_count, days_since=None,
           last_recovery_day=None, now=None):
    """Port of WeakAreaDayEngine.decide."""
    now = now or NOW
    focus = attention_first(report)
    top = focus[0] if focus else None

    if report_has_attention(report) and top:
        return _decide(
            "frequent", top["topicId"], day_count, days_since,
            last_recovery_day,
            "इस हफ़्ते का एक दिन कमज़ोर क्षेत्र की recovery पर रखा गया है — "
            "डायग्नोस्टिक और अभ्यास दोनों यही कह रहे हैं।")

    overdue = sum(1 for i in revision_items if band_of(i, now) == "overdue")
    if (focus and focus[0]["severity"] == "focus") or overdue >= 2:
        focus_id = (focus[0]["topicId"] if focus else
                    (revision_items[0]["topicId"] if revision_items else ""))
        return _decide(
            "occasional", focus_id, day_count, days_since, last_recovery_day,
            ("दो विषयों का दोहराव टल गया है — एक दिन हल्की recovery + दोहराव पर "
             "देंगे।" if (overdue >= 2 and not focus) else
             "इस हफ़्ते एक दिन recovery पर — धीरे-धीरे उस विषय को पक्का करेंगे।"))

    due_soon = [i for i in revision_items if band_of(i, now) != "fresh"]
    if focus or due_soon:
        focus_id = (focus[0]["topicId"] if focus else
                    (due_soon[0]["topicId"] if due_soon else ""))
        return _decide(
            "none", focus_id, day_count, days_since, last_recovery_day,
            "प्रगति ठीक है — बस एक हल्की recovery रखी गई है ताकि दोहराव छूटे नहीं।")

    return {"shouldRecover": False, "frequency": "none", "dayIndex": -1,
            "focusTopicId": "",
            "rationale": "अभी किसी recovery दिन की ज़रूरत नहीं — आपकी प्रगति "
                         "संतुलित है।"}


def _decide(frequency, focus_id, day_count, days_since, last_recovery_day,
            rationale):
    if not focus_id or day_count < 1:
        return {"shouldRecover": False, "frequency": "none", "dayIndex": -1,
                "focusTopicId": "",
                "rationale": "अभी recovery के लिए पर्याप्त सबूत नहीं है।"}

    gap = FREQ_GAP[frequency]
    eligible = days_since is None or days_since >= gap

    day = -1
    if eligible:
        day = 1
        if last_recovery_day is not None and day <= last_recovery_day + 1:
            day = last_recovery_day + 2
        if day >= day_count:
            day = -1

    return {"shouldRecover": day >= 0, "frequency": frequency,
            "dayIndex": day, "focusTopicId": focus_id, "rationale": rationale}


BLUEPRINT_PHASES = ["recap", "mistakeRetry", "targetedPractice", "recheck"]


def blueprint_for(topic_id, topic_title, rationale=""):
    return {"topicId": topic_id, "topicTitle": topic_title,
            "phases": list(BLUEPRINT_PHASES), "rationale": rationale}


# ---------------------------------------------------------------------------
# §22 — RemediationEngine (domain/weakarea/remediation_engine.dart)
# ---------------------------------------------------------------------------

RECHECK_SIZE = 2
MAX_MISTAKE_RETRIES = 3


def build_remediation(topic_id, recap, pool, wrong_ids):
    """Port of RemediationEngine.build."""
    wrong = sorted((q for q in pool if q["id"] in wrong_ids),
                   key=lambda q: q["id"])
    mistake_retry = wrong[:MAX_MISTAKE_RETRIES]

    fresh = sorted((q for q in pool if q["id"] not in wrong_ids),
                   key=lambda q: q["tier"])

    recheck = []
    recheck_pool = []
    for q in fresh:
        if q["tier"] == 2 and len(recheck) < RECHECK_SIZE:
            recheck.append(q)
        else:
            recheck_pool.append(q)
    while recheck_pool and len(recheck) < RECHECK_SIZE:
        recheck.append(recheck_pool.pop(0))

    return {
        "topicId": topic_id, "recap": recap,
        "mistakeRetryQuestions": mistake_retry,
        "targetedQuestions": recheck_pool,
        "recheckQuestions": recheck,
    }


def plan_is_viable(plan):
    return bool(plan["recheckQuestions"]) and bool(
        plan["mistakeRetryQuestions"] + plan["targetedQuestions"])


def judge_recheck(recheck_attempts):
    if len(recheck_attempts) < RECHECK_SIZE:
        return "stillNeedsWork"
    all_good = all(a["verdict"] in ("correct", "partiallyCorrect")
                   for a in recheck_attempts)
    return "recovered" if all_good else "stillNeedsWork"


def outcome_summary(outcome):
    return {
        "recovered": ("अच्छा — mastery जाँच साफ़ हो गई। अब इस विषय का दोहराव "
                      "थोड़ा लंबा अंतराल पर रखेंगे।"),
        "stillNeedsWork": ("अभी पूरी तरह पक्का नहीं हुआ — कोई बात नहीं, अगली "
                           "recovery में फिर छूएँगे। कम-से-कम आगे बढ़ते रहें।"),
        "notRun": "mastery जाँच अभी शुरू नहीं हुई।",
    }[outcome]


# ---------------------------------------------------------------------------
# §12/§56 — Repositories (data/weakarea/*.dart), JSON-level simulation
# ---------------------------------------------------------------------------

ATTEMPT_LOG_MAX_ENTRIES = 300
RECHECK_OUTCOME_CAP = 100


def attempt_log_load_all(store):
    """Port of ExamAttemptLogRepository.loadAll (corrupt → {})."""
    raw = store.get("exam_attempt_log_v1")
    if not raw:
        return {}
    try:
        doc = json.loads(raw)
        out = {}
        for track, value in doc.get("entries", {}).items():
            try:
                out[track] = [
                    {
                        "questionId": e.get("questionId", ""),
                        "topicId": e.get("topicId", ""),
                        "kind": e.get("kind", "mcq"),
                        "verdict": e.get("verdict", ""),
                        "retries": int(e.get("retries", 0) or 0),
                        "atIso": e.get("atIso", ""),
                    }
                    for e in value
                ]
            except (TypeError, KeyError):
                continue  # corrupt entry set — skip (§41)
        return out
    except (ValueError, TypeError):
        return {}


def attempt_log_record(store, track_id, attempts):
    """Port of recordSession (batched, bounded, defensive — never
    creates an empty entry)."""
    if not attempts:
        return
    all_ = attempt_log_load_all(store)
    lst = list(all_.get(track_id, []))
    filtered = [a for a in attempts
                if a["questionId"] and a["topicId"]]
    if not filtered and not lst:
        return
    lst.extend(filtered)
    if len(lst) > ATTEMPT_LOG_MAX_ENTRIES:
        lst = lst[-ATTEMPT_LOG_MAX_ENTRIES:]
    all_[track_id] = lst
    store["exam_attempt_log_v1"] = json.dumps(
        {"version": 1, "entries": all_}, ensure_ascii=False)


def wrong_ids_by_topic(entries):
    out = {}
    for e in entries:
        if ev_is_wrong(e):
            out.setdefault(e["topicId"], set()).add(e["questionId"])
    return out


def weak_state_load(store, track_id):
    """Port of WeakAreaRepository.load (corrupt → empty state)."""
    raw = store.get("exam_weak_area_v1")
    if not raw:
        return {"trackId": track_id, "lastRecoveryDayIso": "",
                "recoveryDayCount": 0, "revision": {},
                "recheckOutcomes": []}
    try:
        doc = json.loads(raw)
        state = doc["states"][track_id]
        revision = {}
        for topic, value in state.get("revision", {}).items():
            try:
                revision[topic] = {
                    "topicId": value.get("topicId", ""),
                    "intervalIndex": int(value.get("intervalIndex", 0) or 0),
                    "lastReviewedIso": value.get("lastReviewedIso", ""),
                    "dueIso": value.get("dueIso", ""),
                }
            except (TypeError, KeyError, ValueError):
                continue
        outcomes = []
        for o in state.get("recheckOutcomes", []):
            try:
                outcomes.append({
                    "topicId": o["topicId"],
                    "outcome": o.get("outcome", "notRun"),
                    "atIso": o.get("atIso", ""),
                })
            except (TypeError, KeyError):
                continue
        return {"trackId": state.get("trackId", track_id),
                "lastRecoveryDayIso": state.get("lastRecoveryDayIso", ""),
                "recoveryDayCount": int(state.get("recoveryDayCount", 0) or 0),
                "revision": revision, "recheckOutcomes": outcomes}
    except (ValueError, TypeError, KeyError):
        return {"trackId": track_id, "lastRecoveryDayIso": "",
                "recoveryDayCount": 0, "revision": {},
                "recheckOutcomes": []}


def weak_state_with_recovery(state, now):
    return {**state, "lastRecoveryDayIso": iso(now),
            "recoveryDayCount": state["recoveryDayCount"] + 1}


def weak_state_with_recheck(state, record):
    bounded = state["recheckOutcomes"] + [record]
    if len(bounded) > RECHECK_OUTCOME_CAP:
        bounded = bounded[-RECHECK_OUTCOME_CAP:]
    return {**state, "recheckOutcomes": bounded}


# ---------------------------------------------------------------------------
# Syllabus scope view + content bank (M2/M6 ports, reused for M8 grounding)
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
    sections = []
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
            board_chapters = [(b, c) for b, c in chapters
                               if c.get("examRelevance") != "internal-only"]
            internal = [(b, c) for b, c in chapters
                        if c.get("examRelevance") == "internal-only"]
            if board_chapters or internal:
                chapters_added = True
                for book, ch in board_chapters:
                    units.append({"id": ch["id"], "title": ch["title"],
                                  "sectionId": section["id"],
                                  "selectable": True, "marks": None})
                for book, ch in internal:
                    units.append({"id": ch["id"], "title": ch["title"],
                                  "sectionId": section["id"],
                                  "selectable": False, "marks": None})
        for item in section.get("items", []):
            if section["stableKey"] == "literature" and chapters_added:
                continue
            selectable = (item.get("status", "published") == "published"
                          and item.get("assessmentType", "board") == "board")
            units.append({"id": item["id"], "title": item["title"],
                          "sectionId": section["id"],
                          "selectable": selectable,
                          "marks": item.get("marks"),
                          "subtopics": subtopics_of(item)})
        sections.append({"id": section["id"], "title": section["title"],
                         "stableKey": section["stableKey"], "units": units})
    return sections


def selectable_ids(view):
    return {u["id"] for s in view for u in s["units"] if u["selectable"]}


def build_practice_bank(course, view, selection, weak_ids=(), target_size=12,
                        topic_filter=()):
    """Port of PracticeContentBank.build incl. the M8 topicFilter and the
    M8 fix for the single-typed-question clamp crash."""
    selected = [u for s in view for u in s["units"]
                if u["selectable"] and u["id"] in selection
                and (not topic_filter or u["id"] in topic_filter)]
    # M8: distractors stay grounded in the WHOLE scope (single-topic
    # pools keep their tier-3 membership MCQs).
    scope_units = [u for s in view for u in s["units"]
                   if u["selectable"] and u["id"] in selection]
    section_titles = [s["title"] for s in view]
    book_titles = [b["title"] for b in course.get("prescribedBooks", [])]
    items_by_id = {i["id"]: i for s in course["sections"]
                   for i in s.get("items", [])}

    questions = []
    for u in selected:
        section_title = next(s["title"] for s in view
                             if s["id"] == u["sectionId"])
        pool = [t for t in section_titles + book_titles if t != section_title]
        opts = build_options(section_title, pool, u["id"] + "_psec")
        if opts:
            questions.append({
                "id": f"prac_{u['id']}_sec", "topicId": u["id"],
                "kind": "mcq",
                "prompt": f"«{u['title']}» किस खंड में आता है?",
                "options": opts[0], "correctIndex": opts[1], "tier": 1})
        subs = u.get("subtopics") or []
        if subs:
            questions.append({
                "id": f"prac_{u['id']}_typed", "topicId": u["id"],
                "kind": "shortAnswer",
                "prompt": f"«{subs[0]}» किस विषय के अंतर्गत आता है? (नाम लिखें)",
                "acceptedAnswers": [u["title"]],
                "requiredPoints": subs[:3], "tier": 2})
        if len(subs) >= 2:
            distractors = []
            for other in scope_units:
                if other["id"] == u["id"]:
                    continue
                item = items_by_id.get(other["id"])
                if item:
                    distractors.extend(subtopics_of(item)[:3])
            opts = build_options(subs[0], distractors, u["id"] + "_psub")
            if opts:
                questions.append({
                    "id": f"prac_{u['id']}_sub", "topicId": u["id"],
                    "kind": "mcq",
                    "prompt": f"इनमें से कौन-सा «{u['title']}» से संबंधित है?",
                    "options": opts[0], "correctIndex": opts[1], "tier": 3})

    def rank(q):
        return (0 if q["topicId"] in weak_ids else 1) * 10 + q["tier"]

    typed_qs = [q for q in questions if q["kind"] == "shortAnswer"]
    mcq_qs = [q for q in questions if q["kind"] == "mcq"]
    typed_qs.sort(key=rank)
    mcq_qs.sort(key=rank)

    # M8 fix: clamp(2, len) is only valid for len >= 2 — a one-typed pool
    # must NOT throw (single-topic recovery scopes hit this).
    if not typed_qs:
        typed_take = 0
    elif len(typed_qs) == 1:
        typed_take = 1
    else:
        typed_take = min(max(target_size // 3, 2), len(typed_qs))

    return typed_qs[:typed_take] + mcq_qs[:max(0, target_size - typed_take)]


# ---------------------------------------------------------------------------
# §29 learner profile port (needed by planner + engines)
# ---------------------------------------------------------------------------

def apply_attempt(mastery, correct):
    attempts = mastery["attemptCount"] + 1
    corrects = mastery["correctCount"] + (1 if correct else 0)
    target = 1.0 if correct else 0.0
    if mastery["attemptCount"] == 0:
        strength = target
    else:
        strength = mastery["strength"] * 0.6 + target * 0.4
    strength = min(1.0, max(0.0, strength))
    accuracy = corrects / attempts
    if attempts < 2:
        stage = "learning"
    elif accuracy < 0.4:
        stage = "needsAttention"
    elif strength >= 0.8 and attempts >= 8 and accuracy >= 0.8:
        stage = "mastered"
    elif strength >= 0.65 and accuracy >= 0.6:
        stage = "strong"
    elif accuracy >= 0.5:
        stage = "practicing"
    else:
        stage = "learning"
    return {"topicId": mastery["topicId"], "stage": stage,
            "strength": strength, "correctCount": corrects,
            "attemptCount": attempts,
            "lastPracticedAtIso": iso(NOW)}


def weak_first(learner, limit=20):
    stage_rank = {"needsAttention": 0, "needsReview": 1, "learning": 2,
                  "practicing": 3, "strong": 4, "mastered": 5}
    lst = [t for t in learner["topics"].values() if t["attemptCount"] > 0]
    lst.sort(key=lambda t: (stage_rank[t["stage"]], t["strength"]))
    return lst[:limit]


# ---------------------------------------------------------------------------
# §22/§23 planner connection — AMENDED deterministic planner + validator
# ---------------------------------------------------------------------------

def task_minutes_for(budget):
    return 15 if budget >= 45 else (10 if budget >= 10 else budget)


def build_plan(track_id, view, selection, profile, learner, scope_rev,
               weak_area=None):
    """Port of the M8-amended DeterministicExamPlanner.build."""
    selected = [u for s in view for u in s["units"]
                if u["selectable"] and u["id"] in selection]
    weak_ids = {t["topicId"] for t in weak_first(learner, 30)}
    ordered = sorted(
        selected,
        key=lambda u: (0 if u["id"] in weak_ids else 1,
                       -(u["marks"] or 0), u["title"]))

    budget = profile["dailyStudyMinutes"]
    task_minutes = task_minutes_for(budget)
    tasks_per_day = max(1, min(4, budget // task_minutes))
    day_count = max(1, min(7, profile["studyDaysPerWeek"]))

    topic_queue = list(ordered)
    rotation = 0
    decision = weak_area["decision"] if weak_area else None
    recovery_day = (decision["dayIndex"]
                    if decision and decision["shouldRecover"] else -1)
    in_scope = {u["id"] for u in selected}
    revision_queue = []
    if weak_area:
        for i in due_today(weak_area["revisionItems"], NOW, limit=5):
            if i["topicId"] in in_scope:
                revision_queue.append(i)
    revision_used = 0
    title_of = {u["id"]: u["title"] for u in selected}

    days = []
    for day in range(day_count):
        tasks = []

        def used():
            return sum(t["minutes"] for t in tasks)

        if day == recovery_day and decision and decision["shouldRecover"]:
            focus_title = title_of.get(decision["focusTopicId"])
            if focus_title:
                tasks.append({
                    "type": "weakArea", "topicId": decision["focusTopicId"],
                    "title": f"कमज़ोर क्षेत्र recovery: {focus_title}",
                    "minutes": task_minutes, "detail": decision["rationale"]})
            while (revision_used < len(revision_queue)
                   and used() + task_minutes <= budget):
                item = revision_queue[revision_used]
                revision_used += 1
                title = title_of.get(item["topicId"])
                if title is None:
                    continue
                tasks.append({
                    "type": "review", "topicId": item["topicId"],
                    "title": f"दोहराव (भूलने का ख़तरा): {title}",
                    "minutes": task_minutes, "detail": band_label(item)})
            if focus_title and used() + 10 <= budget:
                tasks.append({
                    "type": "practice", "topicId": decision["focusTopicId"],
                    "title": f"लक्षित अभ्यास: {focus_title}", "minutes": 10})
            days.append({"dayIndex": day, "tasks": tasks})
            rotation += 1
            if not topic_queue and selected:
                topic_queue.extend(ordered)
            continue

        # §23: a due revision takes the day's FIRST slot, but only when
        # an active backbone task can still fit after it.
        if (day != recovery_day and revision_used < len(revision_queue)
                and tasks_per_day >= 2):
            item = revision_queue[revision_used]
            revision_used += 1
            title = title_of.get(item["topicId"])
            if title:
                tasks.append({
                    "type": "review", "topicId": item["topicId"],
                    "title": f"दोहराव: {title}", "minutes": task_minutes,
                    "detail": band_label(item)})

        if topic_queue:
            t = len(tasks)
            while t < tasks_per_day and topic_queue:
                unit = topic_queue.pop(0)
                type_ = ("learn" if t == 0
                         else ("practice" if t == 1 else "review"))
                title_map = {"learn": "सीखें", "practice": "अभ्यास",
                             "review": "दोहराव"}
                tasks.append({
                    "type": type_, "topicId": unit["id"],
                    "title": f"{title_map[type_]}: {unit['title']}",
                    "minutes": task_minutes})
                t += 1
            if weak_ids and tasks and used() + 10 <= budget:
                weak_unit = next(
                    (u for u in ordered if u["id"] in weak_ids), None)
                if weak_unit and not any(
                        t["topicId"] == weak_unit["id"] for t in tasks):
                    tasks.append({
                        "type": "weakArea", "topicId": weak_unit["id"],
                        "title": f"कमज़ोर क्षेत्र: {weak_unit['title']}",
                        "minutes": 10})
            if day == 3 and ordered and used() + 10 <= budget:
                u = ordered[rotation % len(ordered)]
                tasks.append({"type": "pyq", "topicId": u["id"],
                              "title": f"PYQ अभ्यास — {u['title']}",
                              "minutes": 10})
            if day == 5 and ordered and used() + 10 <= budget:
                u = ordered[rotation % len(ordered)]
                tasks.append({"type": "mock", "topicId": u["id"],
                              "title": f"मिनी mock — {u['title']}",
                              "minutes": 10})
            rotation += 1

        if not topic_queue and selected:
            topic_queue.extend(ordered)
        days.append({"dayIndex": day, "tasks": tasks})

    focus_summary = ("Scope खाली है — पहले syllabus चुनें" if not ordered else
                     "इस सप्ताह का लक्ष्य: " +
                     ", ".join(u["title"] for u in ordered[:3]))
    rationale = ("डायग्नोस्टिक के आधार पर कमज़ोर विषय पहले — फिर अंक-भार के "
                 "क्रम में। हर दिन आपके %d मिनट के अंदर। (offline योजना)"
                 % budget if learner.get("hasDiagnostic") else
                 "डायग्नोस्टिक अभी नहीं हुआ — आधिकारिक अंकों के क्रम में विषय। "
                 "हर दिन आपके %d मिनट के अंदर। (offline योजना)" % budget)
    if recovery_day >= 0 and decision and decision["shouldRecover"]:
        rationale = (decision["rationale"] + " बाक़ी दिन डायग्नोस्टिक क्रम में "
                     "— हर दिन आपके %d मिनट के अंदर। (offline योजना)" % budget)

    return {"id": f"plan-{track_id}-{scope_rev}", "trackId": track_id,
            "source": "deterministic", "scopeRevision": scope_rev,
            "focusSummary": focus_summary, "rationale": rationale,
            "days": days}


def validate_plan_m8(plan, selection, profile):
    """Port of the AMENDED ExamPlanValidator (weakArea is backbone)."""
    errors = []
    allowed = set(selection)
    if not plan["days"]:
        errors.append("no days")
        return errors
    if len(plan["days"]) > 7:
        errors.append("too many days")
    if plan["days"][0]["dayIndex"] != 0:
        errors.append("first day not 0")
    for day in plan["days"]:
        if not day["tasks"]:
            errors.append(f"day {day['dayIndex']} empty")
            continue
        total = sum(t["minutes"] for t in day["tasks"])
        if total > profile["dailyStudyMinutes"]:
            errors.append(
                f"day {day['dayIndex']} over budget: {total} > "
                f"{profile['dailyStudyMinutes']}")
        backbone = any(t["type"] in ("learn", "practice", "weakArea")
                       for t in day["tasks"])
        if not backbone:
            errors.append(f"day {day['dayIndex']} no active task")
        for t in day["tasks"]:
            if t["topicId"] not in allowed:
                errors.append(f"out of scope: {t['topicId']}")
            if t["minutes"] < 1 or t["minutes"] > 90:
                errors.append(f"minutes out of range: {t['minutes']}")
    return errors


# ---------------------------------------------------------------------------
# Source-level wiring + honesty checks
# ---------------------------------------------------------------------------

DART_WEAKAREA = os.path.join(LIB_EXAM, "domain", "weakarea")
DEVANAGARI = re.compile(r"[\u0900-\u097F]")


def dart_source(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def devanagari_string_literals(src):
    """All single/double-quoted literals containing Devanagari (student
    text). Triple strings are matched greedily between fences."""
    out = []
    for m in re.finditer(r"'([^'\\\n]*)'", src):
        if DEVANAGARI.search(m.group(1)):
            out.append(m.group(1))
    for m in re.finditer(r'"([^"\\\n]*)"', src):
        if DEVANAGARI.search(m.group(1)):
            out.append(m.group(1))
    return out


def run_source_checks():
    files = {
        name: dart_source(os.path.join(DART_WEAKAREA, name))
        for name in [
            "error_intelligence.dart", "weak_topic_engine.dart",
            "revision_schedule.dart", "weak_area_day.dart",
            "remediation_engine.dart",
        ]
    }
    files["weak_area_repository.dart"] = dart_source(
        os.path.join(LIB_EXAM, "data", "weakarea", "weak_area_repository.dart"))
    files["attempt_log_repository.dart"] = dart_source(
        os.path.join(LIB_EXAM, "data", "weakarea",
                     "exam_attempt_log_repository.dart"))
    files["weak_area_screen.dart"] = dart_source(
        os.path.join(LIB_EXAM, "presentation", "screens",
                     "exam_weak_area_screen.dart"))
    files["planner.dart"] = dart_source(
        os.path.join(LIB_EXAM, "data", "planner",
                     "deterministic_exam_planner.dart"))
    files["gemini_planner.dart"] = dart_source(
        os.path.join(LIB_EXAM, "data", "planner", "gemini_exam_planner.dart"))
    files["plan_providers.dart"] = dart_source(
        os.path.join(LIB_EXAM, "presentation", "providers",
                     "exam_plan_providers.dart"))
    files["practice_providers.dart"] = dart_source(
        os.path.join(LIB_EXAM, "presentation", "providers",
                     "exam_practice_providers.dart"))
    files["weakarea_providers.dart"] = dart_source(
        os.path.join(LIB_EXAM, "presentation", "providers",
                     "exam_weakarea_providers.dart"))
    files["validator.dart"] = dart_source(
        os.path.join(LIB_EXAM, "domain", "planner", "exam_plan_validator.dart"))
    files["content_bank.dart"] = dart_source(
        os.path.join(LIB_EXAM, "data", "practice", "practice_content_bank.dart"))

    # §30: no student-facing string contains a percentage.
    for name, src in files.items():
        strings = devanagari_string_literals(src)
        check(f"§30 no '%' in student strings [{name}]",
              all("%" not in s for s in strings),
              [s for s in strings if "%" in s][:3])

    # Parity spot-checks: the mirrored sentences exist in the Dart source.
    for cat, sent in PATTERN_SENTENCES.items():
        if not sent:
            continue
        frag = sent[:12]
        check(f"pattern sentence parity [{cat}]",
              frag in files["error_intelligence.dart"], frag)
    for label, frag in [
        ("fresh", "ताज़ा — अभी दोहराने की ज़रूरत नहीं"),
        ("due", "दोहराव का समय आ गया है"),
        ("overdue", "देर हो रही है — भूलने का ख़तरा"),
    ]:
        check(f"band label parity [{label}]",
              frag in files["revision_schedule.dart"], frag)
    for phase, frag in [
        ("recap", "छोटा concept दोहराव"),
        ("recheck", "mastery जाँच"),
    ]:
        check(f"phase label parity [{phase}]",
              frag in files["weak_area_day.dart"], frag)
    check("outcome summary parity [recovered]",
          "अच्छा — mastery जाँच साफ़ हो गई" in
          files["remediation_engine.dart"])

    # Planner connection wiring (M8 spec: "Connect to planner").
    check("planner imports weak-area decision",
          "weak_area_day.dart" in files["planner.dart"])
    check("planner uses dueToday revision",
          "RevisionEngine.dueToday" in files["planner.dart"])
    check("planner reserves the recovery day",
          "recoveryDay" in files["planner.dart"])
    check("validator accepts weakArea backbone",
          "ExamTaskType.weakArea" in files["validator.dart"])
    check("gemini prompt carries the digest",
          "weakAreaDigest" in files["gemini_planner.dart"]
          and "WEAK AREA" in files["gemini_planner.dart"])
    check("plan provider computes the overview",
          "computeWeakAreaOverview" in files["plan_providers.dart"]
          and "WeakAreaPlannerInput" in files["plan_providers.dart"])
    check("practice loop persists attempt evidence",
          "recordSession" in files["practice_providers.dart"]
          and "ErrorEvidence" in files["practice_providers.dart"])
    check("weakarea provider wires all engines",
          all(sym in files["weakarea_providers.dart"] for sym in [
              "ErrorIntelligence.analyze", "WeakAreaEngine.build",
              "RevisionEngine.schedule", "WeakAreaDayEngine.decide",
              "RemediationEngine.build", "RemediationEngine.judgeRecheck"]))

    # Content bank: topicFilter + the clamp fix are present in source.
    check("content bank has topicFilter",
          "topicFilter" in files["content_bank.dart"])
    check("content bank clamp fix present",
          "typed.length == 1" in files["content_bank.dart"])


# ---------------------------------------------------------------------------
# Behavior checks — engines
# ---------------------------------------------------------------------------

def run_error_intelligence_checks():
    ev = lambda qid, tid, verdict, kind="mcq", retries=0, at=None: {
        "questionId": qid, "topicId": tid, "kind": kind, "verdict": verdict,
        "retries": retries, "atIso": at or "2026-09-01T10:00:00"}

    check("classify: correct first-shot is not an error",
          ev_classify(ev("q", "t", "correct")) is None)
    check("classify: correct-after-retry = careless",
          ev_classify(ev("q", "t", "correct", retries=1)) == "carelessMistake")
    check("classify: revealed = recall gap",
          ev_classify(ev("q", "t", "revealed")) == "recallGap")
    check("classify: partial mcq = interpretation",
          ev_classify(ev("q", "t", "partiallyCorrect")) ==
          "questionInterpretation")
    check("classify: partial typed = incomplete",
          ev_classify(ev("q", "t", "partiallyCorrect", kind="typed")) ==
          "incompleteAnswer")
    check("classify: partial typed retry = structure",
          ev_classify(ev("q", "t", "partiallyCorrect", kind="typed",
                        retries=1)) == "structureError")
    check("classify: incorrect retry = concept gap",
          ev_classify(ev("q", "t", "incorrect", retries=1)) == "conceptGap")
    check("classify: incorrect mcq = recall",
          ev_classify(ev("q", "t", "incorrect")) == "recallGap")
    check("classify: incorrect typed = application",
          ev_classify(ev("q", "t", "incorrect", kind="typed")) ==
          "applicationGap")
    check("§26 uncertain never a student error",
          ev_classify(ev("q", "t", "uncertain", kind="photo")) is None)

    check("singletons dropped (§21)",
          analyze([ev("q1", "t1", "incorrect")]) == [])
    check("different topics never merge into a pattern",
          analyze([ev("q1", "t1", "incorrect"),
                   ev("q2", "t2", "incorrect")]) == [])
    pats = analyze([ev("q1", "t1", "incorrect"), ev("q2", "t1", "incorrect")])
    check("two same-topic misses = recallGap pattern",
          len(pats) == 1 and pats[0]["category"] == "recallGap"
          and pats[0]["occurrences"] == 2)
    pats = analyze([ev("q1", "t1", "incorrect"),
                    ev("q2", "t1", "incorrect"),
                    ev("q3", "t1", "incorrect")])
    check("3 first-shot misses stay recallGap (escalation needs "
          "wrong-after-retry evidence)",
          len(pats) == 1 and pats[0]["category"] == "recallGap"
          and pats[0]["occurrences"] == 3)
    pats = analyze([ev("q1", "t1", "incorrect", retries=1),
                    ev("q2", "t1", "incorrect", retries=1),
                    ev("q3", "t1", "incorrect", retries=1)])
    check("3 wrong-after-retry escalate to misconception (§21)",
          len(pats) == 1 and pats[0]["category"] == "misconception")
    pats = analyze([ev("q1", "t1", "incorrect", retries=1),
                    ev("q2", "t1", "incorrect", retries=1)])
    check("wrong-after-retry twice escalates to misconception",
          len(pats) == 1 and pats[0]["category"] == "misconception")

    pats = analyze(
        [ev("q1", "t2", "incorrect", retries=1),
         ev("q2", "t2", "incorrect", retries=1),
         ev("q3", "t2", "incorrect", retries=1),
         ev("q4", "t1", "incorrect"), ev("q5", "t1", "incorrect")])
    check("deterministic order: misconception first",
          pats[0]["category"] == "misconception" and pats[0]["topicId"] == "t2"
          and pats[-1]["category"] == "recallGap")

    flood = analyze(
        [ev(f"q{i}", f"t{i}", "incorrect", retries=1) for i in range(10)] +
        [ev(f"r{i}", f"u{i}", "incorrect", kind="typed") for i in range(10)] +
        [ev(f"s{i}", f"v{i}", "correct", retries=1) for i in range(10)])
    check("unfabricatable categories never emitted",
          all(p["category"] not in UNFABRICATABLE for p in flood))
    check("flood of single-topic mistakes stays empty (per-topic rule)",
          flood == [])


def run_weak_topic_checks():
    def learner(topics):
        return {"topics": topics, "hasDiagnostic": True}

    def mastery(tid, stage, strength=0.5, correct=2, attempts=4):
        return {"topicId": tid, "stage": stage, "strength": strength,
                "correctCount": correct, "attemptCount": attempts,
                "lastPracticedAtIso": "2026-09-01T10:00:00"}

    def pat(cat, tid, n):
        return {"category": cat, "topicId": tid, "occurrences": n,
                "questionIds": [], "firstSeenIso": "", "lastSeenIso": ""}

    r = build_report(learner({"t1": mastery("t1", "needsAttention",
                                            strength=0.2)}), [], [], NOW)
    check("needsAttention stage → needsAttention finding",
          r["findings"][0]["severity"] == "needsAttention"
          and "lowMastery" in r["findings"][0]["signals"])

    r = build_report(learner({"t1": mastery("t1", "needsReview")}), [], [], NOW)
    check("decayed topic → forgottenConcept",
          "forgottenConcept" in r["findings"][0]["signals"])

    r = build_report(learner({
        "t1": mastery("t1", "practicing", strength=0.3, correct=1,
                      attempts=4)}), [], [], NOW)
    check("sustained low accuracy → repeatedWrong",
          "repeatedWrong" in r["findings"][0]["signals"])

    r = build_report(learner({"t1": mastery("t1", "practicing",
                                            strength=0.3, correct=1)}), [],
                     [{"topicId": "t1", "intervalIndex": 2,
                       "lastReviewedIso": "", "dueIso":
                       iso(NOW - timedelta(days=3))}], NOW)
    check("two signals → focus severity",
          r["findings"][0]["severity"] == "focus"
          and len(r["findings"][0]["signals"]) >= 2)

    r = build_report(learner({}), [pat("misconception", "t1", 3)], [], NOW)
    check("misconception pattern → needsAttention + signal",
          r["findings"][0]["severity"] == "needsAttention"
          and "repeatedMisconception" in r["findings"][0]["signals"])

    r = build_report(learner({}),
                     [pat("structureError", "t1", 2),
                      pat("incompleteAnswer", "t2", 2)], [], NOW)
    check("structure/incomplete → poorAnswerQuality",
          len(r["findings"]) == 2 and all(
              "poorAnswerQuality" in f["signals"] for f in r["findings"]))

    r = build_report(learner({}),
                     [pat("grammarError", "t1", 5),
                      pat("timeIssue", "t2", 5)], [], NOW)
    check("unfabricatable patterns produce NO findings",
          r["findings"] == [])

    topics = {f"t{i}": mastery(f"t{i}", "needsAttention",
                               strength=0.1 + i * 0.01)
              for i in range(8)}
    r = build_report(learner(topics), [], [], NOW)
    check("§48 cap: at most 5 findings, weakest first",
          len(r["findings"]) == MAX_FINDINGS
          and r["findings"][0]["topicId"] == "t0")

    r = build_report(learner({"t1": mastery("t1", "strong", strength=0.9,
                                            correct=9, attempts=10)}),
                     [], [], NOW)
    check("strong student: no findings, honest positive note",
          r["findings"] == [] and not r["insufficientEvidence"])

    r = build_report(learner({}), [], [], NOW)
    check("no evidence at all → insufficient + honest note",
          r["findings"] == [] and r["insufficientEvidence"]
          and r["evidenceNote"])

    r = build_report(
        learner({"t1": mastery("t1", "needsAttention"),
                 "t2": mastery("t2", "practicing", strength=0.2)}),
        [pat("misconception", "t1", 3), pat("recallGap", "t2", 2)],
        [{"topicId": "t1", "intervalIndex": 1, "lastReviewedIso": "",
          "dueIso": iso(NOW - timedelta(days=2))}], NOW)
    check("M8 report never emits PYQ/mock signals", report_is_m8_honest(r))


def run_revision_checks():
    base = {"topicId": "t1", "intervalIndex": 0,
            "lastReviewedIso": iso(NOW), "dueIso": iso(NOW)}
    e = rev_expand(base, NOW)
    check("expand climbs to index 1 (2 days)",
          e["intervalIndex"] == 1 and interval_days(e) == 2
          and e["dueIso"] == iso(NOW + timedelta(days=2)))
    top = rev_expand({**base, "intervalIndex": 5}, NOW)
    check("expand saturates at 30 days",
          top["intervalIndex"] == 5 and interval_days(top) == 30)
    c = rev_contract({**base, "intervalIndex": 4}, NOW)
    check("contract drops 2 steps", c["intervalIndex"] == 2)
    c = rev_contract({**base, "intervalIndex": 0}, NOW)
    check("contract floors at 0", c["intervalIndex"] == 0)

    fresh = {"topicId": "a", "intervalIndex": 1, "lastReviewedIso": "",
             "dueIso": iso(NOW + timedelta(days=3))}
    due = {"topicId": "b", "intervalIndex": 1, "lastReviewedIso": "",
           "dueIso": iso(NOW)}
    overdue = {"topicId": "c", "intervalIndex": 1, "lastReviewedIso": "",
               "dueIso": iso(NOW - timedelta(days=2))}
    same_day = {"topicId": "d", "intervalIndex": 1, "lastReviewedIso": "",
                "dueIso": iso(NOW - timedelta(hours=12))}
    check("bands: fresh/due/overdue",
          band_of(fresh, NOW) == "fresh" and band_of(due, NOW) == "due"
          and band_of(overdue, NOW) == "overdue")
    check("same-day grace: 12h late is still due",
          band_of(same_day, NOW) == "due")

    history = {"t1": {"topicId": "t1", "intervalIndex": 3,
                      "lastReviewedIso": "2026-09-01T10:00:00",
                      "dueIso": "2026-09-08T10:00:00"}}
    items = rev_schedule({"topics": {}}, [], history, NOW)
    check("persisted history is authoritative",
          items[0]["intervalIndex"] == 3
          and items[0]["dueIso"] == "2026-09-08T10:00:00")

    items = rev_schedule({"topics": {}}, [pat := {
        "category": "recallGap", "topicId": "t1", "occurrences": 2,
        "questionIds": [], "firstSeenIso": "", "lastSeenIso": ""}], {}, NOW)
    check("error-pattern topic re-enters as relearning due tomorrow",
          items[0]["intervalIndex"] == 0
          and items[0]["dueIso"] == iso(NOW + timedelta(days=1)))

    sooner = {"t1": {"topicId": "t1", "intervalIndex": 0,
                     "lastReviewedIso": "", "dueIso": iso(NOW)}}
    items = rev_schedule({"topics": {}}, [pat], sooner, NOW)
    check("history keeps the even-sooner due date",
          items[0]["dueIso"] == iso(NOW))

    mastered = {"topicId": "m1", "stage": "mastered", "strength": 0.9,
                "correctCount": 7, "attemptCount": 8,
                "lastPracticedAtIso": "2026-09-10T10:00:00"}
    strong = {"topicId": "s1", "stage": "strong", "strength": 0.7,
              "correctCount": 5, "attemptCount": 8,
              "lastPracticedAtIso": "2026-09-10T10:00:00"}
    learning = {"topicId": "l1", "stage": "learning", "strength": 0.3,
                "correctCount": 1, "attemptCount": 2,
                "lastPracticedAtIso": "2026-09-10T10:00:00"}
    items = rev_schedule({"topics": {"m1": mastered, "s1": strong,
                                     "l1": learning}}, [], {}, NOW)
    idx = {i["topicId"]: i["intervalIndex"] for i in items}
    check("mastered seeds at 2, strong at 1, learning not scheduled",
          idx.get("m1") == 2 and idx.get("s1") == 1 and "l1" not in idx)

    due_list = due_today([fresh, due, overdue, same_day], NOW, limit=3)
    # c (2 days overdue) first; then the two due items (b, d) tie-break
    # by topicId; fresh (a) excluded. Note: d is only 12h late — same-day
    # grace keeps it "due", not overdue.
    check("dueToday: overdue first, fresh excluded, limit honored",
          [i["topicId"] for i in due_list] == ["c", "b", "d"]
          and "a" not in [i["topicId"] for i in due_list])

    pool = [dict(q, id=f"{tid}-{i}")
            for tid in ("t1", "t2") for i in range(3)
            for q in [{"id": "", "topicId": tid, "tier": 2}]]
    mix = review_mix(pool, {"t1-0", "t2-0"}, {"t1", "t2"}, target_size=8)
    check("reviewMix: previously-wrong first",
          mix[0]["id"] in ("t1-0", "t2-0")
          and mix[1]["id"] in ("t1-0", "t2-0"))
    ok_adjacent = all(mix[i]["topicId"] != mix[i - 1]["topicId"]
                      for i in range(1, len(mix)))
    check("reviewMix: round-robin (no adjacent same-topic)", ok_adjacent)
    check("reviewMix: bounded + deduped",
          len(mix) == 6 and len({q["id"] for q in mix}) == 6)


def run_weak_area_day_checks():
    def finding(tid, severity, n_signals=1):
        return {"topicId": tid, "severity": severity,
                "signals": {"repeatedWrong"} if n_signals == 1 else
                {"repeatedWrong", "lowMastery"},
                "categories": set(), "sentence": "s"}

    def rep(findings):
        return {"findings": findings, "insufficientEvidence": False,
                "evidenceNote": "n"}

    overdue_items = [
        {"topicId": f"o{i}", "intervalIndex": 1, "lastReviewedIso": "",
         "dueIso": iso(NOW - timedelta(days=5))} for i in range(2)]

    d = decide(rep([finding("t1", "needsAttention")]), [], 7)
    check("needsAttention → frequent tier, day 1",
          d["frequency"] == "frequent" and d["shouldRecover"]
          and d["dayIndex"] == 1 and d["focusTopicId"] == "t1")

    d = decide(rep([finding("t1", "focus")]), [], 7)
    check("focus finding → occasional tier", d["frequency"] == "occasional")

    d = decide(rep([]), overdue_items, 7)
    check("two overdue revisions → occasional recovery",
          d["shouldRecover"] and d["frequency"] == "occasional")

    d = decide(rep([finding("t1", "watch")]), [], 7)
    check("watch-only → at-most-weekly tier",
          d["frequency"] == "none" and d["shouldRecover"])

    fresh_item = {"topicId": "f1", "intervalIndex": 1,
                  "lastReviewedIso": "", "dueIso":
                  iso(NOW + timedelta(days=3))}
    d = decide(rep([]), [fresh_item], 7)
    check("nothing weak, nothing due → no recovery day (§22)",
          not d["shouldRecover"] and d["rationale"])

    d = decide(rep([finding("t1", "needsAttention")]), [], 7,
               days_since=1)
    check("gap not served → no recovery this window",
          not d["shouldRecover"])
    d = decide(rep([finding("t1", "needsAttention")]), [], 7,
               days_since=3)
    check("gap served → recovery happens", d["shouldRecover"])
    d = decide(rep([finding("t1", "needsAttention")]), [], 7,
               last_recovery_day=2)
    check("hard cap: never back-to-back", d["dayIndex"] > 3)
    d = decide(rep([finding("t1", "needsAttention")]), [], 7,
               last_recovery_day=6)
    check("pushed past window → none", not d["shouldRecover"])
    d = decide(rep([finding("", "watch")]), [], 0)
    check("no focus + no days → honest floor", not d["shouldRecover"])

    b = blueprint_for("t1", "Sandhi", "why")
    check("blueprint: 4 phases in §22 order, 40 min",
          b["phases"] == BLUEPRINT_PHASES and
          len(b["phases"]) * 10 == 40)


def run_remediation_checks():
    def pq(qid, tier):
        q = {"id": qid, "topicId": "t1", "tier": tier, "kind":
             "mcq" if tier != 2 else "shortAnswer"}
        return q

    plan = build_remediation("t1", {"topicTitle": "T"}, 
                             [pq("w1", 2), pq("w2", 2), pq("f1", 2),
                              pq("f2", 2), pq("f3", 2)],
                             {"w1", "w2"})
    check("wrong questions lead the retry phase",
          [q["id"] for q in plan["mistakeRetryQuestions"]] == ["w1", "w2"])
    check("recheck holds 2 fresh questions",
          len(plan["recheckQuestions"]) == RECHECK_SIZE and
          all(q["id"].startswith("f")
              for q in plan["recheckQuestions"]))
    all_ids = ([q["id"] for q in plan["mistakeRetryQuestions"]] +
               [q["id"] for q in plan["targetedQuestions"]] +
               [q["id"] for q in plan["recheckQuestions"]])
    check("no question in two phases", len(all_ids) == len(set(all_ids)))
    check("plan viable", plan_is_viable(plan))

    plan = build_remediation(
        "t1", {"topicTitle": "T"},
        [pq(f"w{i}", 2) for i in range(8)] + [pq(f"f{i}", 2)
                                               for i in range(4)],
        {f"w{i}" for i in range(8)})
    check("mistake retries bounded at 3",
          len(plan["mistakeRetryQuestions"]) == MAX_MISTAKE_RETRIES)

    plan = build_remediation("t1", {"topicTitle": "T"},
                             [pq("w1", 2), pq("e1", 1), pq("e2", 1)],
                             {"w1"})
    check("thin pool tops up the recheck from any tier",
          len(plan["recheckQuestions"]) == RECHECK_SIZE)

    plan = build_remediation("t1", {"topicTitle": "T"},
                             [pq("w1", 2), pq("w2", 2)], {"w1", "w2"})
    check("all-wrong pool → recheck empty → NOT viable (honest floor)",
          not plan_is_viable(plan))

    plan = build_remediation("t1", {"topicTitle": "T"},
                             [pq("f1", 2), pq("f2", 2)], set())
    check("no wrong ids → no main phase → NOT viable", not plan_is_viable(plan))

    check("recheck judge: clean pass = recovered",
          judge_recheck([{"questionId": "f1", "verdict": "correct"},
                         {"questionId": "f2", "verdict": "correct"}])
          == "recovered")
    check("recheck judge: any incorrect = stillNeedsWork",
          judge_recheck([{"questionId": "f1", "verdict": "correct"},
                         {"questionId": "f2", "verdict": "incorrect"}])
          == "stillNeedsWork")
    check("recheck judge: partiallyCorrect passes (§29 contract)",
          judge_recheck([{"questionId": "f1", "verdict": "correct"},
                         {"questionId": "f2",
                          "verdict": "partiallyCorrect"}])
          == "recovered")
    check("recheck judge: too few attempts = stillNeedsWork",
          judge_recheck([{"questionId": "f1", "verdict": "correct"}])
          == "stillNeedsWork")
    check("outcome summary: non-empty, no %",
          all(outcome_summary(o) and "%" not in outcome_summary(o)
              for o in ("recovered", "stillNeedsWork", "notRun")))


# ---------------------------------------------------------------------------
# Behavior checks — repositories + content bank + planner connection
# ---------------------------------------------------------------------------

def run_repository_checks():
    store = {}
    check("attempt log: empty store loads empty",
          attempt_log_load_all(store) == {})
    attempt_log_record(store, "cbse_10_sanskrit", [
        {"questionId": "prac_a_sec", "topicId": "cbse_10_sanskrit_a",
         "kind": "mcq", "verdict": "incorrect", "retries": 1,
         "atIso": "2026-09-12T10:00:00"},
        {"questionId": "prac_a_typed", "topicId": "cbse_10_sanskrit_a",
         "kind": "typed", "verdict": "correct", "retries": 0,
         "atIso": "2026-09-12T10:02:00"}])
    loaded = attempt_log_load_all(store)["cbse_10_sanskrit"]
    check("attempt log: batched write reloads verbatim",
          len(loaded) == 2 and loaded[0]["verdict"] == "incorrect"
          and loaded[1]["kind"] == "typed")

    attempt_log_record(store, "cbse_10_hindi_a", [
        {"questionId": "q2", "topicId": "t2", "kind": "mcq",
         "verdict": "correct", "retries": 0, "atIso": ""}])
    check("attempt log: per-track isolation",
          len(attempt_log_load_all(store)["cbse_10_sanskrit"]) == 2
          and len(attempt_log_load_all(store)["cbse_10_hindi_a"]) == 1)

    burst = [{"questionId": f"q{i}", "topicId": "t1", "kind": "mcq",
              "verdict": "incorrect", "retries": 0,
              "atIso": "2026-09-12T10:00:00"}
             for i in range(ATTEMPT_LOG_MAX_ENTRIES + 40)]
    attempt_log_record(store, "burst", burst)
    bounded = attempt_log_load_all(store)["burst"]
    check(f"§56 attempt log bounded at {ATTEMPT_LOG_MAX_ENTRIES}",
          len(bounded) == ATTEMPT_LOG_MAX_ENTRIES
          and bounded[0]["questionId"] == "q40")

    attempt_log_record(store, "x", [
        {"questionId": "", "topicId": "", "kind": "mcq", "verdict": "",
         "retries": 0, "atIso": ""}])
    check("attempt log: empty ids never stored",
          "x" not in attempt_log_load_all(store))

    corrupt = {"exam_attempt_log_v1": "{{{not json"}
    check("§41 attempt log: corrupt store degrades to empty",
          attempt_log_load_all(corrupt) == {})

    good_state = json.dumps({"version": 1, "states": {"good": {
        "schemaVersion": 1, "trackId": "good", "lastRecoveryDayIso": "",
        "recoveryDayCount": 0,
        "revision": {"t1": {"topicId": "t1", "intervalIndex": 3,
                            "lastReviewedIso": "2026-09-01T10:00:00",
                            "dueIso": "2026-09-08T10:00:00"}},
        "recheckOutcomes": []}}}, ensure_ascii=False)
    corrupt_state = {"exam_weak_area_v1": "garbage"}
    check("§41 weak state: corrupt store degrades to empty",
          weak_state_load(corrupt_state, "x")["revision"] == {})
    st = weak_state_load({"exam_weak_area_v1": good_state}, "good")
    check("weak state: revision round-trips",
          st["revision"]["t1"]["intervalIndex"] == 3)
    st2 = weak_state_with_recovery(st, NOW)
    st2 = weak_state_with_recovery(st2, NOW + timedelta(days=4))
    check("weak state: recovery history increments (§22 evidence)",
          st2["recoveryDayCount"] == 2 and st2["lastRecoveryDayIso"] ==
          iso(NOW + timedelta(days=4)))
    st3 = st
    for i in range(130):
        st3 = weak_state_with_recheck(st3, {
            "topicId": f"t{i % 7}", "outcome": "recovered",
            "atIso": "2026-09-01T10:00:00"})
    check(f"§56 recheck outcomes capped at {RECHECK_OUTCOME_CAP}",
          len(st3["recheckOutcomes"]) == RECHECK_OUTCOME_CAP)
    check("wrong ids by topic extraction",
          wrong_ids_by_topic([
              {"questionId": "w1", "topicId": "t1", "verdict": "incorrect",
               "retries": 0, "atIso": "", "kind": "mcq"},
              {"questionId": "c1", "topicId": "t1", "verdict": "correct",
               "retries": 0, "atIso": "", "kind": "mcq"},
              {"questionId": "p1", "topicId": "t2",
               "verdict": "partiallyCorrect", "retries": 0, "atIso": "",
               "kind": "typed"}]) ==
          {"t1": {"w1"}, "t2": {"p1"}})


def run_content_bank_checks(tracks, courses):
    for tid in tracks:
        course = courses[tid]
        view = build_view(course)
        sel = selectable_ids(view)
        full = build_practice_bank(course, view, sel, target_size=12)
        check(f"bank[{tid}]: full scope mixed and grounded",
              full and all(q["topicId"] in sel for q in full))

        # M8 topicFilter: per-topic pools for recovery/revision.
        topics = sorted(sel)
        for topic in topics[:6]:
            pool = build_practice_bank(course, view, sel, target_size=8,
                                       topic_filter={topic})
            check(f"bank[{tid}] topicFilter[{topic}]: only that topic, "
                  "never crashes (clamp fix)",
                  all(q["topicId"] == topic for q in pool))
            typed_in_pool = [q for q in pool if q["kind"] == "shortAnswer"]
            check(f"bank[{tid}] topicFilter[{topic}]: typed take never "
                  "exceeds availability",
                  len([q for q in pool if q["kind"] == "shortAnswer"]) ==
                  (1 if len(typed_in_pool) == 1 else
                   min(max(8 // 3, 2), len(typed_in_pool))) if typed_in_pool
                  else True)


def run_planner_checks(tracks, courses):
    budgets = [5, 10, 15, 30, 45, 60, 120]
    study_days = [1, 3, 5, 7]
    for tid in tracks[:3] + ["cbse_10_sanskrit"]:
        course = courses[tid]
        view = build_view(course)
        sel = sorted(selectable_ids(view))
        if not sel:
            continue
        focus = sel[0]
        for budget in budgets:
            for days in study_days:
                profile = {"dailyStudyMinutes": budget,
                           "studyDaysPerWeek": days}
                learner = {"topics": {}, "hasDiagnostic": True}

                # Shape 1: no weak-area input (pre-M8 behavior).
                plan = build_plan(tid, view, sel, profile, learner, 1)
                errs = validate_plan_m8(plan, sel, profile)
                check(f"plan[{tid} {budget}m {days}d] null-input valid",
                      not errs, errs[:2])

                # Shape 2: recovery day reserved on day 2.
                decision = {"shouldRecover": True, "frequency": "frequent",
                            "dayIndex": 2, "focusTopicId": focus,
                            "rationale": "कमज़ोर क्षेत्र recovery।"}
                plan = build_plan(tid, view, sel, profile, learner, 1,
                                  weak_area={
                                      "decision": decision,
                                      "revisionItems": []})
                errs = validate_plan_m8(plan, sel, profile)
                check(f"plan[{tid} {budget}m {days}d] recovery-day valid",
                      not errs, errs[:2])
                if days > 2:
                    day2 = plan["days"][2]
                    weak_tasks = [t for t in day2["tasks"]
                                  if t["type"] == "weakArea"]
                    check(f"plan[{tid} {budget}m] day 2 carries exactly "
                          "one weakArea task on the focus topic",
                          len(weak_tasks) == 1
                          and weak_tasks[0]["topicId"] == focus)
                    check(f"plan[{tid} {budget}m] recovery day has no "
                          "brand-new learn material",
                          not any(t["type"] == "learn"
                                  for t in day2["tasks"]))
                    others = [d for d in plan["days"]
                              if d["dayIndex"] != 2]
                    check(f"plan[{tid} {budget}m] other days keep the "
                          "learn flow",
                          all(any(t["type"] == "learn" for t in d["tasks"])
                              for d in others))
                    check(f"plan[{tid} {budget}m] rationale states the "
                          "reservation (§50)",
                          "recovery" in plan["rationale"])

                # Shape 3: overdue revisions → spaced review tasks.
                # (Only when ≥2 task slots fit — a 1-slot budget keeps
                # the M5 shape honestly; §9 budget fit wins.)
                overdue_items = [
                    {"topicId": focus, "intervalIndex": 1,
                     "lastReviewedIso": "",
                     "dueIso": iso(NOW - timedelta(days=5))}]
                no_recovery = {"shouldRecover": False,
                               "frequency": "none", "dayIndex": -1,
                               "focusTopicId": "", "rationale": ""}
                plan = build_plan(tid, view, sel, profile, learner, 1,
                                  weak_area={
                                      "decision": no_recovery,
                                      "revisionItems": overdue_items})
                errs = validate_plan_m8(plan, sel, profile)
                check(f"plan[{tid} {budget}m {days}d] revision shape "
                      "valid", not errs, errs[:2])
                tpm = max(1, min(4, budget // task_minutes_for(budget)))
                reviews = [t for d in plan["days"] for t in d["tasks"]
                           if t["type"] == "review"]
                if tpm >= 2:
                    check(f"plan[{tid} {budget}m] overdue topic becomes "
                          "review work",
                          any(t["topicId"] == focus for t in reviews))
                else:
                    check(f"plan[{tid} {budget}m] tiny budget keeps the "
                          "M5 shape (backbone only)",
                          all(any(t["type"] in ("learn", "practice", "weakArea")
                                  for t in d["tasks"])
                              for d in plan["days"]))

                # Shape 4: out-of-scope revision items are never tasks.
                foreign = [{"topicId": "made_up_topic", "intervalIndex": 1,
                            "lastReviewedIso": "",
                            "dueIso": iso(NOW - timedelta(days=9))}]
                plan = build_plan(tid, view, sel, profile, learner, 1,
                                  weak_area={"decision": no_recovery,
                                             "revisionItems": foreign})
                errs = validate_plan_m8(plan, sel, profile)
                check(f"plan[{tid} {budget}m] out-of-scope revision "
                      "filtered (§16 rule 1)", not errs, errs[:2])


# ---------------------------------------------------------------------------
# Student journeys (§M11 previews, end-to-end through the M8 stack)
# ---------------------------------------------------------------------------

def run_journey_checks(tracks, courses):
    tid = "cbse_10_sanskrit"
    course = courses[tid]
    view = build_view(course)
    sel = sorted(selectable_ids(view))
    units_with_subs = [u for s in view for u in s["units"]
                       if u["selectable"] and u.get("subtopics")]
    check("journey: course has topics with sub-topics (typed pool)",
          bool(units_with_subs))
    topic = units_with_subs[0]["id"]
    pool = build_practice_bank(course, view, sel, target_size=8,
                               topic_filter={topic})
    check("journey: topic pool has ≥3 grounded questions",
          len(pool) >= 3, [q["id"] for q in pool])
    wrong_q = pool[0]["id"]

    # --- STUDENT H: repeatedly fails ONE topic, then recovers.
    store = {}
    learner = {"topics": {}, "hasDiagnostic": True}

    def record(mastery_map, evidence_entries, track=tid):
        attempt_log_record(store, track, evidence_entries)
        return mastery_map

    # 6 sessions, same question wrong after retry (concept gap each time),
    # other questions correct.
    entries = []
    for i in range(6):
        entries.append({"questionId": wrong_q, "topicId": topic,
                        "kind": "mcq", "verdict": "incorrect",
                        "retries": 1,
                        "atIso": iso(NOW - timedelta(days=6 - i))})
    for q in pool[1:]:
        entries.append({"questionId": q["id"], "topicId": topic,
                        "kind": q["kind"], "verdict": "correct",
                        "retries": 0, "atIso": iso(NOW)})
    record(learner, entries)

    evidence = attempt_log_load_all(store)[tid]
    patterns = analyze(evidence)
    check("H: pattern detection finds the recurring misconception",
          any(p["topicId"] == topic and p["category"] == "misconception"
              for p in patterns))

    # Learner profile: 6 wrong + corrects on the topic → weak stage.
    m = {"topicId": topic, "stage": "learning", "strength": 0,
         "correctCount": 0, "attemptCount": 0,
         "lastPracticedAtIso": ""}
    for _ in range(6):
        m = apply_attempt(m, False)
    for q in pool[1:]:
        m = apply_attempt(m, True)
    learner["topics"][topic] = m

    revision_items = rev_schedule(learner, patterns, {}, NOW)
    report = build_report(learner, patterns, revision_items, NOW)
    check("H: needsAttention finding on the topic",
          any(f["topicId"] == topic and
              f["severity"] == "needsAttention" for f in report["findings"]))
    check("H: M8-honest report (no PYQ/mock fabrication)",
          report_is_m8_honest(report))

    d = decide(report, revision_items, 7, days_since=None)
    check("H: frequent recovery tier, focus = the failing topic",
          d["frequency"] == "frequent" and d["shouldRecover"]
          and d["focusTopicId"] == topic)

    # The plan reserves the recovery day on that topic.
    profile = {"dailyStudyMinutes": 45, "studyDaysPerWeek": 6}
    plan = build_plan(tid, view, sel, profile, learner, 1,
                      weak_area={"decision": d,
                                 "revisionItems": revision_items})
    errs = validate_plan_m8(plan, sel, profile)
    check("H: plan with the recovery reservation validates", not errs,
          errs[:2])
    day = plan["days"][d["dayIndex"]]
    check("H: recovery day works the failing topic",
          any(t["type"] == "weakArea" and t["topicId"] == topic
              for t in day["tasks"]))

    # Remediation: 1 previously-wrong + fresh recheck → recovered.
    wrong_map = wrong_ids_by_topic(evidence)
    rem = build_remediation(topic, {"topicTitle": units_with_subs[0]
                                    ["title"]}, pool,
                            wrong_map.get(topic, set()))
    check("H: remediation viable (fresh recheck available)",
          plan_is_viable(rem))
    recheck_attempts = [{"questionId": q["id"], "verdict": "correct"}
                        for q in rem["recheckQuestions"]]
    outcome = judge_recheck(recheck_attempts)
    check("H: clean recheck → recovered", outcome == "recovered")

    # Persistence: outcome + expanded revision + recovery history.
    wa = weak_state_load(store, tid)
    item = wa["revision"].get(topic) or {
        "topicId": topic, "intervalIndex": 0, "lastReviewedIso": iso(NOW),
        "dueIso": iso(NOW)}
    moved = (rev_expand(item, NOW) if outcome == "recovered"
             else rev_contract(item, NOW))
    wa["revision"][topic] = moved
    wa = weak_state_with_recovery(wa, NOW)
    check("H: recovery expands the revision interval",
          wa["revision"][topic]["intervalIndex"] >= item["intervalIndex"])

    # Next window: the §22 gap rule blocks an immediate second recovery.
    patterns2 = analyze(attempt_log_load_all(store)[tid])
    revision2 = rev_schedule(learner, patterns2, wa["revision"], NOW)
    report2 = build_report(learner, patterns2, revision2, NOW)
    d2 = decide(report2, revision2, 7, days_since=0)
    check("H: §22 gap rule — no second recovery the next day",
          not d2["shouldRecover"])

    # --- STUDENT A: strong student → no findings, mastered seeds high.
    learner_a = {"topics": {}, "hasDiagnostic": True}
    for t in sel[:4]:
        ma = {"topicId": t, "stage": "learning", "strength": 0,
              "correctCount": 0, "attemptCount": 0,
              "lastPracticedAtIso": "2026-09-10T10:00:00"}
        for _ in range(8):
            ma = apply_attempt(ma, True)
        learner_a["topics"][t] = ma
    report_a = build_report(learner_a, [], [], NOW)
    check("A: no weak findings for a strong student",
          report_a["findings"] == [] and not report_a["insufficientEvidence"])
    items_a = rev_schedule(learner_a, [], {}, NOW)
    idx_a = {i["topicId"]: i["intervalIndex"] for i in items_a}
    check("A: mastered topics seed high on the ladder (retention evidence)",
          all(v >= 2 for v in idx_a.values()))
    d_a = decide(report_a, items_a, 7)
    check("A: no recovery day needed (§22 performing well)",
          not d_a["shouldRecover"])

    # --- STUDENT D-ish: skipped sessions → overdue → forgotten concepts.
    learner_d = {"topics": {}, "hasDiagnostic": True}
    history_d = {t: {"topicId": t, "intervalIndex": 3,
                     "lastReviewedIso": "",
                     "dueIso": iso(NOW - timedelta(days=10))}
                 for t in sel[:2]}
    items_d = rev_schedule(learner_d, [], history_d, NOW)
    report_d = build_report(learner_d, [], items_d, NOW)
    check("D: overdue topics surface as forgotten concepts",
          len(report_d["findings"]) == 2 and all(
              "forgottenConcept" in f["signals"]
              for f in report_d["findings"]))
    d_d = decide(report_d, items_d, 7)
    check("D: two overdue → occasional recovery (§22 struggling more)",
          d_d["shouldRecover"] and d_d["frequency"] == "occasional")
    # ...and the failing-recheck path contracts the interval (relearning).
    fail_item = history_d[sel[0]]
    contracted = rev_contract(fail_item, NOW)
    check("D: failed review contracts sharply (relearning)",
          contracted["intervalIndex"] == 1)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    tracks, courses = load_courses()
    check("all 7 canonical courses load", len(tracks) == 7,
          f"got {len(tracks)}")

    run_source_checks()
    run_error_intelligence_checks()
    run_weak_topic_checks()
    run_revision_checks()
    run_weak_area_day_checks()
    run_remediation_checks()
    run_repository_checks()
    run_content_bank_checks(tracks, courses)
    run_planner_checks(tracks, courses)
    run_journey_checks(tracks, courses)

    print(f"\n{'=' * 64}")
    if CHECKS["failed"] == 0:
        print(f"M8 MIRROR: ALL GREEN — {CHECKS['run']}/{CHECKS['run']} "
              "checks passed")
    else:
        print(f"M8 MIRROR: {CHECKS['failed']} FAILED of {CHECKS['run']}")
        for f in FAILURES[:40]:
            print(f"  FAIL {f}")
    print('=' * 64)
    return 1 if CHECKS["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())


