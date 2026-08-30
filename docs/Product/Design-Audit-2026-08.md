# VaaniX Design Audit - August 2026

Status: Complete takeover pass over the existing Flutter app
Scope: every user-facing surface in `lib/`
Constraint honored: curriculum content frozen (`sanskrit_curriculum.dart`, `sanskrit_exercises.dart`, `assets/curriculum/v1.json` untouched)

---

## 1. What was wrong before the takeover

### P0 - Broken or blocking
| Finding | Where | Fixed |
|---|---|---|
| Short lessons could never be completed: the scroll-gate only flipped on scroll events, so content that fits on one screen kept "Mark Complete" disabled forever | `lesson_content_screen.dart` | Post-frame check unlocks completion when `maxScrollExtent <= 0`; "Read More" now animates to the bottom instead of being dead |
| Genuine mojibake in user-facing strings (splash brand glyph, chat empty-state, onboarding copy) - CP1252-decoded emoji rendered as garbage | splash, chat, onboarding, van profile | All replaced with clean copy or VAN artwork |
| Dead "Read More" button (disabled with no way to proceed) | `lesson_content_screen.dart` | Now scrolls to bottom, then becomes "Mark Complete" |
| `_markComplete` had no failure path - an exception left the spinner stuck forever | `lesson_content_screen.dart` | try/catch/finally + honest error snackbar |

### P1 - Major consistency / dark-mode defects
- Static light-only tokens (`subtextLight`, `borderLight`) used regardless of theme across Home, Learn, Lesson reader, Exercise, Exam, Progress, Settings, VAN profile, achievements - washed-out or invisible in dark mode. All converted to theme-aware tokens.
- `Colors.grey` / `Colors.white` hardcodes in route error states, exercise tiles, exam tiles, disabled chips.
- Exercise progress bar showed `(currentIndex)/total`: 0% on the first question and never 100% before finishing. Now `(currentIndex+1)/total`.
- Raw error dumps (`Error: $error`) shown to learners in Learn.
- Emoji used as UI icons: stat cards on Progress (`⭐🔥📚🏆`), personality cards, streak/XP badges (corrupted glyphs), Nest decorations. All replaced with Material icons in tinted containers.
- Router error/not-found states were raw Center+OutlinedButton screens. Replaced with branded `ErrorStateWidget` / `EmptyStateWidget` and a proper loading state.
- PrimaryButton's loading spinner was near-invisible on outlined/text variants; now variant-aware.
- Exam/Exercise result buttons, dialog confirm colors, and bottom-sheet handles ignored dark mode.

### P2 - Polish and hierarchy
- Home: duplicate "Go" affordance on the continue card (the primary CTA did the same thing); dead avatar; no offline awareness; greeting competed with the VAN bubble. Restructured: Sanskrit greeting as eyebrow, VAN + adaptive bubble as the hero, continue card as the single tap target with a real progress meter, avatar routes to Settings, offline banner wired to `isOnlineProvider`.
- Progress dumped stats before telling the learner what to do. Reordered: NEXT FOCUS first, then stats, meters, weak areas, chapters.
- Achievements had no ordering logic; now unlocked-first, then closest-to-unlock, with first-run copy.
- Settings theme control was a cramped icon-only SegmentedButton beside text; now a full-width labeled control. Reset and Sign Out keep their semantics and got honest post-reset feedback.
- Onboarding nest reveal used emoji decorations; replaced with floating Material icons in warm tinted dots, theme-aware nest surface.
- Splash showed a yellow circle with a corrupted glyph; now VAN himself carries the brand moment (still replaceable through the asset catalog).

---

## 2. Screen-by-screen status after the takeover

| Surface | Status | Notes |
|---|---|---|
| Splash | Polished | VAN brand moment, elastic-in, routing untouched |
| Onboarding (6 pages) | Polished | progress dots, personality cards w/ icons, subject grid, nest reveal, honest failure snackbars |
| Home (Nest) | Redesigned | adaptive hero, meter, offline banner, avatar->settings |
| Learn | Polished | theme-aware, friendly errors, capitalized difficulty, chapter meters |
| Lesson content | Polished | P0 scroll-gate fixed, Read More works, selectable text, theme-aware tables/quotes |
| Lesson content view | Polished | removed nested scroll view (perf), SelectableText, dark-aware |
| Exercises (all 5 types) | Polished | consistent option language, feedback cards, safe submit guards (pre-existing logic kept), progress reaches 100%, dark-aware |
| Exercise feedback | Polished | semantic success/error containers, explanations preserved |
| Exam setup | Polished | selected states, disabled levels, count chips |
| Exam questions | Polished | same option language as practice; exam keeps its own intro/save flow |
| Exam results | Polished | score/best/attempts summary, save semantics untouched |
| Progress | Reordered | NEXT FOCUS first, icon stat tiles, meters, chapter cards tappable, fresh-learner VAN welcome preserved (test-locked) |
| Weak areas | Polished | real mastery counts, theme-aware |
| Achievements | Polished | ordering (unlocked first, then closest), theme-aware, first-run copy |
| AI chat | Polished | clean empty state, honest error banner (pre-existing), usage chip, typing indicator with VAN |
| VAN profile | Polished | Material icons for personality modes, clean dialogue |
| Settings | Polished | full-width theme control, honest reset feedback, dark-aware |
| Reset flows | Kept | semantics preserved exactly; confirmation dialogs use semantic danger color |
| Loading states | Systematized | branded indicator theme-wide; route loading states use it |
| Empty states | Systematized | `EmptyStateWidget` with icon + copy + action |
| Error states | Systematized | `ErrorStateWidget` with retry; friendly copy, no raw dumps |
| Offline states | Added | `OfflineBanner` on Home driven by `isOnlineProvider` |
| Not-found states | Systematized | branded empty states for lesson-not-found routes |

---

## 3. Verification evidence

- `flutter analyze`: 0 errors, 0 warnings (remaining ~241 infos are pre-existing lint infos: dangling library doc comments, prefer_const in old tests).
- `flutter test`: 251/251 passing after the takeover batch (re-verified after each regression fix; the two test updates made were: exercise renderer tests now assert the de-emoji feedback copy "Correct!").
- Curriculum freeze: no commits or edits touch `assets/curriculum/v1.json`, `sanskrit_curriculum.dart`, `sanskrit_exercises.dart`, `unit2_lesson_content.dart`.

---

## 4. Remaining gaps (honest)

1. Final VAN artwork is still pending upstream; the fallback painter + asset catalog path remains the replaceable source of truth.
2. Exercise "ordering" is tap-to-append (no drag-to-reorder). Acceptable for the current exercise sizes; a drag layer would be the next iteration.
3. The exam flow has no mid-exam review screen (answer grid); current flow is linear with immediate feedback. Changing that would alter assessment semantics - needs a product decision.
4. Landscape/tablet layouts inherit Flutter's default adaptive behavior; no dedicated tablet composition exists yet.
5. A handful of pre-existing analyzer infos (dangling doc comments) remain in old files - cosmetic, zero user impact.
