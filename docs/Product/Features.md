# VaaniX Features (V1)

## Onboarding
- Name, CBSE class, goal and Van personality / companion name.
- Persisted into `UserProfile` and used across Home, Learn and AI
  (learner context is passed into every AI prompt).

## Home / Nest (command center)
- Live greeting (time-aware Sanskrit), animated Van, streak + XP + level
  badges, continue-learning card (next unfinished lesson + X/N progress),
  dynamic primary CTA, secondary CTAs for Exam / Progress / Awards,
  chat entry point.

## Learn (READ -> LEARN -> PRACTICE -> FEEDBACK -> MASTER -> COMPLETE)
- 3 chapters, 8 lessons, real Devanagari content with tables and tips.
- Interactive exercise engine per lesson: MCQ / fill-in-the-blank /
  ordering, deterministic shuffles, first-try feedback, retry, per-exercise
  mastery scoring (no double counting), result view with VAN reactions.
- Lesson completion reuses the idempotent XP path (awarded once).

## Exam
- Chapter -> difficulty -> question set -> quiz -> result flow.
- 20 grounded questions (10 beginner / 8 intermediate / 3 advanced),
  tagged from the actual lesson difficulty bands.
- Exam results persist (quiz id + score + attempts) and XP is awarded
  once per quiz id; retry is always allowed.

## AI Tutor
- Conversation pipeline (safety filter -> prompt -> adapter -> cache ->
  rate limit -> usage tracking) with a Gemini adapter boundary and a
  grounded offline tutor (intents: greeting, translate, meaning, numbers,
  greetings, family, grammar, practice with grading, correction boundary,
  encouragement, orientation).
- Offline mode is honest about being offline.

## Progress / Gamification
- XP (idempotent), level curve (pure, tested), streak, completed lessons,
  completed exams, quiz attempt history, progress by chapter.

## VAN
- Companion reactivity across app events (open, learn start, correct /
  wrong answers, completion, exam events, achievements), priority-aware
  state machine, accessible fallback renderer (no final art assets yet).

## Settings / Auth
- Dark mode aware, settings screen for personality / account; auth
  repositories (noop + Supabase) behind one interface.