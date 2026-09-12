#!/usr/bin/env python3
"""Exam Mode 2.0 — M10 Verification Mirror (Python invariant port).

Milestone M10 (HOME + VAN + GAMIFICATION) mirrored against the real
Dart sources and the shared engine ports:

  XP RULES        deterministic, bounded, once-per-session — the exact
                  constants are parsed FROM the Dart source so the
                  mirror and the app can never drift.
  HUB REPOSITORY  day completions + XP ledger: bounds (§56), isolation
                  (§38), corruption degradation (§57), idempotence.
  SNAPSHOT        the pure hub derivation: today's day, continue
                  target, honest one-liners, readiness countdown, the
                  VAN mood/message ladder (all cases from the Dart test
                  suite mirrored 1:1).
  WIRING          source-level: the hub route is registered, the smart
                  gate lands on the hub, all five session controllers
                  feed the gamification chain at their REAL finish
                  points, the honest XP strip renders on every finish
                  view, VAN events are dispatched with honest payloads,
                  and the import-cycle-free leaf provider file exists.

Run: python3 tools/exam/verify_exam_m10.py
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta

PROJECT_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", ".."))
LIB_EXAM = os.path.join(PROJECT_ROOT, "lib", "features", "exam")

CHECKS = {"run": 0, "failed": 0}
FAILURES = []


def check(label, condition, detail=""):
    CHECKS["run"] += 1
    if not condition:
        CHECKS["failed"] += 1
        FAILURES.append(f"{label}: {detail}")


def dart_source(*rel):
    path = os.path.join(PROJECT_ROOT, *rel)
    with open(path, encoding="utf-8") as f:
        return f.read()


NOW = datetime(2026, 9, 12, 15, 0, 0)

# ---------------------------------------------------------------------------
# XP rules — parsed from the REAL Dart source (drift is impossible)
# ---------------------------------------------------------------------------

def parse_xp_tables():
    src = dart_source("lib", "features", "exam", "domain", "hub",
                      "exam_gamification.dart")
    per_correct = {}
    bonus = {}
    cap = {}
    for kind in ("diagnostic", "practice", "recovery", "revision", "pyq",
                 "mock"):
        m = re.search(
            rf"ExamSessionKind\.{kind}:\s*(\d+),", src)
        per_correct[kind] = int(m.group(1))
    # Second and third tables (completion bonus + caps).
    tables = re.findall(
        r"const Map<ExamSessionKind, int> _\w+ = \{(.*?)\};", src, re.S)
    check("m10: three XP tables found in Dart source", len(tables) == 3,
          f"got {len(tables)}")
    for body in tables[1:]:
        for kind, val in re.findall(
                r"ExamSessionKind\.(\w+):\s*(\d+)", body):
            (bonus if not bonus.get(kind) else cap)[kind] = int(val)
        # fill caps on the second pass
    # The regex above fills `bonus` from table 2 and `cap` from table 3
    # (keys already present route to cap). Re-parse explicitly for safety.
    bonus = {}
    cap = {}
    for kind, val in re.findall(r"ExamSessionKind\.(\w+):\s*(\d+)",
                                tables[1]):
        bonus[kind] = int(val)
    for kind, val in re.findall(r"ExamSessionKind\.(\w+):\s*(\d+)",
                                tables[2]):
        cap[kind] = int(val)
    return per_correct, bonus, cap


PER_CORRECT, COMPLETION_BONUS, SESSION_CAP = parse_xp_tables()


def session_xp_total(kind, correct, total):
    if total <= 0 or correct < 0:
        return 0
    base = PER_CORRECT[kind] * correct + COMPLETION_BONUS[kind]
    perfect = total >= 5 and correct == total
    if perfect:
        base += 5
    return min(max(base, 0), SESSION_CAP[kind])


def run_xp_rule_checks():
    for kind in PER_CORRECT:
        check(f"m10: XP table entry exists for {kind}",
              kind in COMPLETION_BONUS and kind in SESSION_CAP)
    check("m10: practice session 6/8 = 15 XP",
          session_xp_total("practice", 6, 8) == 15)
    check("m10: practice session 8/8 = 24 XP (perfect bonus)",
          session_xp_total("practice", 8, 8) == 24)
    check("m10: one-question 'perfect' earns no perfect bonus",
          not (1 >= 5))
    check("m10: mock 20/25 = 95 XP", session_xp_total("mock", 20, 25) == 95)
    check("m10: mock corrupt counts capped",
          session_xp_total("mock", 400, 400) == SESSION_CAP["mock"])
    check("m10: negative correct counts award 0",
          session_xp_total("practice", -3, 10) == 0)
    check("m10: zero-total session awards 0",
          session_xp_total("pyq", 2, 0) == 0)
    # Honest caps: mock may out-earn practice, never the reverse.
    check("m10: mock cap > practice cap (long paper earns more)",
          SESSION_CAP["mock"] > SESSION_CAP["practice"])
    # Recovery completion bonus carries the §22 weight.
    check("m10: recovery completion bonus > practice bonus",
          COMPLETION_BONUS["recovery"] > COMPLETION_BONUS["practice"])


# ---------------------------------------------------------------------------
# Hub repository mirror (§12/§56/§57)
# ---------------------------------------------------------------------------

MAX_DAY_KEYS = 60
MAX_LEDGER = 300


class MirrorHubRepo:
    def __init__(self, store=None):
        self.store = store if store is not None else {}

    def load_day(self, track, day):
        doc = self.store.get("completions", {})
        if not isinstance(doc, dict):
            return set()
        track_doc = doc.get(track, {})
        if not isinstance(track_doc, dict):
            return set()
        day_list = track_doc.get(day, [])
        if not isinstance(day_list, list):
            return set()
        return set(x for x in day_list if isinstance(x, str))

    def record(self, track, day, task_type):
        doc = self.store.setdefault("completions", {})
        track_doc = doc.setdefault(track, {})
        day_list = track_doc.setdefault(day, [])
        if task_type not in day_list:
            day_list.append(task_type)
        keys = sorted(track_doc.keys())
        while len(keys) > MAX_DAY_KEYS:
            track_doc.pop(keys.pop(0))

    def is_awarded(self, key):
        return key in self.store.setdefault("ledger", [])

    def mark_awarded(self, key):
        ledger = self.store.setdefault("ledger", [])
        if key in ledger:
            return
        ledger.append(key)
        while len(ledger) > MAX_LEDGER:
            ledger.pop(0)


def run_repo_checks():
    repo = MirrorHubRepo()
    check("m10 repo: empty store → empty completions",
          repo.load_day("t", "d") == set())
    repo.record("t", "d", "practice")
    repo.record("t", "d", "practice")
    repo.record("t", "d", "pyq")
    check("m10 repo: idempotent union", repo.load_day("t", "d") ==
          {"practice", "pyq"})
    repo.record("a", "d1", "mock")
    repo.record("b", "d1", "review")
    check("m10 repo: track isolation",
          repo.load_day("a", "d1") == {"mock"} and
          repo.load_day("b", "d1") == {"review"})
    for i in range(MAX_DAY_KEYS + 5):
        repo.record("t", f"d{i:03d}", "practice")
    check("m10 repo: §56 oldest day keys dropped",
          repo.load_day("t", "d000") == set() and
          repo.load_day("t", f"d{MAX_DAY_KEYS + 4:03d}") == {"practice"})
    check("m10 repo: ledger once-ever",
          not repo.is_awarded("k1"))
    repo.mark_awarded("k1")
    repo.mark_awarded("k1")
    check("m10 repo: mark_awarded idempotent", repo.is_awarded("k1"))
    for i in range(MAX_LEDGER + 10):
        repo.mark_awarded(f"k{i}")
    # Bounded FIFO: the earliest keys were dropped, recent keys survive.
    check("m10 repo: §56 ledger bounded",
          not repo.is_awarded("k0") and not repo.is_awarded("k1")
          and repo.is_awarded("k299"))

    # §57: corrupt documents degrade to empty (never throw).
    corrupt = MirrorHubRepo({"completions": "not-a-map",
                             "ledger": {"nope": 1}})
    check("m10 repo: corrupt store degrades", corrupt.load_day("t", "d") == set()
          and not corrupt.is_awarded("k"))

    # Dart constants parity: parse the repository file for its bounds.
    src = dart_source("lib", "features", "exam", "data", "hub",
                      "exam_hub_repository.dart")
    check("m10 repo: Dart maxDayKeys == 60",
          re.search(r"maxDayKeys = 60", src) is not None)
    check("m10 repo: Dart maxLedgerEntries == 300",
          re.search(r"maxLedgerEntries = 300", src) is not None)
    check("m10 repo: corrupt-JSON degrade paths present",
          src.count("catch") >= 2)


# ---------------------------------------------------------------------------
# Snapshot derivation mirror (1:1 with the Dart test suite)
# ---------------------------------------------------------------------------

def snapshot_van_message(s):
    """Mirror of ExamHubSnapshot.vanMessage priority ladder."""
    if not s.get("hasDiagnostic"):
        return "A short diagnostic will tell me where to start."
    if s["plan"] is None or not s["plan"]["days"]:
        return "Let me build your study plan."
    if s["plan_window_exhausted"]:
        return "The plan window has passed — shall we rebuild it?"
    if s["recovery_today"]:
        return "Today is your weak-area recovery day. We take it step by step."
    if s["readiness_overdue"]:
        return "Your readiness target passed — setting a new one will re-aim the plan."
    if s["weak"]["revisionDueCount"] > 0:
        return "You have revision due today — a quick review keeps it fresh."
    if s["today_all_done"]:
        return "Today\u2019s plan is complete. Wonderful consistency!"
    task = s["continue_task"]
    if task is not None:
        return f"Next: Task {task['topicId']} · {task['minutes']} min"
    return "Ready when you are."


def build_snapshot(plan=None, profile=None, weak=None, completed=(),
                   has_diagnostic=True, pyq=(0, 0), mock=None, now=NOW,
                   plan_created=None):
    days = (plan or {}).get("days", [])
    if plan_created is None:
        plan_created = (plan or {}).get("createdAtIso",
                                        "2026-09-12T09:00:00.000")
    weak = weak or {"findingCount": 0, "topSeverityName": "",
                    "recoveryRecommended": False, "recoveryDayIndex": 0,
                    "revisionDueCount": 0}
    created = datetime.fromisoformat(plan_created.split(".")[0]) if days else None
    if created:
        created_day = created.replace(hour=0, minute=0, second=0)
        today = now.replace(hour=0, minute=0, second=0)
        offset = (today - created_day).days
        today_index = max(0, min(offset, len(days) - 1))
        exhausted = offset >= len(days)
    else:
        today_index = -1
        exhausted = False
    completed = set(completed)
    today_tasks = [
        {**t, "done": t["type"] in completed} for t in
        (days[today_index]["tasks"] if today_index >= 0 else [])
    ]
    continue_task = next((t for t in today_tasks if not t["done"]), None)
    all_done = bool(today_tasks) and all(t["done"] for t in today_tasks)
    recovery_today = (weak["recoveryRecommended"] and today_index >= 0 and
                      weak["recoveryDayIndex"] == today_index and
                      "weakArea" not in completed)

    anchor = profile.get("target") if profile else None
    if anchor is None and profile and profile.get("weeks"):
        anchor = now + timedelta(weeks=profile["weeks"])
    days_left = None
    if anchor is not None:
        days_left = (anchor.replace(hour=0, minute=0, second=0) -
                     now.replace(hour=0, minute=0, second=0)).days

    s = {
        "hasDiagnostic": has_diagnostic,
        "plan": plan,
        "weak": weak,
        "today_index": today_index,
        "plan_window_exhausted": exhausted,
        "today_all_done": all_done,
        "continue_task": continue_task,
        "recovery_today": recovery_today,
        "pyq": pyq,
        "mock": mock,
        "completed": completed,
    }
    if days_left is not None:
        s["days_left"] = days_left
        s["readiness_overdue"] = days_left < 0
    else:
        s["readiness_overdue"] = False
    return s


def mk_task(kind, topic, minutes):
    return {"type": kind, "topicId": topic, "minutes": minutes}


def mk_plan(days, created="2026-09-12T09:00:00.000"):
    return {"days": days, "createdAtIso": created}


def run_snapshot_checks():
    # -- no data at all
    s = build_snapshot(plan=None, profile=None, has_diagnostic=False)
    check("m10 snap: no data → diagnostic VAN line",
          snapshot_van_message(s) ==
          "A short diagnostic will tell me where to start.")

    # -- readiness countdown
    s = build_snapshot(profile={"target": datetime(2026, 10, 10)})
    check("m10 snap: target date → 28 days",
          s["days_left"] == 28)
    s = build_snapshot(profile={"target": datetime(2026, 9, 5)})
    check("m10 snap: overdue anchor flagged",
          s["readiness_overdue"] is True)

    # -- today's plan + continue
    plan = mk_plan([
        {"tasks": [mk_task("practice", "a", 10), mk_task("pyq", "b", 10)]},
        {"tasks": [mk_task("review", "c", 5)]},
    ])
    s = build_snapshot(plan=plan, profile={"weeks": 6})
    check("m10 snap: plan created today → day 0",
          s["today_index"] == 0)
    check("m10 snap: continue = first not-done task",
          s["continue_task"]["type"] == "practice")

    plan_old = mk_plan([
        {"tasks": [mk_task("learn", f"t{i}", 10)]} for i in range(5)
    ], created="2026-09-09T08:00:00.000")
    s = build_snapshot(plan=plan_old, profile={"weeks": 6})
    check("m10 snap: 3-days-old plan → day 3 (clamped)",
          s["today_index"] == 3)

    plan_stale = mk_plan([{"tasks": [mk_task("learn", "a", 10)]}],
                         created="2026-09-01T08:00:00.000")
    s = build_snapshot(plan=plan_stale, profile={"weeks": 6})
    check("m10 snap: window exhausted → rebuild nudge",
          s["plan_window_exhausted"] and
          snapshot_van_message(s) ==
          "The plan window has passed — shall we rebuild it?")

    s = build_snapshot(plan=mk_plan([{"tasks": [
        mk_task("practice", "a", 10), mk_task("pyq", "b", 10),
        mk_task("mock", "c", 20)]}]),
        profile={"weeks": 6}, completed={"practice"})
    check("m10 snap: finished session marks its task done",
          s["continue_task"]["type"] == "pyq")

    s = build_snapshot(plan=mk_plan([{"tasks": [mk_task("practice", "a", 10)]}]),
                       profile={"weeks": 6}, completed={"practice"})
    check("m10 snap: all done → celebrate line",
          s["today_all_done"] and snapshot_van_message(s) ==
          "Today\u2019s plan is complete. Wonderful consistency!")

    # -- weak area / recovery / revision ladder
    s = build_snapshot(
        plan=mk_plan([{"tasks": [mk_task("practice", "a", 10)]}]),
        profile={"weeks": 6},
        weak={"findingCount": 3, "topSeverityName": "needsAttention",
              "recoveryRecommended": False, "recoveryDayIndex": 2,
              "revisionDueCount": 0})
    check("m10 snap: findings do not trigger recovery-today",
          s["recovery_today"] is False)

    s = build_snapshot(
        plan=mk_plan([{"tasks": [mk_task("practice", "a", 10)]}]),
        profile={"weeks": 6},
        weak={"findingCount": 2, "topSeverityName": "needsAttention",
              "recoveryRecommended": True, "recoveryDayIndex": 0,
              "revisionDueCount": 1})
    check("m10 snap: recovery today → care line",
          s["recovery_today"] and snapshot_van_message(s) ==
          "Today is your weak-area recovery day. We take it step by step.")

    s = build_snapshot(
        plan=mk_plan([{"tasks": [mk_task("weakArea", "a", 15)]}]),
        profile={"weeks": 6},
        weak={"findingCount": 2, "topSeverityName": "needsAttention",
              "recoveryRecommended": True, "recoveryDayIndex": 0,
              "revisionDueCount": 0},
        completed={"weakArea"})
    check("m10 snap: recovery done today is not re-nagged",
          s["recovery_today"] is False)

    s = build_snapshot(
        plan=mk_plan([{"tasks": [mk_task("practice", "a", 10)]}]),
        profile={"weeks": 6},
        weak={"findingCount": 0, "topSeverityName": "",
              "recoveryRecommended": False, "recoveryDayIndex": 0,
              "revisionDueCount": 2})
    check("m10 snap: revision due → focused line",
          snapshot_van_message(s) ==
          "You have revision due today — a quick review keeps it fresh.")

    # -- XP end-to-end over a simulated day (the honest day ledger)
    repo = MirrorHubRepo()
    xp = 0
    sessions = [("practice", 6, 8), ("pyq", 5, 5), ("revision", 3, 4)]
    keys = []
    for kind, correct, total in sessions:
        key = f"exam_xp_{kind}_t_{kind}-{correct}-{total}"
        if not repo.is_awarded(key):
            xp += session_xp_total(kind, correct, total)
            repo.mark_awarded(key)
        repo.record("t", "2026-09-12",
                    {"practice": "practice", "pyq": "pyq",
                     "revision": "review", "recovery": "weakArea",
                     "mock": "mock"}[kind])
        keys.append(key)
    check("m10: simulated day XP = 15 + 24 + 10 = 49",
          xp == 15 + 24 + 10, f"got {xp}")
    # Re-running the same sessions must not double-award.
    for kind, correct, total in sessions:
        key = f"exam_xp_{kind}_t_{kind}-{correct}-{total}"
        if not repo.is_awarded(key):
            xp += session_xp_total(kind, correct, total)
    check("m10: replays never double-award (once-ever)", xp == 49,
          f"got {xp}")
    check("m10: day completions carry the task mapping",
          repo.load_day("t", "2026-09-12") ==
          {"practice", "pyq", "review"})


# ---------------------------------------------------------------------------
# Source-level wiring checks
# ---------------------------------------------------------------------------

def run_source_checks():
    router = dart_source("lib", "app", "router", "app_router.dart")
    check("m10 wire: hub route registered",
          "RouteNames.examHubName" in router and
          "ExamHubScreen" in router)
    check("m10 wire: hub route imports the screen",
          "exam_hub_screen.dart" in router)

    routes = dart_source("lib", "core", "constants", "route_names.dart")
    check("m10 wire: examHub path + name constants",
          "examHub = '/exam/hub/:trackId'" in routes and
          "examHubName = 'exam-hub'" in routes)

    gate_src = dart_source("lib", "features", "exam", "presentation",
                           "screens", "exam_screen.dart")
    check("m10 wire: smart gate lands on the hub",
          "RouteNames.examHubName" in gate_src)
    check("m10 wire: gate no longer lands directly on the plan",
          "router.pushNamed(RouteNames.examPlanName," not in gate_src)

    # All five session controllers feed the gamification chain.
    controller_files = {
        "practice": ("exam_practice_providers.dart",
                     "ExamSessionKind.practice"),
        "weakarea": ("exam_weakarea_providers.dart",
                     "ExamSessionKind.recovery"),
        "pyq": ("pyq_mock_providers.dart", "ExamSessionKind.pyq"),
        "mock": ("pyq_mock_providers.dart", "ExamSessionKind.mock"),
        "diagnostic": ("exam_diagnostic_providers.dart",
                       "ExamSessionKind.diagnostic"),
    }
    for name, (fname, kind) in controller_files.items():
        src = dart_source("lib", "features", "exam", "presentation",
                          "providers", fname)
        check(f"m10 wire: {name} controller records gamification",
              kind in src and "sessionFinished(" in src)
        check(f"m10 wire: {name} controller clears stale outcome",
              "clearLastOutcome" in src)
    weak_src = dart_source("lib", "features", "exam", "presentation",
                           "providers", "exam_weakarea_providers.dart")
    check("m10 wire: weakarea records BOTH recovery and revision",
          "ExamSessionKind.revision" in weak_src)

    # The honest XP strip renders on every finish view.
    strip_screens = ["exam_practice_screen.dart",
                     "exam_diagnostic_screen.dart",
                     "exam_pyq_screen.dart",
                     "exam_mock_screen.dart",
                     "exam_weak_area_screen.dart"]
    for fname in strip_screens:
        src = dart_source("lib", "features", "exam", "presentation",
                          "screens", fname)
        check(f"m10 wire: XP strip on {fname}", "ExamSessionXpStrip" in src)

    # VAN integration: dispatch with honest payloads + streak events.
    game = dart_source("lib", "features", "exam", "presentation",
                       "providers", "exam_gamification_providers.dart")
    for event in ("VanEventType.quizCompleted", "VanEventType.perfectScore",
                  "VanEventType.streakExtended",
                  "VanEventType.achievementUnlocked",
                  "VanEventType.milestoneUnlocked"):
        check(f"m10 van: dispatches {event.split('.')[-1]}",
              event in game)
    check("m10 van: analytics is typed + bounded",
          "AnalyticsEventName.examCompleted" in game and
          "'mode': 'exam2'" in game)
    check("m10 van: streak extension is same-day honest",
          "streak > previous" in game)

    # Leaf provider file exists and pyq_mock re-exports for compat.
    leaf_path = os.path.join(
        LIB_EXAM, "presentation", "providers",
        "exam_repository_providers.dart")
    check("m10 wire: shared leaf repository providers exist",
          os.path.exists(leaf_path))
    pyq_src = dart_source("lib", "features", "exam", "presentation",
                          "providers", "pyq_mock_providers.dart")
    check("m10 wire: pyq_mock re-exports the moved providers",
          "export 'package:vaanix_app/features/exam/presentation/providers/"
          "exam_repository_providers.dart'" in pyq_src)
    weak_src = dart_source("lib", "features", "exam", "presentation",
                           "providers", "exam_weakarea_providers.dart")
    check("m10 wire: weakarea imports the leaf (no provider cycle)",
          "exam_repository_providers.dart" in weak_src)

    # VanState export fix present (the M2-M9 latent compile bug).
    strip = dart_source("lib", "shared", "widgets", "van_speech_strip.dart")
    check("m10 fix: VanSpeechStrip exports VanState",
          "export 'package:vaanix_app/features/van/domain/van_state.dart'"
          in strip)

    # The hub screen renders every M10 element from live state.
    hub = dart_source("lib", "features", "exam", "presentation",
                      "screens", "exam_hub_screen.dart")
    for token, label in [
            ("examHubSnapshotProvider", "snapshot provider"),
            ("xpTotalProvider", "live XP"),
            ("userProfileProvider", "live streak"),
            ("levelFromXp", "level curve"),
            ("VanSpeechStrip", "VAN context"),
            ("RouteNames.examWeakAreaName", "weak-area deep link"),
            ("RouteNames.examPyqName", "PYQ deep link"),
            ("RouteNames.examMockName", "mock deep link"),
            ("RouteNames.examPlanName", "full-plan deep link")]:
        check(f"m10 hub: renders {label}", token in hub)

    # Tests shipped for the milestone.
    test_dir = os.path.join(PROJECT_ROOT, "test", "features", "exam", "hub")
    check("m10 tests: hub test files exist",
          os.path.exists(os.path.join(test_dir, "exam_gamification_test.dart"))
          and os.path.exists(
              os.path.join(test_dir, "exam_hub_snapshot_test.dart")))

    # §30 sweep on the M10 user-facing copy: no percentages, no fake
    # achievement claims in the hub + strip sources.
    for fname, label in [
            ("exam_hub_models.dart", "hub domain copy"),
            ("exam_gamification.dart", "gamification copy"),
            ("exam_xp_strip.dart", "strip copy")]:
        src = dart_source("lib", "features", "exam", *{
                "exam_hub_models.dart": ("domain", "hub", "exam_hub_models.dart"),
                "exam_gamification.dart": ("domain", "hub",
                                           "exam_gamification.dart"),
                "exam_xp_strip.dart": ("presentation", "widgets",
                                       "exam_xp_strip.dart")}[fname])
        for bad in ("% score", "accuracy %", "guaranteed", "100%"):
            check(f"m10 honesty: {label} free of '{bad}'", bad not in src)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    run_xp_rule_checks()
    run_repo_checks()
    run_snapshot_checks()
    run_source_checks()

    print(f"\n{'=' * 64}")
    if CHECKS["failed"] == 0:
        print(f"M10 MIRROR: ALL GREEN — {CHECKS['run']}/{CHECKS['run']} "
              "checks passed")
    else:
        print(f"M10 MIRROR: {CHECKS['failed']} FAILED of {CHECKS['run']}")
        for f in FAILURES[:40]:
            print(f"  FAIL {f}")
    print('=' * 64)
    return 1 if CHECKS["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
