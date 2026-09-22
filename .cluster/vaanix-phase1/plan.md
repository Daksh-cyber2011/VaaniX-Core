# Phase 1 Plan: Truthful Student-Facing State (VaaniX-Core)

Task: Remove fabricated student-facing UI data; wire real state or truthful empty states.
Baseline git status: M lib/app/bootstrap/app_bootstrap.dart; untracked docs/PRODUCTION_AUDIT_2026-09-20.md, supabase/, test/features/environment/bootstrap_supabase_failure_test.dart (PRESERVE ALL).
Repo stats: 284 lib dart files, 141 test files. Riverpod + go_router. Flutter/Dart.

## Subtasks (S2 dispatch, round 1 - all parallel, read-only audits)
1. [audit-learn-lane] Learn Home + Home + screens + progress domain (XP/streak/level/mastery/daily goal/due/current lesson/progress rings). Output: audit_learn.md
2. [audit-exam-lane] Exam dashboards + syllabus + hub/gamification + PYQ/mock + diagnostic status. Output: audit_exam.md
3. [audit-profile-lane] Profile + achievements + settings + auth identity + onboarding defaults + app constants. Output: audit_profile.md
4. [audit-sweep-lane] Repo-wide grep sweep: hardcoded numbers/dates/countdowns, demo/sample data, division-by-zero, clamp/NaN risks, ref.read vs ref.watch stale UI. Output: audit_sweep.md

Dependencies: 1-4 parallel; none depend on each other.

## Review items (S4)
- Cross-check every G-class finding against quoted code (no upgrade of uncertain to confirmed).
- Verify proposed real sources exist (provider/repo paths) and do not introduce parallel state systems.
- Verify empty-state proposals are semantically truthful (no null -> 75% style swaps).
- Verify no scope creep (no Supabase/AI/VAN/audio/curriculum changes).

## Delivery items (S5)
- Implement fixes (zcode_run primary), regression tests, dart format, flutter analyze, targeted tests.
- Final Phase 1 report under DELIVERY/ in AutoCoder control workspace + Phase 1 status section.

## Constraints
- READ-ONLY audits in round 1. No test runs by auditors. No git mutations.
- Only classification G (fabricated student-facing state) and mislabeled E/F are actionable.
- Preserve existing user changes; supabase/ untouched.

## cluster_bypass_reason (2026-09-22 22:05 IST)
Subagent dispatch attempted 3 rounds (10 spawns) across 2026-09-21 and 2026-09-22.
All failed with provider errors ("LLM request failed" / "subagent run lost active
execution context") mid-run, producing 0 report files. sessions_spawn is functionally
unavailable for this task. Per Agent Cluster Mode fallback, mainline continues via
zcode_run (authorized repository delegation path) plus direct AutoCoder evidence capture.

## AutoCoder direct evidence (exam_cockpit_screen.dart, all 738 lines read 2026-09-22)
File: lib/features/exam/presentation/screens/exam_cockpit_screen.dart
- L63-73: candidateLabel correctly derives from userProfileProvider.resolvedDisplayName (already fixed in prior work; 'Daksh Sharma' fallback removed). OK.
- L137-144: _launchTopic falls back to 'cbse_10_hindi_a' default track when no scope store value (E/C borderline; acceptable default but hides missing scope selection).
- L205: hardcoded subtitle 'CBSE Class 10 Hindi Course A' (G: ignores actual user scope).
- L249+260: hardcoded '74' / 'DAYS LEFT' exam countdown (G: no exam date source).
- L272: 'Target Readiness: 98%+' (G: fabricated static claim).
- L296-302: VaaniXRadialGauge(percentage: 78, deltaText: '+3.6%/wk') (G: fabricated readiness % and fabricated weekly delta).
- L320+329: 'High Prep Pace' / 'Based on 32 drills' (G: fabricated drill count + pace).
- L377+395: 'MISSION DIRECTIVE - HIGH YIELD' / 'Unfinished' status pill (G: fabricated status).
- L407-418: hardcoded topic 'Surdas ke Pad', 'Kshitij Part 2', 'Weightage: 6-8 Marks', 'Target Speed: 1.8m/Ans' (G: fabricated mission directive, ignores real plan state).
- L101-113: VanCompanionBubble 'VAN - TACTICAL INTEL (93% MATCH)', 'Pada 3 has appeared in 4 out of the last 5 CBSE board papers' (G: fabricated match % and PYQ statistic).
- L440-491: 'Diagnostic Radar' + 'LIVE TELEMETRY' header; _DiagnosticBar rows with hardcoded topic names, accuracy ints, 'Stable Pace' labels (G: fabricated diagnostic data).
- L494: fallback 'cbse_10_hindi_a' repeated in _buildSimulatorTrays (same as L140).
- L513-546: simulator tray subtitles ('Official CBSE Step-marking scheme (+4/-1 rules)', 'Board Question Bank (2018-2024)') - B/C curriculum/config descriptions, not student state. OK.
- L569: 'System Status: Cockpit Engine Online | LATENCY: 18ms' (G: fabricated latency telemetry; cosmetic but fake data).

## Next (S2-S3 via zcode_run)
1. ZCode completes the forensic audit of remaining lanes (Learn/Progress, Exam rest, Profile/achievements/onboarding, cross-cutting sweep) using the same classification lens.
2. ZCode implements truthful-state fixes per the rules in the user Phase 1 brief (real data OR truthful empty state; no new parallel state systems; no backend work).
3. ZCode adds focused regression tests; runs dart format, flutter analyze, targeted tests.
4. AutoCoder independently verifies evidence and produces the Phase 1 report.
