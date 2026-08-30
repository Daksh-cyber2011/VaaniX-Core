# VaaniX Design System

Version: 2.0
Status: Implemented (additive takeover, 2026-08)
Source of truth: this document + `lib/core/theme/` + `lib/shared/widgets/`

VaaniX is a **premium AI learning companion** for Indian students, built around
**VAN**, an emotionally intelligent duck companion. The visual language is
**warm-scholarly**: an indigo scholarly core, VAN's warm yellow/orange for
emotion and reward, on a warm paper surface. Never generic school-app, never
cheap Duolingo clone, never childish.

---

## 1. Design Principles

1. **Clarity first** - the learner always knows where they are and what to do next.
2. **Momentum** - the next action is the most visible element on every screen.
3. **Low cognitive load** - one primary action per view; everything else recedes.
4. **Emotion through VAN, not noise** - VAN carries warmth; surfaces stay calm.
5. **Premium restraint** - no gradients-everywhere, no rainbow chips, no glow.
6. **One system** - spacing, radii, type and components come from tokens only.

---

## 2. Color Tokens (`lib/core/theme/app_colors.dart`)

### 2.1 Constitutional brand colors (never change)

| Token | Value | Use |
|---|---|---|
| `vanYellow` | `#F4C74A` | VAN's body; highlight accent, CTAs |
| `vanOrange` | `#F07A33` | VAN's beak/feet; warm badges, streaks |

### 2.2 Core palette

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#3B4CCA` | `#6B7CF7` | Brand actions, links, focus |
| `primaryContainer` | `#EAEDFB` | `#2B3266` | Selected states, soft fills |
| `success` | `#4CAF7D` | same | Correct answers, mastery |
| `successContainer` | `#E3F3EA` | `#1E3B2D` | Correct-answer fills |
| `error` | `#E53935` | `#FF6B6B` | Incorrect answers, destructive |
| `errorContainer` | `#FCE7E6` | `#43201F` | Incorrect-answer fills |
| `warning` | `#FFA726` | `#FFB74D` | Offline, streak risk, retake |
| `warningContainer` | `#FFF3E0` | `#41331C` | Offline banner, hints |
| `info` | `#4A90D9` | same | AI explanations, tips |
| `infoContainer` | `#E7F1FB` | `#1C3248` | Tip cards |
| `xp` | `#FFD700` | `#FFD65C` | XP, achievements |
| `streak` | `#FF6B35` | `#FF8C52` | Streaks, fire moments |

### 2.3 Surfaces

| Token | Light | Dark |
|---|---|---|
| `background` | `#FAF8F4` | `#121218` |
| `surface` | `#FFFFFF` | `#1E1E28` |
| `surfaceVariant` | `#F0EDE6` | `#2A2A36` |
| `onBackground` | `#1C1C2E` | `#F0EDE6` |
| `subtext` | `#6B6B80` | `#9090A0` |
| `border` | `#E0DDD6` | `#2E2E3C` |
| `nestWarm` | `#FFF8E7` | `#1C1812` |

**Rules**
- Never use `Colors.grey`/`Colors.white`/`Colors.black` directly; use tokens.
- Text colors must come from the theme (`colorScheme.onSurface`, `subtext`).
- Semantic fills use the `*Container` tokens, never raw semantic colors at full strength.

---

## 3. Typography (`lib/core/theme/app_text_styles.dart`)

Font: **Nunito** (Google Fonts) - rounded, warm, highly legible; matches VAN.

| Role | Style | Size/Weight |
|---|---|---|
| Hero / celebration | `displaySmall` | 36 / w700 |
| Screen titles | `headlineSmall` | 24 / w600 |
| Card titles | `titleMedium` | 16 / w700 |
| Section headers | `titleLarge` | 22 / w700 |
| Body / lesson text | `bodyLarge` | 16 / w500, h1.5 |
| Secondary body | `bodyMedium` | 14 / w500 |
| Captions / meta | `bodySmall` | 12 / w400 |
| Buttons | `labelLarge` | 14 / w700 |
| Badges / nav | `labelMedium`/`labelSmall` | 12/11 / w700-w600 |
| Sanskrit content | `sanskritBody`/`sanskritLarge` | 18-24 / w600-w700 |
| VAN dialogue | `vanDialogue` | 15 / w600 |

**Rules**
- Always access via `AppTextStyles.*` or `theme.textTheme`; never raw `TextStyle`.
- Never use `Colors.grey` for de-emphasis; use `onSurface.withValues(alpha: 0.6)` or `subtext`.

