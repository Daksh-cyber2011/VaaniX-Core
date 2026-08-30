# VAN UX Specification

Version: 1.0 (2026-08 design takeover)
Companion docs: `docs/VAN/Master-Van-Bible.md` (character), `docs/Product/Design-System.md` (tokens)

VAN is a first-class UX element, not decoration. He carries the product's
emotional layer: greeting, encouragement, reassurance, celebration. The
learning task always stays in charge - VAN never blocks content, input, or
the primary action.

---

## 1. State model (implemented)

`VanState`: idle, happy, thinking, focus, caring, surprised, sad, funny,
achievement, speaking, error - arbitrated by `VanController` via typed
`VanEvent`s with a priority ladder (idle < task < interaction < feedback <
achievement < critical). Non-interruptible reactions (achievement, critical
error) always run to completion. Features own the copy; the controller owns
timing and arbitration. Stale timers are sequence-guarded.

## 2. Placement rules

| Surface | VAN treatment | Why |
|---|---|---|
| Home (the Nest) | Full VAN 160px + adaptive speech bubble | VAN is the host of the Nest |
| Splash | VAN 120px, happy | brand moment |
| Onboarding (personality, nest reveal, name, subject, goal) | VAN 130-180px with reactive state | VAN is being introduced |
| Lesson content | Mini VAN 34px in the app bar (reacts to lesson lifecycle) | presence without obstruction |
| Exercise / Exam | Mini VAN 34px app bar; state reacts to answers | feedback near the task |
| Exam / practice results | Full VAN 150-160px, achievement or caring | emotional payoff |
| Chat | VAN avatar + typing indicator | he is the interlocutor |
| VAN profile | Full VAN 180px, tappable | personality surface |
| Progress | VAN welcome only for fresh learners | guidance at the empty moment |
| Empty/error states | VAN 120-140px in sad/thinking | warmth in dead ends |
| Inside answer interaction (typing, matching taps) | no VAN | zero obstruction while solving |

## 3. State mapping

| Moment | Event | VAN state | Copy owner |
|---|---|---|---|
| App opened | `appOpened` | idle | Home |
| Lesson started | `lessonStarted` | idle/speaking | Lesson screen |
| Lesson completed | `lessonCompleted` | happy/speaking | Lesson/Exercise |
| Quiz started | `quizStarted` | thinking | Exercise/Exam |
| Answer correct | `quizAnswerCorrect` | happy | Exercise/Exam |
| Answer wrong | `quizAnswerWrong` | caring | Exercise/Exam |
| Session finished | `quizCompleted` / `perfectScore` | achievement | Exercise/Exam |
| Achievement unlocked | `achievementUnlocked` | achievement | Achievement checker |
| Onboarding done | `onboardingCompleted` | happy | Onboarding |
| Recoverable error | `errorOccurred` | error | Caller |
| Companion tapped | `companionTapped` | happy/funny | Van profile |

## 4. Visual system

- Sizes: hero 160-180, mid 120-140, mini 32-44 (`AppDimens.vanSize*`).
- Speech bubble: surface color, 18px radius, bottom tail, max-width clamped
  to screen - 32; thinking state shows an inline spinner instead of text.
- The fallback painter (vector duck with hoodie) is the current artwork; the
  `VanAssetCatalog` + `VanVisualRenderer` swap in approved Lottie/animation
  assets without touching any screen code. `visualBuilder` remains the
  injection point.
- Motion: 3.5s breathing cycle, two gentle blinks; phase-based (screenshot-
  and test-stable); fully static under `MediaQuery.disableAnimations`.

## 5. Accessibility

- VAN carries `Semantics` labels ("Van is ...") and the speech bubble is a
  live region while loading.
- Tap targets around VAN are >= 48dp where tappable.
- Reduced motion collapses all VAN animation to a static pose.

## 6. Rules of thumb

1. One VAN moment per screen; never two competing VANs.
2. VAN reacts; he does not initiate mid-task interruptions.
3. Never place VAN between the learner and the keyboard or the primary CTA.
4. Copy is short, warm, and specific - never generic praise.
5. Failure copy is honest and recoverable ("almost there", "check your
   connection"), never shaming.
