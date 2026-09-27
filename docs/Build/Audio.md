# VaaniX — Audio Infrastructure

Real playback infrastructure for VaaniX, plus an honest account of what
does and does not exist yet.

---

## 1. What this replaced

`AudioCadenceWaveform` used to run a looping `AnimationController`:

```dart
void _togglePlay() {
  setState(() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _waveController.repeat(reverse: true);   // ← no audio anywhere
    }
  });
}
```

The play button toggled a boolean and the bars swung on a sine wave. No
sound was produced. The duration label was the hardcoded string `'0:03'`.
This was the same class of fabrication previously removed from the profile
tray's "552 MB cached" readout (see the honesty guards in
`profile_tray_screen.dart`), where a button reported success for work it
never did.

That engine is **deleted**. The widget now drives a real `AudioService`,
and when no audio exists it stays idle and says so.

---

## 2. Architecture

```text
Learn / Practice / any consumer
            │
            ▼
    AudioService              (abstract interface, core/audio/audio_service.dart)
            │
            ▼
    JustAudioEngine           (core/audio/just_audio_engine.dart)
            │                  ← the ONLY file importing just_audio
            ▼
    just_audio 0.10.6         → device audio output
```

| File | Role |
|---|---|
| `core/audio/audio_models.dart` | `AudioSource`, `AudioPlaybackState`, `AudioPlayRequest`. Pure Dart. |
| `core/audio/audio_service.dart` | The `AudioService` contract. No engine types leak through it. |
| `core/audio/just_audio_engine.dart` | Real engine. Owns one `AudioPlayer` forever. |
| `core/audio/audio_source_resolver.dart` | Validates/normalises a source *before* the engine sees it. |
| `core/audio/audio_providers.dart` | Riverpod wiring. The single place the engine is chosen. |
| `core/audio/vaanix_audio_event.dart` | Pre-existing event taxonomy (unchanged). |
| `shared/widgets/audio_cadence_waveform.dart` | UI. Consumes `AudioService` only. |

`ui` and `learn` have **no** import of `just_audio`. Swapping the engine
changes exactly one file.

### Why one player, forever

`JustAudioEngine` creates a single `ja.AudioPlayer` in its constructor and
reuses it with `setAudioSource` for every clip. It never constructs a
second player. That makes the "tap A, then B, then A quickly" race
structurally impossible to get wrong: there is no second thing that could
keep playing.

### Why a command queue

`play` / `pause` / `resume` / `stop` / `seek` / `setSpeed` all run through
an internal `_CommandQueue`. Learners tap fast and the engine is
frequently mid-load; without serialisation, a `stop()` could land between a
`setAudioSource` and its `play()`, leaving a silent loaded clip.
`_CommandQueue` makes every operation deterministic, and a failing
command is logged rather than allowed to strand the queue.

A `_loadGeneration` counter additionally invalidates a late-arriving load
whose completion is older than the current request.

---

## 3. Package selection

**`just_audio: ^0.10.6`** — playback only.

Chosen because it is actively maintained, and specifically because it:

* loads bundled assets **and** remote HTTPS from one API;
* exposes real `positionStream`, `durationStream`, `playerStateStream`;
* supports `pause` / `resume` / `seek` / `setSpeed`;
* handles Android audio focus and iOS `AVAudioSession` interruptions
  without extra code from us;
* is playback-only, so it requests **no** microphone permission.

`audioplayers` was rejected (weaker interruption handling, thinner state
model). A TTS package was rejected because VaaniX has no TTS use case yet —
see §8.

### Dependency discipline

One audio package, added declaratively. No Flutter SDK constraint change
(`sdk: ">=3.6.0 <4.0.0"` untouched), no unrelated package upgrades. The
transitive additions are `audio_session`, `just_audio_platform_interface`,
`just_audio_web`, and `synchronized`.

---

## 4. Sources

```dart
AudioSource.asset('assets/audio/pronunciation/hi_namaste.mp3')  // offline-capable
AudioSource.remote('https://cdn.vaanix.app/a.mp3')              // needs network
AudioSource.tts('namaste')                                     // unavailable today
```

`AudioSourceResolver` is a separate, engine-free step that answers "can
this play?" before anything is loaded:

* asset paths must live under `assets/`;
* remote URLs must be `http`/`https` with a host;
* remote sources are **refused while offline** — the app never promises
  offline playback it cannot deliver;
