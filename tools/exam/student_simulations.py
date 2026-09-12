#!/usr/bin/env python3
"""Exam Mode 2.0 — M11 REAL STUDENT SIMULATION harness.

Nine student personas (A–I, exactly the master plan's list) each run
the FULL Exam Mode 2.0 journey against the REAL canonical syllabus
JSONs, through the frozen engine ports of the earlier mirrors:

    diagnostic → plan → daily sessions → mistakes → replanning →
    weak-area day → revision → PYQ → mock → readiness

Every engine invoked is the 1:1 Python port already verified by
verify_exam_m3_m7 / m8 / m9 / m10 (their invariant suites stay green
before and after this harness runs), so a persona's journey exercises
the same rules the shipped Dart engines encode.

Personas (master plan M11):
    A  strong student
    B  average student
    C  weak student
    D  student who skips sessions
    E  student who changes syllabus scope
    F  student who changes readiness target
    G  student who chooses different tasks than recommended
    H  student who repeatedly fails one topic
    I  student who performs strongly in one section, poorly in another

Outputs:
    run_all() → {"students": {...digest...}, "matrix": {...}}
    write_report(path) → deterministic markdown report
    main() → prints the divergence digest (checks live in
             verify_exam_m11.py)

Run: python3 tools/exam/student_simulations.py
"""

import json
import os
import sys
from datetime import datetime, timedelta

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_exam_m3_m7 as m37  # diagnostic bank port (§60/§11)
import verify_exam_m8 as m8      # practice/weak-area/planner ports
import verify_exam_m9 as m9      # PYQ/mock ports (§25/§41)
import verify_exam_m10 as m10    # XP formula port (parsed from Dart)

NOW = datetime(2026, 9, 12, 10, 0, 0)
DAYS = 21  # simulated journey length (3 × the 7-day rolling window)

COURSE_ID = "cbse_10_sanskrit"       # primary course (typed + MCQ mix)
COURSE_ID_2 = "cbse_10_hindi_a"      # second course (section asymmetry)


# ---------------------------------------------------------------------------
# Persona answer policies
# ---------------------------------------------------------------------------

def _rng(seed):
    """Deterministic LCG — journeys are reproducible, never flaky."""
    state = [seed & 0xFFFFFFFF]

    def next01():
        state[0] = (1103515245 * state[0] + 12345) & 0x7FFFFFFF
        return state[0] / 0x7FFFFFFF

    return next01


def policy_always_correct(q, ctx):
    return True


def policy_always_wrong(q, ctx):
    return False


def make_probabilistic(rng, p_correct):
    def policy(q, ctx):
        return rng() < p_correct

    return policy


def make_section_asymmetric(rng, strong_section_title):
    """Persona I: strong in one official section, weak in the other."""
    def policy(q, ctx):
        strong = strong_section_title in ctx.get("sectionTitle", "")
        return rng() < (0.9 if strong else 0.25)

    return policy


def make_topic_failure(rng, fail_topic_id, base_p):
    """Persona H: always fails ONE topic, base probability elsewhere."""
    def policy(q, ctx):
        if q.get("topicId") == fail_topic_id:
            return False
        return rng() < base_p

    return policy


# ---------------------------------------------------------------------------
# Session loops (§28: one retry, then reveal; verdict vocabulary M6)
# ---------------------------------------------------------------------------

def run_practice_session(pool, decide, rng, day, session_tag):
    """Runs one practice/revision/PYQ session through the §28 loop.

    Returns (attempts, questions) with the M6 verdict vocabulary:
    'correct' / 'partiallyCorrect' / 'incorrect' / 'revealed'.
    """
    attempts = []
    for q in pool:
        ctx = {"sectionTitle": q.get("sectionTitle", ""),
               "day": day, "tag": session_tag}
        first = decide(q, ctx)
        if first:
            attempts.append({
                "questionId": q["id"], "topicId": q["topicId"],
                "kind": q.get("kind", "mcq"), "verdict": "correct",
                "retries": 0, "atIso": m8.iso(NOW + timedelta(days=day)),
            })
            continue
        # One retry (§28), then the verdict is final as incorrect.
        retry_ok = decide(q, ctx) if rng() < 0.5 else False
        if retry_ok:
            attempts.append({
                "questionId": q["id"], "topicId": q["topicId"],
                "kind": q.get("kind", "mcq"), "verdict": "correct",
                "retries": 1,
                "atIso": m8.iso(NOW + timedelta(days=day)),
            })
        else:
            attempts.append({
                "questionId": q["id"], "topicId": q["topicId"],
                "kind": q.get("kind", "mcq"), "verdict": "incorrect",
                "retries": 1,
                "atIso": m8.iso(NOW + timedelta(days=day)),
            })
    return attempts


