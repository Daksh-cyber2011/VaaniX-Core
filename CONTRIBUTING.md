# Contributing to VaaniX

Thank you for your interest in contributing to VaaniX — a Sanskrit-first AI language learning app.

## Getting Started

### Prerequisites
- **Flutter** ≥ 3.3.0 (stable channel)
- **Dart** ≥ 3.3.0
- **Android Studio** / VS Code with Flutter + Dart extensions
- A **Supabase** project (for backend services)

### Setup
```bash
git clone https://github.com/your-org/VaaniX-Core.git
cd VaaniX-Core
flutter pub get
cp .env.example .env   # fill in your Supabase credentials
flutter run
```

## Architecture

VaaniX follows **Clean Architecture** with strict layer dependency rules:

```
lib/
├── app/          → Root widget, bootstrap, router  (may import core, shared, features)
├── core/         → Auth contracts, constants, errors, theme, DI  (may import NOTHING from app/features/shared)
├── features/     → Feature modules (auth, onboarding, learn, etc.)  (may import core, shared)
└── shared/       → Extensions, widgets, utilities  (may import NOTHING from core/features)
```

**Layer rules (enforced in review):**
- `core/` must **never** import from `app/`, `features/`, or `shared/`
- `shared/` must **never** import from `core/`, `features/`, or `app/`
- `features/` may import from `core/` and `shared/` only
- `app/` may import from any layer

## Code Style

| Rule | Standard |
|------|----------|
| Imports | `package:` only — no relative imports |
| State management | Riverpod 2.x (hand-written, no codegen) |
| Naming | Files: `snake_case.dart`. Classes: `PascalCase`. Providers: `camelCaseProvider` |
| Formatting | `dart format lib/ test/` (80-col) |
| Linting | `flutter analyze` — zero warnings before merge |

## Pull Request Process

1. **Fork** the repository and create a feature branch from `main`.
2. **Implement** your change following the architecture rules above.
3. **Test** locally — ensure `flutter analyze` passes with no issues.
4. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat(auth): add phone OTP flow`
   - `fix(router): resolve onboarding redirect loop`
   - `refactor(core): extract interface for storage`
5. **Push** and open a Pull Request against `main`.
6. Ensure CI checks pass. A maintainer will review within 48 hours.

## Reporting Issues

- Use **GitHub Issues** with a clear title and reproduction steps.
- Include Flutter/Dart version, device, and relevant logs.
- Attach screenshots if the issue is visual.

## Feature Requests

- Open a GitHub Issue with the `enhancement` label.
- Describe the user story and expected behavior.
- The maintainers will triage and prioritize.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
