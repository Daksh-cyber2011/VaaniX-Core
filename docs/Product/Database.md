# Database & Persistence

> Status: documents the **current** persistence architecture. Supabase is
> **optional** — the app is offline-first and fully functional with no backend.

## Overview

VaaniX is **offline-first**. Learner state (progress, preferences, profile, AI
conversation history) is persisted on-device via
[`shared_preferences`](https://pub.dev/packages/shared_preferences) through a typed
wrapper. Supabase is an optional sync layer exercised only when a session exists;
`NoopAuthRepository` keeps demo/offline mode fully working with no network and no
credentials.

## Layering

```
UI (Riverpod providers)
   |
   v
Repository contracts (features/*/domain)
   +-- ProgressRepository      -> completed lessons/quizzes, XP, quiz attempts
   +-- UserProfileRepository   -> profile + streak
   +-- AuthRepository          -> NoopAuthRepository | SupabaseAuthRepository
   +-- AchievementRepository   -> achievements
   |
   v
ILocalStorageService  (typed SharedPreferences wrapper)
   |
   v
SharedPreferences  (on-device key/value store)
```

## Local storage schema

Static keys are declared in `lib/core/constants/app_constants.dart`. Two key
families are dynamic (`quiz_attempts_<quizId>`, `ai_conversation_<conversationId>`).

| Key | Type | Purpose |
|---|---|---|
| `onboarding_complete` | bool | onboarding finished |
| `companion_name` | String | Van's name (default `Van`) |
| `personality_mode` | String | `cheerleader` / `calm` / `fun` |
| `selected_class` | int | CBSE class (6-10) |
| `daily_goal_minutes` | int | daily goal (default 10) |
| `current_streak` | int | consecutive-day streak |
| `last_active_date` | String | ISO-8601 last active day |
| `xp_total` | int | total XP |
| `completed_lesson_ids` | List<String> | completed lesson IDs |
| `completed_quiz_ids` | List<String> | quiz IDs attempted >= 1 time |
| `theme_mode` | String | theme preference |
| `app_language` | String | app language |
| `quiz_attempts_<quizId>` | String (JSON) | per-quiz attempt history |
| `ai_conversation_<conversationId>` | String (JSON) | per-conversation AI history |
| *(generic)* | String | response cache + token-usage blobs |

## Domain models & JSON

Defined in `lib/features/progress/domain/progress_models.dart` and
`lib/features/profile/domain/user_profile.dart`:

- **Lesson** — `id, chapterId, title, subtitle, difficulty, xpReward, order, content`
- **Chapter** — `id, title, subtitle, lessons[], order`
- **QuizQuestion** — `id, prompt, options[], correctIndex, explanation`
- **QuizResult** — `quizId, score, total, xpEarned, completedAt` (persisted as a JSON array under `quiz_attempts_<quizId>`)
- **UserProfile** — `id, companionName, personalityMode, cbseClass, dailyGoalMinutes, currentStreak, lastActiveDate, isAnonymous`

Curriculum structure (`Chapter` / `Lesson` / `QuizQuestion`) is loaded from
`assets/curriculum/v1.json` with a hardcoded Dart fallback
(`sanskrit_curriculum.dart`); lesson content strings live in
`sanskrit_lesson_content.dart` (kept in Dart to avoid Devanagari encoding issues).

## Repositories

| Contract | Implementation | Backing |
|---|---|---|
| `ProgressRepository` | `LocalProgressRepository` | `ILocalStorageService` |
| `UserProfileRepository` | `LocalUserProfileRepository` | `ILocalStorageService` |
| `AuthRepository` | `NoopAuthRepository` / `SupabaseAuthRepository` | in-memory / Supabase |
| `AchievementRepository` | `AchievementRepository` | `ILocalStorageService` |

All repositories use the `Result<T>` (`dartz` `Either<Failure, T>`) failure
strategy via `ok` / `err` / `guard` / `guardAsync` in `lib/core/utils/result.dart`.

## Idempotency rules

- **Lesson XP** is awarded once per `lesson.id` (guarded by `completed_lesson_ids`).
- **Quiz XP** is awarded once per `quizId`; repeat attempts append to history but
  return `xpEarned = 0`.
- Corrupt JSON (e.g. malformed attempt history) is treated as empty rather than
  throwing.

## Supabase (optional)

Raw Supabase clients (auth, database, storage) are exposed in
`lib/core/supabase/supabase_config.dart`. The auth feature maps Supabase types
into VaaniX domain types so the rest of the app never depends on Supabase
directly. When `AppEnvironment.isSupabaseConfigured` is false, `NoopAuthRepository`
is selected and the app runs fully offline.

Intended tables (not yet implemented — local-only today), derived from the domain
models above:

- `profiles` — `id`, `companion_name`, `personality_mode`, `cbse_class`, `daily_goal_minutes`, `current_streak`, `last_active_date`
- `progress` — `user_id`, `xp_total`, `completed_lesson_ids`, `completed_quiz_ids`
- `quiz_attempts` — `user_id`, `quiz_id`, `score`, `total`, `xp_earned`, `completed_at`
- `ai_conversations` — `conversation_id`, `user_id`, `messages` (JSON)

> Do not stand up a backend merely because this file exists; Supabase remains
> optional and the local store is the source of truth.