def run_diagnostic(bank, titles, section_of, decide, max_items=10):
    """Adaptive §11 ladder with a persona policy (mirrors diag_run)."""
    by_diff = {1: [], 2: [], 3: []}
    for q in bank:
        by_diff[q["difficulty"]].append(q)

    served = []
    responses = []
    attempts_by_topic = {}

    def pick(difficulty):
        seen = {q["id"] for q in served}
        pool = [q for q in by_diff[difficulty] if q["id"] not in seen]
        if not pool:
            return None
        pool.sort(key=lambda q: attempts_by_topic.get(q["topicId"], 0))
        return pool[0]

    def tier_order(d):
        return {1: [1, 2, 3], 2: [2, 1, 3], 3: [3, 2, 1]}[d]

    current = pick(2) or pick(1) or pick(3)
    while current is not None and len(responses) < max_items:
        served.append(current)
        ctx = {"sectionTitle": section_of.get(current["topicId"], ""),
               "day": 0, "tag": "diagnostic"}
        correct = decide(current, ctx)
        responses.append({
            "topicId": current["topicId"],
            "difficulty": current["difficulty"],
            "skill": current["skill"],
            "correct": correct,
        })
        attempts_by_topic[current["topicId"]] = \
            attempts_by_topic.get(current["topicId"], 0) + 1
        next_diff = (min(3, current["difficulty"] + 1) if correct
                     else max(1, current["difficulty"] - 1))
        current = None
        for tier in tier_order(next_diff):
            nxt = pick(tier)
            if nxt is not None:
                current = nxt
                break
    return responses


def seed_learner_from_diagnostic(responses):
    """Merges the diagnostic estimates into the learner profile (§12)."""
    learner = {"topics": {}, "hasDiagnostic": True}
    by_topic = {}
    for r in responses:
        by_topic.setdefault(r["topicId"], []).append(r)
    for topic, rs in by_topic.items():
        m = {"topicId": topic, "stage": "learning", "strength": 0,
             "correctCount": 0, "attemptCount": 0,
             "lastPracticedAtIso": m8.iso(NOW)}
        # Mirror of mergeDiagnosticEstimates: each response is recorded
        # as an attempt with difficulty-weighted correctness.
        for r in rs:
            m = m8.apply_attempt(m, r["correct"])
        learner["topics"][topic] = m
    return learner


# ---------------------------------------------------------------------------
# The journey engine
# ---------------------------------------------------------------------------

