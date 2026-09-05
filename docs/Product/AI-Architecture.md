# VaaniX AI Architecture

How the AI tutor subsystem is built, as actually implemented in
`lib/features/ai/` (V1, post Phase 4 hardening). For product framing see
`PRD.md`; for the companion persona see `VAN-UX-Spec.md` and
`docs/VAN/`.

## 1. Design goals

1. **Offline-first honesty** — the tutor must always answer usefully with no
   network and no API key, and must say so plainly when a real model would
   be required.
2. **Safety before cleverness** — every reply, online or offline, passes the
   same content-safety filter before it reaches a learner.
3. **Bounded resources** — transcripts, stored conversations, rate limits
   and cache sizes are all capped; nothing grows unbounded on a device.
4. **Swappable models** — the UI talks to a pipeline that talks to an
   adapter interface; Gemini is one implementation, the offline tutor is
   another. Neither leaks into widgets.

## 2. Request lifecycle

```
ChatScreen
  → ChatController (Riverpod)
      → ConversationPipeline (safety → prompt → rate limit → cache → adapter)
          → ModelAdapter (GeminiModelAdapter | OfflineModelAdapter)
      → VanController (aiResponseFinished / error states)
      → LocalConversationMemory (persisted, capped)
      → TokenUsageTracker + ResponseCache
```

A turn flows through five stages, all in `data/`:

| Stage | File | Responsibility |
| --- | --- | --- |
| Safety | `safety_filter.dart` | Rejects unsafe input/output; identical rules for online and offline paths. |
| Prompt | `default_prompt_pipeline.dart` | Stable persona system instruction + per-turn learning context. |
| Rate limit | `ai_rate_limiter.dart` | Per-window request gating before spend occurs. |
| Cache | `response_cache.dart` | Dedupes identical recent requests; bounded. |
| Adapter | `model_adapter.dart` | The transport boundary: `stream()` and `complete()`. |

## 3. Model adapters

- **`OfflineModelAdapter`** wraps `offline_tutor.dart`: intent detection
  (greeting / thanks / identity / practice / translate / grammar / numbers /
  family / correction / encouragement / orientation / unknown), a grounded
  vocabulary dictionary, grammar cards and graded practice questions — all
  derived from lesson content, never invented.
- **`GeminiModelAdapter`** implements the same interface for
  `google_generative_ai`. It is active only when `GEMINI_API_KEY` is present
  (`AppEnvironment`); otherwise the registry falls back to offline. The
  learning-context fragment is composed into the outgoing user turn (not
  the system instruction), so the GenerativeModel client — and its implicit
  prompt caching — stays reusable across turns.

## 4. Streaming and failure semantics

`AiConfig.enableStreaming` (production default on) routes turns through
`pipeline.stream`; `complete()` remains as fallback. Deltas render into the
trailing assistant bubble in place. Finalization is shared by both paths
(Van reading-window lifecycle, achievement check, analytics, persistence).

Failure is honest: a stream that fails, returns empty, or produces an
unsafe assembled reply withdraws the partial bubble so UI and stored
memory agree. No half-replies linger.

## 5. Bounds and hygiene (all pinned by tests)

| Resource | Bound |
| --- | --- |
| In-memory transcript | `AppConstants.maxAiTranscriptMessages` (100, newest kept) |
| Stored conversations | `AppConstants.maxStoredAiConversations` (5, oldest pruned by timestamp) |
| Conversation keys | single prefix constant; `clear()` removes keys instead of writing `'[]'` zombies |
| Rate limiter / cache | bounded by their own config (see `ai_rate_limiter.dart`, `response_cache.dart`) |

`Settings → Reset app data` clears the whole AI subsystem: conversations
(`clearAll`), response cache and token-usage history, then invalidates the
chat controller and usage providers so the UI agrees immediately.

## 6. Personalization

`UserProfile.displayName` (persisted via `learner_name`, editable in
Settings → "Your Name") flows into `LearnerContext` on every turn. The
Gemini persona and the offline tutor's greetings both personalize from it;
`resolvedDisplayName` falls back to a neutral greeting when unset.

## 7. Grounding rules

The tutor teaches the curriculum; it does not improvise facts beyond it.
Offline intents resolve against the lesson-grounded dictionary and cards;
when an input needs real generative power, the tutor explains the offline
boundary instead of guessing. Online, the prompt pipeline instructs the
model to stay inside the Sanskrit-for-beginners scope and to prefer
vocabulary the learner has already met in lessons.

## 8. Testing map

- `chat_streaming_test.dart` — progressive rendering, failure withdrawal,
  Van lifecycle, usage-chip invalidation, display-name stamping.
- `ai_transcript_caps_test.dart` — sliding-window transcript cap, conversation
  pruning, zombie-key removal.
- `gemini_request_shaping_test.dart` — history excludes the outgoing turn,
  learning context framed as message content, stable system instruction.
- `learning_context_test.dart`, `offline tutor suites`,
  `safety filter suites`, `rate limiter suites` — stage-level contracts.
