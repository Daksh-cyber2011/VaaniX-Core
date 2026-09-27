# Pronunciation audio assets

This directory holds **bundled pronunciation clips** consumed by
`AudioSource.asset(...)`.

## Status: EMPTY — no audio is bundled yet

VaaniX currently ships **no audio files**. This is deliberate.

The `AudioCadenceWaveform` widget previously ran a looping
`AnimationController` with no audio attached: the play button toggled a
boolean and the bars swung back and forth, so the app *appeared* to play
pronunciation audio that did not exist. That fake engine has been removed
(see `lib/shared/widgets/audio_cadence_waveform.dart`).

Now the widget drives the real `AudioService`. When a Learn item has no
`AudioSource`, the play button does **not** animate and does **not** report
"playing" — it leaves the player idle and logs a warning. A learner is
never shown playback for a clip that does not exist.

## Adding real recordings

1. Drop files here using the naming convention
   `<languageCode>_<conceptId>.mp3`, e.g.:

   ```text
   assets/audio/pronunciation/hi_hi_greet_namaste.mp3
   assets/audio/pronunciation/sa_sa_script_vowels.mp3
   ```

2. Assets are already declared in `pubspec.yaml` under
   `assets/audio/`, so no manifest change is needed.

3. Point the Learn consumer at the file:

   ```dart
   AudioCadenceWaveform(
     phrase: 'नमस्ते',
     transliteration: 'Namaste',
     source: AudioSource.asset(
       'assets/audio/pronunciation/hi_hi_greet_namaste.mp3',
     ),
   )
   ```

   For a language/lesson with no recording, simply omit `source`. The
   widget degrades honestly.

## Requirements for a good clip

| Property | Recommendation |
|---|---|
| Format | MP3 (AAC/OGG also work) |
| Sample rate | 44.1 kHz or 48 kHz |
| Channels | Mono is sufficient and halves the size |
| Length | Under ~5 s — these are single words/short phrases |
| Loudness | Normalised to roughly −16 LUFS; peaks below −1 dBFS |

Because these are bundled assets, anything here plays **offline with no
network**. That is the only source type in VaaniX that can.

## Remote audio

For backend- or CDN-hosted audio, use
`AudioSource.remote(url)` instead. Remote sources require connectivity and
are **not** offline-capable — `AudioSourceResolver` refuses to promise
playability while offline, and `just_audio`'s own HTTP cache may or may not
have the bytes. Do not label remote audio as offline-available unless it
has actually been downloaded. See `docs/BUILD/Audio.md` §Caching.