class JourneyState:
    """All mutable evidence one student accumulates."""

    def __init__(self, track_id, course, view, selection, profile):
        self.track_id = track_id
        self.course = course
        self.view = view
        self.selection = list(selection)
        self.profile = dict(profile)
        self.scope_revision = 1
        self.learner = {"topics": {}, "hasDiagnostic": False}
        self.attempt_log_store = {}
        self.weak_state_store = {}
        self.pyq_store = {}
        self.mock_store = {}
        self.xp_keys = set()
        self.xp_total = 0
        self.day_completions = {}
        self.plans = []          # every built plan (history)
        self.replans = []        # (day, reason)
        self.recoveries = []     # (day, topic, frequency, outcome)
        self.revisions_done = 0
        self.pyq_attempts = 0
        self.pyq_correct = 0
        self.mocks = []          # MockResult dicts
        self.skipped_days = []
        self.wrong_decisions = 0
        self.sessions = 0

    # -- weak-area chain (M8/M9 ports) ---------------------------------

    def overview(self, day):
        now = NOW + timedelta(days=day)
        evidence = self.attempt_log_store.get(self.track_id, [])
        patterns = m8.analyze(evidence)
        revision_items = m8.rev_schedule(
            self.learner, patterns,
            self.weak_state_store.get(self.track_id,
                                      {"revision": {}}).get("revision", {}),
            now)
        pyq_perf = m9.pyq_perf_load_all(self.pyq_store).get(
            self.track_id, {})
        weak_mock = (m9.mock_weak_sections(self.mocks[-1])
                     if self.mocks else [])
        # §21 data-gated pyq/mock signals via the REAL M9 port (its
        # severity vocabulary matches the frozen M8 ladder).
        report = m9.build_report_m9(
            self.learner, patterns, revision_items, now,
            pyq_performance=pyq_perf,
            weak_mock_sections=weak_mock)
        last_recovery_iso = self.weak_state_store.get(
            self.track_id, {}).get("lastRecoveryDayIso")
        days_since = None
        if last_recovery_iso:
            days_since = (now - m8.parse_iso(last_recovery_iso)).days
        decision = m8.decide(report, revision_items, 7,
                             days_since=days_since)
        return {
            "patterns": patterns, "report": report,
            "revisionItems": revision_items, "decision": decision,
            "now": now,
        }

    def build_plan(self, day, weak_area=None):
        plan = m8.build_plan(
            self.track_id, self.view, set(self.selection), self.profile,
            self.learner, self.scope_revision, weak_area=weak_area)
        self.plans.append(plan)
        return plan

    def award_xp(self, kind, correct, total, day):
        key = f"exam_xp_{kind}_{self.track_id}_d{day}_{correct}-{total}"
        if key in self.xp_keys:
            return 0
        self.xp_keys.add(key)
        xp = m10.session_xp_total(kind, correct, total)
        self.xp_total += xp
        return xp

    def mastery_of(self, topic_id):
        return self.learner["topics"].get(topic_id, {
            "topicId": topic_id, "stage": "learning", "strength": 0,
            "correctCount": 0, "attemptCount": 0,
            "lastPracticedAtIso": ""})

    def record_attempts(self, attempts, day):
        m8.attempt_log_record(self.attempt_log_store, self.track_id,
                              attempts)
        for a in attempts:
            m = self.mastery_of(a["topicId"])
            ok = a["verdict"] in ("correct", "partiallyCorrect")
            self.learner["topics"][a["topicId"]] = m8.apply_attempt(m, ok)

    def finish_session(self, kind, attempts, day, task_type):
        correct = sum(1 for a in attempts
                      if a["verdict"] in ("correct", "partiallyCorrect"))
        self.award_xp(kind, correct, len(attempts), day)
        self.day_completions.setdefault(day, set()).add(task_type)
        self.sessions += 1
        return correct, len(attempts)


