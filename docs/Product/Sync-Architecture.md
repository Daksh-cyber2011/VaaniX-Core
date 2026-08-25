# VaaniX Sync Architecture (V1)

Status: **LOCAL-FIRST COMPLETE - REMOTE SYNC BLOCKED EXTERNALLY** (no Supabase
project/credentials exist yet). This document is the exact path to enable
remote sync when the user provides a project.

## Principle

VaaniX is offline-first. Every feature works with zero network. Remote sync
is an *additive* layer: local repositories remain the source of truth for
the UI, and sync pushes/pulls snapshots behind the same repository
interfaces. There is deliberately **one** persistence architecture (the
`*Repository` interfaces in each feature's `domain/`), not two.

## What exists

| Layer | File | Notes |
|---|---|---|
| Local storage | `lib/core/storage/local_storage_service.dart` | SharedPreferences wrapper, injected via `sharedPreferencesProvider` |
| Progress | `lib/features/progress/data/local_progress_repository.dart` + `domain/progress_repository.dart` | Completed lessons, quiz attempts, XP - idempotent (XP once, history append) |
| Profile | `lib/features/profile/...` | Name, companion, class, personality, streak |
| AI memory | `lib/features/ai/data/local_conversation_memory.dart` | Conversation history (key-value JSON) |
| Auth | `lib/features/auth/data/{noop,supabase}_auth_repository.dart` + `domain/auth_repository.dart` | noop until Supabase is configured; supabase impl reads the session |
| Supabase infra | `lib/core/supabase/supabase_config.dart` | Client providers only; init gated on `.env` |
| Schema | `docs/Product/Database.md` | profiles, progress, quiz_attempts, ai_conversations |

## How remote is gated

- `lib/core/environment/app_environment.dart` reads `.env` (bundled asset)
  for `SUPABASE_URL` / `SUPABASE_ANON_KEY` (+ `GEMINI_API_KEY`,
  `SENTRY_DSN`). No credentials are compiled into source.
- `bootstrap()` (`lib/app/bootstrap/app_bootstrap.dart`) initializes
  Supabase **only when configured** and never throws otherwise.
- `authRepositoryProvider` returns `NoopAuthRepository` (or
  `SupabaseAuthRepository`) depending on configuration; the rest of the app
  depends only on the interface.

## What remote sync needs (external setup)

1. A Supabase project (URL + anon key) from the user.
2. `.env` with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`,
   `SENTRY_DSN`.
3. Apply the schema in `docs/Product/Database.md` (SQL provided there).
4. Flip `authRepositoryProvider` to the supabase implementation and add a
   `SyncService` that pushes local snapshots (progress, quiz_attempts,
   ai_conversations) after auth and pulls on startup.

## Sync design (when enabled)

- `SyncService` orchestrates: local repository -> outbox -> Supabase table,
  and Supabase table -> local cache on first-launch-after-login.
- Idempotency keys: lesson XP and quiz XP use the same ids locally and
  remotely, so re-sync never double-awards.
- Conflict policy for V1: last-write-wins by updated_at per row.

## What the app does today without sync

Everything: onboarding, learn, practice, exam, progress, AI offline tutor,
VAN, achievements, settings - all persist locally and survive restarts.
The only features that require the external setup are: real cross-device
progress, cloud auth, and the online Gemini tutor.