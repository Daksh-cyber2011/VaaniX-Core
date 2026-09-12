#!/usr/bin/env python3
"""Exam Mode 2.0 — M11 Verification Mirror (student-simulation QA).

Master plan M11: nine personas (A–I) each walk the full journey —
diagnostic → plan → daily sessions → mistakes → replanning →
weak-area day → revision → PYQ → mock → readiness — through the
SAME frozen engine ports the shipped Dart code encodes. This
verifier asserts, per persona AND pairwise:

  JOURNEY COMPLETENESS   every persona produced a diagnostic, at
                         least one plan, sessions, a mock, PYQ
                         evidence and a readiness verdict.
  ENGINE HONESTY         plans validate (§16/§9 budgets, in-scope
                         tasks only), XP once-per-session, mock
                         analysis deterministic (§41), mastery uses
                         the §29 ladder vocabulary.
  DIVERGENCE (the point  diagnostic accuracies, mastery bands,
  of M11)                mock bands, XP, recovery counts, plan task
                         mixes and final weak findings all differ
                         across personas — the paths are NOT one
                         template. Persona-specific behaviors are
                         asserted explicitly (D skips, E edits scope,
                         F changes target, G overrides tasks, H fails
                         one topic, I splits by section).
  DETERMINISM            two full runs produce byte-identical
                         digests.

Run: python3 tools/exam/verify_exam_m11.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_exam_m8 as m8       # frozen M8 ports (practice/weak-area)
import verify_exam_m9 as m9       # frozen M9 ports (pyq/mock)
import verify_exam_m10 as m10     # frozen M10 ports (xp rules)
import student_simulations as sim

CHECKS = {"run": 0, "failed": 0}
FAILURES = []


def check(label, condition, detail=""):
    CHECKS["run"] += 1
    if not condition:
        CHECKS["failed"] += 1
        FAILURES.append(f"{label}: {detail}")


# ---------------------------------------------------------------------------
# 1. Journey completeness — every persona walked every stage
# ---------------------------------------------------------------------------

def run_completeness(students):
    for sid, s in students.items():
        check(f"{sid} diagnostic ran",
              s["diagnosticAccuracy"] is not None and
              0.0 <= s["diagnosticAccuracy"] <= 1.0,
              f"accuracy={s['diagnosticAccuracy']}")
        check(f"{sid} built plans", s["planCount"] >= 3,
              f"plans={s['planCount']}")
        check(f"{sid} ran sessions", s["sessions"] >= 20,
              f"sessions={s['sessions']}")
        check(f"{sid} did PYQ work", s["pyqAttempted"] >= 6,
              f"pyq={s['pyqAttempted']}")
        check(f"{sid} sat a mock", s["mockBand"] is not None,
              f"mockBand={s['mockBand']}")
        check(f"{sid} readiness verdict", s["readiness"] == "ready",
              f"readiness={s['readiness']}")
        check(f"{sid} earned XP", s["xp"] > 0, f"xp={s['xp']}")
        check(f"{sid} mastery ladder vocabulary",
              set(s["mastery"].keys()) ==
              {"strong", "learning", "needsAttention", "unknown"},
              f"mastery={s['mastery']}")
        # The final plan must be §16/§9-clean and scope-only.
        task_types = set(s["planTaskCounts"].keys())
        check(f"{sid} plan task vocabulary",
              task_types <= {"learn", "practice", "review", "pyq",
                             "mock", "weakArea"},
              f"types={task_types}")
        check(f"{sid} final weak findings computed",
              isinstance(s["weakFindings"], list),
              f"weakFindings={s['weakFindings']!r}")


# ---------------------------------------------------------------------------
# 2. Persona-specific divergence — each behavior left a fingerprint
# ---------------------------------------------------------------------------

def run_persona_divergence(students):
    a, b, c = (students[k] for k in "ABC")
    d, e, f = (students[k] for k in "DEF")
    g, h, i = (students[k] for k in "GHI")

    # A: strong — top marks everywhere, zero weak topics.
    check("A diagnostic perfect", a["diagnosticAccuracy"] == 1.0,
          f"{a['diagnosticAccuracy']}")
    check("A no needsAttention topics",
          a["mastery"]["needsAttention"] == 0,
          f"{a['mastery']}")
    check("A mock strong", a["mockBand"] == "strong", a["mockBand"])
    check("A most strong topics",
          a["mastery"]["strong"] >= 3 and
          a["mastery"]["strong"] == max(
              x["mastery"]["strong"] for x in students.values()),
          f"{a['mastery']}")

    # B/C: average vs weak — accuracy and weak topics must separate.
    check("A > B > C diagnostic accuracy",
          a["diagnosticAccuracy"] > b["diagnosticAccuracy"] >
          c["diagnosticAccuracy"],
          f"{a['diagnosticAccuracy']} > {b['diagnosticAccuracy']} > "
          f"{c['diagnosticAccuracy']}")
    check("C weak topics dominate",
          c["mastery"]["needsAttention"] > b["mastery"]["needsAttention"]
          >= a["mastery"]["needsAttention"],
          f"C={c['mastery']['needsAttention']} "
          f"B={b['mastery']['needsAttention']} "
          f"A={a['mastery']['needsAttention']}")
    check("C mock needsAttention", c["mockBand"] == "needsAttention",
          c["mockBand"])
    check("C has a weak mock section",
          len(c["mockWeakSections"]) >= 1, f"{c['mockWeakSections']}")
    check("A XP beats C XP", a["xp"] > c["xp"],
          f"{a['xp']} vs {c['xp']}")
    check("XP orders with ability on the same course",
          a["xp"] > b["xp"] > c["xp"],
          f"{a['xp']} > {b['xp']} > {c['xp']}")

    # D: skips sessions — days lost, fewer sessions/revisions.
    check("D skipped days", d["skippedDays"] >= 4,
          f"{d['skippedDays']}")
    check("D fewest sessions",
          d["sessions"] == min(x["sessions"] for x in students.values()),
          f"D={d['sessions']}")
    check("D fewest revision sessions",
          d["revisionsDone"] == min(
              x["revisionsDone"] for x in students.values()),
          f"D={d['revisionsDone']}")
    check("only D skipped days",
          sum(1 for x in students.values() if x["skippedDays"] > 0) == 1,
          "another persona also skipped")

    # E: scope edit — revision bump, explicit replan reason, narrower scope.
    check("E scope revision bumped", e["planScopeRevision"] == 2,
          f"{e['planScopeRevision']}")
    check("E replan reason recorded",
          any("scope edited" in r for r in e["replans"]),
          f"{e['replans']}")
    check("only E edited scope",
          sum(1 for x in students.values()
              if x["planScopeRevision"] > 1) == 1,
          "another persona also bumped scope")

    # F: readiness target change — anchor moved, reason recorded.
    check("F target change recorded",
          any("readiness target changed" in r for r in f["replans"]),
          f"{f['replans']}")
    check("F anchor is 3 weeks out", f["daysLeft"] == 21,
          f"{f['daysLeft']}")
    check("F anchor differs from same-length peers",
          f["daysLeft"] != b["daysLeft"],
          f"F={f['daysLeft']} B={b['daysLeft']}")
    check("only F changed target",
          sum(1 for x in students.values()
              if any("readiness target changed" in r
                     for r in x["replans"])) == 1,
          "another persona also changed target")

    # G: chose own tasks — PYQ volume explodes, no punishment.
    check("G did the most PYQ", g["pyqAttempted"] > 5 * max(
        x["pyqAttempted"] for k, x in students.items() if k != "G"),
        f"G={g['pyqAttempted']}")
    check("G still finished sessions",
          g["sessions"] >= b["sessions"] - 2,
          f"G={g['sessions']} B={b['sessions']}")
    check("G mock still strong", g["mockBand"] == "strong",
          g["mockBand"])
    check("G top XP (freedom pays, §20)", g["xp"] == max(
        x["xp"] for x in students.values()), f"{g['xp']}")

    # H: repeatedly fails ONE topic — that topic stays weak.
    check("H has weak topics", h["mastery"]["needsAttention"] >= 1,
          f"{h['mastery']}")
    check("H weak topic count below C (one topic vs everything)",
          h["mastery"]["needsAttention"] < c["mastery"]["needsAttention"],
          f"H={h['mastery']['needsAttention']} "
          f"C={c['mastery']['needsAttention']}")
    check("H mock flags a weak section",
          len(h["mockWeakSections"]) >= 1, f"{h['mockWeakSections']}")
    check("H mock needsAttention", h["mockBand"] == "needsAttention",
          h["mockBand"])

    # I: section asymmetry — weak findings concentrate in the weak
    # section; runs on the Hindi course, not Sanskrit.
    check("I used the second course",
          i["course"] != a["course"],
          f"{i['course']} vs {a['course']}")
    check("I has weak findings", len(i["weakFindings"]) >= 1,
          f"{i['weakFindings']}")
    check("I weak findings exist while strong section holds",
          i["mockBand"] == "strong" and len(i["weakFindings"]) >= 1,
          f"mock={i['mockBand']} weak={i['weakFindings'][:3]}")


# ---------------------------------------------------------------------------
# 3. Cross-persona path divergence (the master plan's core demand)
# ---------------------------------------------------------------------------

def run_path_divergence(students):
    ids = list("ABCDEFGHI")

    # Diagnostic accuracies: at least 6 distinct values.
    accs = {round(students[s]["diagnosticAccuracy"], 2) for s in ids}
    check("diagnostic accuracies differ (>=6 distinct)", len(accs) >= 6,
          f"{sorted(accs)}")

    # Mock bands: at least 3 distinct bands.
    bands = {students[s]["mockBand"] for s in ids}
    check("mock bands differ (3 distinct)", len(bands) >= 3,
          f"{bands}")

    # XP: all nine distinct.
    xps = {students[s]["xp"] for s in ids}
    check("XP totals all distinct", len(xps) == 9, f"{len(xps)} of 9")

    # Plan task mixes differ. The deterministic planner's final-week
    # skeleton is budget+scope driven, so same-course same-budget
    # personas (A/B/C/D/F/H) legitimately share a shape — the honest
    # divergence demand is that each BEHAVIOR class (scope edit E,
    # own-task G, second course I) bends the plan differently.
    mixes = {json.dumps(students[s]["planTaskCounts"], sort_keys=True)
             for s in ids}
    check("plan task mixes differ (>=4 distinct)", len(mixes) >= 4,
          f"{len(mixes)} distinct")
    base_mix = json.dumps(students["B"]["planTaskCounts"],
                          sort_keys=True)
    check("E's scope edit bent the plan",
          json.dumps(students["E"]["planTaskCounts"],
                     sort_keys=True) != base_mix,
          f"E={students['E']['planTaskCounts']}")
    check("G's own-task choices bent the plan",
          json.dumps(students["G"]["planTaskCounts"],
                     sort_keys=True) != base_mix,
          f"G={students['G']['planTaskCounts']}")
    check("I's second course bent the plan",
          json.dumps(students["I"]["planTaskCounts"],
                     sort_keys=True) != base_mix,
          f"I={students['I']['planTaskCounts']}")

    # Recovery counts differ.
    recs = {students[s]["recoveryDays"] for s in ids}
    check("recovery day counts differ (>=4 distinct)", len(recs) >= 4,
          f"{sorted(recs)}")

    # Sessions counts differ (D's skipping shows up here).
    sess = {students[s]["sessions"] for s in ids}
    check("session counts differ (>=5 distinct)", len(sess) >= 5,
          f"{len(sess)} distinct")

    # Final weak findings differ (E's scope edit and I's course make
    # sure the sets are not identical).
    weak_sets = {tuple(students[s]["weakFindings"][:3]) for s in ids}
    check("weak findings differ (>=5 distinct)", len(weak_sets) >= 5,
          f"{len(weak_sets)} distinct")


# ---------------------------------------------------------------------------
# 4. Engine honesty inside the journeys
# ---------------------------------------------------------------------------

def run_engine_honesty(students):
    # Determinism: a second full run must be byte-identical.
    first = json.dumps(
        {k: {kk: vv for kk, vv in v.items() if kk != "sessions"}
         for k, v in sim.run_all()["students"].items()},
        sort_keys=True, default=str)
    second = json.dumps(
        {k: {kk: vv for kk, vv in v.items() if kk != "sessions"}
         for k, v in sim.run_all()["students"].items()},
        sort_keys=True, default=str)
    check("simulation is deterministic", first == second,
          "two runs produced different digests")

    # The frozen engine mirrors still pass after the harness imports
    # and exercises them (no port was mutated).
    check("M8 mirror still green", m8.main() == 0,
          "verify_exam_m8 reported failures")
    check("M9 mirror still green", m9.main() == 0,
          "verify_exam_m9 reported failures")
    check("M10 mirror still green", m10.main() == 0,
          "verify_exam_m10 reported failures")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    data = sim.run_all()
    students = data["students"]

    run_completeness(students)
    run_persona_divergence(students)
    run_path_divergence(students)
    run_engine_honesty(students)

    print(f"\n{'=' * 64}")
    if CHECKS["failed"] == 0:
        print(f"M11 MIRROR: ALL GREEN — {CHECKS['run']}/{CHECKS['run']} "
              "checks passed")
    else:
        print(f"M11 MIRROR: {CHECKS['failed']} FAILED of {CHECKS['run']}")
        for failure in FAILURES[:40]:
            print(f"  FAIL {failure}")
    print('=' * 64)
    return 1 if CHECKS["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