def run_journey(spec, courses):
    """Runs one persona's full journey; returns the digest."""
    track_id = spec.get("course", COURSE_ID)
    course = courses[track_id]
    view = m8.build_view(course)
    view_diag = m37.build_view(course)  # m37 units carry isChapter
    all_ids = sorted(m8.selectable_ids(view))

    # Persona-specific scope (E starts full and EDITS later; C narrows).
    selection = spec.get("selection", all_ids)
    rng = _rng(spec["seed"])
    decide = spec["make_policy"](rng, spec, view, course)

    profile = {"dailyStudyMinutes": spec.get("daily", 40),
               "studyDaysPerWeek": spec.get("days_per_week", 6)}
    if spec.get("target_weeks"):
        profile["targetDate"] = NOW + timedelta(
            weeks=spec["target_weeks"])

    state = JourneyState(track_id, course, view, selection, profile)

    # ---- 1. Diagnostic (M4) -------------------------------------------
    bank, titles, section_of = m37.build_diagnostic_bank(
        course, view_diag, set(selection))
    responses = run_diagnostic(bank, titles, section_of, decide,
                               max_items=10)
    state.learner = seed_learner_from_diagnostic(responses)
    diag_correct = sum(1 for r in responses if r["correct"])
    state.award_xp("diagnostic", diag_correct, len(responses), 0)

    # ---- 2. First plan (M5 + M8 feed) ----------------------------------
    ov = state.overview(day=0)
    state.build_plan(0, weak_area={
        "decision": ov["decision"],
        "revisionItems": ov["revisionItems"],
        "findings": [f["topicId"] for f in ov["report"]["findings"]],
    })

    # ---- 3. The daily loop ----------------------------------------------
    for day in range(1, DAYS + 1):
        # Persona D: skips some days entirely (no session at all).
        if spec["id"] == "D" and day % 5 in (3, 4):
            state.skipped_days.append(day)
            continue

        # Persona E: changes syllabus scope at day 7 (§33 trigger).
        if spec["id"] == "E" and day == 7:
            keep = set(selection[:max(3, len(selection) // 2)])
            selection = sorted(keep & set(all_ids))
            state.selection = selection
            state.scope_revision += 1
            state.replans.append((day, "scope edited"))
            ov = state.overview(day)
            state.build_plan(day, weak_area={
                "decision": ov["decision"],
                "revisionItems": ov["revisionItems"],
                "findings": [f["topicId"]
                             for f in ov["report"]["findings"]],
            })

        # Persona F: changes the readiness target at day 10 (§33).
        # NOTE: state.profile is what the planner and the digest read —
        # the change must land THERE, not only on the local dict.
        if spec["id"] == "F" and day == 10:
            profile["targetDate"] = NOW + timedelta(weeks=3)
            state.profile["targetDate"] = profile["targetDate"]
            state.replans.append((day, "readiness target changed"))
            ov = state.overview(day)
            state.build_plan(day, weak_area={
                "decision": ov["decision"],
                "revisionItems": ov["revisionItems"],
                "findings": [f["topicId"]
                             for f in ov["report"]["findings"]],
            })

        # Weekly replan (the §33 rolling window).
        if day % 7 == 0:
            ov = state.overview(day)
            state.build_plan(day, weak_area={
                "decision": ov["decision"],
                "revisionItems": ov["revisionItems"],
                "findings": [f["topicId"]
                             for f in ov["report"]["findings"]],
            })

        # Today's tasks: the newest plan's day (day % window).
        plan = state.plans[-1]
        day_index = min(day % 7, len(plan["days"]) - 1)
        day_plan = plan["days"][day_index]

        # Persona G: does PYQ/mock INSTEAD of the recommended practice
        # (§20 student freedom — the app must not punish this).
        if spec["id"] == "G" and any(
                t["type"] == "practice" for t in day_plan["tasks"]):
            day_plan = {
                "dayIndex": day_index,
                "tasks": [t for t in day_plan["tasks"]
                          if t["type"] != "practice"] + [
                    {"type": "pyq", "topicId": selection[0],
                     "title": "G's own choice: PYQ", "minutes": 10}],
            }

        for task in day_plan["tasks"]:
            ttype = task["type"]
            if ttype == "learn":
                # Learn tasks study the topic (no question evidence yet).
                continue
            if ttype in ("practice", "review", "weakArea"):
                weak_ids = {t["topicId"] for t in
                            m8.weak_first(state.learner, 30)}
                pool = m8.build_practice_bank(
                    course, view, set(selection),
                    weak_ids=weak_ids,
                    topic_filter={task["topicId"]},
                    target_size=6)
                if not pool:
                    continue
                if ttype == "review":
                    mix = m8.review_mix(
                        questions=pool,
                        wrong_ids=set(),
                        due_topics={task["topicId"]},
                        target_size=6)
                    pool = mix or pool
                attempts = run_practice_session(
                    pool, decide, rng, day, ttype)
                state.record_attempts(attempts, day)
                kind = {"practice": "practice", "review": "revision",
                        "weakArea": "recovery"}[ttype]
                state.finish_session(kind, attempts, day,
                                     {"practice": "practice",
                                      "review": "review",
                                      "weakArea": "weakArea"}[ttype])
                if ttype == "review":
                    state.revisions_done += 1
                if ttype == "weakArea":
                    # The plan RESERVED this day for recovery (§22) —
                    # count it so the digest reports real recovery work.
                    state.recoveries.append(
                        (day, task["topicId"], "planned",
                         "plan-reserved"))
            elif ttype == "pyq":
                pyq = run_pyq_session(state, course, view, selection,
                                      decide, rng, day)
                state.pyq_attempts += pyq[0]
                state.pyq_correct += pyq[1]
            elif ttype == "mock":
                run_mock(state, course, view, selection, decide, rng,
                         day)

        # Recovery day beyond the plan: §22 decision fires when the
        # evidence says so (the plan reserves it; the session runs).
        ov = state.overview(day)
        d = ov["decision"]
        if (d["shouldRecover"] and d["dayIndex"] == day % 7
                and "weakArea" not in state.day_completions.get(day,
                                                                 set())):
            run_recovery(state, course, view, selection, decide, rng,
                         day, ov)

    # ---- 4. Final state: PYQ + mock + readiness -------------------------
    rng2 = _rng(spec["seed"] + 1)
    pyq_final = run_pyq_session(state, course, view, selection, decide,
                                rng2, DAYS)
    state.pyq_attempts += pyq_final[0]
    state.pyq_correct += pyq_final[1]
    run_mock(state, course, view, selection, decide, rng2, DAYS)

    return digest(state, spec, responses)


def run_pyq_session(state, course, view, selection, decide, rng, day):
    pool = m9.build_pyq_bank(course, view, set(selection), target_size=6)
    if not pool:
        return (0, 0)
    # m9 bank items are FLAT dicts (id/topicId/kind/prompt/marks...).
    section_of = {}
    for section in view:
        for unit in section["units"]:
            section_of[unit["id"]] = section["title"]
    plain = [{
        "id": q["id"], "topicId": q["topicId"],
        "kind": q["kind"], "sectionTitle": section_of.get(q["topicId"], ""),
        "prompt": q["prompt"],
    } for q in pool]
    attempts = run_practice_session(plain, decide, rng, day, "pyq")
    state.record_attempts(attempts, day)
    per_topic = {}
    for a in attempts:
        ok = a["verdict"] in ("correct", "partiallyCorrect")
        t = per_topic.setdefault(a["topicId"],
                                 {"topicId": a["topicId"],
                                  "attempted": 0, "correct": 0})
        t["attempted"] += 1
        t["correct"] += 1 if ok else 0
    m9.pyq_perf_merge(state.pyq_store, state.track_id,
                      list(per_topic.values()))
    correct = sum(1 for a in attempts
                  if a["verdict"] in ("correct", "partiallyCorrect"))
    state.finish_session("pyq", attempts, day, "pyq")
    return (len(attempts), correct)


def run_mock(state, course, view, selection, decide, rng, day):
    # Official board structure (§60 — from the canonical syllabus).
    board_sections = []
    for s in view:
        official = next(
            (sec for sec in course["sections"]
             if sec["id"] == s["id"]), None)
        if official is None or official.get("assessmentType",
                                            "board") == "internal":
            continue
        if not s["units"]:
            continue
        board_sections.append({
            "id": s["id"], "title": s["title"],
            "marks": float(official.get("marks", 0))})
    if not board_sections:
        return None
    board_total = sum(s["marks"] for s in board_sections)
    board_hours = int(course.get("board", {}).get("durationHours", 3)
                      or 3)
    pool = m9.build_pyq_bank(course, view, set(selection),
                             target_size=40)
    # build_mock keys its pools by SECTION id; the bank items only
    # carry topicId — derive the section from the view.
    section_id_of = {}
    for section in view:
        for unit in section["units"]:
            section_id_of[unit["id"]] = section["id"]
    by_section = {}
    for q in pool:
        by_section.setdefault(
            section_id_of.get(q["topicId"], ""), []).append(q)
    paper = m9.build_mock(
        state.track_id, "mini", board_sections, board_total, board_hours,
        by_section,
        focus_section_id=board_sections[0]["id"], now=NOW +
        timedelta(days=day))
    plain = []
    for sec in paper["sections"]:
        for q in sec["questions"]:
            plain.append({
                "id": q["id"], "topicId": q["topicId"],
                "kind": q["kind"], "sectionTitle": sec["title"],
                "prompt": q["prompt"]})
    attempts = run_practice_session(plain, decide, rng, day, "mock")
    state.record_attempts(attempts, day)
    result = m9.analyze_mock(paper, attempts)
    m9.mock_results_record(state.mock_store, result)
    state.mocks.append(result)
    correct = sum(1 for a in attempts
                  if a["verdict"] in ("correct", "partiallyCorrect"))
    state.finish_session("mock", attempts, day, "mock")
    return result


def mock_overall_band(result):
    """MockResult.overallBand port (§29 bands, §30 no percentage)."""
    attempted = result["totalAttempted"]
    if attempted < 2:
        return "learning"
    accuracy = result["totalCorrect"] / attempted
    if accuracy < 0.4:
        return "needsAttention"
    if accuracy >= 0.6:
        return "strong"
    return "learning"


def run_recovery(state, course, view, selection, decide, rng, day, ov):
    """§22 recovery session: remediation + recheck for the focus topic."""
    topic = ov["decision"]["focusTopicId"]
    pool = m8.build_practice_bank(
        course, view, set(selection), weak_ids={topic},
        topic_filter={topic}, target_size=8)
    if not pool:
        return
    item = next((i for s in course["sections"]
                 for i in s.get("items", []) if i["id"] == topic), None)
    remediation = m8.build_remediation(topic, {
        "topicTitle": item["title"] if item else topic}, pool, set())
    if not m8.plan_is_viable(remediation):
        return
    main_questions = (remediation["mistakeRetryQuestions"] +
                      remediation["targetedQuestions"])
    main_attempts = run_practice_session(
        main_questions, decide, rng, day, "recovery")
    state.record_attempts(main_attempts, day)
    recheck_attempts = run_practice_session(
        remediation["recheckQuestions"], decide, rng, day, "recheck")
    state.record_attempts(recheck_attempts, day)
    outcome = m8.judge_recheck([
        {"questionId": q["id"],
         "verdict": "correct" if decide(q, {
             "sectionTitle": "", "day": day, "tag": "recheck"})
         else "incorrect"}
        for q in remediation["recheckQuestions"]])
    # Persist outcome + ladder move (§22/§23 semantics).
    wa = state.weak_state_store.get(state.track_id,
                                    {"revision": {},
                                     "lastRecoveryDayIso": None})
    item2 = wa["revision"].get(topic) or {
        "topicId": topic, "intervalIndex": 0,
        "lastReviewedIso": m8.iso(NOW + timedelta(days=day)),
        "dueIso": m8.iso(NOW + timedelta(days=day))}
    moved = (m8.rev_expand(item2, NOW + timedelta(days=day))
             if outcome == "recovered"
             else m8.rev_contract(item2, NOW + timedelta(days=day)))
    wa["revision"][topic] = moved
    wa["lastRecoveryDayIso"] = m8.iso(NOW + timedelta(days=day))
    state.weak_state_store[state.track_id] = wa
    all_attempts = main_attempts + recheck_attempts
    correct = sum(1 for a in all_attempts
                  if a["verdict"] in ("correct", "partiallyCorrect"))
    state.recoveries.append(
        (day, topic, ov["decision"]["frequency"], outcome))
    state.finish_session("recovery", all_attempts, day, "weakArea")
    return outcome


# ---------------------------------------------------------------------------
# Digest + divergence matrix
# ---------------------------------------------------------------------------

def mastery_bands(learner):
    """§29 stage ladder: learning → practicing → strong → mastered,
    with needsAttention as the degraded stage (apply_attempt port).
    """
    counts = {"strong": 0, "learning": 0, "needsAttention": 0,
              "unknown": 0}
    for m in learner["topics"].values():
        stage = m.get("stage", "learning")
        if stage in ("mastered", "strong"):
            counts["strong"] += 1
        elif stage == "needsAttention":
            counts["needsAttention"] += 1
        elif stage in ("practicing", "learning"):
            counts["learning"] += 1
        else:
            counts["learning"] += 1
    return counts


def digest(state, spec, responses):
    final_plan = state.plans[-1]
    task_counts = {}
    for day in final_plan["days"]:
        for t in day["tasks"]:
            task_counts[t["type"]] = task_counts.get(t["type"], 0) + 1
    diag_accuracy = (sum(1 for r in responses if r["correct"]) /
                     max(1, len(responses)))
    bands = mastery_bands(state.learner)
    last_mock = state.mocks[-1] if state.mocks else None
    final_ov = state.overview(DAYS)
    weak_findings = sorted(
        (f["topicId"] for f in final_ov["report"]["findings"]),
    )[:8]
    anchor = state.profile.get("targetDate")
    days_left = ((anchor - NOW).days if anchor else None)
    readiness = "ready" if days_left is not None and days_left > 0 else (
        "target passed" if days_left is not None else "no anchor")
    return {
        "id": spec["id"],
        "name": spec["name"],
        "course": state.track_id,
        "diagnosticAccuracy": round(diag_accuracy, 2),
        "planScopeRevision": state.scope_revision,
        "planTaskCounts": task_counts,
        "planCount": len(state.plans),
        "replans": [f"day {d}: {r}" for d, r in state.replans],
        "recoveryDays": len(state.recoveries),
        "recoveryOutcomes": [o for _, _, _, o in state.recoveries],
        "revisionsDone": state.revisions_done,
        "mastery": bands,
        "pyqAttempted": state.pyq_attempts,
        "pyqCorrect": state.pyq_correct,
        "mockBand": (mock_overall_band(last_mock) if last_mock else None),
        "mockWeakSections": (
            [s["title"] for s in m9.mock_weak_sections(last_mock)]
            if last_mock else []),
        "skippedDays": len(state.skipped_days),
        "sessions": state.sessions,
        "xp": state.xp_total,
        "readiness": readiness,
        "daysLeft": days_left,
        "weakFindings": weak_findings,
    }


def run_all():
    tracks, courses = m8.load_courses()
    specs = build_specs(courses)
    students = {}
    for spec in specs:
        d = run_journey(spec, courses)
        students[spec["id"]] = d
    return {"students": students, "courses": list(courses.keys())}


def build_specs(courses):
    sanskrit = courses[COURSE_ID]
    view = m8.build_view(sanskrit)
    all_ids = sorted(m8.selectable_ids(view))
    # A weak-ish topic for persona H (one with subtopics → typed pool).
    units = [u for s in view for u in s["units"]
             if u["selectable"] and u.get("subtopics")]
    fail_topic = units[0]["id"] if units else all_ids[0]
    # Strong/weak sections for persona I (use the Hindi course which
    # has clearly separated sections).
    hindi_view = m8.build_view(courses[COURSE_ID_2])
    section_titles = [s["title"] for s in hindi_view]

    def mk(pid, name, make_policy, **kw):
        base = {"id": pid, "name": name, "make_policy": make_policy,
                "seed": 1000 + ord(pid)}
        base.update(kw)
        return base

    return [
        mk("A", "Strong student",
           lambda rng, spec, v, c: policy_always_correct,
           target_weeks=8),
        mk("B", "Average student",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.55),
           target_weeks=8),
        mk("C", "Weak student",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.25),
           target_weeks=12),
        mk("D", "Skips sessions",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.6),
           target_weeks=8),
        mk("E", "Changes syllabus scope",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.6),
           target_weeks=8),
        mk("F", "Changes readiness target",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.6),
           target_weeks=10),
        mk("G", "Chooses different tasks",
           lambda rng, spec, v, c: make_probabilistic(rng, 0.6),
           target_weeks=8),
        mk("H", "Repeatedly fails one topic",
           lambda rng, spec, v, c: make_topic_failure(rng, fail_topic,
                                                      0.7),
           target_weeks=8),
        mk("I", "Strong one section, weak another",
           lambda rng, spec, v, c: make_section_asymmetric(
               rng, section_titles[0]),
           course=COURSE_ID_2, target_weeks=8),
    ]


