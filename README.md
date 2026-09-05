# VaaniX

A Sanskrit-first AI-powered language learning companion for Indian students, built with Flutter.

VaaniX centers around **Van** — an emotionally intelligent AI duck companion who guides students through gamified Sanskrit lessons, practice quizzes, and progress tracking.

## Architecture

```
lib/
├── app/                    # App composition root
│   ├── app.dart            #   Root MaterialApp.router widget
│   ├── bootstrap/          #   Startup sequence (env, Supabase, prefs)
│   └── router/             #   GoRouter config, guards, splash screen
├── core/                   # Cross-cutting infrastructure (no feature imports)
│   ├── auth/               #   Auth repository contract + session models
│   ├── constants/          #   Route names, app constants
│   ├── environment/        #   Env config (Flavor, Supabase, API URLs)
│   ├── errors/             #   Exceptions → Failures → Either<Failure, T>
│   ├── lifecycle/          #   AppLifecycleState reactive provider
│   ├── logging/            #   Structured AppLogger (debug → prod stub)
│   ├── navigation/         #   Context-free NavigationService
│   ├── network/            #   Dio client + auth/logging/retry interceptors
│   ├── providers/          #   Core Riverpod providers (SharedPreferences, session)
│   ├── storage/            #   ILocalStorageService abstraction + impl
│   ├── supabase/           #   Supabase client providers
│   ├── theme/              #   Light/dark Material 3 themes, ThemeNotifier
│   └── utils/              #   Result type (dartz Either wrapper)
├── features/               # Feature modules (depend on core, never vice versa)
│   ├── auth/               #   Supabase auth implementation
│   ├── onboarding/         #   6-page onboarding flow (name → nest reveal)
│   ├── home/               #   The Nest — Van's learning space
│   ├── learn/              #   Lesson tree (placeholder)
│   ├── exam/               #   Practice quizzes (placeholder)
│   ├── progress/           #   Streaks & analytics (placeholder)
│   ├── settings/           #   Theme, profile, preferences
│   └── van_profile/        #   Van customization (placeholder)
├── shared/                 # Reusable UI components (no feature imports)
│   ├── extensions/         #   StringX, DateTimeX, BuildContextX, IntX
│   └── widgets/            #   VaaniXCard, VanWidget, PrimaryButton, etc.
└── main.dart               # Entry point — zone guard + bootstrap + ProviderScope
```

### Dependency Rule

```
app → core, features, shared
features → core, shared
shared → core (design tokens only: theme colors, text styles, constants)
core → core only (never features, app, or shared)
```

> **Design-token carve-out**: `shared/widgets` may import `core/theme/` and
> `core/constants/` because these are pure data classes (colors, typography,
> string constants) with no business logic or feature coupling. All other
> `core/` packages (providers, storage, network, auth) are off-limits to
> `shared/`.

### State Management

**Riverpod 2.5** (codegen-free, hand-written providers).

| Layer | Pattern | Example |
|---|---|---|
| Infrastructure | `Provider<T>` | `sharedPreferencesProvider`, `supabaseClientProvider` |
| State | `Notifier<T>` | `SessionManager`, `ThemeNotifier` |
| Async stream | `StreamProvider<T>` | `authSessionStreamProvider`, `connectivityStatusProvider` |
| Feature state | `StateNotifier<T>` | `OnboardingNotifier` |

### Error Strategy

```
Data layer throws → ExceptionMapper.toFailure() → domain Failure
Repository returns → Either<Failure, T> (via guardAsync helper)
UI consumes → AsyncValue / fold()
```

### Navigation

**go_router** with `StatefulShellRoute.indexedStack` (5-tab bottom nav). Declarative redirect guards:
1. Onboarding gate → `/onboarding` if not complete
2. Auth gate → `/auth` if Supabase configured and unauthenticated

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.32 (Dart ≥ 3.6). Verified on 3.47.2 stable —
  the app uses `Color.withValues()` and the current `CardThemeData`/
  `DialogThemeData` theme APIs, which older toolchains reject.
- Dart ≥ 3.3.0
- A Supabase project (optional — app runs without backend)

### Setup

```bash
# Clone the repository
git clone https://github.com/Daksh-cyber2011/VaaniX-Core.git
cd VaaniX-Core

# Copy environment template
cp .env.example assets/env/.env
# Edit assets/env/.env with your Supabase credentials (or leave as-is for offline mode)

# Install dependencies
flutter pub get

# Run
flutter run
```

### Without Supabase

The app runs in offline/demo mode when Supabase is not configured. Onboarding, theme, settings, and the Van companion all work without a backend.

## Documentation

Detailed product and design documentation is in `docs/`:

| Folder | Content |
|---|---|
| `docs/Constitution/` | Project constitution and founding principles |
| `docs/VAN/` | Van character bible — visual design, expressions, animations |
| `docs/Market Intelligence/` | Competitor analysis (Duolingo, Babbel, etc.) |
| `docs/Product/` | PRD, AI architecture, database schema, roadmap |
| `docs/Build/` | Flutter, FastAPI, Supabase, deployment, testing guides |

## Coding Conventions

- **Package imports only** — all internal imports use `package:vaanix_app/...`
- **No relative imports** — no `../../` paths
- **Clean Architecture layers** — `core` never imports `features`
- **Failure-first returns** — repositories return `Either<Failure, T>`, never throw
- **Const constructors** — preferred everywhere per analysis_options
- **Single quotes** — for string literals per linter rules

## License

See [LICENSE](LICENSE).