---

## 4. Spacing, Radii & Touch (`lib/core/theme/app_dimens.dart`)

- **Spacing (4pt grid):** `space1` 4 / `space2` 8 / `space3` 12 / `space4` 16 / `space5` 20 / `space6` 24 / `space7` 32 / `space8` 40 / `space9` 48.
- **Radii:** `radiusSm` 10 (chips) / `radiusMd` 14 (inputs, secondary buttons) / `radiusLg` 20 (cards, dialogs) / `radiusXl` 28 (hero cards, sheets) / `radiusPill` 999 (badges).
- **Touch floor:** every interactive element is at least 48dp (`minTouchTarget`); primary CTAs are 56dp.
- **VAN sizes:** hero 160 (Home/Nest), bubble 64 (onboarding/chat moments), strip 44 (`VanSpeechStrip`).
- **Motion:** `AppMotion.fast` 150ms (feedback) / `base` 250ms (transitions) / `slow` 400ms (hero, meters) / `celebrate` 600ms; curves `emphasized` (easeOutCubic) and `playful` (easeOutBack, celebration only). Always honor reduced-motion.

---

## 5. Elevation (`lib/core/theme/app_shadows.dart`)

Shadows are **tinted with the primary hue, never pure black**, and the dark
theme deepens shadows instead of brightening borders.

| Level | Use |
|---|---|
| `forCard` | Resting cards, badges |
| `resolve` | Raised/interactive (continue card, selected tiles) |
| `forFloating` | Dialogs, VAN speech bubble, overlays |

---

## 6. Component Inventory (`lib/shared/widgets/`)

### 6.1 Core primitives
| Component | Notes |
|---|---|
| `PrimaryButton` (`.secondary()`, `.text()`) | 56dp filled / outlined / text; variant-aware loading spinner |
| `VaaniXCard` | Surface + border card, optional tap |
| `VaaniXTextField` | Input with label, validation, password toggle |
| `VaaniXDialog` | Branded confirm dialog; `isDangerous` uses semantic error |
| `VaaniXBottomSheet` | Rounded sheet, drag handle, SafeArea |
| `VaaniXScaffold` | Screen shell: padding, app bar, optional pull-to-refresh |

### 6.2 Status & feedback
| Component | Notes |
|---|---|
| `VaaniXLoadingIndicator` / `VaaniXLoadingOverlay` | Theme-aware spinner + message |
| `ErrorStateWidget` | Icon + title + message + retry; theme-aware |
| `EmptyStateWidget` | Icon + title + description + optional action |
| `OfflineBanner` | Calm offline strip driven by `isOnlineProvider` |

### 6.3 Progress & data
| Component | Notes |
|---|---|
| `ProgressMeter` | Rounded animated progress bar; requires semantic label |
| `StatTile` | Icon + value + label stat, tinted accent |
| `SectionHeader` | Section title + optional "See all" action |

### 6.4 VAN system
| Component | Notes |
|---|---|
| `VanWidget` | Full companion; 11 states, speech bubble, replaceable asset renderer |
| `VanSpeechStrip` | Compact VAN line (44dp) + speech container for task screens |

---

## 7. VAN Integration Pattern

- VAN is a **first-class UX element but never a blocker**: he appears where emotion or guidance helps, and stays out of focused task surfaces.
- **Full VAN** (160): Home (the Nest), onboarding reveal, achievements celebration.
- **Strip VAN** (44): lesson intros, exam preparation/results, error and offline reassurance, empty states that need warmth.
- **No VAN**: inside exercise answer interaction, during typing/translation input, settings rows.
- VAN reacts through `vanControllerProvider.dispatch(VanEvent(...))`; features own the copy, the state machine owns arbitration and timing.

---

## 8. Accessibility Floor

- Contrast: body text >= 4.5:1, large text >= 3:1 in both themes.
- Touch targets >= 48dp; icon buttons expose tooltips (`tooltip:`) and semantics.
- All progress meters carry `semanticLabel`; badges expose readable labels.
- Reduced motion collapses VAN animation and meter animations to static poses.
- Incomplete answers can never auto-submit; destructive actions always confirm.

---

## 9. Dark Mode Rules

- Every surface chooses tokens by brightness; no hardcoded light-only colors.
- The dark theme keeps the warm character (`#121218`, warm surface `#1E1E28`), never pure black.
- Accents that lose punch on dark (`xp`, `streak`, `warning`) use the dark-tuned variants listed in §2.2.