* `localhost` / `127.0.0.1` / `0.0.2.2` are blocked, so a server-supplied
  URL cannot probe the learner's LAN;
* TTS resolves to `AudioSourceUnavailable` rather than silently no-oping.

The resolver takes an optional connectivity probe and is wired to the
app's real `ConnectivityService` in `audio_providers.dart`.

---

## 5. Playback state

`AudioPlaybackStatus`: `idle`, `loading`, `playing`, `paused`,
`completed`, `error`.

`AudioPlaybackState` carries status, **real** position, real duration, the
source, and a typed failure. `progress` returns `null` when the duration is
unknown — never a fabricated ratio — and clamps to `0..1` otherwise.

Failures use the project's canonical hierarchy, added in
`core/errors/failures.dart`:

| Failure | Code | Meaning |
|---|---|---|
| `AudioSourceFailure` | `AUDIO_SOURCE` | Malformed or unsupported source. |
| `AudioNetworkFailure` | `AUDIO_NETWORK` | Could not be fetched. |
| `AudioOfflineFailure` | `AUDIO_OFFLINE` | Not cached, device offline. |
| `AudioPlaybackFailure` | `AUDIO_PLAYBACK` | Decoded bytes would not play. |
| `AudioUnavailableFailure` | `AUDIO_UNAVAILABLE` | No output route / missing bundle. |

### A note on engine error codes

`ja.PlayerException.code` is a **platform-native int** — `NSError.code` on
iOS, `ExoPlaybackException.type` on Android, `MediaError.code` on web.
There is no cross-platform enum. An earlier draft compared it against
strings like `'network'`, which silently never matched and collapsed every
failure into one bucket. `JustAudioEngine.mapPlayerException` now
classifies from the portable **message** plus the source kind, and treats
the int as an opaque value that is logged but never branched on. The method
is `@visibleForTesting` so the taxonomy can be asserted directly.

---

## 6. Lifecycle

| Situation | Behaviour |
|---|---|
| Widget disposed mid-playback | Audio **continues**. The engine is container-owned, not widget-owned — navigating away should not cut a word short. Call `stop()` explicitly to end it. |
| New clip requested | Replaces the current one on the same player. |
| Same clip re-requested while playing | Idempotent no-op (does not restart from zero). |
| Same clip after `completed` | Restarts from `Duration.zero`. |
| `pause` when not playing | No-op. |
| `seek` with nothing loaded | No-op. |
| `seek` beyond bounds | Clamped to `0..duration`. |
| Any call after `dispose()` | Resolves safely, performs no work. |
| Events after `dispose()` | Never emitted; the stream is closed. |
| Speed | Clamped to `0.5..2.0`, persists across clips. |

### Per-source ownership in the UI

Because the engine is shared, two mounted waveforms would both have shown
a pause glyph while one clip played — and tapping the second's "play"
would have *paused the first*. Each waveform now only reflects state when
`state.source` matches **its own** source, so a player that owns the
clip shows pause and every other shows play. This was caught by a test,
not by inspection.

---

## 7. Offline behaviour

* **Bundled assets** always play offline. They are the only
  offline-capable source (`AudioSource.isOfflineCapable`).
* **Remote audio** requires connectivity. `AudioSourceResolver` returns an
  explicit unavailable result when offline, so the UI can say "needs a
  connection" rather than failing opaquely later.
* **Nothing pretends.** A failed load surfaces as
  `AudioPlaybackStatus.error` with a typed failure. The play button never
  flips to pause on a failed load, and `onPlayStateChanged` is not fired
  with `true`.
* **No audio → no motion.** With `source: null` the widget logs a warning
  and leaves the player idle. `pumpAndSettle` completing is itself
  asserted as proof that nothing loops.

---

## 8. Caching

**Not implemented, deliberately.** VaaniX has a `LocalStorageService`
cache for preferences, but no bounded blob store for media, and retrofitting
one here would mean inventing disk-space policy, eviction, corruption
handling, and download-progress plumbing — well beyond audio
infrastructure.

What exists instead:

* `AudioSource.deterministicKey` — a stable cache key per source, ready
  for a real cache to key on. Tests pin its determinism.
* `just_audio` manages its own HTTP caching. That is **not** a guarantee of
  offline availability, and VaaniX does not claim it is.

If remote caching is added later, the constraint to respect: remote audio
must not be presented as offline-capable unless the bytes are actually on
disk.