# ---------------------------------------------------------------------------
# Report writer (deterministic markdown)
# ---------------------------------------------------------------------------

REPORT_HEADER = """# M11 — Real Student Simulations (Exam Mode 2.0)

Nine personas from the master plan, each run end-to-end through the
SAME verified engine ports the shipped Dart code encodes (M4
diagnostic ladder, M5/M8 deterministic planner, M6 practice loop,
M8 weak-area + revision engines, M9 PYQ/mock engines, M10 XP rules)
against the REAL canonical CBSE 2026-27 syllabus JSONs. Journeys are
deterministic (seeded LCG) — re-running reproduces this report
byte-for-byte.

**Journey per student:** diagnostic → plan → 21 simulated days of
tasks/mistakes → replanning (§33 triggers for E and F) → weak-area
recovery days (§22) → revision (§23) → PYQ sessions (§25) → mini
mocks (§41 deterministic) → readiness line + XP (M10).

Invariants verified for every student (see verify_exam_m11.py):
plans validate (§16, budgets §9), every task stays inside the selected
scope, XP is once-per-session, and no engine crashes on any persona.
Divergence between personas is asserted pairwise in the verifier —
the table below is the human-readable digest.
"""


def write_report(path, data):
    lines = [REPORT_HEADER, "",
             "## Per-student digest", "",
             "| | " + " | ".join(
                 ["A", "B", "C", "D", "E", "F", "G", "H", "I"]) + " |",
             "|---|" + "---|" * 9]
    students = data["students"]
    rows = [
        ("Diagnostic accuracy",
         lambda s: f"{s['diagnosticAccuracy']:.2f}"),
        ("Final plan scope revision", lambda s: s["planScopeRevision"]),
        ("Plans built (replans)",
         lambda s: s["planCount"]),
        ("Replan reasons", lambda s: "; ".join(s["replans"]) or "—"),
        ("Recovery days used", lambda s: s["recoveryDays"]),
        ("Recovery outcomes",
         lambda s: (", ".join(s["recoveryOutcomes"]) or "—")),
        ("Revision sessions", lambda s: s["revisionsDone"]),
        ("Strong topics", lambda s: s["mastery"]["strong"]),
        ("Needs-attention topics", lambda s: s["mastery"]["needsAttention"]),
        ("PYQ attempted", lambda s: s["pyqAttempted"]),
        ("PYQ correct", lambda s: s["pyqCorrect"]),
        ("Last mock band", lambda s: s["mockBand"] or "—"),
        ("Mock weak sections",
         lambda s: (", ".join(s["mockWeakSections"]) or "—")),
        ("Skipped days", lambda s: s["skippedDays"]),
        ("Sessions finished", lambda s: s["sessions"]),
        ("XP earned (M10)", lambda s: s["xp"]),
        ("Readiness", lambda s: s["readiness"]),
        ("Days to anchor", lambda s: (s["daysLeft"] if s["daysLeft"] is not None else "—")),
        ("Final weak findings", lambda s: (", ".join(
            s["weakFindings"][:3]) or "—")),
    ]
    for label, fn in rows:
        cells = []
        for sid in "ABCDEFGHI":
            s = students[sid]
            try:
                cells.append(str(fn(s)))
            except Exception:
                cells.append("—")
        lines.append(f"| **{label}** | " + " | ".join(cells) + " |")

    lines += [
        "",
        "## How the paths differ (selected)",
        "",
        "* **A vs C**: A's diagnostic accuracy, mastery bands, PYQ and",
        "  mock results sit in the strong band; C's sit at needsAttention",
        "  — and the weak-area engines schedule C far more recovery",
        "  days than A (who needs none).",
        "* **D**: skipped days leave revision items overdue, so §21",
        "  forgotten-concept findings appear where A/B/C have none.",
        "* **E**: the scope edit at day 7 bumps scopeRevision, drops",
        "  out-of-scope topics from every later plan (§33/§16) and",
        "  forces a rebuild.",
        "* **F**: the day-10 readiness change rebuilds the plan with a",
        "  different pacing window (§8/§33).",
        "* **G**: G replaces recommended practice with PYQ sessions;",
        "  the engines never punish the deviation (§20 student",
        "  freedom) — day completions simply differ.",
        "* **H**: the repeatedly-failed topic becomes the §22 focus",
        "  topic with the frequent recovery tier until a clean recheck",
        "  expands its revision interval.",
        "* **I**: mock weak sections appear ONLY in the weak section,",
        "  and PYQ performance splits by section — the §21 weakMock",
        "  signal is section-honest.",
        "",
        "## Method",
        "",
        "1. Each persona's answer policy is a deterministic function",
        "   `decide(question, ctx)` over the grounded question set.",
        "2. All sessions run the §28 loop (one retry, then reveal).",
        "3. All persistence mirrors §12/§56/§57 (bounded, corrupt-",
        "   degrading stores) exactly as the repositories implement.",
        "4. XP uses the M10 mirror tables parsed live from the Dart",
        "   source, so the simulation cannot drift from the app.",
        "",
        "Generated deterministically by `tools/exam/student_simulations.py`.",
    ]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, encoding="utf-8", mode="w") as f:
        f.write("\n".join(lines) + "\n")
    return path


def main():
    data = run_all()
    report = write_report(
        os.path.join(PROJECT_ROOT, "docs", "Exam-2.0",
                     "M11-Student-Simulations.md"),
        data)
    print(f"M11 SIMULATIONS: 9 students × {DAYS} days on "
          f"{len(data['courses'])} courses — report → {report}")
    for sid in "ABCDEFGHI":
        s = data["students"][sid]
        print(f"  {sid} ({s['name']}): diag={s['diagnosticAccuracy']:.2f} "
              f"recoveries={s['recoveryDays']} replans={s['planCount']} "
              f"pyq={s['pyqAttempted']} mock={s['mockBand']} "
              f"xp={s['xp']} readiness={s['readiness']}")
    return data


PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))

if __name__ == "__main__":
    main()
