# CLAUDE.md

Guidance for AI-assisted work in this repository. The full rationale lives in `docs/`;
this file is the summary you follow by default. When in doubt, the docs win — read them.

## What this project is

A career-planning and employment-guidance tool for undergraduates, graduate students,
recent graduates, and career changers. It is **not** a mental-health service, diagnostic
tool, job board, or promise of employment. Phase 1 (foundation, mock data) is complete;
everything else is planned, not built, and the interface must say so honestly
(`docs/product/roadmap.md`, `docs/product/product-principles.md`).

## Architecture rules (`docs/architecture/architecture-overview.md`)

Five path-linked packages with one-way dependencies:

- `packages/launchpad_domain` — pure Dart entities (`Goal`, `Session`, `Evidence`) and
  repository interfaces. **No Flutter, no I/O, no JSON.** If a design decision reaches
  into this package, it is in the wrong place (e.g. `Goal` carries a `GoalIcon` enum,
  never `IconData`).
- `packages/launchpad_data` — repository implementations. Currently in-memory; networked
  implementations go **beside** these, not in place of them.
- `packages/launchpad_core` — design tokens, themes, breakpoints, accessibility helpers.
  Depends on Flutter, knows nothing about careers.
- `packages/launchpad_ui` — shared widgets. Knows domain entities, not routing or state.
- `apps/launchpad_app` — feature folders, routing, l10n, providers, tests.

Other standing rules:

- **Feature-first layout**: new modules are new folders under `lib/src/features/`.
  Cross-feature widgets graduate to `launchpad_ui`; cross-feature types to
  `launchpad_domain`.
- **State management is Riverpod with exactly three patterns** — `Provider` for wiring,
  `FutureProvider` for repository reads, `Notifier` for user-changeable UI state. Do not
  introduce a fourth.
- **Routing is `go_router`, declarative.** Goals are addressed by **slug**, never by enum
  index; `GoalId.fromSlug` is the only way in. The goal page reads its goal from the URL,
  not from selection state, so refreshed/shared links work.
- **Responsive layout**: column count comes from window width via `Breakpoints`
  (compact/medium/expanded → 1/2/3 columns), not from the grid's own constraints. Use
  `Wrap` with computed item widths, not `GridView` with `childAspectRatio` (aspect-ratio
  grids overflow at large text sizes).
- **No Melos.** `./tool/dev.sh` handles get/format/analyze/test across packages.

## Tone and language rules (`docs/product/tone-and-language.md`)

Write like a good adviser: plain, specific, on the reader's side. Never patronising,
clinical, bureaucratic, trendy, or academic.

1. Active voice, second person.
2. A control says what it does ("Continue", not "Submit").
3. Sentence case everywhere — headings, buttons, labels.
4. Never label the person ("confused students", "if you're feeling lost"). Describe the
   situation, not the reader. Uncertainty is a situation, not a diagnosis.
5. **No outcome promises** — no "land the job", "guarantee", "ensures you get". Enforced
   by a test in `packages/launchpad_data/test`.
6. Errors explain what happened and what to do; no apologies, never vague.
7. Empty states invite action.
8. **No emoji in the product interface** (screen readers, rendering, contrast).
9. Numbers carry their source and as-of date, or they do not appear.

Recommendations (when built) must show their reasoning and provenance (`Evidence.kind`),
express confidence in words not percentages, offer multiple paths including non-degree
routes, never condition on protected characteristics or their proxies, and refer
out-of-scope situations to human services — see
`docs/product/career-recommendation-principles.md`.

## Privacy rules (`docs/privacy/privacy-design.md`)

Data minimisation is a design constraint. The product currently collects nothing, stores
nothing durably, transmits nothing — keep it that way:

- No analytics, advertising, attribution, or crash-reporting SDKs in the dependency tree.
  Check with `flutter pub deps` before adding any dependency.
- `InMemorySessionRepository` is deliberately not backed by `shared_preferences` or a
  database. Nothing the user types may survive a restart until a consent flow and a
  documented retention policy exist.
- **Never log personal information** — no user text, answers, or identifiers in logs,
  crash reports, or breadcrumbs. Free text is the highest-risk field.
- Ask only what changes the answer; explain at the point of asking; protected
  characteristics are not collected.
- Anonymous stays first-class: sign-in is never a gate on exploration. Local first.
  Deletion and export must exist before any durable storage ships.
- **No compliance claims** (FERPA, GDPR, CCPA, COPPA, …) anywhere — interface, README, or
  marketing — until legal and technical review is complete.
- Known leak path: Flutter's CanvasKit renderer can fetch fallback fonts from
  Google-hosted URLs at runtime. Self-host CanvasKit before making any "no third-party
  requests" claim.
- No signing credentials, provisioning profiles, or store secrets in this repository.

## Accessibility (`docs/accessibility/accessibility-requirements.md`)

WCAG 2.1 AA is part of the definition of done for every screen, and it is tested: 4.5:1
text contrast in both themes, 3:1 non-text boundaries, ≥ 48dp labelled tap targets,
keyboard operation via `ActivateIntent` (no hand-rolled key listeners), descriptions in
the semantics tree at all times, colour never the only signal, opaque text colours, all
durations from `AppMotion` with a real reduce-motion path, layout tested at 2× text
scale. Do not claim conformance anywhere; the audit has not happened.

## Known Flutter hazards — do not rediscover these

- **`AnimatedSize` must not be given `Duration.zero`.** `RenderAnimatedSize` restarts its
  controller inside `performLayout` and trips a "mutated in its own performLayout"
  assertion. The reduce-motion path drops the animation wrapper entirely instead of
  animating over zero milliseconds. See `_RevealedDescription`.
- **`tester.binding.setSurfaceSize` does not feed through to `MediaQuery`.** Layout tests
  relying on it run at the default 800×600 and pass for the wrong reason. Size
  `tester.view` directly.
- **Wrapping the app in a `MediaQuery` to fake brightness, text scale, or reduce-motion
  asserts nothing** — `WidgetsApp` rebuilds `MediaQuery.fromView` internally. Use
  `test/helpers.dart`, which sets these on the test `PlatformDispatcher`.
- **Riverpod 3 does not export the `Override` type**, so test helpers cannot declare
  `List<Override>` parameters. `test/helpers.dart` builds the override list internally
  for this reason.
- Widget tests pump the real `LaunchpadApp` with the real router and theme, not a
  simplified harness — a test that passes against a stand-in tree proves little.

## Run the tests before claiming work is done

Work is not done until the checks pass. Run:

```sh
./tool/dev.sh test    # every package's tests
./tool/dev.sh ci      # format check + analyze + test, exactly as CI does
```

Never report a change as complete without having run the tests and seen them pass. If
tests fail or cannot be run, say so explicitly instead of claiming success.