---

## 9. Platform configuration

**No manifest or plist changes were needed.**

* `just_audio`'s own `AndroidManifest.xml` declares zero permissions.
* `android/app/src/main/AndroidManifest.xml` already has
  `INTERNET` (required for remote audio only).
* App `minSdk = 24`, comfortably above the plugin's floor.
* Playback-only means **no** microphone permission is requested anywhere,
  on either platform.
* iOS needs no `Info.plist` entry for playback.

### Audio focus / interruption

Delegated to `just_audio`, which configures `AVAudioSession` on iOS and
ExoPlayer audio attributes on Android. VaaniX adds no custom focus logic.

---

## 10. Security

* No API keys, auth tokens, or Supabase credentials appear anywhere in
  `core/audio/`.
* **Remote URLs are logged host + path only**, with the query string
  replaced by `<query stripped>`. A signed-URL backend puts its credential
  in the query; logging the raw URI would write it to Sentry.
* LAN addresses are refused by the resolver, so a server-supplied URL
  cannot reach the learner's private network.
* No per-position or per-frame logging — only play started, completed,
  failed, and the source label.

If authenticated audio is added later, credentials should be injected by
the existing authenticated networking layer
(`core/api/vaanix_api_client.dart`), never embedded in an
`AudioSource`.

---

## 11. Learn integration

Two consumers, both already using `AudioCadenceWaveform`:

| Screen | Role |
|---|---|
| `features/learn/presentation/screens/learn_home_screen.dart` | Pronunciation Lab card |
| `features/practice/presentation/screens/interactive_drill_screen.dart` | Applied-drill cadence player |

**Neither passes a `source`.** VaaniX bundles no recordings
(`assets/audio/pronunciation/` contains only a README), so both drive a
real player with nothing to play — which renders as an honest idle player
rather than an animated lie.

No Learn architecture was touched. Course generation, the diagnostic, the
mastery engine, the adaptive planner, the session engine, and the concept
graph are all unchanged.

### Adding real recordings

1. Drop `<langCode>_<conceptId>.mp3` into `assets/audio/pronunciation/`.
   The directory is already declared in `pubspec.yaml`.
2. Pass it:
   ```dart
   const AudioCadenceWaveform(
     phrase: 'नमस्ते',
     source: AudioSource.asset('assets/audio/pronunciation/hi_hi_greet_namaste.mp3'),
   )
   ```

---

## 12. Tests

| Suite | Count | Covers |
|---|---|---|
| `test/core/audio/audio_source_resolver_test.dart` | 25 | source validation, offline honesty, LAN blocking, TTS-unavailable, state model maths, failure codes |
| `test/core/audio/audio_cadence_waveform_test.dart` | 17 | play/pause/resume, real progress, honest empty-audio, speed, failure recovery, concurrency, shared-engine ownership |
| `test/support/fake_audio_service.dart` | — | deterministic `AudioService` double (injected time, no wall clock) |

The fake models the real lifecycle rather than recording calls: it loads,
becomes playing, advances only when playing, clamps seeks, and emits
typed failures. That way a broken state machine cannot pass.

**The `JustAudioEngine` itself is not unit-tested** — it needs a platform
channel. Its error-classification table is `@visibleForTesting` and can be
asserted directly; the rest is covered on-device.

---

## 13. Known limitations

1. **No bundled audio.** The infrastructure is real; the content is not
   there. See §11.
2. **No TTS.** `AudioSource.tts` resolves to unavailable. Declared because
   `VaanixAudioEvent` already models the `guideTts` policy, so a future TTS
   engine slots in without changing the vocabulary. No speech recognition
   was added — that is a separate product decision.
3. **`JustAudioEngine` is not unit-tested** (platform channel). Verified by
   `flutter analyze` and by the interface-level tests, not at runtime.
4. **No audio caching layer** — see §8.
5. **Diagnostic still refuses to score listening.** `diagnostic_engine.dart`
   deliberately does not emit a LISTENING dimension because no audio
   exists. That remains correct and was intentionally left alone: audio
   infrastructure is not the same thing as an assessment, and claiming a
   listening score without a validated probe would repeat the exact
   fabrication this task removed.
6. **`AudioDuckingPolicy` is carried but not yet applied** to a platform
   audio session; the requests pass it, and the engine currently does not
   act on it beyond normal engine focus handling.
