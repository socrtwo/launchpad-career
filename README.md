# Launchpad Career

Cross-platform career planning and employment guidance for students and recent graduates.

Launchpad Career helps undergraduates, graduate students, recent graduates, and career
changers turn one goal into a realistic plan, in a labour market being reshaped by
automation, thin entry-level hiring, and economic uncertainty.

It is a career-planning and employment-guidance tool. It is **not** a mental-health
service, and it makes no medical, psychological, diagnostic, legal, or
guaranteed-employment claims.

---

## Project status

**Phase 1 (Foundation) — implemented and verified.** The responsive home screen, theming,
routing, accessibility work, and mock data layer are done and tested. Everything past the
home screen is a described placeholder, clearly labelled as such in the interface.

Verified locally against Flutter 3.44.8 / Dart 3.12.2:

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed apps packages` | clean, 42 files |
| `flutter analyze` (all five packages) | no issues |
| `flutter test` (app) | 27 passing |
| `flutter test` (core / domain / data / ui) | 11 / 6 / 5 / 2 passing |
| `flutter build web --release` | builds |

Not yet verified: Android, iOS, Windows, macOS and Linux builds (see
[Known limitations](#known-limitations)).

## Target audience

Undergraduates, graduate students, recent graduates, and career changers — plus the
university career offices and workforce organisations that may put the product in front of
them.

## Screenshots

_Placeholder._ Add `docs/product/screenshots/` images here once the home screen is final:

| Phone | Tablet | Desktop / web |
| --- | --- | --- |
| _pending_ | _pending_ | _pending_ |

## Supported platforms

One Flutter codebase targets:

- Android (and therefore ChromeOS, via the Android runtime)
- iOS
- Windows
- macOS
- Linux
- Web (and therefore ChromeOS, via the browser)

ChromeOS is not a separate Flutter target; it is covered by the Android and web builds.

## Architecture summary

A five-package workspace with path dependencies:

```
launchpad-career/
├── apps/
│   └── launchpad_app/          Flutter application: routing, features, l10n, tests
├── packages/
│   ├── launchpad_core/         Design tokens, themes, breakpoints, a11y helpers
│   ├── launchpad_domain/       Pure Dart: entities + repository interfaces
│   ├── launchpad_data/         In-memory repository implementations (mock data)
│   └── launchpad_ui/           Shared widgets (goal card, grid, tiles)
├── docs/
├── .github/
└── tool/
```

Dependencies point one way: `app → ui → core`, `app → data → domain`. `launchpad_domain`
has no Flutter dependency at all, which is why icons are carried as enum tokens
(`GoalIcon`) and resolved to `IconData` in `launchpad_ui`.

State management is Riverpod; routing is `go_router`, declarative, with deep-linkable
URLs. See [`docs/architecture/architecture-overview.md`](docs/architecture/architecture-overview.md).

**No Melos.** The suggested structure listed `melos.yaml`; five packages with path
dependencies do not need a bootstrap tool. `tool/dev.sh` runs get/format/analyze/test
across all of them in about the same number of keystrokes. Revisit if the package count
grows or packages start being published.

## Prerequisites

- Flutter **3.44.8** stable or newer (Dart ≥ 3.6 — the code uses `Color.withValues`)
- Git
- Per-platform toolchains only for the platforms you actually build:
  Android Studio + JDK 17 (Android), Xcode (iOS/macOS), Visual Studio with the
  "Desktop development with C++" workload (Windows)

## Setup

```bash
git clone https://github.com/<owner>/launchpad-career.git
cd launchpad-career
./tool/dev.sh get
```

Native platform folders are not committed (they are generated, and they are where signing
material tends to leak in). Generate them before your first native build:

```bash
cd apps/launchpad_app
flutter create --org com.launchpadcareer --platforms=android,ios,windows,macos,linux .
```

## Run the app

```bash
cd apps/launchpad_app
flutter run -d chrome      # web
flutter run -d macos       # or windows, linux
flutter run                # attached mobile device or emulator
```

## Run the tests

```bash
./tool/dev.sh test                    # every package
cd apps/launchpad_app && flutter test  # just the app
flutter test integration_test/app_test.dart -d chrome   # integration, needs a device
```

`./tool/dev.sh ci` runs format, analyze, and test exactly as CI does.

## Platform build commands

```bash
cd apps/launchpad_app
flutter build web --release
flutter build apk --debug            # unsigned verification build
flutter build appbundle --release    # requires signing config, not in this repo
flutter build windows --release
flutter build macos --release
flutter build linux --release
flutter build ios --no-codesign
```

## Accessibility commitments

Not aspirations — these are enforced by tests in `test/accessibility_test.dart` and
`packages/launchpad_core/test/contrast_test.dart`:

- Every interactive element is reachable and operable from the keyboard; Enter and Space
  activate cards through `ActivateIntent` rather than hand-rolled key handling.
- Card descriptions are in the semantics tree at all times, whatever the visual state.
  Hover is never the only route to information.
- Selection is announced (`Semantics.selected`, `inMutuallyExclusiveGroup`) and shown with
  an explicit indicator, never by colour alone.
- Text and interactive colours are opaque so contrast is computable, and body and
  secondary text meet WCAG 2.1 AA in both themes.
- Touch targets are at least 48dp; the layout survives a 2× system text scale without
  overflow.
- "Reduce motion" is honoured through `AppMotion`; no essential content is hidden behind
  animation.

Details and known gaps: [`docs/accessibility/accessibility-requirements.md`](docs/accessibility/accessibility-requirements.md).

## Privacy principles

- Anonymous by default. No name, no email, no account to explore.
- Data minimisation: nothing is requested that is not needed for the answer being given.
- Free text stays in memory only; it is never logged and never sent to analytics.
- No third-party analytics, ads, or tracking SDKs in the dependency tree.
- No compliance claims (FERPA, GDPR, COPPA, or any other) until legal and technical review
  is complete. The privacy screen is an explicit placeholder.

Details: [`docs/privacy/privacy-design.md`](docs/privacy/privacy-design.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and
[SECURITY.md](SECURITY.md). Pull requests must keep format, analyze, and tests green, and
must not commit secrets or generated platform folders.

## Roadmap

Six phases, from foundation to production release:
[`docs/product/roadmap.md`](docs/product/roadmap.md). Milestone-sized issues can be opened
in bulk with `tool/create_issues.sh` (requires the `gh` CLI).

## Known limitations

- Only Phase 1 is implemented. Every goal leads to a placeholder page that describes the
  planned flow rather than performing it.
- All content is mock data. There is no backend, no persistence, and no recommendation
  engine; nothing survives an app restart.
- Web, and only web, has been build-verified here. Android, iOS, Windows, macOS and Linux
  builds are wired into CI but have not been run on this machine.
- Localisation is structured but single-locale (`en`). Strings live in
  `lib/src/l10n/app_strings.dart`, not yet in ARB files.
- Icon fonts are bundled, but on the web Flutter's CanvasKit renderer may still fetch
  fallback fonts from Google servers; self-host CanvasKit before any privacy claim is made.
  See the privacy doc.
- No signing, store credentials, or release automation. Deliberately.
